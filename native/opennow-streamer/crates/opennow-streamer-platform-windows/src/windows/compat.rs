//! DirectX 10 compatibility bridge.
//!
//! Feature level 10_0 and 10_1 GPUs create a D3D11 device and decode H.264 through DXVA, but
//! they expose neither Shader Model 5.0 nor the D3D11 video processor that the normal Windows
//! pipeline uses for YCbCr-to-RGB conversion, ten-bit output and flip-model presentation. The
//! same gap appears on a DirectX 11 device whose driver refuses `ID3D11VideoDevice`, which is
//! what happens on the WARP software rasterizer Qt Quick falls back to when the hardware cannot
//! run its D3D11 RHI.
//!
//! This module owns the bounded replacement path:
//!
//! 1. [`CompatDecodeDevice`] creates a hardware D3D11 device that accepts feature level 10_x and
//!    hands Media Foundation its DXGI device manager, so DXVA decode still runs on the GPU.
//! 2. [`CompatConverter`] reads the decoded NV12 surface back through a staging texture and
//!    converts it once per frame on the decoder worker thread. The conversion math lives in
//!    [`crate::nv12_convert`] and is unit tested on every host.
//! 3. [`CompatUploader`] publishes the finished RGBA8 buffer into the presentation device as an
//!    ordinary texture, which needs no video interface and no Shader Model 5.0.
//! 4. [`CompatPresenter`] draws that texture into a bitblt-model back buffer with a Shader Model
//!    4.0 pair, keeping scaling and letterboxing on the GPU.
//!
//! The CPU read-back and conversion are the explicit, bounded cost of this path: one frame at a
//! time, video-sized output, and one reusable staging surface per extent.

use std::ffi::c_void;
use std::sync::Arc;

use ::windows::Win32::Foundation::{HMODULE, LUID};
use ::windows::Win32::Graphics::Direct3D::Fxc::D3DCompile;
use ::windows::Win32::Graphics::Direct3D::{
    D3D_DRIVER_TYPE_HARDWARE, D3D_FEATURE_LEVEL, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST, ID3DBlob,
};
use ::windows::Win32::Graphics::Direct3D10::ID3D10Multithread;
use ::windows::Win32::Graphics::Direct3D11::{
    D3D11_BIND_SHADER_RESOURCE, D3D11_COMPARISON_NEVER, D3D11_CPU_ACCESS_READ,
    D3D11_CPU_ACCESS_WRITE, D3D11_CREATE_DEVICE_BGRA_SUPPORT, D3D11_CREATE_DEVICE_VIDEO_SUPPORT,
    D3D11_CULL_NONE, D3D11_FILTER_MIN_MAG_MIP_LINEAR, D3D11_FILL_SOLID, D3D11_MAP_READ,
    D3D11_MAP_WRITE_DISCARD, D3D11_MAPPED_SUBRESOURCE, D3D11_RASTERIZER_DESC, D3D11_SAMPLER_DESC,
    D3D11_SDK_VERSION, D3D11_TEXTURE2D_DESC, D3D11_TEXTURE_ADDRESS_CLAMP, D3D11_USAGE_DYNAMIC,
    D3D11_USAGE_STAGING, D3D11_VIEWPORT, D3D11CreateDevice, ID3D11Device,
    ID3D11DeviceContext, ID3D11PixelShader, ID3D11RasterizerState, ID3D11RenderTargetView,
    ID3D11SamplerState, ID3D11ShaderResourceView, ID3D11Texture2D, ID3D11VertexShader,
};
use ::windows::Win32::Graphics::Dxgi::Common::{
    DXGI_FORMAT_NV12, DXGI_FORMAT_R8G8B8A8_UNORM, DXGI_SAMPLE_DESC,
};
use ::windows::Win32::Graphics::Dxgi::IDXGIDevice;
use ::windows::Win32::Media::MediaFoundation::{IMFDXGIDeviceManager, MFCreateDXGIDeviceManager};
use ::windows::core::{Interface, PCSTR};

use super::decoder::DecodedVideoFrame;
use super::embedded::MAX_FRAME_SLOTS;
use super::graphics::fit_rect;
use crate::VideoFormat;
use crate::aperture::VideoAperture;
use crate::feature_level::{self, DeviceFeatureLevel, FeatureTier, REQUESTED_FEATURE_LEVELS};
use crate::nv12_convert::{self, Nv12Surface, YuvRgbCoefficients};

/// One CPU-converted video frame, ready to upload into a presentation device.
///
/// The buffer is shared rather than copied so a frame can wait in the bounded decoded queue
/// without duplicating up to seven video-sized allocations.
#[derive(Clone)]
pub(crate) struct CompatPixels {
    pub(crate) width: u32,
    pub(crate) height: u32,
    pub(crate) data: Arc<Vec<u8>>,
}

impl CompatPixels {
    fn row_bytes(&self) -> usize {
        self.width as usize * 4
    }

    fn is_complete(&self) -> bool {
        self.width > 0
            && self.height > 0
            && self.data.len() >= self.width as usize * self.height as usize * 4
    }
}

fn requested_feature_levels() -> [D3D_FEATURE_LEVEL; REQUESTED_FEATURE_LEVELS.len()] {
    [
        D3D_FEATURE_LEVEL(REQUESTED_FEATURE_LEVELS[0]),
        D3D_FEATURE_LEVEL(REQUESTED_FEATURE_LEVELS[1]),
        D3D_FEATURE_LEVEL(REQUESTED_FEATURE_LEVELS[2]),
        D3D_FEATURE_LEVEL(REQUESTED_FEATURE_LEVELS[3]),
    ]
}

fn immediate_context_of(texture: &ID3D11Texture2D) -> Result<ID3D11DeviceContext, String> {
    unsafe {
        let device = texture
            .GetDevice()
            .map_err(|error| format!("compatibility frame texture device: {error}"))?;
        device
            .GetImmediateContext()
            .map_err(|error| format!("compatibility immediate context: {error}"))
    }
}

/// Hardware decode device for the compatibility path.
///
/// The adopted Qt device is unusable for Media Foundation here: either it is below feature level
/// 11_0 or it refuses the D3D11 video interfaces outright. This device is created on the default
/// hardware adapter with DirectX 10 feature levels included, so DXVA decode still runs on the GPU
/// while Qt presents through its own device.
pub(super) struct CompatDecodeDevice {
    device: ID3D11Device,
    manager: IMFDXGIDeviceManager,
    feature_level: Option<DeviceFeatureLevel>,
}

impl CompatDecodeDevice {
    pub(super) fn new() -> Result<Self, String> {
        let levels = requested_feature_levels();
        let mut device = None;
        let mut context = None;
        let mut raw_feature_level = D3D_FEATURE_LEVEL(0);
        let mut result = unsafe {
            D3D11CreateDevice(
                None,
                D3D_DRIVER_TYPE_HARDWARE,
                HMODULE::default(),
                D3D11_CREATE_DEVICE_BGRA_SUPPORT | D3D11_CREATE_DEVICE_VIDEO_SUPPORT,
                Some(&levels),
                D3D11_SDK_VERSION,
                Some(&mut device),
                Some(&mut raw_feature_level),
                Some(&mut context),
            )
        };
        if result.is_err() {
            // Some DirectX 10 drivers reject the video-support creation flag even though DXVA
            // decode works through Media Foundation's DXGI device manager. Retry once without it
            // instead of declaring the device unusable.
            video_log!(
                "DirectX 10 compatibility decode device retrying without video support: {result:?}"
            );
            device = None;
            context = None;
            raw_feature_level = D3D_FEATURE_LEVEL(0);
            result = unsafe {
                D3D11CreateDevice(
                    None,
                    D3D_DRIVER_TYPE_HARDWARE,
                    HMODULE::default(),
                    D3D11_CREATE_DEVICE_BGRA_SUPPORT,
                    Some(&levels),
                    D3D11_SDK_VERSION,
                    Some(&mut device),
                    Some(&mut raw_feature_level),
                    Some(&mut context),
                )
            };
        }
        result.map_err(|error| format!("DirectX 10 compatibility decode device: {error}"))?;
        let device = device.ok_or("D3D11CreateDevice returned no compatibility device")?;
        let context =
            context.ok_or("D3D11CreateDevice returned no compatibility immediate context")?;
        let feature_level = DeviceFeatureLevel::from_raw(raw_feature_level.0);
        unsafe {
            let multithread: ID3D10Multithread = context
                .cast()
                .map_err(|error| format!("compatibility decode context multithread: {error}"))?;
            let _ = multithread.SetMultithreadProtected(true);
        }
        let mut reset_token = 0;
        let mut manager = None;
        unsafe {
            MFCreateDXGIDeviceManager(&mut reset_token, &mut manager)
                .map_err(|error| format!("compatibility MFCreateDXGIDeviceManager: {error}"))?;
        }
        let manager =
            manager.ok_or("MFCreateDXGIDeviceManager returned no compatibility manager")?;
        unsafe {
            manager
                .ResetDevice(&device, reset_token)
                .map_err(|error| {
                    format!("compatibility IMFDXGIDeviceManager::ResetDevice: {error}")
                })?;
        }
        video_log!(
            "DirectX 10 compatibility decode device created featureLevel={} tier={}",
            feature_level.map(|level| level.label()).unwrap_or("unknown"),
            feature_level::tier_of(feature_level.map(|level| level.raw())).label(),
        );
        Ok(Self {
            device,
            manager,
            feature_level,
        })
    }

    pub(super) fn manager(&self) -> &IMFDXGIDeviceManager {
        &self.manager
    }

    pub(super) fn feature_level(&self) -> Option<DeviceFeatureLevel> {
        self.feature_level
    }

    pub(super) fn adapter_luid(&self) -> Result<LUID, String> {
        unsafe {
            let dxgi_device: IDXGIDevice = self
                .device
                .cast()
                .map_err(|error| format!("compatibility decode DXGI device: {error}"))?;
            let adapter = dxgi_device
                .GetAdapter()
                .map_err(|error| format!("compatibility decode adapter: {error}"))?;
            Ok(adapter
                .GetDesc()
                .map_err(|error| format!("compatibility decode adapter description: {error}"))?
                .AdapterLuid)
        }
    }
}

struct StagingSurface {
    width: u32,
    height: u32,
    texture: ID3D11Texture2D,
}

/// Reads decoded NV12 surfaces back and converts them on the calling thread.
///
/// Callers must run this on the decoder worker thread, never on Qt's render thread: `Map` blocks
/// until the GPU has finished the copy.
#[derive(Default)]
pub(super) struct CompatConverter {
    staging: Option<StagingSurface>,
}

impl CompatConverter {
    pub(super) fn convert(&mut self, frame: &DecodedVideoFrame) -> Result<CompatPixels, String> {
        self.convert_texture(&frame.texture, frame.subresource, frame.format, frame.aperture)
    }

    /// Converts one NV12 array slice of `texture`, ignoring the frame's sample lifetime. Used by
    /// the standalone presenter, which receives the decoded texture without its Media Foundation
    /// sample.
    pub(super) fn convert_texture(
        &mut self,
        texture: &ID3D11Texture2D,
        subresource: u32,
        format: VideoFormat,
        aperture: VideoAperture,
    ) -> Result<CompatPixels, String> {
        let coefficients = YuvRgbCoefficients::new(format)?;
        let mut description = D3D11_TEXTURE2D_DESC::default();
        unsafe {
            texture.GetDesc(&mut description);
        }
        if description.Format != DXGI_FORMAT_NV12 {
            return Err(format!(
                "DirectX 10 compatibility conversion needs NV12 decoder output, got DXGI format {}",
                description.Format.0
            ));
        }
        aperture.validate_extent(description.Width, description.Height)?;
        let device = unsafe {
            texture
                .GetDevice()
                .map_err(|error| format!("compatibility frame texture device: {error}"))?
        };
        let staging = self.staging_surface(&device, &description)?;
        let staging_texture = staging.texture.clone();
        let context = immediate_context_of(texture)?;
        let mut mapped = D3D11_MAPPED_SUBRESOURCE::default();
        unsafe {
            context.CopySubresourceRegion(
                &staging_texture,
                0,
                0,
                0,
                0,
                texture,
                subresource,
                None,
            );
            context
                .Map(&staging_texture, 0, D3D11_MAP_READ, 0, Some(&mut mapped))
                .map_err(|error| format!("map compatibility NV12 staging surface: {error}"))?;
        }
        let pixels = convert_mapped(&mapped, &description, aperture, &coefficients);
        unsafe {
            context.Unmap(&staging_texture, 0);
        }
        pixels
    }

    fn staging_surface(
        &mut self,
        device: &ID3D11Device,
        description: &D3D11_TEXTURE2D_DESC,
    ) -> Result<&StagingSurface, String> {
        if self.staging.as_ref().is_some_and(|staging| {
            staging.width == description.Width && staging.height == description.Height
        }) {
            return self
                .staging
                .as_ref()
                .ok_or_else(|| "no compatibility staging surface".to_owned());
        }
        let mut staging_description = *description;
        staging_description.Usage = D3D11_USAGE_STAGING;
        staging_description.BindFlags = 0;
        staging_description.CPUAccessFlags = D3D11_CPU_ACCESS_READ.0 as u32;
        staging_description.ArraySize = 1;
        staging_description.MipLevels = 1;
        staging_description.MiscFlags = 0;
        let mut staging = None;
        unsafe {
            device
                .CreateTexture2D(&staging_description, None, Some(&mut staging))
                .map_err(|error| format!("create compatibility NV12 staging surface: {error}"))?;
        }
        self.staging = Some(StagingSurface {
            width: description.Width,
            height: description.Height,
            texture: staging.ok_or("D3D11 returned no compatibility staging surface")?,
        });
        self.staging
            .as_ref()
            .ok_or_else(|| "no compatibility staging surface".to_owned())
    }
}

/// Converts one mapped NV12 staging surface. Kept separate so the mapping is always released,
/// including when the conversion rejects the negotiated color metadata.
fn convert_mapped(
    mapped: &D3D11_MAPPED_SUBRESOURCE,
    description: &D3D11_TEXTURE2D_DESC,
    aperture: VideoAperture,
    coefficients: &YuvRgbCoefficients,
) -> Result<CompatPixels, String> {
    if mapped.pData.is_null() {
        return Err("mapped compatibility staging surface has no data pointer".to_owned());
    }
    let row_pitch = mapped.RowPitch as usize;
    let rows = description.Height as usize + description.Height as usize / 2;
    let length = row_pitch
        .checked_mul(rows)
        .ok_or_else(|| {
            "compatibility NV12 staging surface size overflowed".to_owned()
        })?;
    let surface = Nv12Surface {
        data: unsafe { std::slice::from_raw_parts(mapped.pData.cast::<u8>(), length) },
        row_pitch,
        width: description.Width,
        height: description.Height,
    };
    surface.validate()?;
    let mut buffer = vec![0u8; nv12_convert::rgba8_len(aperture)];
    nv12_convert::nv12_to_rgba8(&surface, aperture, coefficients, &mut buffer)?;
    Ok(CompatPixels {
        width: aperture.width,
        height: aperture.height,
        data: Arc::new(buffer),
    })
}

struct CompatSlot {
    target: ID3D11Texture2D,
    view: ID3D11ShaderResourceView,
    width: u32,
    height: u32,
}

/// Uploads RGBA8 pixels into one slot texture of a presentation device.
///
/// The upload texture is `D3D11_USAGE_DYNAMIC` with write-discard access, so the runtime renames
/// it and the previous frame's GPU read is never disturbed.
pub(super) struct CompatUploader {
    device: ID3D11Device,
    slots: [Option<CompatSlot>; MAX_FRAME_SLOTS],
}

impl CompatUploader {
    pub(super) fn new(device: &ID3D11Device) -> Self {
        Self {
            device: device.clone(),
            slots: std::array::from_fn(|_| None),
        }
    }

    /// Fills `slot` and returns the native texture pointer published to Qt plus a shader-resource
    /// view for the compatibility present draw.
    pub(super) fn upload(
        &mut self,
        context: &ID3D11DeviceContext,
        slot: usize,
        pixels: &CompatPixels,
    ) -> Result<(*mut c_void, ID3D11ShaderResourceView), String> {
        if slot >= MAX_FRAME_SLOTS {
            return Err(format!("invalid compatibility frame slot {slot}"));
        }
        if !pixels.is_complete() {
            return Err(
                "compatibility frame pixels do not match the reported extent".to_owned()
            );
        }
        let needs_slot = match self.slots[slot].as_ref() {
            Some(existing) => existing.width != pixels.width || existing.height != pixels.height,
            None => true,
        };
        if needs_slot {
            self.slots[slot] = Some(self.create_slot(pixels)?);
        }
        let active = self.slots[slot]
            .as_ref()
            .ok_or_else(|| "no compatibility frame slot".to_owned())?;
        // The slot texture is the published one, so writing it needs no GPU copy: `Map` with
        // write-discard access hands back renamed memory and Qt's previous sample of this slot is
        // left untouched.
        let mut mapped = D3D11_MAPPED_SUBRESOURCE::default();
        unsafe {
            context
                .Map(&active.target, 0, D3D11_MAP_WRITE_DISCARD, 0, Some(&mut mapped))
                .map_err(|error| format!("map compatibility upload surface: {error}"))?;
        }
        let copy = write_rows(&mapped, pixels);
        unsafe {
            context.Unmap(&active.target, 0);
        }
        copy?;
        Ok((active.target.as_raw(), active.view.clone()))
    }

    fn create_slot(&self, pixels: &CompatPixels) -> Result<CompatSlot, String> {
        let description = D3D11_TEXTURE2D_DESC {
            Width: pixels.width,
            Height: pixels.height,
            MipLevels: 1,
            ArraySize: 1,
            Format: DXGI_FORMAT_R8G8B8A8_UNORM,
            SampleDesc: DXGI_SAMPLE_DESC {
                Count: 1,
                Quality: 0,
            },
            // Written by the CPU every presented frame and sampled by the presenter, which is what
            // dynamic usage is for. A dynamic resource cannot also be a render target, and neither
            // Qt's texture import nor the Shader Model 4.0 present draw needs one: both only read
            // the shader-resource view. Feature level 10_0 supports this description.
            Usage: D3D11_USAGE_DYNAMIC,
            BindFlags: D3D11_BIND_SHADER_RESOURCE.0 as u32,
            CPUAccessFlags: D3D11_CPU_ACCESS_WRITE.0 as u32,
            MiscFlags: 0,
        };
        let mut target = None;
        let mut view = None;
        unsafe {
            self.device
                .CreateTexture2D(&description, None, Some(&mut target))
                .map_err(|error| format!("create compatibility frame slot: {error}"))?;
        }
        let target = target.ok_or("D3D11 returned no compatibility frame slot")?;
        unsafe {
            self.device
                .CreateShaderResourceView(&target, None, Some(&mut view))
                .map_err(|error| format!("create compatibility frame slot view: {error}"))?;
        }
        Ok(CompatSlot {
            target,
            view: view.ok_or("D3D11 returned no compatibility frame slot view")?,
            width: pixels.width,
            height: pixels.height,
        })
    }
}

/// Copies tightly packed RGBA8 rows into a mapped surface, honoring its reported row pitch.
fn write_rows(mapped: &D3D11_MAPPED_SUBRESOURCE, pixels: &CompatPixels) -> Result<(), String> {
    if mapped.pData.is_null() {
        return Err("mapped compatibility upload surface has no data pointer".to_owned());
    }
    let row_bytes = pixels.row_bytes();
    let pitch = mapped.RowPitch as usize;
    if pitch < row_bytes {
        return Err(format!(
            "compatibility upload row pitch {pitch} is smaller than the {row_bytes} byte row"
        ));
    }
    for row in 0..pixels.height as usize {
        let source = row * row_bytes;
        unsafe {
            std::ptr::copy_nonoverlapping(
                pixels.data[source..source + row_bytes].as_ptr(),
                mapped.pData.cast::<u8>().add(row * pitch),
                row_bytes,
            );
        }
    }
    Ok(())
}

#[derive(Clone)]
struct CompatOutput {
    view: ID3D11RenderTargetView,
    backbuffer: usize,
    width: u32,
    height: u32,
}

/// Standalone DirectX 10 presenter: CPU conversion plus a Shader Model 4.0 letterbox draw.
pub(super) struct CompatPresenter {
    context: ID3D11DeviceContext,
    converter: CompatConverter,
    uploader: CompatUploader,
    vertex: ID3D11VertexShader,
    pixel: ID3D11PixelShader,
    sampler: ID3D11SamplerState,
    rasterizer: ID3D11RasterizerState,
    output: Option<CompatOutput>,
}

impl CompatPresenter {
    pub(super) fn new(
        device: &ID3D11Device,
        context: &ID3D11DeviceContext,
    ) -> Result<Self, String> {
        let shader_model = FeatureTier::Direct3d10.shader_model();
        let vertex_code = compile(c"vertex_main", shader_model.vertex_target())?;
        let pixel_code = compile(c"pixel_main", shader_model.pixel_target())?;
        let mut vertex = None;
        let mut pixel = None;
        unsafe {
            device
                .CreateVertexShader(
                    std::slice::from_raw_parts(
                        vertex_code.GetBufferPointer().cast(),
                        vertex_code.GetBufferSize(),
                    ),
                    None,
                    Some(&mut vertex),
                )
                .map_err(|error| format!("create compatibility vertex shader: {error}"))?;
            device
                .CreatePixelShader(
                    std::slice::from_raw_parts(
                        pixel_code.GetBufferPointer().cast(),
                        pixel_code.GetBufferSize(),
                    ),
                    None,
                    Some(&mut pixel),
                )
                .map_err(|error| format!("create compatibility pixel shader: {error}"))?;
        }
        let mut sampler = None;
        let mut rasterizer = None;
        unsafe {
            device
                .CreateSamplerState(
                    &D3D11_SAMPLER_DESC {
                        Filter: D3D11_FILTER_MIN_MAG_MIP_LINEAR,
                        AddressU: D3D11_TEXTURE_ADDRESS_CLAMP,
                        AddressV: D3D11_TEXTURE_ADDRESS_CLAMP,
                        AddressW: D3D11_TEXTURE_ADDRESS_CLAMP,
                        ComparisonFunc: D3D11_COMPARISON_NEVER,
                        MaxLOD: f32::MAX,
                        ..Default::default()
                    },
                    Some(&mut sampler),
                )
                .map_err(|error| format!("create compatibility sampler: {error}"))?;
            device
                .CreateRasterizerState(
                    &D3D11_RASTERIZER_DESC {
                        FillMode: D3D11_FILL_SOLID,
                        CullMode: D3D11_CULL_NONE,
                        DepthClipEnable: true.into(),
                        ..Default::default()
                    },
                    Some(&mut rasterizer),
                )
                .map_err(|error| format!("create compatibility rasterizer: {error}"))?;
        }
        video_log!(
            "DirectX 10 compatibility presenter ready ({} / {})",
            shader_model.vertex_target().to_string_lossy(),
            shader_model.pixel_target().to_string_lossy(),
        );
        Ok(Self {
            context: context.clone(),
            converter: CompatConverter::default(),
            uploader: CompatUploader::new(device),
            vertex: vertex.ok_or("no compatibility vertex shader")?,
            pixel: pixel.ok_or("no compatibility pixel shader")?,
            sampler: sampler.ok_or("no compatibility sampler")?,
            rasterizer: rasterizer.ok_or("no compatibility rasterizer")?,
            output: None,
        })
    }

    /// Converts one decoded frame, uploads the RGBA8 result and draws it into `backbuffer`.
    ///
    /// `target` is the back buffer extent in pixels; the draw is letterboxed inside it with
    /// [`fit_rect`], matching the video processor's destination rectangle.
    pub(super) fn present_texture(
        &mut self,
        texture: &ID3D11Texture2D,
        subresource: u32,
        format: VideoFormat,
        aperture: VideoAperture,
        backbuffer: &ID3D11Texture2D,
        target: (u32, u32),
    ) -> Result<(), String> {
        let pixels = self
            .converter
            .convert_texture(texture, subresource, format, aperture)?;
        let context = self.context.clone();
        let (_, view) = self.uploader.upload(&context, 0, &pixels)?;
        let output_view = self.output_view(backbuffer, target)?;
        let destination = fit_rect(pixels.width, pixels.height, target.0, target.1);
        unsafe {
            self.context
                .ClearRenderTargetView(&output_view, &[0.0, 0.0, 0.0, 1.0]);
            self.context
                .IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
            self.context.VSSetShader(&self.vertex, None);
            self.context.PSSetShader(&self.pixel, None);
            self.context
                .PSSetShaderResources(0, Some(&[Some(view)]));
            self.context
                .PSSetSamplers(0, Some(&[Some(self.sampler.clone())]));
            self.context.RSSetState(&self.rasterizer);
            self.context.RSSetViewports(Some(&[D3D11_VIEWPORT {
                TopLeftX: destination.left as f32,
                TopLeftY: destination.top as f32,
                Width: (destination.right - destination.left).max(1) as f32,
                Height: (destination.bottom - destination.top).max(1) as f32,
                MinDepth: 0.0,
                MaxDepth: 1.0,
            }]));
            self.context
                .OMSetRenderTargets(Some(&[Some(output_view)]), None);
            self.context.Draw(3, 0);
            // Release the back buffer and the source view before DXGI presents the chain.
            self.context.OMSetRenderTargets(Some(&[]), None);
            self.context.PSSetShaderResources(0, Some(&[]));
            self.context.Flush();
        }
        Ok(())
    }

    fn output_view(
        &mut self,
        backbuffer: &ID3D11Texture2D,
        target: (u32, u32),
    ) -> Result<ID3D11RenderTargetView, String> {
        let identity = backbuffer.as_raw() as usize;
        if let Some(output) = self.output.as_ref() {
            if output.backbuffer == identity && output.width == target.0 && output.height == target.1
            {
                return Ok(output.view.clone());
            }
        }
        let device = unsafe {
            backbuffer
                .GetDevice()
                .map_err(|error| format!("compatibility back buffer device: {error}"))?
        };
        let mut view = None;
        unsafe {
            device
                .CreateRenderTargetView(backbuffer, None, Some(&mut view))
                .map_err(|error| format!("create compatibility back buffer view: {error}"))?;
        }
        let view = view.ok_or("D3D11 returned no compatibility back buffer view")?;
        self.output = Some(CompatOutput {
            view: view.clone(),
            backbuffer: identity,
            width: target.0,
            height: target.1,
        });
        Ok(view)
    }
}

fn compile(entry: &std::ffi::CStr, target: &std::ffi::CStr) -> Result<ID3DBlob, String> {
    let source = include_bytes!("compat_present.hlsl");
    let mut code = None;
    let mut errors = None;
    let result = unsafe {
        D3DCompile(
            source.as_ptr().cast(),
            source.len(),
            PCSTR::null(),
            None,
            None,
            PCSTR(entry.as_ptr().cast()),
            PCSTR(target.as_ptr().cast()),
            0,
            0,
            &mut code,
            Some(&mut errors),
        )
    };
    if let Err(error) = result {
        let detail = errors
            .map(|errors| unsafe {
                String::from_utf8_lossy(std::slice::from_raw_parts(
                    errors.GetBufferPointer().cast(),
                    errors.GetBufferSize(),
                ))
                .into_owned()
            })
            .unwrap_or_default();
        return Err(format!("compile compatibility shader: {error}: {detail}"));
    }
    code.ok_or_else(|| "no compatibility shader bytecode".to_owned())
}
