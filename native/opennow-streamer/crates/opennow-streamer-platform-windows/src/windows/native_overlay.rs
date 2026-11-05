use std::time::{Duration, Instant};

use ::windows::Win32::Graphics::Direct2D::Common::{
    D2D_RECT_F, D2D1_ALPHA_MODE_PREMULTIPLIED, D2D1_COLOR_F, D2D1_PIXEL_FORMAT,
};
use ::windows::Win32::Graphics::Direct2D::{
    D2D1_ANTIALIAS_MODE_PER_PRIMITIVE, D2D1_BITMAP_OPTIONS_CANNOT_DRAW, D2D1_BITMAP_OPTIONS_TARGET,
    D2D1_BITMAP_PROPERTIES1, D2D1_DEVICE_CONTEXT_OPTIONS_NONE, D2D1_DRAW_TEXT_OPTIONS_CLIP,
    D2D1_ELLIPSE, D2D1_FACTORY_TYPE_SINGLE_THREADED, D2D1_ROUNDED_RECT, D2D1CreateFactory,
    ID2D1Bitmap1, ID2D1Device, ID2D1DeviceContext, ID2D1Factory1, ID2D1SolidColorBrush,
};
use ::windows::Win32::Graphics::Direct3D11::ID3D11Device;
use ::windows::Win32::Graphics::DirectComposition::{IDCompositionDevice, IDCompositionVisual};
use ::windows::Win32::Graphics::DirectWrite::{
    DWRITE_FACTORY_TYPE_SHARED, DWRITE_FONT_STRETCH_NORMAL, DWRITE_FONT_STYLE_NORMAL,
    DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_WEIGHT_SEMI_BOLD, DWRITE_MEASURING_MODE_NATURAL,
    DWRITE_PARAGRAPH_ALIGNMENT_CENTER, DWRITE_TEXT_ALIGNMENT_LEADING,
    DWRITE_TEXT_ALIGNMENT_TRAILING, DWRITE_WORD_WRAPPING_NO_WRAP, DWRITE_WORD_WRAPPING_WRAP,
    DWriteCreateFactory, IDWriteFactory, IDWriteTextFormat,
};
use ::windows::Win32::Graphics::Dxgi::Common::{
    DXGI_ALPHA_MODE_PREMULTIPLIED, DXGI_FORMAT_R8G8B8A8_UNORM, DXGI_SAMPLE_DESC,
};
use ::windows::Win32::Graphics::Dxgi::{
    DXGI_PRESENT, DXGI_SCALING_STRETCH, DXGI_SWAP_CHAIN_DESC1, DXGI_SWAP_CHAIN_FLAG,
    DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL, DXGI_USAGE_RENDER_TARGET_OUTPUT, IDXGIDevice, IDXGIFactory2,
    IDXGISurface, IDXGISwapChain1,
};
use ::windows::core::{IUnknown, Interface, PCWSTR, w};
use windows_numerics::Vector2;

use crate::native_overlay::{
    NativeOverlayLayout, NativeOverlayRect, NativeOverlayShared, NativeOverlaySnapshot,
};
use opennow_streamer_protocol::{NativeOverlay, NativeOverlayItem};

const TRANSITION_DURATION: Duration = Duration::from_millis(300);

struct NativeOverlayBrushes {
    panel: ID2D1SolidColorBrush,
    surface: ID2D1SolidColorBrush,
    text: ID2D1SolidColorBrush,
    muted: ID2D1SolidColorBrush,
    accent: ID2D1SolidColorBrush,
    danger: ID2D1SolidColorBrush,
    warning: ID2D1SolidColorBrush,
}

impl NativeOverlayBrushes {
    fn new(context: &ID2D1DeviceContext) -> Result<Self, String> {
        Ok(Self {
            panel: brush(context)?,
            surface: brush(context)?,
            text: brush(context)?,
            muted: brush(context)?,
            accent: brush(context)?,
            danger: brush(context)?,
            warning: brush(context)?,
        })
    }
}

struct NativeOverlayDevice {
    _device: ID2D1Device,
    context: ID2D1DeviceContext,
    write: IDWriteFactory,
    brushes: NativeOverlayBrushes,
}

impl NativeOverlayDevice {
    fn new(device: &ID3D11Device) -> Result<Self, String> {
        unsafe {
            let factory: ID2D1Factory1 = D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, None)
                .map_err(|error| format!("Direct2D factory: {error}"))?;
            let dxgi: IDXGIDevice = device.cast().map_err(|error| error.to_string())?;
            let device = factory
                .CreateDevice(&dxgi)
                .map_err(|error| format!("Direct2D device: {error}"))?;
            let context = device
                .CreateDeviceContext(D2D1_DEVICE_CONTEXT_OPTIONS_NONE)
                .map_err(|error| format!("Direct2D context: {error}"))?;
            // Layout is already in physical client pixels. A fixed 96-DPI
            // Direct2D unit space prevents a second, hidden DPI multiplication.
            context.SetDpi(96.0, 96.0);
            let write: IDWriteFactory = DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED)
                .map_err(|error| format!("DirectWrite factory: {error}"))?;
            let brushes = NativeOverlayBrushes::new(&context)?;
            Ok(Self {
                _device: device,
                context,
                write,
                brushes,
            })
        }
    }
}

struct NativeTextFormats {
    menu_title: IDWriteTextFormat,
    title: IDWriteTextFormat,
    body: IDWriteTextFormat,
    body_bold: IDWriteTextFormat,
    menu_detail: IDWriteTextFormat,
    caption: IDWriteTextFormat,
    mono: IDWriteTextFormat,
    small: IDWriteTextFormat,
}

impl NativeTextFormats {
    fn new(write: &IDWriteFactory, view: &NativeOverlay, scale: f32) -> Result<Self, String> {
        let body_family = if view.font_family.trim().is_empty() {
            "Segoe UI"
        } else {
            view.font_family.trim()
        };
        let mono_family = if view.mono_font_family.trim().is_empty() {
            "Consolas"
        } else {
            view.mono_font_family.trim()
        };
        Ok(Self {
            menu_title: text_format(write, body_family, 20.0 * scale, true)?,
            title: text_format(write, body_family, 20.0 * scale, true)?,
            body: text_format(write, body_family, 16.0 * scale, false)?,
            body_bold: text_format(write, body_family, 16.0 * scale, true)?,
            menu_detail: text_format(write, body_family, 14.0 * scale, false)?,
            caption: text_format(write, body_family, 12.0 * scale, false)?,
            mono: text_format(write, mono_family, 13.0 * scale, false)?,
            small: text_format(write, body_family, 10.0 * scale, false)?,
        })
    }
}

pub(super) struct NativeOverlayRenderer {
    shared: std::sync::Arc<NativeOverlayShared>,
    device: Option<NativeOverlayDevice>,
    bitmap: Option<ID2D1Bitmap1>,
    visual: Option<IDCompositionVisual>,
    swap_chain: Option<IDXGISwapChain1>,
    formats: Option<NativeTextFormats>,
    format_key: Option<(String, String, u32)>,
    size: (u32, u32),
    rendered_generation: Option<u64>,
    rendered_transition: Option<u64>,
    transition_started: Instant,
    last_render: Option<Instant>,
}

impl NativeOverlayRenderer {
    pub(super) fn new(shared: std::sync::Arc<NativeOverlayShared>) -> Self {
        Self {
            shared,
            device: None,
            bitmap: None,
            visual: None,
            swap_chain: None,
            formats: None,
            format_key: None,
            size: (0, 0),
            rendered_generation: None,
            rendered_transition: None,
            transition_started: Instant::now(),
            last_render: None,
        }
    }

    pub(super) fn set_presentation_available(&self, available: bool) {
        self.shared.set_presentation_available(available);
    }

    pub(super) fn render(
        &mut self,
        device: &ID3D11Device,
        composition_device: &IDCompositionDevice,
        video_visual: &IDCompositionVisual,
        size: (u32, u32),
        dpi_scale: f32,
    ) -> Result<bool, String> {
        self.shared.set_viewport(size.0, size.1, dpi_scale);
        let (active, generation, transition, reduced_motion) = self.shared.render_state();
        if !active {
            if self.swap_chain.is_some() {
                self.detach(composition_device, video_visual)?;
            }
            self.rendered_generation = Some(generation);
            return Ok(false);
        }
        let now = Instant::now();
        let transition_changed = self.rendered_transition != Some(transition);
        let progress = if reduced_motion {
            1.0
        } else if transition_changed {
            0.0
        } else {
            (self.transition_started.elapsed().as_secs_f32() / TRANSITION_DURATION.as_secs_f32())
                .clamp(0.0, 1.0)
        };
        let dirty =
            self.rendered_generation != Some(generation) || self.size != size || transition_changed;
        if !dirty && progress >= 1.0 {
            // A retained composition visual does not need a fresh swap-chain
            // frame. Avoid cloning strings/metrics on every video frame.
            return Ok(false);
        }
        if !dirty
            && self
                .last_render
                .is_some_and(|last| now.duration_since(last) < Duration::from_millis(15))
        {
            return Ok(false);
        }
        let snapshot = self.shared.snapshot();
        if snapshot.view.kind.is_empty() && snapshot.view.hud.is_empty() {
            if self.swap_chain.is_some() {
                self.detach(composition_device, video_visual)?;
            }
            self.rendered_generation = Some(snapshot.generation);
            return Ok(false);
        }
        let transition_changed = self.rendered_transition != Some(snapshot.transition);
        if transition_changed {
            self.transition_started = now;
            self.rendered_transition = Some(snapshot.transition);
        }
        let progress = if snapshot.view.reduced_motion {
            1.0
        } else {
            ((now.duration_since(self.transition_started).as_secs_f32())
                / TRANSITION_DURATION.as_secs_f32())
            .clamp(0.0, 1.0)
        };
        if self.device.is_none() {
            self.device = Some(NativeOverlayDevice::new(device)?);
        }
        self.ensure_target(device, composition_device, video_visual, size)?;
        self.ensure_formats(&snapshot.view, snapshot.layout().scale)?;
        let alpha = 1.0 - (1.0 - progress).powi(3);
        self.draw(&snapshot, alpha)?;
        let swap_chain = self
            .swap_chain
            .as_ref()
            .ok_or("native overlay swap chain is unavailable")?;
        unsafe {
            swap_chain
                .Present(0, DXGI_PRESENT(0))
                .ok()
                .map_err(|error| format!("native overlay present: {error}"))?;
        }
        self.rendered_generation = Some(snapshot.generation);
        self.last_render = Some(now);
        Ok(true)
    }

    pub(super) fn detach(
        &mut self,
        composition_device: &IDCompositionDevice,
        video_visual: &IDCompositionVisual,
    ) -> Result<(), String> {
        if let Some(device) = self.device.as_ref() {
            unsafe { device.context.SetTarget(None) };
        }
        self.bitmap = None;
        if let Some(visual) = self.visual.take() {
            unsafe {
                video_visual
                    .RemoveVisual(&visual)
                    .map_err(|error| format!("native overlay visual removal: {error}"))?;
                composition_device
                    .Commit()
                    .map_err(|error| format!("native overlay composition commit: {error}"))?;
            }
        }
        self.swap_chain = None;
        self.size = (0, 0);
        self.last_render = None;
        Ok(())
    }

    fn ensure_target(
        &mut self,
        device: &ID3D11Device,
        composition_device: &IDCompositionDevice,
        video_visual: &IDCompositionVisual,
        size: (u32, u32),
    ) -> Result<(), String> {
        if self.swap_chain.is_some() && self.size == size && self.bitmap.is_some() {
            return Ok(());
        }
        let context = &self
            .device
            .as_ref()
            .ok_or("native overlay Direct2D device is unavailable")?
            .context;
        if self.swap_chain.is_some() {
            unsafe { context.SetTarget(None) };
            self.bitmap = None;
        }
        if self.swap_chain.is_none() {
            let (swap_chain, visual) =
                create_overlay_swap_chain(device, composition_device, video_visual, size)?;
            self.swap_chain = Some(swap_chain);
            self.visual = Some(visual);
            self.size = size;
        } else if self.size != size {
            let swap_chain = self.swap_chain.as_ref().expect("checked swap chain");
            unsafe {
                swap_chain
                    .ResizeBuffers(
                        2,
                        size.0.max(2),
                        size.1.max(2),
                        DXGI_FORMAT_R8G8B8A8_UNORM,
                        DXGI_SWAP_CHAIN_FLAG(0),
                    )
                    .map_err(|error| format!("native overlay resize: {error}"))?;
            }
            self.size = size;
        }
        let swap_chain = self.swap_chain.as_ref().expect("created swap chain");
        let surface: IDXGISurface = unsafe {
            swap_chain
                .GetBuffer(0)
                .map_err(|error| format!("native overlay back buffer: {error}"))?
        };
        let properties = D2D1_BITMAP_PROPERTIES1 {
            pixelFormat: D2D1_PIXEL_FORMAT {
                format: DXGI_FORMAT_R8G8B8A8_UNORM,
                alphaMode: D2D1_ALPHA_MODE_PREMULTIPLIED,
            },
            dpiX: 96.0,
            dpiY: 96.0,
            bitmapOptions: D2D1_BITMAP_OPTIONS_TARGET | D2D1_BITMAP_OPTIONS_CANNOT_DRAW,
            ..Default::default()
        };
        let bitmap = unsafe {
            context
                .CreateBitmapFromDxgiSurface(&surface, Some(&properties))
                .map_err(|error| format!("native overlay D2D target: {error}"))?
        };
        unsafe { context.SetTarget(&bitmap) };
        self.bitmap = Some(bitmap);
        Ok(())
    }

    fn ensure_formats(&mut self, view: &NativeOverlay, scale: f32) -> Result<(), String> {
        let key = (
            view.font_family.clone(),
            view.mono_font_family.clone(),
            (scale * 1000.0).round() as u32,
        );
        if self.format_key.as_ref() == Some(&key) && self.formats.is_some() {
            return Ok(());
        }
        let write = &self
            .device
            .as_ref()
            .ok_or("native overlay DirectWrite device is unavailable")?
            .write;
        self.formats = Some(NativeTextFormats::new(write, view, scale)?);
        self.format_key = Some(key);
        Ok(())
    }

    fn draw(&self, snapshot: &NativeOverlaySnapshot, alpha: f32) -> Result<(), String> {
        let device = self
            .device
            .as_ref()
            .ok_or("native overlay device is unavailable")?;
        let formats = self
            .formats
            .as_ref()
            .ok_or("native overlay text formats are unavailable")?;
        let layout = snapshot.layout();
        unsafe {
            device.context.BeginDraw();
            device.context.Clear(Some(&color(0.0, 0.0, 0.0, 0.0)));
        }
        draw_hud(device, formats, snapshot, &layout, alpha);
        if layout.scrim {
            let alpha_scrim = if snapshot.view.kind == "exit" {
                0.52
            } else {
                0.18
            };
            fill_rect(
                &device.context,
                &device.brushes.panel,
                NativeOverlayRect {
                    x: 0.0,
                    y: 0.0,
                    width: snapshot.width as f32,
                    height: snapshot.height as f32,
                },
                color(0.015, 0.025, 0.035, alpha_scrim),
                alpha,
            );
        }
        if let Some(panel) = layout.panel {
            let menu_like = matches!(snapshot.view.kind.as_str(), "menu" | "settings");
            let panel_opacity = snapshot.view.opacity as f32 / 100.0;
            if menu_like {
                // The original shell is a square, full-height #191919 sidebar
                // with a soft right shadow, not an inset rounded glass card.
                for band in 0..8 {
                    let falloff = 1.0 - band as f32 / 8.0;
                    fill_rect(
                        &device.context,
                        &device.brushes.panel,
                        NativeOverlayRect {
                            x: panel.x + panel.width + band as f32,
                            y: panel.y,
                            width: 1.0,
                            height: panel.height,
                        },
                        color(0.0, 0.0, 0.0, 0.30 * falloff * falloff),
                        alpha,
                    );
                }
                fill_rect(
                    &device.context,
                    &device.brushes.panel,
                    panel,
                    color(0.098, 0.098, 0.098, panel_opacity),
                    alpha,
                );
            } else {
                fill_round_rect(
                    &device.context,
                    &device.brushes.panel,
                    panel,
                    20.0 * layout.scale,
                    color(0.035, 0.052, 0.068, panel_opacity),
                    alpha,
                );
                stroke_round_rect(
                    &device.context,
                    &device.brushes.surface,
                    panel,
                    20.0 * layout.scale,
                    1.0,
                    color(1.0, 1.0, 1.0, 0.09),
                    alpha,
                );
            }
            match snapshot.view.kind.as_str() {
                "menu" | "settings" => draw_menu(device, formats, snapshot, &layout, panel, alpha),
                "stats" => draw_stats(device, formats, snapshot, &layout, panel, alpha),
                "exit" => draw_exit(device, formats, snapshot, &layout, panel, alpha),
                _ => {}
            }
        }
        unsafe {
            device
                .context
                .EndDraw(None, None)
                .map_err(|error| format!("native overlay EndDraw: {error}"))?;
        }
        Ok(())
    }
}

fn create_overlay_swap_chain(
    device: &ID3D11Device,
    composition_device: &IDCompositionDevice,
    video_visual: &IDCompositionVisual,
    size: (u32, u32),
) -> Result<(IDXGISwapChain1, IDCompositionVisual), String> {
    unsafe {
        let dxgi: IDXGIDevice = device.cast().map_err(|error| error.to_string())?;
        let adapter = dxgi.GetAdapter().map_err(|error| error.to_string())?;
        let factory: IDXGIFactory2 = adapter.GetParent().map_err(|error| error.to_string())?;
        let description = DXGI_SWAP_CHAIN_DESC1 {
            Width: size.0.max(2),
            Height: size.1.max(2),
            Format: DXGI_FORMAT_R8G8B8A8_UNORM,
            Stereo: false.into(),
            SampleDesc: DXGI_SAMPLE_DESC {
                Count: 1,
                Quality: 0,
            },
            BufferUsage: DXGI_USAGE_RENDER_TARGET_OUTPUT,
            BufferCount: 2,
            Scaling: DXGI_SCALING_STRETCH,
            SwapEffect: DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL,
            AlphaMode: DXGI_ALPHA_MODE_PREMULTIPLIED,
            Flags: 0,
        };
        let swap_chain = factory
            .CreateSwapChainForComposition(device, &description, None)
            .map_err(|error| format!("native overlay swap chain: {error}"))?;
        let visual = composition_device
            .CreateVisual()
            .map_err(|error| format!("native overlay visual: {error}"))?;
        let content: IUnknown = swap_chain.cast().map_err(|error| error.to_string())?;
        visual
            .SetContent(&content)
            .map_err(|error| format!("native overlay visual content: {error}"))?;
        video_visual
            .AddVisual(&visual, true, None)
            .map_err(|error| format!("native overlay visual order: {error}"))?;
        composition_device
            .Commit()
            .map_err(|error| format!("native overlay composition commit: {error}"))?;
        Ok((swap_chain, visual))
    }
}

fn draw_menu(
    device: &NativeOverlayDevice,
    formats: &NativeTextFormats,
    snapshot: &NativeOverlaySnapshot,
    layout: &NativeOverlayLayout,
    panel: NativeOverlayRect,
    alpha: f32,
) {
    let s = layout.scale;
    let appbar = NativeOverlayRect {
        x: panel.x,
        y: panel.y,
        width: panel.width,
        height: 56.0 * s,
    };
    fill_rect(
        &device.context,
        &device.brushes.panel,
        appbar,
        color(0.224, 0.224, 0.224, 1.0),
        alpha,
    );
    let first_action_x = layout
        .items
        .iter()
        .filter(|placement| {
            snapshot
                .view
                .items
                .get(placement.index)
                .is_some_and(|item| item.role == "appbar")
        })
        .map(|placement| placement.rect.x)
        .min_by(f32::total_cmp)
        .unwrap_or(panel.x + panel.width - 16.0 * s);
    draw_text(
        &device.context,
        &formats.menu_title,
        &device.brushes.text,
        &snapshot.view.title,
        NativeOverlayRect {
            x: panel.x + 16.0 * s,
            y: panel.y + 14.0 * s,
            width: (first_action_x - panel.x - 40.0 * s).max(0.0),
            height: 28.0 * s,
        },
        color(0.94, 0.94, 0.94, 1.0),
        alpha,
        false,
    );
    draw_items_region(device, formats, snapshot, layout, alpha, Some("appbar"));

    if let Some(content) = layout.content {
        let clip = d2d_rect(content);
        unsafe {
            device
                .context
                .PushAxisAlignedClip(&clip, D2D1_ANTIALIAS_MODE_PER_PRIMITIVE);
        }
        draw_items_region(device, formats, snapshot, layout, alpha, Some("content"));
        unsafe { device.context.PopAxisAlignedClip() };

        if layout.max_scroll > 0.0 && content.height > 0.0 {
            let thumb_height = (content.height * content.height
                / (content.height + layout.max_scroll))
                .max(24.0 * s)
                .min(content.height);
            let travel = (content.height - thumb_height).max(0.0);
            let thumb_y =
                content.y + travel * (layout.scroll_offset / layout.max_scroll).clamp(0.0, 1.0);
            fill_round_rect(
                &device.context,
                &device.brushes.muted,
                NativeOverlayRect {
                    x: content.x + content.width - 3.0 * s,
                    y: thumb_y,
                    width: 2.0 * s,
                    height: thumb_height,
                },
                s,
                color(1.0, 1.0, 1.0, 0.30),
                alpha,
            );
        }
    }

    if let Some(toast) = layout.footer {
        fill_round_rect(
            &device.context,
            &device.brushes.panel,
            toast,
            6.0 * s,
            color(0.16, 0.16, 0.16, 0.98),
            alpha,
        );
        draw_text(
            &device.context,
            &formats.menu_detail,
            &device.brushes.text,
            &snapshot.view.footer,
            NativeOverlayRect {
                x: toast.x + 16.0 * s,
                y: toast.y + 14.0 * s,
                width: (toast.width - 32.0 * s).max(0.0),
                height: 20.0 * s,
            },
            color(0.94, 0.94, 0.94, 1.0),
            alpha,
            false,
        );
    }
}

fn draw_stats(
    device: &NativeOverlayDevice,
    formats: &NativeTextFormats,
    snapshot: &NativeOverlaySnapshot,
    layout: &NativeOverlayLayout,
    panel: NativeOverlayRect,
    alpha: f32,
) {
    let s = layout.scale;
    let inset = 20.0 * s;
    draw_text(
        &device.context,
        &formats.title,
        &device.brushes.text,
        &snapshot.view.title,
        line_rect(panel, inset, 12.0 * s, inset, 30.0 * s),
        color(0.94, 0.97, 0.98, 1.0),
        alpha,
        false,
    );
    draw_text(
        &device.context,
        &formats.caption,
        &device.brushes.muted,
        &snapshot.view.subtitle,
        line_rect(panel, inset, 46.0 * s, inset, 20.0 * s),
        color(0.60, 0.68, 0.72, 1.0),
        alpha,
        false,
    );
    draw_text(
        &device.context,
        &formats.small,
        &device.brushes.muted,
        &snapshot.view.detail,
        line_rect(panel, inset, 68.0 * s, inset, 18.0 * s),
        color(0.52, 0.60, 0.65, 1.0),
        alpha,
        false,
    );
    draw_items(device, formats, snapshot, layout, alpha);
}

fn draw_exit(
    device: &NativeOverlayDevice,
    formats: &NativeTextFormats,
    snapshot: &NativeOverlaySnapshot,
    layout: &NativeOverlayLayout,
    panel: NativeOverlayRect,
    alpha: f32,
) {
    let s = layout.scale;
    let inset = 28.0 * s;
    draw_text(
        &device.context,
        &formats.title,
        &device.brushes.text,
        &snapshot.view.title,
        line_rect(panel, inset, 24.0 * s, inset, 34.0 * s),
        color(0.96, 0.97, 0.98, 1.0),
        alpha,
        false,
    );
    draw_wrapped_text(
        &device.context,
        &formats.body,
        &device.brushes.muted,
        &snapshot.view.subtitle,
        line_rect(panel, inset, 64.0 * s, inset, 82.0 * s),
        color(0.67, 0.72, 0.75, 1.0),
        alpha,
        false,
    );
    draw_text(
        &device.context,
        &formats.caption,
        &device.brushes.muted,
        &snapshot.view.detail,
        line_rect(panel, inset, 152.0 * s, inset, 20.0 * s),
        color(0.55, 0.62, 0.66, 1.0),
        alpha,
        false,
    );
    draw_items(device, formats, snapshot, layout, alpha);
}

fn draw_items(
    device: &NativeOverlayDevice,
    formats: &NativeTextFormats,
    snapshot: &NativeOverlaySnapshot,
    layout: &NativeOverlayLayout,
    alpha: f32,
) {
    draw_items_region(device, formats, snapshot, layout, alpha, None);
}

fn draw_items_region(
    device: &NativeOverlayDevice,
    formats: &NativeTextFormats,
    snapshot: &NativeOverlaySnapshot,
    layout: &NativeOverlayLayout,
    alpha: f32,
    region: Option<&str>,
) {
    for placement in &layout.items {
        let Some(item) = snapshot.view.items.get(placement.index) else {
            continue;
        };
        let role = item.role.as_str();
        let menu_like = matches!(snapshot.view.kind.as_str(), "menu" | "settings");
        if menu_like {
            let item_region = if role == "appbar" {
                "appbar"
            } else {
                "content"
            };
            if region != Some(item_region) {
                continue;
            }
        } else if region.is_some() {
            continue;
        }
        let focused = snapshot.focused == Some(placement.index);
        let hovered = snapshot.hovered == Some(placement.index);
        let pressed = snapshot.pressed == Some(placement.index);
        let accent = accent(&snapshot.view);
        let mut rect = placement.rect;
        if menu_like {
            rect.x += (1.0 - alpha) * 24.0 * layout.scale;
            match role {
                "divider" => {
                    fill_rect(
                        &device.context,
                        &device.brushes.muted,
                        NativeOverlayRect {
                            x: rect.x + 16.0 * layout.scale,
                            y: rect.y + 16.0 * layout.scale,
                            width: (rect.width - 32.0 * layout.scale).max(0.0),
                            height: layout.scale.max(1.0),
                        },
                        color(1.0, 1.0, 1.0, 0.14),
                        alpha,
                    );
                    continue;
                }
                "gap" => continue,
                "appbar" => {
                    if hovered || pressed {
                        fill_round_rect(
                            &device.context,
                            &device.brushes.surface,
                            rect,
                            4.0 * layout.scale,
                            color(1.0, 1.0, 1.0, if pressed { 0.16 } else { 0.09 }),
                            alpha,
                        );
                    }
                    if focused && !hovered {
                        stroke_round_rect(
                            &device.context,
                            &device.brushes.accent,
                            rect,
                            4.0 * layout.scale,
                            1.5 * layout.scale,
                            accent,
                            alpha,
                        );
                    }
                    let glyph = inset_rect(
                        rect,
                        6.0 * layout.scale,
                        6.0 * layout.scale,
                        6.0 * layout.scale,
                        6.0 * layout.scale,
                    );
                    draw_vector_icon(device, &item.id, glyph, color(0.94, 0.94, 0.94, 1.0), alpha);
                    continue;
                }
                _ => {}
            }
            if hovered || pressed {
                fill_rect(
                    &device.context,
                    &device.brushes.surface,
                    rect,
                    color(1.0, 1.0, 1.0, if pressed { 0.13 } else { 0.075 }),
                    alpha,
                );
            }
            if focused && !hovered && item.enabled {
                stroke_rect(
                    &device.context,
                    &device.brushes.accent,
                    rect,
                    1.5 * layout.scale,
                    accent,
                    alpha,
                );
            }
            draw_menu_item(device, formats, snapshot, item, rect, alpha, layout.scale);
            continue;
        }

        let focused = focused || hovered;
        let item_alpha = alpha;
        let mut fill = match role {
            "primary" => accent,
            "danger" => color(0.30, 0.08, 0.09, 0.70),
            "metric" => color(1.0, 1.0, 1.0, 0.025),
            _ => color(1.0, 1.0, 1.0, 0.055),
        };
        if focused && role != "primary" {
            fill = color(
                accent.r,
                accent.g,
                accent.b,
                if pressed { 0.34 } else { 0.18 },
            );
        }
        if pressed && role == "primary" {
            fill = color(accent.r * 0.78, accent.g * 0.78, accent.b * 0.78, accent.a);
        }
        let radius = if role == "toggle" { 13.0 } else { 11.0 } * layout.scale;
        if role != "metric" || snapshot.view.kind == "stats" {
            fill_round_rect(
                &device.context,
                &device.brushes.surface,
                rect,
                radius,
                fill,
                item_alpha,
            );
        }
        if focused && item.enabled {
            stroke_round_rect(
                &device.context,
                &device.brushes.accent,
                rect,
                radius,
                1.5 * layout.scale,
                accent,
                item_alpha,
            );
        } else if role == "danger" {
            stroke_round_rect(
                &device.context,
                &device.brushes.danger,
                rect,
                radius,
                1.0,
                color(1.0, 0.42, 0.40, 0.28),
                item_alpha,
            );
        }
        draw_item_text(
            device,
            formats,
            snapshot,
            item,
            rect,
            role,
            focused,
            layout.scale,
            layout.compact,
            item_alpha,
        );
        if role == "toggle"
            && let Some(checked) = item.checked
        {
            let track = NativeOverlayRect {
                x: rect.x + rect.width - 40.0 * layout.scale,
                y: rect.y + 11.0 * layout.scale,
                width: 28.0 * layout.scale,
                height: 14.0 * layout.scale,
            };
            fill_round_rect(
                &device.context,
                if checked {
                    &device.brushes.accent
                } else {
                    &device.brushes.muted
                },
                track,
                7.0 * layout.scale,
                if checked {
                    accent
                } else {
                    color(0.42, 0.49, 0.53, 0.65)
                },
                item_alpha,
            );
            let knob = NativeOverlayRect {
                x: track.x + if checked { 16.0 } else { 2.0 } * layout.scale,
                y: track.y + 2.0 * layout.scale,
                width: 10.0 * layout.scale,
                height: 10.0 * layout.scale,
            };
            fill_round_rect(
                &device.context,
                &device.brushes.text,
                knob,
                5.0 * layout.scale,
                color(0.96, 0.98, 0.98, 1.0),
                item_alpha,
            );
        }
    }
}

fn draw_menu_item(
    device: &NativeOverlayDevice,
    formats: &NativeTextFormats,
    snapshot: &NativeOverlaySnapshot,
    item: &NativeOverlayItem,
    rect: NativeOverlayRect,
    alpha: f32,
    scale: f32,
) {
    let s = scale;
    let role = item.role.as_str();
    let text = if item.enabled {
        color(0.94, 0.94, 0.94, 1.0)
    } else {
        color(0.94, 0.94, 0.94, 0.38)
    };
    let muted = if item.enabled {
        color(0.70, 0.70, 0.70, 1.0)
    } else {
        color(0.70, 0.70, 0.70, 0.38)
    };
    let setting = role == "setting";
    let icon_box = NativeOverlayRect {
        x: rect.x + 16.0 * s,
        y: if setting {
            rect.y + 10.0 * s
        } else {
            rect.y + (rect.height - 36.0 * s) / 2.0
        },
        width: 36.0 * s,
        height: 36.0 * s,
    };
    let icon_name = if item.id == "record" && item.checked == Some(true) {
        "record-active"
    } else {
        item.id.as_str()
    };
    draw_vector_icon(
        device,
        icon_name,
        inset_rect(icon_box, 6.0 * s, 6.0 * s, 6.0 * s, 6.0 * s),
        text,
        alpha,
    );

    let has_switch = matches!(role, "toggle" | "setting") && item.checked.is_some();
    let has_trailing_icon = matches!(role, "chevron" | "save" | "record");
    let value_width = if item.value.trim().is_empty() {
        0.0
    } else {
        ((item.value.chars().count() as f32 * 8.0 + 20.0).clamp(64.0, 140.0)) * s
    };
    let trailing_base = if has_switch {
        68.0 * s
    } else if has_trailing_icon {
        52.0 * s
    } else {
        16.0 * s
    };
    let trailing_width = trailing_base + value_width;
    let text_x = rect.x + 68.0 * s;
    let text_width = (rect.x + rect.width - trailing_width - text_x).max(0.0);
    let title_y = if setting || !item.detail.trim().is_empty() || !item.value.trim().is_empty() {
        14.0
    } else {
        12.0
    } * s;
    draw_text(
        &device.context,
        &formats.body,
        &device.brushes.text,
        &item.label,
        NativeOverlayRect {
            x: text_x,
            y: rect.y + title_y,
            width: text_width,
            height: 24.0 * s,
        },
        text,
        alpha,
        false,
    );
    if !item.detail.trim().is_empty() {
        let detail_rect = NativeOverlayRect {
            x: text_x,
            y: rect.y + if setting { 46.0 * s } else { 38.0 * s },
            width: if setting {
                (rect.x + rect.width - 16.0 * s - text_x).max(0.0)
            } else {
                text_width
            },
            height: if setting { 66.0 * s } else { 20.0 * s },
        };
        if setting {
            draw_wrapped_text(
                &device.context,
                &formats.menu_detail,
                &device.brushes.muted,
                &item.detail,
                detail_rect,
                muted,
                alpha,
                false,
            );
        } else {
            draw_text(
                &device.context,
                &formats.menu_detail,
                &device.brushes.muted,
                &item.detail,
                detail_rect,
                muted,
                alpha,
                false,
            );
        }
    }
    if !item.value.trim().is_empty() {
        draw_text(
            &device.context,
            &formats.menu_detail,
            &device.brushes.muted,
            &item.value,
            NativeOverlayRect {
                x: rect.x + rect.width - trailing_base - value_width,
                y: rect.y + (rect.height - 20.0 * s) / 2.0,
                width: value_width,
                height: 20.0 * s,
            },
            muted,
            alpha,
            true,
        );
    }
    if has_switch {
        let checked = item.checked == Some(true);
        let track = NativeOverlayRect {
            x: rect.x + rect.width - 52.0 * s,
            y: if setting {
                rect.y + 18.0 * s
            } else {
                rect.y + (rect.height - 20.0 * s) / 2.0
            },
            width: 36.0 * s,
            height: 20.0 * s,
        };
        fill_round_rect(
            &device.context,
            if checked {
                &device.brushes.accent
            } else {
                &device.brushes.muted
            },
            track,
            10.0 * s,
            if checked {
                accent(&snapshot.view)
            } else {
                color(0.42, 0.42, 0.42, 1.0)
            },
            alpha,
        );
        fill_round_rect(
            &device.context,
            &device.brushes.text,
            NativeOverlayRect {
                x: track.x + if checked { 18.0 } else { 2.0 } * s,
                y: track.y + 2.0 * s,
                width: 16.0 * s,
                height: 16.0 * s,
            },
            8.0 * s,
            color(0.96, 0.96, 0.96, 1.0),
            alpha,
        );
    }
    if has_trailing_icon {
        let glyph = NativeOverlayRect {
            x: rect.x + rect.width - 40.0 * s,
            y: rect.y + (rect.height - 24.0 * s) / 2.0,
            width: 24.0 * s,
            height: 24.0 * s,
        };
        let trailing_icon = match role {
            "save" => "save",
            "record" if item.checked == Some(true) => "stop",
            "record" => "play",
            _ => "chevron",
        };
        draw_vector_icon(device, trailing_icon, glyph, muted, alpha);
    }
}

fn draw_item_text(
    device: &NativeOverlayDevice,
    formats: &NativeTextFormats,
    snapshot: &NativeOverlaySnapshot,
    item: &NativeOverlayItem,
    rect: NativeOverlayRect,
    role: &str,
    focused: bool,
    scale: f32,
    compact: bool,
    alpha: f32,
) {
    let s = scale;
    let padding = 14.0 * s;
    let normal = if role == "danger" {
        color(1.0, 0.61, 0.58, 1.0)
    } else if role == "primary" {
        color(0.025, 0.08, 0.045, 1.0)
    } else if item.enabled {
        color(0.92, 0.95, 0.96, 1.0)
    } else {
        color(0.56, 0.62, 0.65, 1.0)
    };
    let muted = if role == "primary" {
        color(0.04, 0.12, 0.07, 0.82)
    } else {
        color(0.58, 0.66, 0.70, 1.0)
    };
    if role == "toggle" {
        draw_text(
            &device.context,
            &formats.caption,
            &device.brushes.muted,
            &item.label,
            line_rect(
                rect,
                padding,
                (if compact { 4.0 } else { 8.0 }) * s,
                padding
                    + if item.checked.is_some() {
                        36.0 * s
                    } else {
                        0.0
                    },
                (if compact { 16.0 } else { 20.0 }) * s,
            ),
            muted,
            alpha,
            false,
        );
        draw_text(
            &device.context,
            &formats.body_bold,
            if focused {
                &device.brushes.text
            } else {
                &device.brushes.text
            },
            &item.value,
            line_rect(
                rect,
                padding,
                (if compact { 24.0 } else { 32.0 }) * s,
                padding,
                (if compact { 20.0 } else { 24.0 }) * s,
            ),
            normal,
            alpha,
            false,
        );
        if !item.detail.is_empty() && !compact {
            draw_text(
                &device.context,
                &formats.small,
                &device.brushes.muted,
                &item.detail,
                line_rect(rect, padding, 60.0 * s, padding, 16.0 * s),
                muted,
                alpha,
                false,
            );
        }
        return;
    }
    if snapshot.view.kind == "stats" {
        draw_text(
            &device.context,
            &formats.caption,
            &device.brushes.muted,
            &item.label,
            inset_rect(rect, 2.0 * s, 0.0, rect.width * 0.42, 0.0),
            muted,
            alpha,
            false,
        );
        draw_text(
            &device.context,
            &formats.mono,
            &device.brushes.text,
            &item.value,
            NativeOverlayRect {
                x: rect.x + rect.width * 0.42,
                y: rect.y,
                width: rect.width * 0.58,
                height: rect.height,
            },
            normal,
            alpha,
            true,
        );
        return;
    }
    draw_text(
        &device.context,
        if role == "primary" || role == "danger" {
            &formats.body_bold
        } else {
            &formats.body
        },
        &device.brushes.text,
        &item.label,
        inset_rect(rect, padding, 0.0, rect.width * 0.40 + padding, 0.0),
        normal,
        alpha,
        false,
    );
    if !item.value.is_empty() {
        draw_text(
            &device.context,
            &formats.caption,
            &device.brushes.muted,
            &item.value,
            NativeOverlayRect {
                x: rect.x + rect.width * 0.58,
                y: rect.y,
                width: rect.width * 0.42 - padding,
                height: rect.height,
            },
            muted,
            alpha,
            true,
        );
    }
}

fn draw_vector_icon(
    device: &NativeOverlayDevice,
    name: &str,
    rect: NativeOverlayRect,
    ink: D2D1_COLOR_F,
    alpha: f32,
) {
    if rect.width <= 0.0 || rect.height <= 0.0 {
        return;
    }
    let point = |x: f32, y: f32| {
        Vector2::new(
            rect.x + x * rect.width / 24.0,
            rect.y + y * rect.height / 24.0,
        )
    };
    let width = (rect.width / 24.0 * 1.8).max(1.0);
    let line = |x1: f32, y1: f32, x2: f32, y2: f32| unsafe {
        paint(&device.brushes.text, ink, alpha);
        device.context.DrawLine(
            point(x1, y1),
            point(x2, y2),
            &device.brushes.text,
            width,
            None,
        );
    };
    let polyline = |points: &[(f32, f32)]| {
        for segment in points.windows(2) {
            line(segment[0].0, segment[0].1, segment[1].0, segment[1].1);
        }
    };
    let box_rect = |x: f32, y: f32, w: f32, h: f32| NativeOverlayRect {
        x: rect.x + x * rect.width / 24.0,
        y: rect.y + y * rect.height / 24.0,
        width: w * rect.width / 24.0,
        height: h * rect.height / 24.0,
    };
    let stroke_box = |x: f32, y: f32, w: f32, h: f32| unsafe {
        paint(&device.brushes.text, ink, alpha);
        device.context.DrawRectangle(
            &d2d_rect(box_rect(x, y, w, h)),
            &device.brushes.text,
            width,
            None,
        );
    };
    let ellipse = |cx: f32, cy: f32, radius: f32, fill: bool| {
        let ellipse = D2D1_ELLIPSE {
            point: point(cx, cy),
            radiusX: radius * rect.width / 24.0,
            radiusY: radius * rect.height / 24.0,
        };
        unsafe {
            paint(&device.brushes.text, ink, alpha);
            if fill {
                device.context.FillEllipse(&ellipse, &device.brushes.text);
            } else {
                device
                    .context
                    .DrawEllipse(&ellipse, &device.brushes.text, width, None);
            }
        }
    };
    match name {
        "close" => {
            line(6.0, 6.0, 18.0, 18.0);
            line(18.0, 6.0, 6.0, 18.0);
        }
        "settings" => {
            for spoke in 0..8 {
                let angle = spoke as f32 * std::f32::consts::PI / 4.0;
                let (sin, cos) = angle.sin_cos();
                line(
                    12.0 + 7.0 * cos,
                    12.0 + 7.0 * sin,
                    12.0 + 10.0 * cos,
                    12.0 + 10.0 * sin,
                );
            }
            ellipse(12.0, 12.0, 6.0, false);
            ellipse(12.0, 12.0, 2.0, false);
        }
        "back" => {
            line(20.0, 12.0, 4.0, 12.0);
            polyline(&[(10.0, 6.0), (4.0, 12.0), (10.0, 18.0)]);
        }
        "gallery" => {
            stroke_box(3.0, 4.0, 18.0, 16.0);
            ellipse(8.0, 9.0, 1.5, false);
            polyline(&[
                (5.0, 17.0),
                (10.0, 12.0),
                (13.0, 15.0),
                (16.0, 11.0),
                (20.0, 17.0),
            ]);
        }
        "record" | "record-active" => {
            ellipse(12.0, 12.0, 8.0, false);
            if name == "record-active" {
                ellipse(12.0, 12.0, 4.0, true);
            }
        }
        "replay-save" | "replay" => {
            polyline(&[(5.0, 4.0), (5.0, 10.0), (11.0, 10.0)]);
            polyline(&[
                (5.0, 10.0),
                (8.0, 6.0),
                (13.0, 5.0),
                (18.0, 8.0),
                (19.0, 13.0),
                (16.0, 18.0),
                (11.0, 19.0),
                (7.0, 17.0),
                (5.0, 14.0),
            ]);
        }
        "screenshot" => {
            stroke_box(3.0, 7.0, 18.0, 13.0);
            polyline(&[(7.0, 7.0), (9.0, 4.0), (15.0, 4.0), (17.0, 7.0)]);
            ellipse(12.0, 13.0, 4.0, false);
        }
        "microphone" => {
            stroke_round_rect(
                &device.context,
                &device.brushes.text,
                box_rect(9.0, 2.0, 6.0, 12.0),
                3.0 * rect.width / 24.0,
                width,
                ink,
                alpha,
            );
            polyline(&[
                (5.0, 11.0),
                (5.0, 14.0),
                (7.0, 18.0),
                (12.0, 19.0),
                (17.0, 18.0),
                (19.0, 14.0),
                (19.0, 11.0),
            ]);
            line(12.0, 19.0, 12.0, 22.0);
            line(8.0, 22.0, 16.0, 22.0);
        }
        "statistics" | "stats" => {
            for (x, y, h) in [(4.0, 13.0, 7.0), (10.0, 8.0, 12.0), (16.0, 4.0, 16.0)] {
                fill_rect(
                    &device.context,
                    &device.brushes.text,
                    box_rect(x, y, 3.0, h),
                    ink,
                    alpha,
                );
            }
        }
        "quit" => {
            polyline(&[
                (8.0, 5.0),
                (5.0, 8.0),
                (4.0, 13.0),
                (6.0, 18.0),
                (10.0, 20.0),
                (15.0, 19.0),
                (19.0, 15.0),
                (19.0, 10.0),
                (16.0, 5.0),
            ]);
            line(12.0, 2.0, 12.0, 11.0);
        }
        "clipboard" => {
            stroke_round_rect(
                &device.context,
                &device.brushes.text,
                box_rect(5.0, 5.0, 14.0, 17.0),
                2.0 * rect.width / 24.0,
                width,
                ink,
                alpha,
            );
            stroke_box(9.0, 2.0, 6.0, 5.0);
            line(8.0, 12.0, 16.0, 12.0);
            line(8.0, 16.0, 16.0, 16.0);
        }
        "play" => polyline(&[(9.0, 6.0), (18.0, 12.0), (9.0, 18.0), (9.0, 6.0)]),
        "stop" => stroke_box(7.0, 7.0, 10.0, 10.0),
        "chevron" => polyline(&[(9.0, 6.0), (15.0, 12.0), (9.0, 18.0)]),
        "save" => {
            line(12.0, 3.0, 12.0, 15.0);
            polyline(&[(7.0, 10.0), (12.0, 15.0), (17.0, 10.0)]);
            polyline(&[(4.0, 15.0), (4.0, 20.0), (20.0, 20.0), (20.0, 15.0)]);
        }
        _ => {}
    }
}

fn draw_hud(
    device: &NativeOverlayDevice,
    formats: &NativeTextFormats,
    snapshot: &NativeOverlaySnapshot,
    layout: &NativeOverlayLayout,
    alpha: f32,
) {
    for placement in &layout.hud {
        let Some(item) = snapshot.view.hud.get(placement.index) else {
            continue;
        };
        let toast = item.role == "toast";
        fill_round_rect(
            &device.context,
            &device.brushes.panel,
            placement.rect,
            if toast { 14.0 } else { 18.0 } * layout.scale,
            color(0.025, 0.040, 0.052, if toast { 0.94 } else { 0.76 }),
            alpha,
        );
        if toast {
            let warning = item.id.contains("warning");
            let stripe = NativeOverlayRect {
                x: placement.rect.x,
                y: placement.rect.y,
                width: 4.0 * layout.scale,
                height: placement.rect.height,
            };
            fill_round_rect(
                &device.context,
                if warning {
                    &device.brushes.warning
                } else {
                    &device.brushes.accent
                },
                stripe,
                2.0 * layout.scale,
                if warning {
                    color(1.0, 0.72, 0.25, 1.0)
                } else {
                    accent(&snapshot.view)
                },
                alpha,
            );
            draw_text(
                &device.context,
                &formats.body_bold,
                &device.brushes.text,
                &item.label,
                line_rect(
                    placement.rect,
                    18.0 * layout.scale,
                    8.0 * layout.scale,
                    14.0 * layout.scale,
                    24.0 * layout.scale,
                ),
                color(0.94, 0.97, 0.98, 1.0),
                alpha,
                false,
            );
            draw_text(
                &device.context,
                &formats.caption,
                &device.brushes.muted,
                &item.value,
                line_rect(
                    placement.rect,
                    18.0 * layout.scale,
                    38.0 * layout.scale,
                    14.0 * layout.scale,
                    24.0 * layout.scale,
                ),
                color(0.63, 0.70, 0.73, 1.0),
                alpha,
                false,
            );
        } else {
            draw_text(
                &device.context,
                &formats.caption,
                &device.brushes.text,
                &item.label,
                inset_rect(
                    placement.rect,
                    12.0 * layout.scale,
                    0.0,
                    12.0 * layout.scale,
                    0.0,
                ),
                color(0.87, 0.93, 0.92, 1.0),
                alpha,
                false,
            );
        }
    }
}

fn brush(context: &ID2D1DeviceContext) -> Result<ID2D1SolidColorBrush, String> {
    unsafe {
        context
            .CreateSolidColorBrush(&color(0.0, 0.0, 0.0, 0.0), None)
            .map_err(|error| format!("native overlay brush: {error}"))
    }
}

fn text_format(
    write: &IDWriteFactory,
    family: &str,
    size: f32,
    semibold: bool,
) -> Result<IDWriteTextFormat, String> {
    let family = family.encode_utf16().chain(Some(0)).collect::<Vec<_>>();
    unsafe {
        let format = write
            .CreateTextFormat(
                PCWSTR::from_raw(family.as_ptr()),
                None,
                if semibold {
                    DWRITE_FONT_WEIGHT_SEMI_BOLD
                } else {
                    DWRITE_FONT_WEIGHT_NORMAL
                },
                DWRITE_FONT_STYLE_NORMAL,
                DWRITE_FONT_STRETCH_NORMAL,
                size.max(8.0),
                w!("en-US"),
            )
            .map_err(|error| format!("native overlay text format: {error}"))?;
        format
            .SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP)
            .map_err(|error| error.to_string())?;
        Ok(format)
    }
}

fn draw_text(
    context: &ID2D1DeviceContext,
    format: &IDWriteTextFormat,
    brush: &ID2D1SolidColorBrush,
    text: &str,
    rect: NativeOverlayRect,
    text_color: D2D1_COLOR_F,
    alpha: f32,
    trailing: bool,
) {
    if text.is_empty() || rect.width <= 0.0 || rect.height <= 0.0 {
        return;
    }
    let text = text.encode_utf16().collect::<Vec<_>>();
    unsafe {
        let _ = format.SetTextAlignment(if trailing {
            DWRITE_TEXT_ALIGNMENT_TRAILING
        } else {
            DWRITE_TEXT_ALIGNMENT_LEADING
        });
        let _ = format.SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT_CENTER);
        paint(brush, text_color, alpha);
        context.DrawText(
            &text,
            format,
            &d2d_rect(rect),
            brush,
            D2D1_DRAW_TEXT_OPTIONS_CLIP,
            DWRITE_MEASURING_MODE_NATURAL,
        );
    }
}

fn draw_wrapped_text(
    context: &ID2D1DeviceContext,
    format: &IDWriteTextFormat,
    brush: &ID2D1SolidColorBrush,
    text: &str,
    rect: NativeOverlayRect,
    text_color: D2D1_COLOR_F,
    alpha: f32,
    trailing: bool,
) {
    if text.is_empty() || rect.width <= 0.0 || rect.height <= 0.0 {
        return;
    }
    let text = text.encode_utf16().collect::<Vec<_>>();
    unsafe {
        let _ = format.SetWordWrapping(DWRITE_WORD_WRAPPING_WRAP);
        let _ = format.SetTextAlignment(if trailing {
            DWRITE_TEXT_ALIGNMENT_TRAILING
        } else {
            DWRITE_TEXT_ALIGNMENT_LEADING
        });
        let _ = format.SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT_CENTER);
        paint(brush, text_color, alpha);
        context.DrawText(
            &text,
            format,
            &d2d_rect(rect),
            brush,
            D2D1_DRAW_TEXT_OPTIONS_CLIP,
            DWRITE_MEASURING_MODE_NATURAL,
        );
        let _ = format.SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP);
    }
}

fn fill_rect(
    context: &ID2D1DeviceContext,
    brush: &ID2D1SolidColorBrush,
    rect: NativeOverlayRect,
    fill: D2D1_COLOR_F,
    alpha: f32,
) {
    unsafe {
        paint(brush, fill, alpha);
        context.FillRectangle(&d2d_rect(rect), brush);
    }
}

fn fill_round_rect(
    context: &ID2D1DeviceContext,
    brush: &ID2D1SolidColorBrush,
    rect: NativeOverlayRect,
    radius: f32,
    fill: D2D1_COLOR_F,
    alpha: f32,
) {
    let rounded = D2D1_ROUNDED_RECT {
        rect: d2d_rect(rect),
        radiusX: radius,
        radiusY: radius,
    };
    unsafe {
        paint(brush, fill, alpha);
        context.FillRoundedRectangle(&rounded, brush);
    }
}

fn stroke_rect(
    context: &ID2D1DeviceContext,
    brush: &ID2D1SolidColorBrush,
    rect: NativeOverlayRect,
    width: f32,
    stroke: D2D1_COLOR_F,
    alpha: f32,
) {
    unsafe {
        paint(brush, stroke, alpha);
        context.DrawRectangle(&d2d_rect(rect), brush, width, None);
    }
}

fn stroke_round_rect(
    context: &ID2D1DeviceContext,
    brush: &ID2D1SolidColorBrush,
    rect: NativeOverlayRect,
    radius: f32,
    width: f32,
    stroke: D2D1_COLOR_F,
    alpha: f32,
) {
    let rounded = D2D1_ROUNDED_RECT {
        rect: d2d_rect(rect),
        radiusX: radius,
        radiusY: radius,
    };
    unsafe {
        paint(brush, stroke, alpha);
        context.DrawRoundedRectangle(&rounded, brush, width, None);
    }
}

fn paint(brush: &ID2D1SolidColorBrush, paint: D2D1_COLOR_F, alpha: f32) {
    unsafe {
        brush.SetColor(&D2D1_COLOR_F {
            a: (paint.a * alpha).clamp(0.0, 1.0),
            ..paint
        });
        brush.SetOpacity(1.0);
    }
}

fn line_rect(
    rect: NativeOverlayRect,
    left: f32,
    top: f32,
    right: f32,
    height: f32,
) -> NativeOverlayRect {
    NativeOverlayRect {
        x: rect.x + left,
        y: rect.y + top,
        width: (rect.width - left - right).max(0.0),
        height: height.max(0.0),
    }
}

fn inset_rect(
    rect: NativeOverlayRect,
    left: f32,
    top: f32,
    right: f32,
    bottom: f32,
) -> NativeOverlayRect {
    NativeOverlayRect {
        x: rect.x + left,
        y: rect.y + top,
        width: (rect.width - left - right).max(0.0),
        height: (rect.height - top - bottom).max(0.0),
    }
}

fn d2d_rect(rect: NativeOverlayRect) -> D2D_RECT_F {
    D2D_RECT_F {
        left: rect.x,
        top: rect.y,
        right: rect.x + rect.width,
        bottom: rect.y + rect.height,
    }
}

const fn color(r: f32, g: f32, b: f32, a: f32) -> D2D1_COLOR_F {
    D2D1_COLOR_F { r, g, b, a }
}

fn accent(view: &NativeOverlay) -> D2D1_COLOR_F {
    let packed = if view.accent == 0 {
        0x001db954
    } else {
        view.accent
    };
    color(
        ((packed >> 16) & 0xff) as f32 / 255.0,
        ((packed >> 8) & 0xff) as f32 / 255.0,
        (packed & 0xff) as f32 / 255.0,
        1.0,
    )
}
