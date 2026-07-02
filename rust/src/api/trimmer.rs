use std::fs::File;
use std::io::{Read, Write};

const BITRATE_TABLE_V1_L3: [u32; 16] = [
    0, 32000, 40000, 48000, 56000, 64000, 80000, 96000, 112000, 128000, 160000, 192000, 224000, 256000, 320000, 0
];
const BITRATE_TABLE_V2_L3: [u32; 16] = [
    0, 8000, 16000, 24000, 32000, 40000, 48000, 56000, 64000, 80000, 96000, 112000, 128000, 144000, 160000, 0
];

const SAMPLERATE_TABLE_V1: [u32; 4] = [44100, 48000, 32000, 0];
const SAMPLERATE_TABLE_V2: [u32; 4] = [22050, 24000, 16000, 0];
const SAMPLERATE_TABLE_V2_5: [u32; 4] = [11025, 12000, 8000, 0];

/// Trim an MP3 file losslessly from start_secs to end_secs.
///
/// Automatically copies original ID3 tags to preserve album art and metadata.
#[flutter_rust_bridge::frb]
pub fn trim_mp3(
    input_path: String,
    output_path: String,
    start_secs: f64,
    end_secs: f64,
) -> Result<String, String> {
    let mut file = File::open(&input_path).map_err(|e| format!("Failed to open input: {}", e))?;
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes).map_err(|e| format!("Failed to read input: {}", e))?;

    if bytes.len() < 10 {
        return Err("File is too small".to_string());
    }

    // 1. Skip ID3v2 tags if present and locate headers start
    let mut id3_size = 0;
    if bytes.starts_with(b"ID3") {
        if bytes.len() >= 10 {
            let b0 = bytes[6] as usize;
            let b1 = bytes[7] as usize;
            let b2 = bytes[8] as usize;
            let b3 = bytes[9] as usize;
            // ID3v2 size bytes are synchsafe (7 bits per byte)
            let tag_size = (b3 & 0x7F) | ((b2 & 0x7F) << 7) | ((b1 & 0x7F) << 14) | ((b0 & 0x7F) << 21);
            id3_size = 10 + tag_size;
            if id3_size > bytes.len() {
                id3_size = 0; // fallback in case of corruption
            }
        }
    }

    // 2. Scan MP3 frames
    let mut i = id3_size;
    let mut frames = Vec::new();
    let mut current_time = 0.0;

    while i < bytes.len() - 4 {
        // Syncword check: 12 bits set to 1 (0xFF and 0xF0 mask in next byte)
        if bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0 {
            let b1 = bytes[i + 1];
            let b2 = bytes[i + 2];

            let version = (b1 >> 3) & 3;
            let layer = (b1 >> 1) & 3;
            let bitrate_idx = (b2 >> 4) & 15;
            let sample_rate_idx = (b2 >> 2) & 3;
            let padding = ((b2 >> 1) & 1) as u32;

            // Focus on Layer III (index 1) with valid settings
            if layer == 1 && bitrate_idx > 0 && bitrate_idx < 15 && sample_rate_idx < 3 {
                let sample_rate = match version {
                    3 => SAMPLERATE_TABLE_V1[sample_rate_idx as usize],
                    2 => SAMPLERATE_TABLE_V2[sample_rate_idx as usize],
                    0 => SAMPLERATE_TABLE_V2_5[sample_rate_idx as usize],
                    _ => 0,
                };

                let bitrate = if version == 3 {
                    BITRATE_TABLE_V1_L3[bitrate_idx as usize]
                } else {
                    BITRATE_TABLE_V2_L3[bitrate_idx as usize]
                };

                if sample_rate > 0 && bitrate > 0 {
                    let coeff = if version == 3 { 144 } else { 72 };
                    let frame_size = ((coeff * bitrate) / sample_rate + padding) as usize;

                    if frame_size > 0 && i + frame_size <= bytes.len() {
                        let samples = if version == 3 { 1152 } else { 576 };
                        let duration = samples as f64 / sample_rate as f64;

                        frames.push((i, frame_size, current_time));
                        current_time += duration;

                        i += frame_size;
                        continue;
                    }
                }
            }
        }
        i += 1;
    }

    if frames.is_empty() {
        return Err("No valid MP3 audio frames found".to_string());
    }

    // 3. Find slicing boundaries
    let mut start_idx = 0;
    let mut end_idx = frames.len();

    for (idx, &(_, _, time)) in frames.iter().enumerate() {
        if time < start_secs {
            start_idx = idx;
        }
        if time <= end_secs {
            end_idx = idx + 1;
        }
    }

    if start_idx >= end_idx {
        return Err("Invalid trim range".to_string());
    }

    let start_offset = frames[start_idx].0;
    let last_frame = frames[end_idx - 1];
    let end_offset = last_frame.0 + last_frame.1;

    // 4. Write output file
    let mut out_file = File::create(&output_path).map_err(|e| format!("Failed to create output: {}", e))?;

    // Copy original ID3 metadata header if present
    if id3_size > 0 {
        out_file.write_all(&bytes[0..id3_size]).map_err(|e| format!("Failed to write metadata: {}", e))?;
    }

    // Append raw sliced audio frames
    out_file.write_all(&bytes[start_offset..end_offset]).map_err(|e| format!("Failed to write audio data: {}", e))?;

    Ok(output_path)
}

/// Trim a WAV file from start_secs to end_secs by slicing PCM bytes and updating header size.
#[flutter_rust_bridge::frb]
pub fn trim_wav(
    input_path: String,
    output_path: String,
    start_secs: f64,
    end_secs: f64,
) -> Result<String, String> {
    let mut file = File::open(&input_path).map_err(|e| format!("Failed to open input: {}", e))?;
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes).map_err(|e| format!("Failed to read input: {}", e))?;

    if bytes.len() < 44 {
        return Err("File is too small to be a valid WAV".to_string());
    }

    // Locate "fmt " chunk
    let mut fmt_offset = 0;
    for i in 12..bytes.len() - 8 {
        if &bytes[i..i + 4] == b"fmt " {
            fmt_offset = i;
            break;
        }
    }

    if fmt_offset == 0 {
        return Err("Could not locate WAV fmt chunk".to_string());
    }

    // Parse audio configuration
    let _channels = u16::from_le_bytes([bytes[fmt_offset + 10], bytes[fmt_offset + 11]]) as u32;
    let sample_rate = u32::from_le_bytes([
        bytes[fmt_offset + 12],
        bytes[fmt_offset + 13],
        bytes[fmt_offset + 14],
        bytes[fmt_offset + 15],
    ]);
    let block_align = u16::from_le_bytes([bytes[fmt_offset + 20], bytes[fmt_offset + 21]]) as usize;

    let byte_rate = block_align as u32 * sample_rate;

    // Locate "data" chunk
    let mut data_offset = 0;
    for i in 12..bytes.len() - 8 {
        if &bytes[i..i + 4] == b"data" {
            data_offset = i;
            break;
        }
    }

    if data_offset == 0 {
        return Err("Could not locate WAV data chunk".to_string());
    }

    let original_data_size = u32::from_le_bytes([
        bytes[data_offset + 4],
        bytes[data_offset + 5],
        bytes[data_offset + 6],
        bytes[data_offset + 7],
    ]) as usize;

    let pcm_start = data_offset + 8;
    let pcm_bytes_len = std::cmp::min(bytes.len() - pcm_start, original_data_size);

    // Calculate byte boundaries aligned to sample blocks
    let start_byte = (start_secs * byte_rate as f64) as usize;
    let end_byte = (end_secs * byte_rate as f64) as usize;

    let start_aligned = (start_byte / block_align) * block_align;
    let end_aligned = (end_byte / block_align) * block_align;

    let start_offset = std::cmp::min(start_aligned, pcm_bytes_len);
    let end_offset = std::cmp::min(end_aligned, pcm_bytes_len);

    if start_offset >= end_offset {
        return Err("Invalid trim range".to_string());
    }

    let slice_len = end_offset - start_offset;

    // Modify header values (sizes are in Little-Endian)
    let new_data_size = slice_len as u32;
    let new_riff_size = (pcm_start + slice_len - 8) as u32;

    // Build the output buffer
    let mut out_bytes = bytes[0..pcm_start].to_vec();
    
    // Update RIFF chunk size (index 4 to 7)
    let riff_bytes = new_riff_size.to_le_bytes();
    out_bytes[4..8].copy_from_slice(&riff_bytes);

    // Update data chunk size (index data_offset+4 to data_offset+7)
    let data_size_bytes = new_data_size.to_le_bytes();
    out_bytes[data_offset + 4 .. data_offset + 8].copy_from_slice(&data_size_bytes);

    // Append sliced PCM bytes
    out_bytes.extend_from_slice(&bytes[pcm_start + start_offset .. pcm_start + end_offset]);

    // Write output file
    let mut out_file = File::create(&output_path).map_err(|e| format!("Failed to create output: {}", e))?;
    out_file.write_all(&out_bytes).map_err(|e| format!("Failed to write WAV output: {}", e))?;

    Ok(output_path)
}
