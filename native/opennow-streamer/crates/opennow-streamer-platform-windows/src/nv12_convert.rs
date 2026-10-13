//! CPU NV12 to RGBA8 conversion for the DirectX 10 compatibility path.
//!
//! Feature level 10_x hardware decodes H.264 through DXVA but cannot create the NV12
//! shader-resource views or the D3D11 video processor that the normal Windows pipeline uses for
//! YCbCr-to-RGB conversion. The decoded surface is therefore read back once per frame on the
//! decoder worker thread and converted here, and only the finished RGBA8 buffer crosses into the
//! presentation device.
//!
//! The module holds no `windows` crate types so its color math is unit tested on every host. The
//! coefficients match [`crate::windows::color::input_color_space`], which is what the video
//! processor is told to use on capable hardware, so a DirectX 10 device and a DirectX 11 device
//! agree on the same stream.

use crate::aperture::VideoAperture;
use crate::{VideoColorMatrix, VideoFormat, VideoPixelFormat, VideoTransferFunction};

/// Normalized YCbCr-to-RGB coefficients for one negotiated `VideoFormat`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) struct YuvRgbCoefficients {
    pub(crate) y_scale: f32,
    pub(crate) y_offset: f32,
    pub(crate) c_scale: f32,
    pub(crate) c_offset: f32,
    pub(crate) r_cr: f32,
    pub(crate) g_cb: f32,
    pub(crate) g_cr: f32,
    pub(crate) b_cb: f32,
}

impl YuvRgbCoefficients {
    /// Derives the exact coefficients for a negotiated format.
    ///
    /// Only 8-bit 4:2:0 SDR is accepted, which is the whole DirectX 10 decode ceiling. HDR,
    /// ten-bit and 4:4:4 formats fail explicitly instead of being down-converted, matching the
    /// rest of the Windows pipeline.
    pub(crate) fn new(format: VideoFormat) -> Result<Self, String> {
        format.validate_color().map_err(|error| error.to_string())?;
        if format.pixel_format != VideoPixelFormat::Nv12 {
            return Err(format!(
                "DirectX 10 compatibility conversion requires NV12 decoder output, not {:?}",
                format.pixel_format
            ));
        }
        if format.transfer_function != VideoTransferFunction::Sdr {
            return Err(
                "DirectX 10 compatibility conversion is SDR-only; HDR needs the embedded Qt presenter"
                    .to_owned(),
            );
        }
        let (y_scale, y_offset, c_scale, c_offset) = if format.full_range {
            (1.0 / 255.0, 0.0, 1.0 / 255.0, -128.0 / 255.0)
        } else {
            (1.0 / 219.0, -16.0 / 219.0, 1.0 / 224.0, -128.0 / 224.0)
        };
        let (r_cr, g_cb, g_cr, b_cb) = match format.color_matrix {
            VideoColorMatrix::Bt601 => (1.402, -0.344_136, -0.714_136, 1.772),
            VideoColorMatrix::Bt709 => (1.5748, -0.187_324_27, -0.468_124_27, 1.8556),
            VideoColorMatrix::Bt2020 => (1.4746, -0.164_553_12, -0.571_353_14, 1.8814),
        };
        Ok(Self {
            y_scale,
            y_offset,
            c_scale,
            c_offset,
            r_cr,
            g_cb,
            g_cr,
            b_cb,
        })
    }

    fn rgb(&self, y: u8, cb: f32, cr: f32) -> [u8; 3] {
        let y = y as f32 * self.y_scale + self.y_offset;
        [
            quantize(y + self.r_cr * cr),
            quantize(y + self.g_cb * cb + self.g_cr * cr),
            quantize(y + self.b_cb * cb),
        ]
    }
}

fn quantize(value: f32) -> u8 {
    (value * 255.0).round().clamp(0.0, 255.0) as u8
}

/// One mapped NV12 surface: a single allocation whose chroma plane starts after the luma plane,
/// both using the `RowPitch` reported by `ID3D11DeviceContext::Map`.
#[derive(Debug, Clone, Copy)]
pub(crate) struct Nv12Surface<'a> {
    pub(crate) data: &'a [u8],
    pub(crate) row_pitch: usize,
    pub(crate) width: u32,
    pub(crate) height: u32,
}

impl Nv12Surface<'_> {
    /// Validates that the mapped slice really covers both planes of this surface.
    pub(crate) fn validate(&self) -> Result<(), String> {
        if self.width == 0 || self.height == 0 {
            return Err("NV12 surface has an empty extent".to_owned());
        }
        if self.width % 2 != 0 || self.height % 2 != 0 {
            return Err(format!(
                "NV12 surface extent {}x{} is not chroma aligned",
                self.width, self.height
            ));
        }
        if self.row_pitch < self.width as usize {
            return Err(format!(
                "NV12 row pitch {} is smaller than the surface width {}",
                self.row_pitch, self.width
            ));
        }
        let required = self
            .row_pitch
            .checked_mul(self.height as usize + (self.height as usize / 2))
            .ok_or("NV12 surface size overflowed")?;
        if self.data.len() < required {
            return Err(format!(
                "mapped NV12 surface holds {} bytes, expected at least {required}",
                self.data.len()
            ));
        }
        Ok(())
    }
}

/// Byte length of the tightly packed RGBA8 output for an aperture.
pub(crate) fn rgba8_len(aperture: VideoAperture) -> usize {
    aperture.width as usize * aperture.height as usize * 4
}

/// Converts the aperture of an NV12 surface into tightly packed RGBA8.
///
/// Chroma is replicated across each 2x2 luma block, which is the same nearest-chroma
/// approximation the video processor applies for 4:2:0 content. The caller owns `output`; it must
/// be exactly [`rgba8_len`] bytes long so a size mismatch fails instead of writing past the end.
pub(crate) fn nv12_to_rgba8(
    surface: &Nv12Surface<'_>,
    aperture: VideoAperture,
    coefficients: &YuvRgbCoefficients,
    output: &mut [u8],
) -> Result<(), String> {
    surface.validate()?;
    aperture.validate_extent(surface.width, surface.height)?;
    let expected = rgba8_len(aperture);
    if output.len() != expected {
        return Err(format!(
            "RGBA8 output holds {} bytes, expected {expected} for a {}x{} aperture",
            output.len(),
            aperture.width,
            aperture.height
        ));
    }
    let pitch = surface.row_pitch;
    let chroma_offset = pitch * surface.height as usize;
    for row in 0..aperture.height as usize {
        let source_y = aperture.y as usize + row;
        let luma = &surface.data[source_y * pitch..][..surface.width as usize];
        let chroma =
            &surface.data[chroma_offset + (source_y / 2) * pitch..][..surface.width as usize];
        let destination = row * aperture.width as usize * 4;
        let mut column = 0;
        while column < aperture.width as usize {
            let source_x = aperture.x as usize + column;
            let chroma_index = (source_x / 2) * 2;
            let cb = chroma[chroma_index] as f32 * coefficients.c_scale + coefficients.c_offset;
            let cr =
                chroma[chroma_index + 1] as f32 * coefficients.c_scale + coefficients.c_offset;
            for step in 0..2usize.min(aperture.width as usize - column) {
                let [red, green, blue] = coefficients.rgb(luma[source_x + step], cb, cr);
                let pixel = destination + (column + step) * 4;
                output[pixel] = red;
                output[pixel + 1] = green;
                output[pixel + 2] = blue;
                output[pixel + 3] = 255;
            }
            column += 2;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{VideoChromaFormat, VideoChromaSiting, VideoCodec};
    use std::num::NonZeroU32;

    fn format(matrix: VideoColorMatrix, full_range: bool) -> VideoFormat {
        VideoFormat {
            codec: VideoCodec::H264,
            width: 64,
            height: 64,
            frame_rate_numerator: NonZeroU32::new(60).unwrap(),
            frame_rate_denominator: NonZeroU32::new(1).unwrap(),
            average_bitrate: 4_000_000,
            pixel_format: VideoPixelFormat::Nv12,
            chroma_format: VideoChromaFormat::Cs420,
            chroma_siting: VideoChromaSiting::Left,
            full_range,
            transfer_function: VideoTransferFunction::Sdr,
            color_primaries: crate::VideoColorPrimaries::Bt709,
            color_matrix: matrix,
        }
    }

    fn full_aperture(width: u32, height: u32) -> VideoAperture {
        VideoAperture::new(width, height, None).unwrap()
    }

    /// Builds a padded NV12 surface: `luma` fills every luma sample, `uv` every chroma pair.
    fn surface(width: u32, height: u32, pitch: usize, luma: u8, uv: (u8, u8)) -> Vec<u8> {
        let mut data = vec![0u8; pitch * (height as usize + height as usize / 2)];
        for row in 0..height as usize {
            for column in 0..width as usize {
                data[row * pitch + column as usize] = luma;
            }
        }
        let chroma_offset = pitch * height as usize;
        for row in 0..height as usize / 2 {
            for pair in 0..width as usize / 2 {
                data[chroma_offset + row * pitch + pair * 2] = uv.0;
                data[chroma_offset + row * pitch + pair * 2 + 1] = uv.1;
            }
        }
        data
    }

    fn convert(
        data: &[u8],
        width: u32,
        height: u32,
        pitch: usize,
        aperture: VideoAperture,
        coefficients: &YuvRgbCoefficients,
    ) -> Vec<u8> {
        let mut output = vec![0u8; rgba8_len(aperture)];
        nv12_to_rgba8(
            &Nv12Surface {
                data,
                row_pitch: pitch,
                width,
                height,
            },
            aperture,
            coefficients,
            &mut output,
        )
        .unwrap();
        output
    }

    #[test]
    fn limited_range_neutral_chroma_maps_studio_black_and_white() {
        let coefficients = YuvRgbCoefficients::new(format(VideoColorMatrix::Bt709, false)).unwrap();
        let black = convert(
            &surface(8, 8, 8, 16, (128, 128)),
            8,
            8,
            8,
            full_aperture(8, 8),
            &coefficients,
        );
        assert_eq!(&black[..4], &[0, 0, 0, 255]);
        let white = convert(
            &surface(8, 8, 8, 235, (128, 128)),
            8,
            8,
            8,
            full_aperture(8, 8),
            &coefficients,
        );
        assert_eq!(&white[..4], &[255, 255, 255, 255]);
        // Studio-range mid-gray expands to full-range mid-gray, and below-black/above-white clamp
        // instead of wrapping: (126 - 16) / 219 * 255 = 128.
        let gray = convert(
            &surface(8, 8, 8, 126, (128, 128)),
            8,
            8,
            8,
            full_aperture(8, 8),
            &coefficients,
        );
        assert_eq!(&gray[..4], &[128, 128, 128, 255]);
        let clamped = convert(
            &surface(8, 8, 8, 0, (128, 128)),
            8,
            8,
            8,
            full_aperture(8, 8),
            &coefficients,
        );
        assert_eq!(&clamped[..4], &[0, 0, 0, 255]);
        let clamped_high = convert(
            &surface(8, 8, 8, 255, (128, 128)),
            8,
            8,
            8,
            full_aperture(8, 8),
            &coefficients,
        );
        assert_eq!(&clamped_high[..4], &[255, 255, 255, 255]);
    }

    #[test]
    fn full_range_uses_the_whole_byte_range() {
        let coefficients = YuvRgbCoefficients::new(format(VideoColorMatrix::Bt709, true)).unwrap();
        assert_eq!(coefficients.y_offset, 0.0);
        let black = convert(
            &surface(8, 8, 8, 0, (128, 128)),
            8,
            8,
            8,
            full_aperture(8, 8),
            &coefficients,
        );
        assert_eq!(&black[..4], &[0, 0, 0, 255]);
        let white = convert(
            &surface(8, 8, 8, 255, (128, 128)),
            8,
            8,
            8,
            full_aperture(8, 8),
            &coefficients,
        );
        assert_eq!(&white[..4], &[255, 255, 255, 255]);
    }

    #[test]
    fn bt601_and_bt709_disagree_on_saturated_chroma() {
        let aperture = full_aperture(8, 8);
        // Cb below neutral and Cr above it: red-dominant in both matrices.
        let data = surface(8, 8, 8, 128, (16, 240));
        let bt601 = YuvRgbCoefficients::new(format(VideoColorMatrix::Bt601, false)).unwrap();
        let bt709 = YuvRgbCoefficients::new(format(VideoColorMatrix::Bt709, false)).unwrap();
        let (bt601_rgb, bt709_rgb) = (
            convert(&data, 8, 8, 8, aperture, &bt601),
            convert(&data, 8, 8, 8, aperture, &bt709),
        );
        assert_ne!(
            bt601_rgb[..3], bt709_rgb[..3],
            "matrices must not collapse into one another"
        );
        assert!(bt601_rgb[0] > bt601_rgb[2] && bt709_rgb[0] > bt709_rgb[2]);
    }

    #[test]
    fn bt709_coefficients_match_the_video_processor_color_space_contract() {
        let coefficients = YuvRgbCoefficients::new(format(VideoColorMatrix::Bt709, false)).unwrap();
        assert_eq!(coefficients.r_cr, 1.5748);
        assert_eq!(coefficients.g_cb, -0.187_324_27);
        assert_eq!(coefficients.g_cr, -0.468_124_27);
        assert_eq!(coefficients.b_cb, 1.8556);
        let bt2020 = VideoFormat {
            color_matrix: VideoColorMatrix::Bt2020,
            color_primaries: crate::VideoColorPrimaries::Bt2020,
            ..format(VideoColorMatrix::Bt709, false)
        };
        let coefficients = YuvRgbCoefficients::new(bt2020).unwrap();
        assert_eq!(coefficients.r_cr, 1.4746);
        assert_eq!(coefficients.b_cb, 1.8814);
    }

    #[test]
    fn chroma_is_replicated_across_each_two_by_two_block() {
        let coefficients = YuvRgbCoefficients::new(format(VideoColorMatrix::Bt709, false)).unwrap();
        let width = 4u32;
        let height = 4u32;
        let pitch = width as usize;
        let mut data = surface(width, height, pitch, 128, (128, 128));
        // One distinct chroma pair per 2x2 block, so a wrong chroma index is visible.
        let chroma_offset = pitch * height as usize;
        for chroma_row in 0..height as usize / 2 {
            for pair in 0..width as usize / 2 {
                data[chroma_offset + chroma_row * pitch + pair * 2] =
                    96 + (chroma_row * 16 + pair * 32) as u8;
                data[chroma_offset + chroma_row * pitch + pair * 2 + 1] =
                    160 - (chroma_row * 8 + pair * 16) as u8;
            }
        }
        let aperture = full_aperture(width, height);
        let rgba = convert(&data, width, height, pitch, aperture, &coefficients);
        for block_row in 0..2usize {
            for block_column in 0..2usize {
                let first = (block_row * 2 * width as usize + block_column * 2) * 4;
                let right = first + 4;
                let below = first + width as usize * 4;
                let diagonal = below + 4;
                assert_eq!(
                    &rgba[first..first + 4],
                    &rgba[right..right + 4],
                    "horizontally adjacent pixels share chroma"
                );
                assert_eq!(
                    &rgba[first..first + 4],
                    &rgba[below..below + 4],
                    "vertically adjacent pixels share chroma"
                );
                assert_eq!(
                    &rgba[first..first + 4],
                    &rgba[diagonal..diagonal + 4],
                    "a 2x2 block is one chroma sample"
                );
            }
        }
        // Distinct blocks must not collapse into each other.
        let first_block = &rgba[..3];
        let last_block = &rgba[(3 * width as usize + 3) * 4..][..3];
        assert_ne!(first_block, last_block);
    }

    #[test]
    fn aperture_crops_and_padded_pitches_are_honored() {
        let coefficients = YuvRgbCoefficients::new(format(VideoColorMatrix::Bt709, false)).unwrap();
        let pitch = 64usize;
        let mut data = vec![0u8; pitch * (16 + 8)];
        // Left half black, right half white, with a distinct chroma row so padding is detectable.
        for row in 0..16usize {
            for column in 0..16usize {
                data[row * pitch + column] = if column < 8 { 16 } else { 235 };
            }
            for column in 16..pitch {
                data[row * pitch + column] = 255;
            }
        }
        for row in 16..(16 + 8) {
            for column in 0..pitch {
                data[row * pitch + column] = 128;
            }
        }
        let aperture = VideoAperture::new(16, 16, Some((8, 0, 8, 16))).unwrap();
        let rgba = convert(&data, 16, 16, pitch, aperture, &coefficients);
        assert_eq!(rgba.len(), rgba8_len(aperture));
        assert_eq!(&rgba[..4], &[255, 255, 255, 255], "cropped to the white half");
        let cropped_left = VideoAperture::new(16, 16, Some((0, 0, 8, 16))).unwrap();
        let rgba = convert(&data, 16, 16, pitch, cropped_left, &coefficients);
        assert_eq!(&rgba[..4], &[0, 0, 0, 255], "cropped to the black half");
    }

    #[test]
    fn mismatched_buffers_and_unsupported_formats_fail_explicitly() {
        let coefficients = YuvRgbCoefficients::new(format(VideoColorMatrix::Bt709, false)).unwrap();
        let data = surface(8, 8, 8, 16, (128, 128));
        let surface = Nv12Surface {
            data: &data,
            row_pitch: 8,
            width: 8,
            height: 8,
        };
        let aperture = full_aperture(8, 8);
        let mut short = vec![0u8; rgba8_len(aperture) - 4];
        assert!(nv12_to_rgba8(&surface, aperture, &coefficients, &mut short).is_err());

        let too_small = Nv12Surface {
            data: &data[..16],
            row_pitch: 8,
            width: 8,
            height: 8,
        };
        let mut output = vec![0u8; rgba8_len(aperture)];
        assert!(nv12_to_rgba8(&too_small, aperture, &coefficients, &mut output).is_err());

        let narrow_pitch = Nv12Surface {
            data: &data,
            row_pitch: 4,
            width: 8,
            height: 8,
        };
        assert!(nv12_to_rgba8(&narrow_pitch, aperture, &coefficients, &mut output).is_err());

        let odd = Nv12Surface {
            data: &data,
            row_pitch: 8,
            width: 7,
            height: 7,
        };
        assert!(odd.validate().is_err());

        let outside = VideoAperture::new(8, 8, Some((4, 4, 8, 8)));
        assert!(outside.is_err());

        for format in [
            VideoFormat {
                pixel_format: VideoPixelFormat::P010,
                ..format(VideoColorMatrix::Bt709, false)
            },
            VideoFormat {
                pixel_format: VideoPixelFormat::Y410,
                chroma_format: VideoChromaFormat::Cs444,
                transfer_function: VideoTransferFunction::Pq,
                color_primaries: crate::VideoColorPrimaries::Bt2020,
                color_matrix: VideoColorMatrix::Bt2020,
                ..format(VideoColorMatrix::Bt709, false)
            },
            VideoFormat {
                transfer_function: VideoTransferFunction::Hlg,
                pixel_format: VideoPixelFormat::P010,
                color_primaries: crate::VideoColorPrimaries::Bt2020,
                color_matrix: VideoColorMatrix::Bt2020,
                ..format(VideoColorMatrix::Bt709, false)
            },
        ] {
            assert!(
                YuvRgbCoefficients::new(format).is_err(),
                "{:?} must not be silently down-converted",
                format.pixel_format
            );
        }
    }
}
