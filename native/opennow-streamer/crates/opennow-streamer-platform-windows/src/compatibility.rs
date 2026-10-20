//! Bounds and color math for the explicit CPU-decode compatibility path.
//! No Windows APIs here: layout and color invariants run on every test host.
use crate::{
    VideoChromaFormat, VideoChromaSiting, VideoCodec, VideoColorMatrix, VideoColorPrimaries,
    VideoFormat, VideoPixelFormat, VideoTransferFunction,
};

/// Keep CPU allocations bounded independently of a transform's reported size.
pub(crate) const MAX_NV12_SAMPLE_BYTES: u32 = 64 * 1024 * 1024;

pub(crate) fn output_buffer_alignment(size: u32, alignment: u32) -> Result<u32, String> {
    if size == 0
        || size > MAX_NV12_SAMPLE_BYTES
        || alignment > 65536
        || (alignment != 0 && !alignment.is_power_of_two())
    {
        return Err("invalid or oversized software decoder output buffer".to_owned());
    }
    // MFT_OUTPUT_STREAM_INFO uses bytes; MFCreateAlignedMemoryBuffer uses a
    // mask (MF_16_BYTE_ALIGNMENT = 15). Zero means no additional alignment.
    Ok(alignment.saturating_sub(1))
}

pub(crate) fn video_backend(available: bool) -> opennow_streamer_protocol::VideoBackendCapability {
    use opennow_streamer_protocol::{CodecCapability, DecodeDimensions, VideoBackendCapability};
    // The ID names Qt's presentation API, not the physical GPU's feature
    // level. Annotate CPU decode without adding a new backend choice to the UI.
    VideoBackendCapability {
        backend: "d3d11",
        platform: "windows",
        software_decode: true,
        codecs: ["h264", "h265", "av1"]
            .into_iter()
            .map(|codec| {
                let usable = available && codec == "h264";
                CodecCapability {
                    codec,
                    available: usable,
                    color_qualities: Some(if usable { vec!["8bit_420"] } else { Vec::new() }),
                    hdr_color_qualities: Some(Vec::new()),
                    hdr_supported: Some(false),
                    max_decode_dimensions: usable.then_some(DecodeDimensions {
                        width: crate::MAX_DECODE_WIDTH,
                        height: crate::MAX_DECODE_HEIGHT,
                    }),
                    reason: (!usable).then_some(
                        "Windows compatibility mode requires H.264 8-bit 4:2:0 SDR and a usable software decoder",
                    ),
                }
            })
            .collect(),
        zero_copy_modes: Vec::new(),
        available,
        reason: (!available).then_some(
            "Windows WARP/H.264 compatibility decode or texture upload is unavailable",
        ),
    }
}

pub(crate) fn validate_format(format: VideoFormat) -> Result<(), String> {
    format.validate().map_err(|error| error.to_string())?;
    if format.codec != VideoCodec::H264
        || format.pixel_format != VideoPixelFormat::Nv12
        || format.chroma_format != VideoChromaFormat::Cs420
        || format.transfer_function != VideoTransferFunction::Sdr
        || format.color_primaries != VideoColorPrimaries::Bt709
        || !matches!(
            format.color_matrix,
            VideoColorMatrix::Bt601 | VideoColorMatrix::Bt709
        )
    {
        return Err("Windows compatibility mode supports H.264 8-bit 4:2:0 SDR only; select Auto codec and 8-bit 4:2:0 or a hardware-capable GPU".to_owned());
    }
    Ok(())
}

pub(crate) fn decoder_idle_wait(asynchronous: bool, output_pending: bool) -> std::time::Duration {
    std::time::Duration::from_millis(if asynchronous || output_pending {
        1
    } else {
        100
    })
}

pub(crate) fn ready_frame_capacity(mode: crate::WindowsDecoderMode) -> usize {
    match mode {
        // A slow CPU should discard stale decoded output, not retain seven
        // large system-memory samples while waiting for Qt/WARP to compose.
        crate::WindowsDecoderMode::Software => 1,
        crate::WindowsDecoderMode::Hardware => crate::ADAPTIVE_VIDEO_QUEUE_CAPACITY,
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct Nv12Layout {
    pub(crate) width: u32,
    pub(crate) height: u32,
    pub(crate) pitch: u32,
    pub(crate) uv_offset: usize,
    pub(crate) byte_len: usize,
}

impl Nv12Layout {
    pub(crate) fn new(width: u32, height: u32, pitch: i32, len: usize) -> Result<Self, String> {
        // Allow codec allocation padding while keeping the fallback bounded.
        // Never dereference a layout derived from unchecked MFT metadata.
        if width == 0
            || height == 0
            || width > 4096
            || height > 2560
            || width % 2 != 0
            || height % 2 != 0
            || pitch <= 0
            || (pitch as u32) < width
            || pitch > 16384
        {
            return Err("invalid or oversized compatibility NV12 layout".to_owned());
        }
        let pitch = pitch as u32;
        let uv_offset = (pitch as usize)
            .checked_mul(height as usize)
            .ok_or("compatibility luma layout overflow")?;
        let byte_len = uv_offset
            .checked_add((pitch as usize) * (height as usize / 2))
            .ok_or("compatibility chroma layout overflow")?;
        if byte_len > len {
            return Err(format!(
                "compatibility NV12 sample is truncated: {len} < {byte_len}"
            ));
        }
        Ok(Self {
            width,
            height,
            pitch,
            uv_offset,
            byte_len,
        })
    }
}

#[repr(C)]
pub(crate) struct SdrConstants {
    pub(crate) scale_bias: [f32; 4],
    pub(crate) matrix: [f32; 4],
    pub(crate) source: [f32; 4],
    pub(crate) chroma: [f32; 4],
}

impl SdrConstants {
    pub(crate) fn new(
        format: VideoFormat,
        width: u32,
        height: u32,
        x: u32,
        y: u32,
    ) -> Result<Self, String> {
        validate_format(format)?;
        // Textures return normalized 8-bit codes. Do not use the legacy
        // video-processor defaults (or RGB conversion in the software codec).
        Ok(Self {
            scale_bias: if format.full_range {
                [1.0, 0.0, 1.0, -128.0 / 255.0]
            } else {
                [255.0 / 219.0, -16.0 / 219.0, 255.0 / 224.0, -128.0 / 224.0]
            },
            matrix: match format.color_matrix {
                VideoColorMatrix::Bt601 => [1.402, -0.344_136_3, -0.714_136_3, 1.772],
                _ => [1.5748, -0.187_324_27, -0.468_124_27, 1.8556],
            },
            source: [width as f32, height as f32, x as f32, y as f32],
            // LEFT is horizontally cosited, vertically centered. TOPLEFT is
            // cosited in both axes. Coordinates refer to luma pixel centers.
            chroma: [
                0.5,
                if format.chroma_siting == VideoChromaSiting::TopLeft {
                    0.5
                } else {
                    0.0
                },
                format.width as f32,
                format.height as f32,
            ],
        })
    }
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use std::num::NonZeroU32;

    pub(crate) fn format() -> VideoFormat {
        VideoFormat {
            codec: VideoCodec::H264,
            width: 1920,
            height: 1080,
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
        }
    }

    #[test]
    fn h264_probe_contains_one_independent_access_unit_not_a_whole_stream() {
        let data = include_bytes!("../fixtures/probe/h264-nv12-sdr.h264");
        let nals = data
            .windows(4)
            .filter_map(|window| (window[..3] == [0, 0, 1]).then_some(window[3] & 31))
            .collect::<Vec<_>>();
        assert_eq!(nals, [7, 8, 6, 5], "SPS, PPS, SEI and one IDR only");
    }

    #[test]
    fn compatibility_capabilities_are_explicit_and_fail_closed() {
        for available in [false, true] {
            let backend = video_backend(available);
            assert_eq!((backend.backend, backend.platform), ("d3d11", "windows"));
            assert!(backend.software_decode);
            assert!(backend.zero_copy_modes.is_empty());
            assert_eq!(backend.available, available);
            assert_eq!(backend.reason.is_none(), available);
            assert_eq!(backend.codecs.len(), 3);
            for codec in backend.codecs {
                let usable = available && codec.codec == "h264";
                assert_eq!(codec.available, usable);
                assert_eq!(codec.hdr_supported, Some(false));
                assert_eq!(codec.hdr_color_qualities, Some(Vec::new()));
                assert_eq!(
                    codec
                        .max_decode_dimensions
                        .as_ref()
                        .map(|limit| (limit.width, limit.height)),
                    usable.then_some((crate::MAX_DECODE_WIDTH, crate::MAX_DECODE_HEIGHT)),
                );
                assert_eq!(
                    codec.color_qualities,
                    Some(if usable { vec!["8bit_420"] } else { Vec::new() })
                );
                assert_eq!(codec.reason.is_none(), usable);
            }
        }
    }

    #[test]
    fn output_allocations_are_bounded_and_convert_alignment_bytes_to_a_mask() {
        for (bytes, mask) in [(0, 0), (1, 0), (16, 15), (65536, 65535)] {
            assert_eq!(
                output_buffer_alignment(1920 * 1080 * 3 / 2, bytes).unwrap(),
                mask
            );
        }
        for (size, alignment) in [(0, 0), (MAX_NV12_SAMPLE_BYTES + 1, 0), (32, 3), (32, 65537)] {
            assert!(output_buffer_alignment(size, alignment).is_err());
        }
    }

    #[test]
    fn only_a_drained_synchronous_decoder_uses_the_long_idle_wait() {
        use std::time::Duration;
        assert_eq!(decoder_idle_wait(false, false), Duration::from_millis(100));
        for (asynchronous, pending) in [(true, false), (true, true), (false, true)] {
            assert_eq!(
                decoder_idle_wait(asynchronous, pending),
                Duration::from_millis(1)
            );
        }
    }

    #[test]
    fn software_ready_queue_is_latest_only_without_shrinking_hardware_burst_allowance() {
        assert_eq!(ready_frame_capacity(crate::WindowsDecoderMode::Software), 1);
        assert_eq!(
            ready_frame_capacity(crate::WindowsDecoderMode::Hardware),
            crate::ADAPTIVE_VIDEO_QUEUE_CAPACITY
        );
    }

    #[test]
    fn padded_nv12_layout_keeps_the_entire_chroma_plane_in_bounds() {
        let layout = Nv12Layout::new(1920, 1088, 2048, 2048 * 1632).unwrap();
        assert_eq!(layout.uv_offset, 2048 * 1088);
        assert_eq!(layout.byte_len, 2048 * 1632);
        assert!(Nv12Layout::new(1920, 1088, 2048, layout.byte_len - 1).is_err());
        assert_eq!(Nv12Layout::new(2, 2, 2, 6).unwrap().byte_len, 6);
    }

    #[test]
    fn malformed_layouts_never_reach_a_texture_upload() {
        for (width, height, pitch) in [
            (0, 1080, 1920),
            (1921, 1080, 1922),
            (1920, 1079, 1920),
            (1920, 1080, 1919),
            (1920, 1080, -1920),
            (8194, 2, 8194),
            (2, u32::MAX, 2),
            (2, 2, i32::MAX),
        ] {
            assert!(Nv12Layout::new(width, height, pitch, usize::MAX).is_err());
        }
    }

    #[test]
    fn compatibility_never_claims_advanced_profiles() {
        validate_format(format()).unwrap();
        for changed in [
            VideoFormat {
                codec: VideoCodec::H265,
                ..format()
            },
            VideoFormat {
                codec: VideoCodec::Av1,
                ..format()
            },
            VideoFormat {
                pixel_format: VideoPixelFormat::P010,
                ..format()
            },
            VideoFormat {
                pixel_format: VideoPixelFormat::Ayuv,
                chroma_format: VideoChromaFormat::Cs444,
                ..format()
            },
            VideoFormat {
                transfer_function: VideoTransferFunction::Pq,
                ..format()
            },
            VideoFormat {
                color_primaries: VideoColorPrimaries::Bt2020,
                ..format()
            },
        ] {
            assert!(validate_format(changed).is_err());
        }
    }

    #[test]
    fn sdr_conversion_preserves_range_and_chroma_siting_explicitly() {
        assert_eq!(std::mem::size_of::<SdrConstants>(), 64);
        for full_range in [false, true] {
            let constants = SdrConstants::new(
                VideoFormat {
                    full_range,
                    ..format()
                },
                1920,
                1088,
                8,
                4,
            )
            .unwrap();
            let [ys, yb, cs, cb] = constants.scale_bias;
            let (black, white) = if full_range { (0, 255) } else { (16, 235) };
            assert!((black as f32 / 255.0 * ys + yb).abs() < 0.000001);
            assert!((white as f32 / 255.0 * ys + yb - 1.0).abs() < 0.000001);
            assert!((128.0 / 255.0 * cs + cb).abs() < 0.000001);
            assert_eq!(constants.source, [1920.0, 1088.0, 8.0, 4.0]);
            assert_eq!(constants.chroma, [0.5, 0.0, 1920.0, 1080.0]);
        }
        let constants = SdrConstants::new(
            VideoFormat {
                chroma_siting: VideoChromaSiting::TopLeft,
                ..format()
            },
            1920,
            1080,
            0,
            0,
        )
        .unwrap();
        assert_eq!(constants.chroma[1], 0.5);
        let bt601 = SdrConstants::new(
            VideoFormat {
                color_matrix: VideoColorMatrix::Bt601,
                ..format()
            },
            1920,
            1080,
            0,
            0,
        )
        .unwrap();
        assert_eq!(bt601.matrix, [1.402, -0.344_136_3, -0.714_136_3, 1.772]);
    }
}
