/// Playlist, play-count, and lyrics serialization + favorites computation.

use serde::{Deserialize, Serialize};
use super::models::{Playlist, PlayCountEntry, LyricsEntry};

// ── Internal serde types (not exposed via FFI) ──

#[derive(Serialize, Deserialize)]
struct PlaylistJson {
    name: String,
    songs: Vec<String>,
}



// ── Playlist serialization ──

/// Serialize user playlists to JSON (excludes system playlists).
#[flutter_rust_bridge::frb(sync)]
pub fn serialize_playlists(playlists: Vec<Playlist>) -> String {
    let json_list: Vec<PlaylistJson> = playlists
        .into_iter()
        .filter(|p| !p.is_system)
        .map(|p| PlaylistJson { name: p.name, songs: p.songs })
        .collect();
    serde_json::to_string(&json_list).unwrap_or_else(|_| "[]".into())
}

/// Deserialize user playlists from JSON.
#[flutter_rust_bridge::frb(sync)]
pub fn deserialize_playlists(json: String) -> Vec<Playlist> {
    let list: Vec<PlaylistJson> = serde_json::from_str(&json).unwrap_or_default();
    list.into_iter()
        .map(|p| Playlist { name: p.name, songs: p.songs, is_system: false })
        .collect()
}

// ── Play count serialization ──

/// Serialize play counts to JSON string.
#[flutter_rust_bridge::frb(sync)]
pub fn serialize_play_counts(entries: Vec<PlayCountEntry>) -> String {
    let map: std::collections::HashMap<String, String> = entries
        .into_iter()
        .map(|e| (e.path, e.count.to_string()))
        .collect();
    serde_json::to_string(&map).unwrap_or_else(|_| "{}".into())
}

/// Deserialize play counts from JSON string.
#[flutter_rust_bridge::frb(sync)]
pub fn deserialize_play_counts(json: String) -> Vec<PlayCountEntry> {
    let map: std::collections::HashMap<String, String> =
        serde_json::from_str(&json).unwrap_or_default();
    map.into_iter()
        .map(|(path, val)| PlayCountEntry {
            path,
            count: val.parse().unwrap_or(0),
        })
        .collect()
}

// ── Lyrics serialization ──

/// Serialize lyrics to JSON string.
#[flutter_rust_bridge::frb(sync)]
pub fn serialize_lyrics(entries: Vec<LyricsEntry>) -> String {
    let map: std::collections::HashMap<String, String> = entries
        .into_iter()
        .map(|e| (e.path, e.lyrics))
        .collect();
    serde_json::to_string(&map).unwrap_or_else(|_| "{}".into())
}

/// Deserialize lyrics from JSON string.
#[flutter_rust_bridge::frb(sync)]
pub fn deserialize_lyrics(json: String) -> Vec<LyricsEntry> {
    let map: std::collections::HashMap<String, String> =
        serde_json::from_str(&json).unwrap_or_default();
    map.into_iter()
        .map(|(path, lyrics)| LyricsEntry { path, lyrics })
        .collect()
}

// ── Favorites ──

/// Compute the top N most-played song paths, sorted by count descending.
#[flutter_rust_bridge::frb(sync)]
pub fn compute_favorites(entries: Vec<PlayCountEntry>, limit: i32) -> Vec<String> {
    let mut sorted = entries;
    sorted.sort_by(|a, b| b.count.cmp(&a.count));
    sorted.into_iter()
        .take(limit as usize)
        .map(|e| e.path)
        .collect()
}

// ── Playlist mutations ──

/// Add a song to a playlist (no duplicates). Returns the updated playlist.
#[flutter_rust_bridge::frb(sync)]
pub fn add_song_to_playlist(playlist: Playlist, song_path: String) -> Playlist {
    let mut songs = playlist.songs;
    if !songs.contains(&song_path) {
        songs.push(song_path);
    }
    Playlist { name: playlist.name, songs, is_system: playlist.is_system }
}

/// Remove a song from a playlist. Returns the updated playlist.
#[flutter_rust_bridge::frb(sync)]
pub fn remove_song_from_playlist(playlist: Playlist, song_path: String) -> Playlist {
    let songs: Vec<String> = playlist.songs.into_iter()
        .filter(|s| s != &song_path)
        .collect();
    Playlist { name: playlist.name, songs, is_system: playlist.is_system }
}
