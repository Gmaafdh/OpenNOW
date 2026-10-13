//! Direct3D feature-level policy for the Windows decode, conversion and presentation paths.
//!
//! DirectX 10 class GPUs (feature level 10_0 and 10_1) do create a D3D11 device, but they
//! expose neither Shader Model 5.0 nor the D3D11 video processor that the normal Windows
//! pipeline uses for YCbCr-to-RGB conversion, ten-bit output and flip-model presentation.
//! A DirectX 11 device can land in the same situation when the driver refuses
//! `ID3D11VideoDevice`, which is what happens on the WARP software rasterizer Qt Quick
//! falls back to when the hardware cannot run its D3D11 RHI.
//!
//! This module is the single owner of that decision so the capability probe, the standalone
//! presenter and the embedded Qt pipeline cannot disagree about what a device may decode and
//! how it may present. It is deliberately free of `windows` crate types so its unit tests run
//! on every host that builds the streamer workspace.

use std::ffi::CStr;

use crate::{VideoCodec, VideoPixelFormat};

/// Raw `D3D_FEATURE_LEVEL` values reported by `ID3D11Device::GetFeatureLevel`.
pub const FEATURE_LEVEL_9_3: i32 = 0x9300;
pub const FEATURE_LEVEL_10_0: i32 = 0xa000;
pub const FEATURE_LEVEL_10_1: i32 = 0xa100;
pub const FEATURE_LEVEL_11_0: i32 = 0xb000;
pub const FEATURE_LEVEL_11_1: i32 = 0xb100;
pub const FEATURE_LEVEL_12_0: i32 = 0xc000;
pub const FEATURE_LEVEL_12_1: i32 = 0xc100;
pub const FEATURE_LEVEL_12_2: i32 = 0xc200;

/// The feature levels requested when OpenNOW creates its own D3D11 device. DirectX 10 class
/// adapters are included so a DX10 GPU is used for DXVA decode instead of being skipped.
pub const REQUESTED_FEATURE_LEVELS: [i32; 4] = [
    FEATURE_LEVEL_11_1,
    FEATURE_LEVEL_11_0,
    FEATURE_LEVEL_10_1,
    FEATURE_LEVEL_10_0,
];

/// Everything below feature level 11_0 shares one capability ceiling, so the pipeline only
/// needs to distinguish the two tiers.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FeatureTier {
    /// Feature level 10_1 and below: Shader Model 4.x, no D3D11 video processor, no
    /// flip-model swap chain, no ten-bit or HDR output.
    Direct3d10,
    /// Feature level 11_0 and above: the normal OpenNOW Windows pipeline.
    Direct3d11,
}

impl FeatureTier {
    pub const fn label(self) -> &'static str {
        match self {
            Self::Direct3d10 => "DirectX 10",
            Self::Direct3d11 => "DirectX 11",
        }
    }

    /// Whether `ID3D11VideoProcessor` may be used for YCbCr-to-RGB conversion. Feature level
    /// 10_x exposes the D3D11 video decode interfaces but not the video processor, so the
    /// compatibility converter in `windows/compat.rs` takes over.
    pub const fn video_processor(self) -> bool {
        matches!(self, Self::Direct3d11)
    }

    /// Whether the presenter may create a flip-model swap chain with a frame-latency waitable
    /// object and tearing. Bitblt-model presentation is the DirectX 10 contract.
    pub const fn flip_model_swap_chain(self) -> bool {
        matches!(self, Self::Direct3d11)
    }

    pub const fn allow_tearing(self) -> bool {
        matches!(self, Self::Direct3d11)
    }

    /// Ten-bit scan-out and HDR need `R10G10B10A2` output plus a ten-bit conversion path that
    /// DirectX 10 class hardware cannot provide.
    pub const fn ten_bit_output(self) -> bool {
        matches!(self, Self::Direct3d11)
    }

    pub const fn hdr_output(self) -> bool {
        matches!(self, Self::Direct3d11)
    }

    pub const fn shader_model(self) -> ShaderModel {
        match self {
            Self::Direct3d10 => ShaderModel::Sm40,
            Self::Direct3d11 => ShaderModel::Sm50,
        }
    }

    /// Whether the CPU conversion bridge is the only way to reach an RGB frame on this tier.
    pub const fn compat_conversion(self) -> bool {
        matches!(self, Self::Direct3d10)
    }
}

/// Shader Model targets for runtime `D3DCompile` calls. DirectX 10 class hardware rejects
/// Shader Model 5.0 bytecode, which is also why Qt Quick's D3D11 RHI cannot use it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShaderModel {
    Sm40,
    Sm50,
}

impl ShaderModel {
    pub const fn vertex_target(self) -> &'static CStr {
        match self {
            Self::Sm40 => c"vs_4_0",
            Self::Sm50 => c"vs_5_0",
        }
    }

    pub const fn pixel_target(self) -> &'static CStr {
        match self {
            Self::Sm40 => c"ps_4_0",
            Self::Sm50 => c"ps_5_0",
        }
    }
}

/// A validated device feature level.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DeviceFeatureLevel(i32);

impl DeviceFeatureLevel {
    /// Accepts only feature levels Direct3D 11 can report. An unrecognized value stays `None`
    /// so callers fall back to the normal pipeline instead of inventing a ceiling.
    pub const fn from_raw(raw: i32) -> Option<Self> {
        match raw {
            FEATURE_LEVEL_9_3
            | FEATURE_LEVEL_10_0
            | FEATURE_LEVEL_10_1
            | FEATURE_LEVEL_11_0
            | FEATURE_LEVEL_11_1
            | FEATURE_LEVEL_12_0
            | FEATURE_LEVEL_12_1
            | FEATURE_LEVEL_12_2 => Some(Self(raw)),
            _ => None,
        }
    }

    pub const fn raw(self) -> i32 {
        self.0
    }

    pub const fn tier(self) -> FeatureTier {
        if self.0 >= FEATURE_LEVEL_11_0 {
            FeatureTier::Direct3d11
        } else {
            FeatureTier::Direct3d10
        }
    }

    pub const fn label(self) -> &'static str {
        match self.0 {
            FEATURE_LEVEL_9_3 => "9_3",
            FEATURE_LEVEL_10_0 => "10_0",
            FEATURE_LEVEL_10_1 => "10_1",
            FEATURE_LEVEL_11_0 => "11_0",
            FEATURE_LEVEL_11_1 => "11_1",
            FEATURE_LEVEL_12_0 => "12_0",
            FEATURE_LEVEL_12_1 => "12_1",
            FEATURE_LEVEL_12_2 => "12_2",
            _ => "unknown",
        }
    }
}

/// Classifies an optional raw feature level. `None` means the device did not report one, which
/// is treated as the normal pipeline: the runtime probe of the video interfaces still decides
/// whether the compatibility converter is required.
pub const fn tier_of(feature_level: Option<i32>) -> FeatureTier {
    match feature_level {
        Some(raw) => {
            if raw < FEATURE_LEVEL_11_0 {
                FeatureTier::Direct3d10
            } else {
                FeatureTier::Direct3d11
            }
        }
        None => FeatureTier::Direct3d11,
    }
}

/// Whether the CPU conversion bridge must replace the D3D11 video processor.
///
/// A missing video interface forces it on any feature level, because the conversion is the only
/// remaining way to produce RGB. A reported feature level below 11_0 forces it even when the
/// interface exists, because Shader Model 5.0 and the ten-bit output paths are unavailable.
pub const fn requires_compat_conversion(
    feature_level: Option<i32>,
    video_interface_available: bool,
) -> bool {
    match video_interface_available {
        false => true,
        true => tier_of(feature_level).compat_conversion(),
    }
}

/// The exact decode ceiling for a tier.
///
/// DirectX 10 class hardware decodes H.264 8-bit 4:2:0 through DXVA. HEVC and AV1 Media
/// Foundation decoders need feature level 11_0 hardware, and ten-bit, 4:4:4 and HDR output all
/// need the video processor or a Shader Model 5.0 conversion path, so they stay unsupported
/// rather than being down-converted silently.
pub const fn tier_allows_format(
    tier: FeatureTier,
    codec: VideoCodec,
    pixel_format: VideoPixelFormat,
    hdr: bool,
) -> bool {
    match tier {
        FeatureTier::Direct3d11 => true,
        FeatureTier::Direct3d10 => match hdr {
            true => false,
            false => {
                matches!(codec, VideoCodec::H264) && matches!(pixel_format, VideoPixelFormat::Nv12)
            }
        },
    }
}

/// Whether a feature level allows the format at all, without a validated tier.
pub const fn allows_format(
    feature_level: Option<i32>,
    codec: VideoCodec,
    pixel_format: VideoPixelFormat,
    hdr: bool,
) -> bool {
    tier_allows_format(tier_of(feature_level), codec, pixel_format, hdr)
}

/// Swap-chain parameters for the standalone Windows presenter, derived from the feature level.
///
/// DirectX 10 class devices get a bitblt-model chain: one buffer, no waitable object, no
/// tearing and 8-bit scan-out. Scaling and letterboxing stay on the GPU through the Shader
/// Model 4.0 present draw in `windows/compat.rs`, not in DXGI and not on the CPU.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SwapChainProfile {
    pub flip_model: bool,
    pub buffer_count: u32,
    pub allow_tearing: bool,
    pub waitable_object: bool,
    pub ten_bit_output: bool,
    /// Interval passed to `IDXGISwapChain1::Present`. Bitblt presentation waits for vsync
    /// because tearing is not available.
    pub present_sync_interval: u32,
}

pub const fn swap_chain_profile(feature_level: Option<i32>) -> SwapChainProfile {
    match tier_of(feature_level) {
        FeatureTier::Direct3d11 => SwapChainProfile {
            flip_model: true,
            buffer_count: 2,
            allow_tearing: true,
            waitable_object: true,
            ten_bit_output: true,
            present_sync_interval: 0,
        },
        FeatureTier::Direct3d10 => SwapChainProfile {
            flip_model: false,
            buffer_count: 1,
            allow_tearing: false,
            waitable_object: false,
            ten_bit_output: false,
            present_sync_interval: 1,
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn feature_levels_classify_into_exactly_two_tiers() {
        assert_eq!(
            DeviceFeatureLevel::from_raw(FEATURE_LEVEL_9_3).unwrap().tier(),
            FeatureTier::Direct3d10
        );
        assert_eq!(
            DeviceFeatureLevel::from_raw(FEATURE_LEVEL_10_0).unwrap().tier(),
            FeatureTier::Direct3d10
        );
        assert_eq!(
            DeviceFeatureLevel::from_raw(FEATURE_LEVEL_10_1).unwrap().tier(),
            FeatureTier::Direct3d10
        );
        assert_eq!(
            DeviceFeatureLevel::from_raw(FEATURE_LEVEL_10_1).unwrap().label(),
            "10_1"
        );
        for raw in [
            FEATURE_LEVEL_11_0,
            FEATURE_LEVEL_11_1,
            FEATURE_LEVEL_12_0,
            FEATURE_LEVEL_12_1,
            FEATURE_LEVEL_12_2,
        ] {
            let level = DeviceFeatureLevel::from_raw(raw).unwrap();
            assert_eq!(level.tier(), FeatureTier::Direct3d11);
            assert_eq!(level.raw(), raw);
        }
    }

    #[test]
    fn unrecognized_feature_levels_stay_unknown_instead_of_guessing_a_ceiling() {
        for raw in [0, -1, 0x9200, 0xa200, 0xb200, i32::MAX] {
            assert!(DeviceFeatureLevel::from_raw(raw).is_none(), "raw={raw}");
        }
        assert_eq!(DeviceFeatureLevel::from_raw(0xa200).map(|level| level.label()), None);
        // An absent feature level keeps the normal pipeline; the video-interface probe decides.
        assert_eq!(tier_of(None), FeatureTier::Direct3d11);
        assert_eq!(tier_of(Some(0)), FeatureTier::Direct3d11);
    }

    #[test]
    fn directx10_devices_never_use_the_video_processor_flip_chain_or_ten_bit_output() {
        let ten = FeatureTier::Direct3d10;
        assert!(!ten.video_processor());
        assert!(!ten.flip_model_swap_chain());
        assert!(!ten.allow_tearing());
        assert!(!ten.ten_bit_output());
        assert!(!ten.hdr_output());
        assert!(ten.compat_conversion());
        assert_eq!(ten.shader_model(), ShaderModel::Sm40);
        assert_eq!(ten.label(), "DirectX 10");

        let eleven = FeatureTier::Direct3d11;
        assert!(eleven.video_processor());
        assert!(eleven.flip_model_swap_chain());
        assert!(eleven.allow_tearing());
        assert!(eleven.ten_bit_output());
        assert!(eleven.hdr_output());
        assert!(!eleven.compat_conversion());
        assert_eq!(eleven.shader_model(), ShaderModel::Sm50);
    }

    #[test]
    fn shader_targets_match_the_tier() {
        assert_eq!(ShaderModel::Sm40.vertex_target(), c"vs_4_0");
        assert_eq!(ShaderModel::Sm40.pixel_target(), c"ps_4_0");
        assert_eq!(ShaderModel::Sm50.vertex_target(), c"vs_5_0");
        assert_eq!(ShaderModel::Sm50.pixel_target(), c"ps_5_0");
    }

    #[test]
    fn a_missing_video_interface_forces_compat_conversion_on_every_feature_level() {
        assert!(requires_compat_conversion(Some(FEATURE_LEVEL_12_1), false));
        assert!(requires_compat_conversion(Some(FEATURE_LEVEL_11_0), false));
        assert!(requires_compat_conversion(None, false));
        assert!(requires_compat_conversion(Some(FEATURE_LEVEL_10_1), true));
        assert!(!requires_compat_conversion(None, true));
        assert!(!requires_compat_conversion(Some(FEATURE_LEVEL_11_1), true));
    }

    #[test]
    fn directx10_ceiling_is_h264_eight_bit_420_sdr_only() {
        let ten = FeatureTier::Direct3d10;
        assert!(tier_allows_format(
            ten,
            VideoCodec::H264,
            VideoPixelFormat::Nv12,
            false
        ));
        for (codec, pixel_format, hdr) in [
            (VideoCodec::H264, VideoPixelFormat::Nv12, true),
            (VideoCodec::H264, VideoPixelFormat::P010, false),
            (VideoCodec::H265, VideoPixelFormat::Nv12, false),
            (VideoCodec::H265, VideoPixelFormat::P010, false),
            (VideoCodec::H265, VideoPixelFormat::P010, true),
            (VideoCodec::H265, VideoPixelFormat::Ayuv, false),
            (VideoCodec::H265, VideoPixelFormat::Y410, false),
            (VideoCodec::H265, VideoPixelFormat::Y410, true),
            (VideoCodec::Av1, VideoPixelFormat::Nv12, false),
            (VideoCodec::Av1, VideoPixelFormat::P010, false),
            (VideoCodec::Av1, VideoPixelFormat::P010, true),
        ] {
            assert!(
                !tier_allows_format(ten, codec, pixel_format, hdr),
                "{codec:?} {pixel_format:?} hdr={hdr} must stay unsupported on DirectX 10"
            );
        }
        // The normal tier keeps its existing ceiling, which the runtime probes still decide.
        for (codec, pixel_format, hdr) in [
            (VideoCodec::H264, VideoPixelFormat::Nv12, false),
            (VideoCodec::H265, VideoPixelFormat::Y410, true),
            (VideoCodec::Av1, VideoPixelFormat::P010, true),
        ] {
            assert!(tier_allows_format(
                FeatureTier::Direct3d11,
                codec,
                pixel_format,
                hdr
            ));
        }
    }

    #[test]
    fn allows_format_follows_the_reported_feature_level() {
        assert!(!allows_format(
            Some(FEATURE_LEVEL_10_0),
            VideoCodec::H265,
            VideoPixelFormat::Nv12,
            false
        ));
        assert!(allows_format(
            Some(FEATURE_LEVEL_11_0),
            VideoCodec::H265,
            VideoPixelFormat::Nv12,
            false
        ));
        assert!(allows_format(
            None,
            VideoCodec::Av1,
            VideoPixelFormat::P010,
            true
        ));
    }

    #[test]
    fn directx10_swap_chains_are_bitblt_single_buffer_stretch_and_vsync() {
        let compat = swap_chain_profile(Some(FEATURE_LEVEL_10_1));
        assert!(!compat.flip_model);
        assert_eq!(compat.buffer_count, 1);
        assert!(!compat.allow_tearing);
        assert!(!compat.waitable_object);
        assert!(!compat.ten_bit_output);
        assert_eq!(compat.present_sync_interval, 1);
        assert_eq!(compat, swap_chain_profile(Some(FEATURE_LEVEL_9_3)));

        let normal = swap_chain_profile(Some(FEATURE_LEVEL_12_0));
        assert!(normal.flip_model);
        assert_eq!(normal.buffer_count, 2);
        assert!(normal.allow_tearing);
        assert!(normal.waitable_object);
        assert!(normal.ten_bit_output);
        assert_eq!(normal.present_sync_interval, 0);
        assert_eq!(normal, swap_chain_profile(None));
    }

    #[test]
    fn requested_feature_levels_keep_directx10_adapters_in_the_search() {
        assert_eq!(
            REQUESTED_FEATURE_LEVELS,
            [
                FEATURE_LEVEL_11_1,
                FEATURE_LEVEL_11_0,
                FEATURE_LEVEL_10_1,
                FEATURE_LEVEL_10_0
            ]
        );
        assert!(REQUESTED_FEATURE_LEVELS
            .iter()
            .any(|raw| DeviceFeatureLevel::from_raw(*raw).unwrap().tier() == FeatureTier::Direct3d10));
    }
}
