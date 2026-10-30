//! Explicit, bounded system-memory decode -> D3D11 texture upload. This is
//! never used by the normal GPU decode path. Qt still owns the only presenter.
use super::decoder::{DecodedSurface, DecodedVideoFrame, DecoderDevice};
use super::embedded::{
    AdoptedD3d11Context, D3d11ColorSpace, D3d11RecordedFrame, D3d11TextureFormat, MAX_FRAME_SLOTS,
    clone_interface, com_identity, d3d11_adapter_luid, enable_multithread_protection,
};
use crate::VideoFormat;
use crate::compatibility::{Nv12Layout, SdrConstants, validate_format};
use ::windows::Win32::Foundation::LUID;
use ::windows::Win32::Graphics::Direct3D::D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST;
use ::windows::Win32::Graphics::Direct3D11::*;
use ::windows::Win32::Graphics::Dxgi::Common::{
    DXGI_FORMAT, DXGI_FORMAT_R8_UNORM, DXGI_FORMAT_R8G8_UNORM, DXGI_FORMAT_R8G8B8A8_UNORM,
    DXGI_SAMPLE_DESC,
};
use ::windows::Win32::Media::MediaFoundation::{
    IMF2DBuffer2, IMFDXGIBuffer, IMFDXGIDeviceManager, IMFMediaBuffer, IMFSample,
    MF2DBuffer_LockFlags_Read,
};
use ::windows::core::Interface;
use std::ffi::c_void;

pub(super) struct CpuNv12Surface {
    buffer: IMFMediaBuffer,
    width: u32,
    height: u32,
    stride: i32,
}

impl CpuNv12Surface {
    pub(super) fn new(
        sample: &IMFSample,
        width: u32,
        height: u32,
        stride: i32,
    ) -> Result<Self, String> {
        // Validate metadata before either Media Foundation or D3D11 can use it
        // to size a copy. Actual pitch and byte extent are checked while locked.
        Nv12Layout::new(width, height, stride, usize::MAX)?;
        let buffer = unsafe { sample.ConvertToContiguousBuffer() }
            .map_err(|error| format!("software decoder contiguous output: {error}"))?;
        if buffer.cast::<IMFDXGIBuffer>().is_ok() {
            return Err(
                "software compatibility decoder unexpectedly returned a DXGI surface".to_owned(),
            );
        }
        Ok(Self {
            buffer,
            width,
            height,
            stride,
        })
    }

    fn lock(&self) -> Result<LockedNv12<'_>, String> {
        let two_d = self.buffer.cast::<IMF2DBuffer2>().ok();
        let mut scanline = std::ptr::null_mut();
        let mut start = std::ptr::null_mut();
        let mut pitch = self.stride;
        let mut len = 0;
        if let Some(buffer) = &two_d {
            unsafe {
                buffer.Lock2DSize(
                    MF2DBuffer_LockFlags_Read,
                    &mut scanline,
                    &mut pitch,
                    &mut start,
                    &mut len,
                )
            }
            .map_err(|error| format!("lock 2D software video: {error}"))?;
        } else {
            unsafe { self.buffer.Lock(&mut scanline, None, Some(&mut len)) }
                .map_err(|error| format!("lock software video: {error}"))?;
            start = scanline;
        }
        // Construct the unlock guard before validation; every failure must
        // release the MF buffer lock as well as its tracked sample lease.
        let mut locked = LockedNv12 {
            surface: self,
            two_d,
            scanline,
            layout: Nv12Layout {
                width: self.width,
                height: self.height,
                pitch: 0,
                uv_offset: 0,
                byte_len: 0,
            },
        };
        let offset = (scanline as usize)
            .checked_sub(start as usize)
            .filter(|offset| *offset <= len as usize)
            .ok_or("invalid software video scanline address")?;
        if scanline.is_null() || start.is_null() {
            return Err("null software video buffer".to_owned());
        }
        locked.layout = Nv12Layout::new(self.width, self.height, pitch, len as usize - offset)?;
        Ok(locked)
    }
}

struct LockedNv12<'a> {
    surface: &'a CpuNv12Surface,
    two_d: Option<IMF2DBuffer2>,
    scanline: *mut u8,
    layout: Nv12Layout,
}
impl Drop for LockedNv12<'_> {
    fn drop(&mut self) {
        unsafe {
            if let Some(buffer) = &self.two_d {
                let _ = buffer.Unlock2D();
            } else {
                let _ = self.surface.buffer.Unlock();
            }
        }
    }
}

struct Plane {
    texture: ID3D11Texture2D,
    view: ID3D11ShaderResourceView,
}
struct OutputSlot {
    texture: ID3D11Texture2D,
    view: ID3D11RenderTargetView,
}
struct Converter {
    format: VideoFormat,
    aperture: crate::aperture::VideoAperture,
    extent: (u32, u32),
    y: Plane,
    uv: Plane,
    deferred: ID3D11DeviceContext,
    vertex: ID3D11VertexShader,
    pixel: ID3D11PixelShader,
    constants: ID3D11Buffer,
    sampler: ID3D11SamplerState,
    rasterizer: ID3D11RasterizerState,
    slots: [Option<OutputSlot>; MAX_FRAME_SLOTS],
}

pub(super) struct CompatibilityResources {
    device: ID3D11Device,
    context: ID3D11DeviceContext,
    format: VideoFormat,
    converter: Option<Converter>,
    generation: u64,
}

impl CompatibilityResources {
    pub(super) unsafe fn new(
        adopted: AdoptedD3d11Context,
        format: VideoFormat,
    ) -> Result<Self, String> {
        validate_format(format)?;
        let device = unsafe { clone_interface::<ID3D11Device>(adopted.device)? };
        let context = unsafe { clone_interface::<ID3D11DeviceContext>(adopted.immediate_context)? };
        let context_device = unsafe { context.GetDevice() }.map_err(|error| error.to_string())?;
        if com_identity(&device)? != com_identity(&context_device)? {
            return Err(
                "Qt compatibility context does not belong to the adopted device".to_owned(),
            );
        }
        enable_multithread_protection(&context)?;
        Ok(Self {
            device,
            context,
            format,
            converter: None,
            generation: 0,
        })
    }

    pub(super) unsafe fn validate_adopted_context(
        &self,
        adopted: AdoptedD3d11Context,
    ) -> Result<(), String> {
        let device = unsafe { clone_interface::<ID3D11Device>(adopted.device)? };
        let context = unsafe { clone_interface::<ID3D11DeviceContext>(adopted.immediate_context)? };
        if com_identity(&device)? != com_identity(&self.device)?
            || com_identity(&context)? != com_identity(&self.context)?
        {
            return Err("compatibility frame belongs to an older Qt graphics context".to_owned());
        }
        Ok(())
    }

    pub(super) fn record(
        &mut self,
        frame_slot: u32,
        frame: &DecodedVideoFrame,
    ) -> Result<D3d11RecordedFrame, String> {
        let slot = frame_slot as usize;
        if slot >= MAX_FRAME_SLOTS {
            return Err("invalid compatibility frame slot".to_owned());
        }
        let DecodedSurface::Nv12(surface) = &frame.surface else {
            return Err(
                "hardware video surface cannot enter the compatibility uploader".to_owned(),
            );
        };
        validate_format(frame.format)?;
        frame
            .aperture
            .validate_extent(surface.width, surface.height)?;
        let locked = surface.lock()?;
        let extent = (locked.layout.width, locked.layout.height);
        if self.converter.as_ref().is_none_or(|converter| {
            converter.format != frame.format
                || converter.aperture != frame.aperture
                || converter.extent != extent
        }) {
            self.converter = None;
            self.converter = Some(Converter::new(&self.device, frame, extent)?);
        }
        let converter = self
            .converter
            .as_mut()
            .ok_or("no compatibility converter")?;
        if converter.slots[slot].is_none() {
            let texture = create_texture(
                &self.device,
                frame.aperture.width,
                frame.aperture.height,
                DXGI_FORMAT_R8G8B8A8_UNORM,
                D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_RENDER_TARGET,
            )?;
            let mut view = None;
            unsafe {
                self.device
                    .CreateRenderTargetView(&texture, None, Some(&mut view))
            }
            .map_err(|error| format!("create compatibility output view: {error}"))?;
            converter.slots[slot] = Some(OutputSlot {
                texture,
                view: view.ok_or("no compatibility output view")?,
            });
        }
        let output = converter.slots[slot]
            .as_ref()
            .ok_or("no compatibility output slot")?;
        unsafe {
            // Upload only NV12 (1.5 bytes/pixel), not a CPU-converted RGBA
            // image. Both planes and visited output slots are reused. These
            // immediate-context copies precede the draw on Qt's same queue.
            self.context.UpdateSubresource(
                &converter.y.texture,
                0,
                None,
                locked.scanline.cast(),
                locked.layout.pitch,
                0,
            );
            self.context.UpdateSubresource(
                &converter.uv.texture,
                0,
                None,
                locked.scanline.add(locked.layout.uv_offset).cast(),
                locked.layout.pitch,
                0,
            );
            converter
                .deferred
                .IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
            converter.deferred.VSSetShader(&converter.vertex, None);
            converter.deferred.PSSetShader(&converter.pixel, None);
            converter.deferred.PSSetShaderResources(
                0,
                Some(&[
                    Some(converter.y.view.clone()),
                    Some(converter.uv.view.clone()),
                ]),
            );
            converter
                .deferred
                .PSSetSamplers(0, Some(&[Some(converter.sampler.clone())]));
            converter
                .deferred
                .PSSetConstantBuffers(0, Some(&[Some(converter.constants.clone())]));
            converter.deferred.RSSetState(&converter.rasterizer);
            converter.deferred.RSSetViewports(Some(&[D3D11_VIEWPORT {
                Width: frame.aperture.width as f32,
                Height: frame.aperture.height as f32,
                MaxDepth: 1.0,
                ..Default::default()
            }]));
            converter
                .deferred
                .OMSetRenderTargets(Some(&[Some(output.view.clone())]), None);
            converter.deferred.Draw(3, 0);
            let mut commands = None;
            converter
                .deferred
                .FinishCommandList(false, Some(&mut commands))
                .map_err(|error| format!("finish compatibility conversion: {error}"))?;
            self.context
                .ExecuteCommandList(&commands.ok_or("no compatibility commands")?, true);
            self.device
                .GetDeviceRemovedReason()
                .map_err(|error| format!("compatibility device lost: {error}"))?;
        }
        self.generation = self.generation.wrapping_add(1).max(1);
        Ok(D3d11RecordedFrame {
            texture: output.texture.as_raw(),
            texture_format: D3d11TextureFormat::Rgba8,
            color_space: D3d11ColorSpace::Sdr709,
            width: frame.aperture.width,
            height: frame.aperture.height,
            frame_slot,
            generation: self.generation,
            presentation_time_ns: u64::try_from(frame.timestamp_100ns.max(0))
                .unwrap_or(0)
                .saturating_mul(100),
        })
    }
}

impl DecoderDevice for CompatibilityResources {
    fn device_manager(&self) -> Option<&IMFDXGIDeviceManager> {
        None
    }
    fn adapter_luid(&self) -> Result<LUID, String> {
        let raw = unsafe { d3d11_adapter_luid(self.device.as_raw()) }?.get();
        Ok(LUID {
            LowPart: raw as u32,
            HighPart: (raw >> 32) as u32 as i32,
        })
    }
    fn video_format(&self) -> VideoFormat {
        self.format
    }
}

fn create_texture(
    device: &ID3D11Device,
    width: u32,
    height: u32,
    format: DXGI_FORMAT,
    bind: D3D11_BIND_FLAG,
) -> Result<ID3D11Texture2D, String> {
    let mut texture = None;
    unsafe {
        device.CreateTexture2D(
            &D3D11_TEXTURE2D_DESC {
                Width: width,
                Height: height,
                MipLevels: 1,
                ArraySize: 1,
                Format: format,
                SampleDesc: DXGI_SAMPLE_DESC {
                    Count: 1,
                    Quality: 0,
                },
                Usage: D3D11_USAGE_DEFAULT,
                BindFlags: bind.0 as u32,
                ..Default::default()
            },
            None,
            Some(&mut texture),
        )
    }
    .map_err(|error| format!("create compatibility texture: {error}"))?;
    texture.ok_or_else(|| "no compatibility texture".to_owned())
}

impl Converter {
    fn new(
        device: &ID3D11Device,
        frame: &DecodedVideoFrame,
        extent: (u32, u32),
    ) -> Result<Self, String> {
        let parameters = SdrConstants::new(
            frame.format,
            extent.0,
            extent.1,
            frame.aperture.x,
            frame.aperture.y,
        )?;
        let plane = |width, height, format| -> Result<Plane, String> {
            let texture =
                create_texture(device, width, height, format, D3D11_BIND_SHADER_RESOURCE)?;
            let mut view = None;
            unsafe { device.CreateShaderResourceView(&texture, None, Some(&mut view)) }
                .map_err(|error| format!("create compatibility input view: {error}"))?;
            Ok(Plane {
                texture,
                view: view.ok_or("no compatibility input view")?,
            })
        };
        let y = plane(extent.0, extent.1, DXGI_FORMAT_R8_UNORM)?;
        let uv = plane(extent.0 / 2, extent.1 / 2, DXGI_FORMAT_R8G8_UNORM)?;
        let source = include_bytes!("compatibility.hlsl");
        let vertex_code = super::shader::compile(source, c"vertex_main", c"vs_4_0")?;
        let pixel_code = super::shader::compile(source, c"pixel_main", c"ps_4_0")?;
        let mut vertex = None;
        let mut pixel = None;
        let mut deferred = None;
        let mut constants = None;
        let mut sampler = None;
        let mut rasterizer = None;
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
            device
                .CreateDeferredContext(0, Some(&mut deferred))
                .map_err(|error| error.to_string())?;
            device
                .CreateBuffer(
                    &D3D11_BUFFER_DESC {
                        ByteWidth: std::mem::size_of::<SdrConstants>() as u32,
                        Usage: D3D11_USAGE_IMMUTABLE,
                        BindFlags: D3D11_BIND_CONSTANT_BUFFER.0 as u32,
                        ..Default::default()
                    },
                    Some(&D3D11_SUBRESOURCE_DATA {
                        pSysMem: std::ptr::from_ref(&parameters).cast::<c_void>(),
                        ..Default::default()
                    }),
                    Some(&mut constants),
                )
                .map_err(|error| format!("create compatibility constants: {error}"))?;
            device
                .CreateSamplerState(
                    &D3D11_SAMPLER_DESC {
                        Filter: D3D11_FILTER_MIN_MAG_LINEAR_MIP_POINT,
                        AddressU: D3D11_TEXTURE_ADDRESS_CLAMP,
                        AddressV: D3D11_TEXTURE_ADDRESS_CLAMP,
                        AddressW: D3D11_TEXTURE_ADDRESS_CLAMP,
                        MaxLOD: f32::MAX,
                        MaxAnisotropy: 1,
                        ComparisonFunc: D3D11_COMPARISON_NEVER,
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
                .map_err(|error| error.to_string())?;
        }
        Ok(Self {
            format: frame.format,
            aperture: frame.aperture,
            extent,
            y,
            uv,
            deferred: deferred.ok_or("no compatibility deferred context")?,
            vertex: vertex.ok_or("no compatibility vertex shader")?,
            pixel: pixel.ok_or("no compatibility pixel shader")?,
            constants: constants.ok_or("no compatibility constants")?,
            sampler: sampler.ok_or("no compatibility sampler")?,
            rasterizer: rasterizer.ok_or("no compatibility rasterizer")?,
            slots: std::array::from_fn(|_| None),
        })
    }
}

pub(crate) fn is_software_adapter(luid: Option<crate::WindowsAdapterLuid>) -> Result<bool, String> {
    let Some(adapter) = super::graphics::resolve_adapter(luid)? else {
        return Ok(false);
    };
    let adapter: ::windows::Win32::Graphics::Dxgi::IDXGIAdapter1 = adapter
        .cast()
        .map_err(|error| format!("compatibility adapter interface: {error}"))?;
    let description = unsafe { adapter.GetDesc1() }.map_err(|error| error.to_string())?;
    Ok(
        description.Flags & ::windows::Win32::Graphics::Dxgi::DXGI_ADAPTER_FLAG_SOFTWARE.0 as u32
            != 0,
    )
}

// Repeated Qt capability refreshes must not start a decoder or compile the
// upload shaders each time. Cache only successful, adapter-specific probes for
// five seconds; failures remain immediately retryable. No COM/device is cached.
pub(crate) fn probe(luid: Option<crate::WindowsAdapterLuid>) -> Result<(), String> {
    use std::sync::Mutex;
    use std::time::{Duration, Instant};
    static READY: Mutex<Vec<(crate::WindowsAdapterLuid, Instant)>> = Mutex::new(Vec::new());
    if !is_software_adapter(luid)? {
        return Err("compatibility mode requires the explicitly selected WARP adapter".to_owned());
    }
    let luid = luid.ok_or("missing compatibility adapter")?;
    if READY
        .lock()
        .unwrap_or_else(|error| error.into_inner())
        .iter()
        .any(|(key, at)| *key == luid && at.elapsed() < Duration::from_secs(5))
    {
        return Ok(());
    }
    probe_uncached(Some(luid))?;
    let mut cache = READY.lock().unwrap_or_else(|error| error.into_inner());
    cache.retain(|(key, _)| *key != luid);
    if cache.len() == 4 {
        cache.remove(0);
    }
    cache.push((luid, Instant::now()));
    Ok(())
}

fn probe_uncached(luid: Option<crate::WindowsAdapterLuid>) -> Result<(), String> {
    use super::decoder::Decoder;
    use super::embedded::{DecoderThreadApartment, EmbeddedMediaRuntime};
    use crate::{
        VideoChromaFormat, VideoChromaSiting, VideoCodec, VideoColorMatrix, VideoColorPrimaries,
        VideoPixelFormat, VideoTransferFunction, WindowsDecoderMode,
    };
    use std::num::NonZeroU32;
    let _apartment = DecoderThreadApartment::initialize()?;
    let _runtime = EmbeddedMediaRuntime::initialize()?;
    let adapter = super::graphics::resolve_adapter(luid)?.ok_or("missing compatibility adapter")?;
    let (device, context) = super::graphics::create_d3d11_device(Some(&adapter), false)?;
    let adopted = AdoptedD3d11Context {
        device: device.as_raw(),
        immediate_context: context.as_raw(),
    };
    let format = VideoFormat {
        codec: VideoCodec::H264,
        width: 64,
        height: 64,
        frame_rate_numerator: NonZeroU32::new(60).unwrap(),
        frame_rate_denominator: NonZeroU32::new(1).unwrap(),
        average_bitrate: 10_000_000,
        pixel_format: VideoPixelFormat::Nv12,
        chroma_format: VideoChromaFormat::Cs420,
        full_range: false,
        chroma_siting: VideoChromaSiting::Left,
        transfer_function: VideoTransferFunction::Sdr,
        color_primaries: VideoColorPrimaries::Bt709,
        color_matrix: VideoColorMatrix::Bt709,
    };
    let mut resources = unsafe { CompatibilityResources::new(adopted, format) }?;
    let mut decoder = Decoder::new(&resources, format, WindowsDecoderMode::Software)?;
    let frame = decoder.probe_frame(include_bytes!("../../fixtures/probe/h264-nv12-sdr.h264"))?;
    resources.record(0, &frame)?;
    // D3D11 retains the submitted commands and their resources. No synchronous
    // GPU wait belongs on the native host or Qt render thread.
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::super::decoder::Decoder;
    use super::super::embedded::{DecoderThreadApartment, EmbeddedMediaRuntime};
    use super::*;
    use crate::{WindowsAdapterLuid, WindowsDecoderMode};
    use ::windows::Win32::Graphics::Dxgi::{CreateDXGIFactory1, IDXGIAdapter, IDXGIFactory4};
    use ::windows::Win32::Media::MediaFoundation::{MFCreateMemoryBuffer, MFCreateSample};

    fn warp() -> (ID3D11Device, ID3D11DeviceContext, WindowsAdapterLuid) {
        let factory: IDXGIFactory4 = unsafe { CreateDXGIFactory1() }.expect("DXGI factory");
        let adapter: IDXGIAdapter = unsafe { factory.EnumWarpAdapter() }.expect("WARP adapter");
        let description = unsafe { adapter.GetDesc() }.unwrap();
        let luid = WindowsAdapterLuid::new(
            u64::from(description.AdapterLuid.LowPart)
                | ((description.AdapterLuid.HighPart as u32 as u64) << 32),
        )
        .unwrap();
        let (device, context) =
            super::super::graphics::create_d3d11_device(Some(&adapter), false).expect("D3D11 WARP");
        (device, context, luid)
    }
    fn format() -> VideoFormat {
        VideoFormat {
            width: 64,
            height: 64,
            ..crate::compatibility::tests::format()
        }
    }
    fn adopted(device: &ID3D11Device, context: &ID3D11DeviceContext) -> AdoptedD3d11Context {
        AdoptedD3d11Context {
            device: device.as_raw(),
            immediate_context: context.as_raw(),
        }
    }
    fn sample(format: VideoFormat, len: usize) -> (DecodedVideoFrame, IMFMediaBuffer) {
        let buffer = unsafe { MFCreateMemoryBuffer(len as u32) }.unwrap();
        let mut pointer = std::ptr::null_mut();
        unsafe {
            buffer.Lock(&mut pointer, None, None).unwrap();
            let bytes = std::slice::from_raw_parts_mut(pointer, len);
            bytes.fill(255); // Deliberately poison the codec's invisible padding.
            if len >= 80 * 120 {
                for row in 0..64 {
                    bytes[row * 80..row * 80 + 32].fill(if format.full_range { 0 } else { 16 });
                    bytes[row * 80 + 32..row * 80 + 64].fill(if format.full_range {
                        255
                    } else {
                        235
                    });
                }
                for row in 0..32 {
                    bytes[80 * 80 + row * 80..80 * 80 + row * 80 + 64].fill(128);
                }
            }
            buffer.Unlock().unwrap();
            buffer.SetCurrentLength(len as u32).unwrap();
        }
        let sample = unsafe { MFCreateSample() }.unwrap();
        unsafe {
            sample.AddBuffer(&buffer).unwrap();
            sample.SetSampleTime(12345).unwrap();
            sample
                .SetSampleDuration(format.frame_duration_100ns())
                .unwrap();
        }
        let aperture = crate::aperture::VideoAperture::new(64, 64, None).unwrap();
        (
            DecodedVideoFrame::from_memory_sample(sample, format, aperture, 64, 80, 80).unwrap(),
            buffer,
        )
    }
    fn pixel(
        device: &ID3D11Device,
        context: &ID3D11DeviceContext,
        frame: D3d11RecordedFrame,
        x: usize,
        y: usize,
    ) -> [u8; 4] {
        let texture = unsafe { clone_interface::<ID3D11Texture2D>(frame.texture) }.unwrap();
        let mut description = D3D11_TEXTURE2D_DESC::default();
        unsafe {
            texture.GetDesc(&mut description);
        }
        description.Usage = D3D11_USAGE_STAGING;
        description.BindFlags = 0;
        description.CPUAccessFlags = D3D11_CPU_ACCESS_READ.0 as u32;
        let mut staging = None;
        unsafe { device.CreateTexture2D(&description, None, Some(&mut staging)) }.unwrap();
        let staging = staging.unwrap();
        let mut mapped = D3D11_MAPPED_SUBRESOURCE::default();
        // Readback and the GPU wait exist only in this deterministic test.
        unsafe {
            context.CopyResource(&staging, &texture);
            context
                .Map(&staging, 0, D3D11_MAP_READ, 0, Some(&mut mapped))
                .unwrap();
            let pointer = mapped
                .pData
                .cast::<u8>()
                .add(y * mapped.RowPitch as usize + x * 4);
            let result = std::ptr::read_unaligned(pointer.cast::<[u8; 4]>());
            context.Unmap(&staging, 0);
            result
        }
    }

    #[test]
    fn warp_probe_decodes_real_h264_without_d3d11_video_interfaces() {
        let _apartment = DecoderThreadApartment::initialize().unwrap();
        let _runtime = EmbeddedMediaRuntime::initialize().unwrap();
        let (device, context, luid) = warp();
        assert!(is_software_adapter(Some(luid)).unwrap());
        probe(Some(luid)).expect("real CPU decode and the Qt compatibility texture converter");
        let mut resources =
            unsafe { CompatibilityResources::new(adopted(&device, &context), format()) }.unwrap();
        assert!(resources.device_manager().is_none());
        let mut decoder = Decoder::new(&resources, format(), WindowsDecoderMode::Software).unwrap();
        let frame = decoder
            .probe_frame(include_bytes!("../../fixtures/probe/h264-nv12-sdr.h264"))
            .unwrap();
        assert!(
            frame.texture().is_err(),
            "software frames must not masquerade as hardware surfaces"
        );
        assert!(matches!(&frame.surface, DecodedSurface::Nv12(_)));
        let first = resources.record(0, &frame).unwrap();
        let next = resources.record(0, &frame).unwrap();
        assert_eq!(first.texture, next.texture, "reuse the visited output slot");
        assert!(next.generation > first.generation);
        assert_eq!(first.texture_format, D3d11TextureFormat::Rgba8);
        assert!(resources.record(MAX_FRAME_SLOTS as u32, &frame).is_err());
        let (replacement, replacement_context, _) = warp();
        assert!(
            unsafe {
                resources.validate_adopted_context(adopted(&replacement, &replacement_context))
            }
            .is_err()
        );
    }

    #[test]
    fn warp_upload_preserves_sdr_range_excludes_padding_and_reuses_slots() {
        let _apartment = DecoderThreadApartment::initialize().unwrap();
        let _runtime = EmbeddedMediaRuntime::initialize().unwrap();
        let (device, context, _) = warp();
        let mut resources =
            unsafe { CompatibilityResources::new(adopted(&device, &context), format()) }.unwrap();
        for full_range in [false, true] {
            let format = VideoFormat {
                full_range,
                ..format()
            };
            let (frame, _) = sample(format, 80 * 120);
            let recorded = resources.record(0, &frame).unwrap();
            assert_eq!((recorded.width, recorded.height), (64, 64));
            assert_eq!(recorded.presentation_time_ns, 1_234_500);
            assert_eq!(recorded.color_space, D3d11ColorSpace::Sdr709);
            assert_eq!(pixel(&device, &context, recorded, 0, 0), [0, 0, 0, 255]);
            assert_eq!(
                pixel(&device, &context, recorded, 63, 63),
                [255, 255, 255, 255]
            );
            assert_eq!(
                resources
                    .converter
                    .as_ref()
                    .unwrap()
                    .slots
                    .iter()
                    .filter(|slot| slot.is_some())
                    .count(),
                1
            );
            assert_eq!(
                resources.record(0, &frame).unwrap().texture,
                recorded.texture
            );
        }
        let (truncated, buffer) = sample(format(), 80 * 119 + 64 - 1);
        assert!(resources.record(0, &truncated).is_err());
        // Failure must unlock the CPU buffer, not leave a poisoned lease.
        let mut pointer = std::ptr::null_mut();
        unsafe {
            buffer.Lock(&mut pointer, None, None).unwrap();
            buffer.Unlock().unwrap();
        }
    }

    #[test]
    fn warp_shader_uses_the_negotiated_sdr_matrix_in_both_ranges() {
        let _apartment = DecoderThreadApartment::initialize().unwrap();
        let _runtime = EmbeddedMediaRuntime::initialize().unwrap();
        let (device, context, _) = warp();
        let mut resources =
            unsafe { CompatibilityResources::new(adopted(&device, &context), format()) }.unwrap();
        for color_matrix in [
            crate::VideoColorMatrix::Bt601,
            crate::VideoColorMatrix::Bt709,
        ] {
            for full_range in [false, true] {
                let format = VideoFormat {
                    color_matrix,
                    full_range,
                    ..format()
                };
                let (frame, buffer) = sample(format, 80 * 120);
                let mut pointer = std::ptr::null_mut();
                unsafe {
                    buffer.Lock(&mut pointer, None, None).unwrap();
                    for row in 0..64 {
                        std::ptr::write_bytes(pointer.add(row * 80), 126, 64);
                    }
                    for row in 0..32 {
                        for col in (0..64).step_by(2) {
                            *pointer.add(80 * 80 + row * 80 + col) = 90;
                            *pointer.add(80 * 80 + row * 80 + col + 1) = 200;
                        }
                    }
                    buffer.Unlock().unwrap();
                }
                let recorded = resources.record(0, &frame).unwrap();
                let actual = pixel(&device, &context, recorded, 16, 16);
                let constants = SdrConstants::new(format, 64, 80, 0, 0).unwrap();
                let y = 126.0 / 255.0 * constants.scale_bias[0] + constants.scale_bias[1];
                let u = 90.0 / 255.0 * constants.scale_bias[2] + constants.scale_bias[3];
                let v = 200.0 / 255.0 * constants.scale_bias[2] + constants.scale_bias[3];
                let expected = [
                    y + constants.matrix[0] * v,
                    y + constants.matrix[1] * u + constants.matrix[2] * v,
                    y + constants.matrix[3] * u,
                ];
                for channel in 0..3 {
                    let expected = (expected[channel].clamp(0.0, 1.0) * 255.0).round() as i32;
                    assert!(
                        (actual[channel] as i32 - expected).abs() <= 1,
                        "matrix={color_matrix:?} full_range={full_range} actual={actual:?} channel={channel} expected={expected}"
                    );
                }
                assert_eq!(actual[3], 255);
            }
        }
    }

    #[test]
    fn warp_upload_accepts_2d_system_memory_and_rejects_corrupt_samples() {
        use ::windows::Win32::Media::MediaFoundation::{
            MF2DBuffer_LockFlags_Write, MFCreate2DMediaBuffer, MFSampleExtension_FrameCorruption,
            MFVideoFormat_NV12,
        };
        let _apartment = DecoderThreadApartment::initialize().unwrap();
        let _runtime = EmbeddedMediaRuntime::initialize().unwrap();
        let (device, context, _) = warp();
        let buffer =
            unsafe { MFCreate2DMediaBuffer(64, 80, MFVideoFormat_NV12.data1, false) }.unwrap();
        let two_d: IMF2DBuffer2 = buffer.cast().unwrap();
        let mut scanline = std::ptr::null_mut();
        let mut start = std::ptr::null_mut();
        let mut pitch = 0;
        let mut len = 0;
        unsafe {
            two_d
                .Lock2DSize(
                    MF2DBuffer_LockFlags_Write,
                    &mut scanline,
                    &mut pitch,
                    &mut start,
                    &mut len,
                )
                .unwrap();
            assert!(pitch >= 64);
            std::ptr::write_bytes(start, 128, len as usize);
            for row in 0..80 {
                std::ptr::write_bytes(scanline.add(row * pitch as usize), 16, 64);
            }
            two_d.Unlock2D().unwrap();
        }
        let mf_sample = unsafe { MFCreateSample() }.unwrap();
        unsafe {
            mf_sample.AddBuffer(&buffer).unwrap();
        }
        let aperture = crate::aperture::VideoAperture::new(64, 64, None).unwrap();
        let frame = DecodedVideoFrame::from_memory_sample(
            mf_sample.clone(),
            format(),
            aperture,
            64,
            80,
            64,
        )
        .unwrap();
        let mut resources =
            unsafe { CompatibilityResources::new(adopted(&device, &context), format()) }.unwrap();
        let recorded = resources.record(0, &frame).unwrap();
        assert_eq!(pixel(&device, &context, recorded, 63, 63), [0, 0, 0, 255]);
        unsafe {
            mf_sample
                .SetUINT32(&MFSampleExtension_FrameCorruption, 1)
                .unwrap();
        }
        assert_eq!(
            DecodedVideoFrame::from_memory_sample(mf_sample, format(), aperture, 64, 80, 64)
                .err()
                .unwrap(),
            "Media Foundation decoder reported a corrupted output frame"
        );
    }
}
