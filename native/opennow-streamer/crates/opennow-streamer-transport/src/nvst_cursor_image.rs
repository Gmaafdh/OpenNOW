//! Normalizes GeForce NOW's native bitmap cursor record for this client.
//!
//! NVST carries a game's own cursor art as a Windows BMP inside command 0x0110.
//! Neither the shell nor the media host parses that layout, but both already
//! decode the platform's custom cursor shape - a base64 PNG with a hotspot - so
//! the record is converted here once instead of in two places.

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD as BASE64;
use image::ExtendedColorType;
use image::ImageEncoder;
use image::codecs::png::PngEncoder;

/// Widest and tallest cursor the media host accepts and the shell scales to.
const MAX_CURSOR_EXTENT: u32 = 256;

/// A Windows bitmap needs its 14 byte file header plus the 40 byte info header
/// that header points at before a single pixel can be located.
const MIN_BITMAP_BYTES: usize = 54;

/// Where the embedded BMP starts inside a bitmap cursor record.
const BITMAP_OFFSET: usize = 12;

/// What one bitmap cursor record turned out to carry.
#[derive(Debug)]
pub(crate) enum NativeBitmapCursor {
    /// The record references an image the host published earlier, so the cursor
    /// already on screen is the current one and nothing is sent on.
    Reference,
    /// The game's cursor art, normalized into the platform's wire shape.
    Image(Vec<u8>),
    /// The record carries art this build cannot decode. The reason belongs in
    /// the diagnostics log so a report shows what is missing.
    Undecodable(String),
}

/// Normalizes one bitmap cursor payload, command 0x0110.
///
/// The native layout is:
///
/// ```text
/// [0..4]   u32  host cursor id
/// [4..6]   u16  length of the embedded BMP, 0 when the record only references
///                an image the host published earlier
/// [6..8]   u16  hotspot x
/// [8..10]  u16  hotspot y
/// [12..]   the BMP itself
/// ```
pub(crate) fn native_bitmap_cursor(payload: &[u8]) -> NativeBitmapCursor {
    let Some(header) = payload.get(..6) else {
        let reason = format!("record is {} bytes long", payload.len());
        return NativeBitmapCursor::Undecodable(reason);
    };
    let host_id = u32::from_le_bytes([header[0], header[1], header[2], header[3]]);
    let bitmap_length = u16::from_le_bytes([header[4], header[5]]);
    if bitmap_length == 0 {
        return NativeBitmapCursor::Reference;
    }
    let Some(bitmap) = embedded_bitmap(payload, usize::from(bitmap_length)) else {
        let reason = format!("no {bitmap_length} byte bitmap follows the header");
        return NativeBitmapCursor::Undecodable(reason);
    };
    let decoded = match decode_bitmap(bitmap) {
        Ok(decoded) => decoded,
        Err(reason) => return NativeBitmapCursor::Undecodable(reason),
    };
    match wire_custom_cursor(host_id, payload, &decoded) {
        Ok(normalized) => NativeBitmapCursor::Image(normalized),
        Err(reason) => NativeBitmapCursor::Undecodable(reason),
    }
}

/// Returns the embedded BMP, or nothing when the record does not carry one.
fn embedded_bitmap(payload: &[u8], length: usize) -> Option<&[u8]> {
    let signature = payload.get(BITMAP_OFFSET..BITMAP_OFFSET + 2)?;
    if signature[0] != b'B' || signature[1] != b'M' {
        return None;
    }
    let end = BITMAP_OFFSET.checked_add(length.max(MIN_BITMAP_BYTES))?;
    payload.get(BITMAP_OFFSET..end)
}

/// Top-down RGBA pixels of one decoded cursor.
struct DecodedBitmap {
    width: u32,
    height: u32,
    rgba: Vec<u8>,
}

/// Decodes a 24 or 32 bit BI_RGB Windows bitmap into top-down RGBA pixels.
fn decode_bitmap(bitmap: &[u8]) -> Result<DecodedBitmap, String> {
    if bitmap.len() < MIN_BITMAP_BYTES {
        return Err(format!("bitmap is {} bytes long", bitmap.len()));
    }
    let data_offset = u32::from_le_bytes([bitmap[10], bitmap[11], bitmap[12], bitmap[13]]);
    let info_size = u32::from_le_bytes([bitmap[14], bitmap[15], bitmap[16], bitmap[17]]);
    let width = i32::from_le_bytes([bitmap[18], bitmap[19], bitmap[20], bitmap[21]]);
    let height = i32::from_le_bytes([bitmap[22], bitmap[23], bitmap[24], bitmap[25]]);
    let planes = u16::from_le_bytes([bitmap[26], bitmap[27]]);
    let bit_count = u16::from_le_bytes([bitmap[28], bitmap[29]]);
    let compression = u32::from_le_bytes([bitmap[30], bitmap[31], bitmap[32], bitmap[33]]);
    if info_size < 40 {
        return Err(format!("bitmap info header is {info_size} bytes"));
    }
    if planes != 1 {
        return Err(format!("bitmap stores {planes} planes"));
    }
    if compression != 0 {
        return Err(format!("bitmap compression {compression} is not BI_RGB"));
    }
    if !matches!(bit_count, 24 | 32) {
        return Err(format!("bitmap is {bit_count} bits per pixel"));
    }
    if width < 1 || width as u32 > MAX_CURSOR_EXTENT {
        return Err(format!("cursor width {width} is outside 1..=256"));
    }
    let columns = width as usize;
    let stored_rows = height.unsigned_abs() as usize;
    if stored_rows < 1 || stored_rows > 2 * columns {
        return Err(format!("cursor height {height} is not one or two images"));
    }
    // A cursor stores its colour image and, below it, a monochrome AND mask.
    // The header counts both, so a cursor twice as tall as it is wide has one.
    let masked = stored_rows == 2 * columns;
    let rows = if masked { columns } else { stored_rows };
    let bottom_up = height > 0;
    let bytes_per_pixel = usize::from(bit_count / 8);
    let stride = (columns * bytes_per_pixel + 3) & !3;
    let offset = data_offset as usize;
    let pixels_end = offset + rows * stride;
    let held = bitmap.len();
    if held < pixels_end {
        return Err(format!("bitmap holds {held} of {pixels_end} bytes"));
    }
    let mut rgba = vec![0_u8; rows * columns * 4];
    let mut alpha_used = false;
    for row in 0..rows {
        let stored_row = if bottom_up { rows - 1 - row } else { row };
        let source = offset + stored_row * stride;
        for column in 0..columns {
            let pixel = source + column * bytes_per_pixel;
            let alpha = if bit_count == 32 {
                bitmap[pixel + 3]
            } else {
                255
            };
            let target = (row * columns + column) * 4;
            rgba[target] = bitmap[pixel + 2];
            rgba[target + 1] = bitmap[pixel + 1];
            rgba[target + 2] = bitmap[pixel];
            rgba[target + 3] = alpha;
            alpha_used = alpha_used || alpha != 0;
        }
    }
    if !alpha_used {
        // A cursor that stores no alpha keeps its shape in the AND mask. With
        // neither, the art would be a solid rectangle or fully transparent.
        let mask = if masked {
            and_mask_alpha(bitmap, offset, stride, columns, rows, bottom_up)
        } else {
            None
        };
        match mask {
            Some(alpha) => {
                for (pixel, value) in rgba.chunks_exact_mut(4).zip(alpha) {
                    pixel[3] = value;
                }
            }
            None => {
                for pixel in rgba.chunks_exact_mut(4) {
                    pixel[3] = 255;
                }
            }
        }
    }
    let image_width = columns as u32;
    let image_height = rows as u32;
    Ok(DecodedBitmap {
        width: image_width,
        height: image_height,
        rgba,
    })
}

/// Reads the monochrome AND mask under a cursor's colour image: a set bit is
/// transparent, a clear bit is opaque. Returns nothing when it is truncated.
fn and_mask_alpha(
    bitmap: &[u8],
    offset: usize,
    stride: usize,
    columns: usize,
    rows: usize,
    bottom_up: bool,
) -> Option<Vec<u8>> {
    let mask_stride = ((columns + 31) / 32) * 4;
    let mask_offset = offset + rows * stride;
    if bitmap.len() < mask_offset + rows * mask_stride {
        return None;
    }
    let mut alpha = Vec::with_capacity(rows * columns);
    for row in 0..rows {
        let stored_row = if bottom_up { rows - 1 - row } else { row };
        let source = mask_offset + stored_row * mask_stride;
        for column in 0..columns {
            let bit = 0x80 >> (column % 8);
            let opaque = bitmap[source + column / 8] & bit == 0;
            alpha.push(if opaque { 255 } else { 0 });
        }
    }
    Some(alpha)
}

/// Builds the platform's custom cursor shape: type 1, one byte of cursor id,
/// the hotspot, an empty MIME field and the base64 PNG both consumers decode.
fn wire_custom_cursor(
    host_id: u32,
    payload: &[u8],
    bitmap: &DecodedBitmap,
) -> Result<Vec<u8>, String> {
    let mut png = Vec::new();
    let encoder = PngEncoder::new(&mut png);
    let written = encoder.write_image(
        &bitmap.rgba,
        bitmap.width,
        bitmap.height,
        ExtendedColorType::Rgba8,
    );
    if let Err(error) = written {
        return Err(format!("cursor PNG encoding failed: {error}"));
    }
    let encoded = BASE64.encode(&png);
    let Ok(length) = u16::try_from(encoded.len()) else {
        let reason = format!("cursor PNG is {} base64 bytes", encoded.len());
        return Err(reason);
    };
    let (hotspot_x, hotspot_y) = hotspot(payload, bitmap);
    let mut normalized = vec![1, cursor_id(host_id), hotspot_x, hotspot_y, 0];
    normalized.extend_from_slice(&length.to_le_bytes());
    normalized.extend_from_slice(encoded.as_bytes());
    Ok(normalized)
}

/// The hotspot the host reported, clamped into the decoded image.
fn hotspot(payload: &[u8], bitmap: &DecodedBitmap) -> (u8, u8) {
    let Some(bytes) = payload.get(6..10) else {
        return (0, 0);
    };
    let reported_x = u32::from(u16::from_le_bytes([bytes[0], bytes[1]]));
    let reported_y = u32::from(u16::from_le_bytes([bytes[2], bytes[3]]));
    let x = reported_x.min(bitmap.width - 1);
    let y = reported_y.min(bitmap.height - 1);
    (x as u8, y as u8)
}

/// The wire shape stores one byte of cursor id. Distinct host cursors keep
/// distinct ids so the media host caches their art separately.
fn cursor_id(host_id: u32) -> u8 {
    let id = (host_id & 0xff) as u8;
    if id == 0 { 1 } else { id }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Builds a Windows BMP the way a host embeds one: bottom-up rows of BGR or
    /// BGRA pixels, plus a monochrome AND mask when one is supplied.
    fn windows_bitmap(
        width: u32,
        height: u32,
        bit_count: u16,
        pixels: &[u8],
        mask: Option<&[u8]>,
    ) -> Vec<u8> {
        let bytes_per_pixel = usize::from(bit_count / 8);
        let stride = (width as usize * bytes_per_pixel + 3) & !3;
        let mask_stride = ((width as usize + 31) / 32) * 4;
        let mask_rows = mask.map_or(0, |_| height as usize);
        let stored_height = height + mask_rows as u32;
        let image_bytes = height as usize * stride;
        let mask_bytes = mask_rows * mask_stride;
        let data_bytes = image_bytes + mask_bytes;
        let file_size = (MIN_BITMAP_BYTES + data_bytes) as u32;
        let data_offset = MIN_BITMAP_BYTES as u32;
        let info_size = 40_u32;
        let size_image = data_bytes as u32;
        let mut bytes = Vec::new();
        bytes.extend_from_slice(b"BM");
        bytes.extend_from_slice(&file_size.to_le_bytes());
        bytes.extend_from_slice(&[0, 0, 0, 0]);
        bytes.extend_from_slice(&data_offset.to_le_bytes());
        bytes.extend_from_slice(&info_size.to_le_bytes());
        bytes.extend_from_slice(&width.to_le_bytes());
        bytes.extend_from_slice(&stored_height.to_le_bytes());
        bytes.extend_from_slice(&[1, 0]);
        bytes.extend_from_slice(&bit_count.to_le_bytes());
        bytes.extend_from_slice(&[0, 0, 0, 0]);
        bytes.extend_from_slice(&size_image.to_le_bytes());
        bytes.extend_from_slice(&[0; 16]);
        bytes.extend_from_slice(pixels);
        if let Some(mask) = mask {
            bytes.extend_from_slice(mask);
        }
        assert_eq!(bytes.len(), MIN_BITMAP_BYTES + data_bytes);
        bytes
    }

    /// Wraps a bitmap in the record layout a host publishes.
    fn record(host_id: u32, bitmap: &[u8], hotspot_x: u16, hotspot_y: u16) -> Vec<u8> {
        let mut payload = Vec::new();
        payload.extend_from_slice(&host_id.to_le_bytes());
        payload.extend_from_slice(&(bitmap.len() as u16).to_le_bytes());
        payload.extend_from_slice(&hotspot_x.to_le_bytes());
        payload.extend_from_slice(&hotspot_y.to_le_bytes());
        payload.extend_from_slice(&[0, 0]);
        payload.extend_from_slice(bitmap);
        payload
    }

    /// Decodes the normalized payload the way the media host and the shell do.
    fn decoded_image(normalized: &[u8]) -> image::DynamicImage {
        assert_eq!(normalized[0], 1, "custom cursor type");
        assert_eq!(normalized[4], 0, "the MIME field stays empty");
        let length = u16::from_le_bytes([normalized[5], normalized[6]]) as usize;
        let text = &normalized[7..7 + length];
        assert_eq!(7 + length, normalized.len(), "no trailing fields");
        let png = BASE64.decode(text).expect("base64 PNG");
        image::load_from_memory(&png)
            .expect("a PNG the media host and the shell both decode")
    }

    fn expect_image(payload: &[u8]) -> image::DynamicImage {
        match native_bitmap_cursor(payload) {
            NativeBitmapCursor::Image(normalized) => decoded_image(&normalized),
            other => panic!("expected a decoded cursor, got {other:?}"),
        }
    }

    fn expect_reason(payload: &[u8]) -> String {
        match native_bitmap_cursor(payload) {
            NativeBitmapCursor::Undecodable(reason) => reason,
            other => panic!("expected an undecodable record, got {other:?}"),
        }
    }

    #[test]
    fn a_hosts_bitmap_becomes_the_platforms_custom_cursor() {
        // BGRA rows in file order, so the bottom row comes first and the top
        // row last. The alpha is real, so no AND mask is needed.
        let pixels = [
            12, 22, 32, 64, 13, 23, 33, 255, 10, 20, 30, 255, 11, 21, 31, 128,
        ];
        let bitmap = windows_bitmap(2, 2, 32, &pixels, None);
        let payload = record(1000, &bitmap, 1, 0);
        match native_bitmap_cursor(&payload) {
            NativeBitmapCursor::Image(normalized) => {
                assert_eq!(normalized[1], 232, "host id 1000 keeps its low byte");
                assert_eq!(normalized[2], 1, "hotspot x");
                assert_eq!(normalized[3], 0, "hotspot y");
                let image = decoded_image(&normalized);
                assert_eq!((image.width(), image.height()), (2, 2));
                let rgba = image.to_rgba8();
                assert_eq!(rgba.get_pixel(0, 0).0, [30, 20, 10, 255]);
                assert_eq!(rgba.get_pixel(1, 0).0, [31, 21, 11, 128]);
                assert_eq!(rgba.get_pixel(0, 1).0, [32, 22, 12, 64]);
                assert_eq!(rgba.get_pixel(1, 1).0, [33, 23, 13, 255]);
            }
            other => panic!("expected a decoded cursor, got {other:?}"),
        }
    }

    #[test]
    fn a_bitmap_without_alpha_falls_back_to_its_and_mask() {
        let pixels = [1, 2, 3, 0, 4, 5, 6, 0, 7, 8, 9, 0, 10, 11, 12, 0];
        // One bit per pixel, MSB first, set means transparent. File row 0 is the
        // bottom row, so it masks the second image row.
        let mask = [0x80, 0, 0, 0, 0x40, 0, 0, 0];
        let bitmap = windows_bitmap(2, 2, 32, &pixels, Some(&mask));
        let image = expect_image(&record(7, &bitmap, 0, 0));
        let rgba = image.to_rgba8();
        assert_eq!(rgba.get_pixel(0, 0).0, [9, 8, 7, 255]);
        assert_eq!(rgba.get_pixel(1, 0).0, [12, 11, 10, 0]);
        assert_eq!(rgba.get_pixel(0, 1).0, [3, 2, 1, 0]);
        assert_eq!(rgba.get_pixel(1, 1).0, [6, 5, 4, 255]);
    }

    #[test]
    fn a_bitmap_with_neither_alpha_nor_mask_stays_opaque() {
        let pixels = [1, 2, 3, 0, 4, 5, 6, 0];
        let bitmap = windows_bitmap(2, 1, 32, &pixels, None);
        let image = expect_image(&record(9, &bitmap, 0, 0));
        let rgba = image.to_rgba8();
        assert_eq!(rgba.get_pixel(0, 0).0, [3, 2, 1, 255]);
        assert_eq!(rgba.get_pixel(1, 0).0, [6, 5, 4, 255]);
    }

    #[test]
    fn a_24_bit_bitmap_is_decoded_as_opaque() {
        // Three bytes per pixel, and a row of two pixels is padded to eight.
        let pixels = [255, 128, 64, 0, 10, 20, 30, 0];
        let bitmap = windows_bitmap(2, 1, 24, &pixels, None);
        let image = expect_image(&record(11, &bitmap, 0, 0));
        let rgba = image.to_rgba8();
        assert_eq!(rgba.get_pixel(0, 0).0, [64, 128, 255, 255]);
        assert_eq!(rgba.get_pixel(1, 0).0, [30, 20, 10, 255]);
    }

    #[test]
    fn a_hotspot_outside_the_image_is_clamped_into_it() {
        let pixels = [9, 8, 7, 255, 6, 5, 4, 255, 3, 2, 1, 255, 0, 0, 0, 255];
        let bitmap = windows_bitmap(2, 2, 32, &pixels, None);
        match native_bitmap_cursor(&record(1000, &bitmap, 65535, 65535)) {
            NativeBitmapCursor::Image(normalized) => {
                assert_eq!(normalized[2], 1);
                assert_eq!(normalized[3], 1);
            }
            other => panic!("expected a decoded cursor, got {other:?}"),
        }
    }

    #[test]
    fn a_record_that_only_references_an_image_publishes_nothing() {
        // Captured from a host: the cursor id, a zero length, a hash and a
        // flag. Sending a placeholder on would throw the game's art away.
        let payload = [0xe8, 0x03, 0, 0, 0, 0, 0x07, 0x38, 0x82, 0x61, 0];
        let outcome = native_bitmap_cursor(&payload);
        assert!(matches!(outcome, NativeBitmapCursor::Reference));
    }

    #[test]
    fn a_record_that_promises_an_image_it_does_not_carry_is_reported() {
        let mut payload = Vec::new();
        payload.extend_from_slice(&1000_u32.to_le_bytes());
        payload.extend_from_slice(&64_u16.to_le_bytes());
        payload.extend_from_slice(&[0; 6]);
        payload.extend_from_slice(&[0xff; 8]);
        let reason = expect_reason(&payload);
        assert!(reason.contains("bitmap"));
    }

    #[test]
    fn a_bitmap_whose_pixels_are_truncated_is_reported() {
        let pixels = [1, 2, 3, 255, 4, 5, 6, 255];
        let bitmap = windows_bitmap(2, 2, 32, &pixels, None);
        let payload = record(4, &bitmap[..bitmap.len() - 8], 0, 0);
        let reason = expect_reason(&payload);
        assert!(reason.contains("bitmap"));
    }

    #[test]
    fn an_oversized_cursor_is_reported_instead_of_guessed() {
        let width = MAX_CURSOR_EXTENT + 1;
        let pixels = vec![7_u8; width as usize * 4];
        let bitmap = windows_bitmap(width, 1, 32, &pixels, None);
        let reason = expect_reason(&record(3, &bitmap, 0, 0));
        assert!(reason.contains("width"));
    }

    #[test]
    fn a_compressed_bitmap_is_reported_instead_of_guessed() {
        let pixels = [1, 2, 3, 255];
        let mut bitmap = windows_bitmap(1, 1, 32, &pixels, None);
        bitmap[30..34].copy_from_slice(&2_u32.to_le_bytes());
        let reason = expect_reason(&record(5, &bitmap, 0, 0));
        assert!(reason.contains("BI_RGB"));
    }
}
