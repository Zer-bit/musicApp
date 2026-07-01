/// Shared data models for the Jezsic music app.
///
/// All structs here are passed across the Flutter ↔ Rust FFI boundary.

/// Audio file metadata extracted during filesystem scanning.
#[flutter_rust_bridge::frb]
pub struct SongMetadata {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_seconds: f64,
    pub path: String,
    pub modified_date: i64,
    pub cover_path: String,
}

/// A user-created or system playlist.
#[flutter_rust_bridge::frb]
#[derive(Clone)]
pub struct Playlist {
    pub name: String,
    pub songs: Vec<String>,
    pub is_system: bool,
}

/// A single play-count entry (song path → count).
#[flutter_rust_bridge::frb]
pub struct PlayCountEntry {
    pub path: String,
    pub count: i64,
}

/// A single lyrics entry (song path → lyrics text).
#[flutter_rust_bridge::frb]
pub struct LyricsEntry {
    pub path: String,
    pub lyrics: String,
}

/// Result of a file rename operation.
#[flutter_rust_bridge::frb]
pub struct RenameResult {
    pub success: bool,
    pub new_path: String,
    pub error: String,
}

/// Result of a file delete operation.
#[flutter_rust_bridge::frb]
pub struct DeleteResult {
    pub success: bool,
    pub error: String,
}

/// Result of a next/previous song index calculation.
#[flutter_rust_bridge::frb]
pub struct NextSongResult {
    pub index: i32,
    pub found: bool,
}
