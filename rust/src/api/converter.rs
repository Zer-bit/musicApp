use std::fs::File;
use std::io::{BufReader, BufWriter, Write};
use std::path::Path;
use mp4::Mp4Reader;

fn make_adts_header(payload_len: usize, sample_rate_index: u8, channel_config: u8) -> [u8; 7] {
    let mut header = [0u8; 7];
    
    // Syncword: 0xFFF (12 bits)
    header[0] = 0xFF;
    header[1] = 0xF0;
    
    // MPEG Version: 0 (MPEG-4)
    // Layer: 00
    // Protection absent: 1 (no CRC)
    header[1] |= 0x01; // 0xF0 | 0x01 -> 0xF1
    
    // Profile: 1 (AAC-LC) (2 bits) -> 01
    // Sampling Frequency Index: 4 bits
    // Private bit: 1 bit -> 0
    // Channel Configuration: 3 bits
    let profile = 1u8;
    
    header[2] = (profile << 6) | (sample_rate_index << 2) | (channel_config >> 2);
    header[3] = (channel_config & 0x03) << 6;
    
    // Frame Length: 13 bits (Header length 7 + payload length)
    let frame_len = (payload_len + 7) as u32;
    header[3] |= ((frame_len >> 11) & 0x03) as u8;
    header[4] = ((frame_len >> 3) & 0xFF) as u8;
    header[5] = (((frame_len & 0x07) << 5) | 0x1F) as u8; // 0x1F is 5 bits of fullness
    
    // Buffer Fullness: 11 bits -> 0x7FF (Variable bitrate)
    header[6] = 0xFC;
    
    header
}

fn extract_aac_lossless(input_path: &str, output_path: &str) -> Result<(), String> {
    let f = File::open(input_path).map_err(|e| format!("Failed to open file: {}", e))?;
    let size = f.metadata().map_err(|e| format!("Failed to read metadata: {}", e))?.len();
    let reader = BufReader::new(f);
    
    let mut mp4 = Mp4Reader::read_header(reader, size)
        .map_err(|e| format!("Failed to parse MP4 container: {}", e))?;
        
    // Find audio track and extract properties directly
    let mut audio_details = None;
    for track in mp4.tracks().values() {
        if let Ok(mp4::TrackType::Audio) = track.track_type() {
            let stsd = &track.trak.mdia.minf.stbl.stsd;
            if let Some(mp4a) = &stsd.mp4a {
                audio_details = Some((
                    track.track_id(),
                    mp4a.channelcount as u8,
                    mp4a.samplerate.value(),
                    track.sample_count(),
                ));
                break;
            }
        }
    }
    
    let (track_id, channel_count, sample_rate, sample_count) = audio_details
        .ok_or_else(|| "No audio track found in MP4".to_string())?;
    
    let sample_rate_index = match sample_rate as u32 {
        96000 => 0,
        88200 => 1,
        64000 => 2,
        48000 => 3,
        44100 => 4,
        32000 => 5,
        24000 => 6,
        22050 => 7,
        16000 => 8,
        12000 => 9,
        11025 => 10,
        8000 => 11,
        7350 => 12,
        _ => 4, // Default to 44100 Hz if not matching
    };
    
    let out_file = File::create(output_path).map_err(|e| format!("Failed to create output file: {}", e))?;
    let mut writer = BufWriter::new(out_file);
    
    for sample_id in 1..=sample_count {
        let sample = mp4.read_sample(track_id, sample_id)
            .map_err(|e| format!("Failed to read sample #{}: {}", sample_id, e))?
            .ok_or_else(|| format!("Sample #{} not found", sample_id))?;
            
        let adts_header = make_adts_header(sample.bytes.len(), sample_rate_index, channel_count);
        writer.write_all(&adts_header).map_err(|e| format!("Failed to write ADTS header: {}", e))?;
        writer.write_all(&sample.bytes).map_err(|e| format!("Failed to write AAC payload: {}", e))?;
    }
    
    writer.flush().map_err(|e| format!("Failed to flush output: {}", e))?;
    Ok(())
}

fn convert_to_mp3_transcode(input_path: &str, output_path: &str) -> Result<(), String> {
    use symphonia::core::codecs::{DecoderOptions, CODEC_TYPE_NULL};
    use symphonia::core::formats::FormatOptions;
    use symphonia::core::io::MediaSourceStream;
    use symphonia::core::meta::MetadataOptions;
    use symphonia::core::probe::Hint;
    use symphonia::core::audio::SampleBuffer;
    use shine_rs::{Mp3Encoder, Mp3EncoderConfig, StereoMode};
    
    // Open source file
    let src_file = File::open(input_path).map_err(|e| format!("Failed to open input file: {}", e))?;
    let mss = MediaSourceStream::new(Box::new(src_file), Default::default());
    
    // Hint format from extension
    let mut hint = Hint::default();
    if let Some(ext) = Path::new(input_path).extension().and_then(|s| s.to_str()) {
        hint.with_extension(ext);
    }
    
    // Probe format
    let probed = symphonia::default::get_probe()
        .format(&hint, mss, &FormatOptions::default(), &MetadataOptions::default())
        .map_err(|e| format!("Format probe failed: {}", e))?;
        
    let mut format = probed.format;
    
    // Find first audio track
    let track = format.tracks()
        .iter()
        .find(|t| t.codec_params.codec != CODEC_TYPE_NULL)
        .ok_or_else(|| "No audio track found in media file".to_string())?;
        
    let track_id = track.id;
    
    // Create decoder
    let mut decoder = symphonia::default::get_codecs()
        .make(&track.codec_params, &DecoderOptions::default())
        .map_err(|e| format!("Failed to create decoder: {}", e))?;
        
    // Read audio specs from decoder
    let sample_rate = decoder.codec_params().sample_rate.unwrap_or(44100);
    let channels = decoder.codec_params().channels.map(|c| c.count()).unwrap_or(2);
    
    if sample_rate == 0 || channels == 0 {
        return Err("Invalid audio specifications (zero sample rate or channels)".to_string());
    }
    
    // Setup MP3 encoder
    let stereo_mode = match channels {
        1 => StereoMode::Mono,
        _ => StereoMode::Stereo,
    };
    
    let encoder_config = Mp3EncoderConfig::new()
        .sample_rate(sample_rate)
        .bitrate(192) // High quality 192kbps
        .channels(if channels == 1 { 1 } else { 2 })
        .stereo_mode(stereo_mode);
        
    let mut encoder = Mp3Encoder::new(encoder_config)
        .map_err(|e| format!("Failed to initialize MP3 encoder: {}", e))?;
        
    let out_file = File::create(output_path)
        .map_err(|e| format!("Failed to create output file: {}", e))?;
    let mut writer = BufWriter::new(out_file);
    
    // Decoded buffer buffer
    let mut sample_buf = None;
    
    loop {
        // Read next packet
        let packet = match format.next_packet() {
            Ok(packet) => packet,
            Err(symphonia::core::errors::Error::IoError(ref err)) if err.kind() == std::io::ErrorKind::UnexpectedEof => {
                break;
            }
            Err(err) => {
                return Err(format!("Demuxing error: {}", err));
            }
        };
        
        // If not our audio track, skip
        if packet.track_id() != track_id {
            continue;
        }
        
        // Decode
        let decoded = match decoder.decode(&packet) {
            Ok(decoded) => decoded,
            Err(symphonia::core::errors::Error::DecodeError(err)) => {
                // Log and skip decode errors
                eprintln!("Decode frame error: {}", err);
                continue;
            }
            Err(err) => {
                return Err(format!("Decoding error: {}", err));
            }
        };
        
        // Convert to PCM
        if sample_buf.is_none() {
            let spec = *decoded.spec();
            let duration = decoded.capacity() as u64;
            sample_buf = Some(SampleBuffer::<i16>::new(duration, spec));
        }
        
        if let Some(buf) = &mut sample_buf {
            buf.copy_interleaved_ref(decoded);
            let pcm_samples = buf.samples();
            
            let encoded_mp3 = encoder.encode_interleaved(pcm_samples)
                .map_err(|e| format!("MP3 encoding error: {}", e))?;
                
            for chunk in &encoded_mp3 {
                writer.write_all(chunk)
                    .map_err(|e| format!("Failed to write MP3 data: {}", e))?;
            }
        }
    }
    
    // Flush encoder
    let final_mp3 = encoder.finish()
        .map_err(|e| format!("Failed to finalize MP3: {}", e))?;
        
    writer.write_all(&final_mp3)
        .map_err(|e| format!("Failed to write remaining MP3 data: {}", e))?;
        
    writer.flush().map_err(|e| format!("Failed to flush output file: {}", e))?;
    
    Ok(())
}

/// Native FFI conversion engine from video to audio (MP3/M4A).
///
/// Automatically attempts fast lossless demuxing for M4A outputs,
/// and falls back to full PCM decoding and MP3 encoding for all formats.
#[flutter_rust_bridge::frb]
pub fn convert_media_file(
    input_path: String,
    output_path: String,
    target_format: String,
) -> Result<String, String> {
    if target_format == "m4a" && (input_path.ends_with(".mp4") || input_path.ends_with(".m4a") || input_path.ends_with(".mov")) {
        match extract_aac_lossless(&input_path, &output_path) {
            Ok(_) => return Ok(output_path),
            Err(e) => {
                println!("Lossless extraction failed, falling back to transcoding: {}", e);
            }
        }
    }
    
    // If lossless failed or target format is MP3, transcode to MP3
    let final_output_path = if target_format == "mp3" {
        output_path
    } else {
        // Fallback for m4a: transcode to MP3 and rename output extension
        output_path.replace(".m4a", ".mp3")
    };
    
    convert_to_mp3_transcode(&input_path, &final_output_path)?;
    Ok(final_output_path)
}
