use super::models::NextSongResult;

/// Calculate the next song index.
///
/// loop_mode: "off", "all", or "one".
#[flutter_rust_bridge::frb(sync)]
pub fn next_song_index(
    current_index: i32,
    playlist_length: i32,
    is_shuffle: bool,
    loop_mode: String,
    timestamp_seed: i64,
) -> NextSongResult {
    if playlist_length <= 0 {
        return NextSongResult { index: -1, found: false };
    }

    if is_shuffle && playlist_length > 1 {
        // Simple pseudo-random using multiplication/mix off the timestamp seed
        let mut seed = timestamp_seed;
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        let next_idx = (seed.abs() % playlist_length as i64) as i32;
        
        // Prevent repeating the same song immediately if possible
        if next_idx == current_index {
            let alternative = (next_idx + 1) % playlist_length;
            return NextSongResult { index: alternative, found: true };
        }
        return NextSongResult { index: next_idx, found: true };
    }

    if loop_mode == "off" && current_index == playlist_length - 1 {
        return NextSongResult { index: -1, found: false };
    }

    let index = (current_index + 1) % playlist_length;
    NextSongResult { index, found: true }
}

/// Calculate the previous song index.
///
/// If position_seconds > 3, it should restart the current song instead of moving back.
#[flutter_rust_bridge::frb(sync)]
pub fn prev_song_index(
    current_index: i32,
    playlist_length: i32,
    is_shuffle: bool,
    position_seconds: i32,
    timestamp_seed: i64,
) -> NextSongResult {
    if playlist_length <= 0 {
        return NextSongResult { index: -1, found: false };
    }

    // If active track has played > 3 seconds, replay it instead of going back
    if position_seconds > 3 {
        return NextSongResult { index: current_index, found: true };
    }

    if is_shuffle && playlist_length > 1 {
        let mut seed = timestamp_seed;
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        let prev_idx = (seed.abs() % playlist_length as i64) as i32;
        if prev_idx == current_index {
            let alternative = (prev_idx + playlist_length - 1) % playlist_length;
            return NextSongResult { index: alternative, found: true };
        }
        return NextSongResult { index: prev_idx, found: true };
    }

    let index = (current_index - 1 + playlist_length) % playlist_length;
    NextSongResult { index, found: true }
}
