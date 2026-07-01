/// Filesystem scanning and audio metadata extraction.

use std::path::Path;
use std::hash::{Hash, Hasher};
use walkdir::WalkDir;
use lofty::{TaggedFileExt, AudioFile, Accessor};

use super::models::SongMetadata;

/// Supported audio file extensions.
const EXTENSIONS: &[&str] = &["mp3", "m4a", "wav", "flac", "ogg", "aac"];

/// Standard subdirectories to scan on Android.
const SCAN_SUBDIRS: &[&str] = &[
    "Music", "Download", "Downloads",
    "Recordings", "Recorder", "VoiceRecorder",
    "Audio", "Record", "DCIM",
];

/// Build a deduplicated list of directories to scan.
///
/// Combines default Android paths with any additional external root.
#[flutter_rust_bridge::frb]
pub fn build_scan_paths(base_path: String, external_root: String) -> Vec<String> {
    let mut paths: Vec<String> = SCAN_SUBDIRS
        .iter()
        .map(|sub| format!("{}/{}", base_path, sub))
        .collect();

    if !external_root.is_empty() && external_root != base_path {
        for sub in SCAN_SUBDIRS {
            let candidate = format!("{}/{}", external_root, sub);
            if !paths.contains(&candidate) {
                paths.push(candidate);
            }
        }
    }

    paths
}

/// Recursively scan directories for audio files and extract metadata.
///
/// Runs on a native OS thread — never blocks the Dart UI.
#[flutter_rust_bridge::frb]
pub fn scan_music_files(directories: Vec<String>, cache_dir: String) -> Vec<SongMetadata> {
    let mut results = Vec::new();
    let mut seen = std::collections::HashSet::new();

    for dir_path in &directories {
        let dir = Path::new(dir_path);
        if !dir.is_dir() {
            continue;
        }

        for entry in WalkDir::new(dir).follow_links(false).into_iter().filter_map(|e| e.ok()) {
            if !entry.file_type().is_file() {
                continue;
            }

            let path = entry.path();
            let ext = path.extension()
                .and_then(|e| e.to_str())
                .unwrap_or("")
                .to_lowercase();

            if !EXTENSIONS.contains(&ext.as_str()) {
                continue;
            }

            let path_str = path.to_string_lossy().to_string();
            if !seen.insert(path_str.clone()) {
                continue;
            }

            let modified_date = std::fs::metadata(path)
                .and_then(|m| m.modified())
                .map(|t| t.duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_millis() as i64)
                .unwrap_or(0);

            let file_name = path.file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("Unknown")
                .to_string();

            let (title, artist, album, duration_seconds, cover_path) =
                extract_metadata(path, &file_name, &path_str, &cache_dir);

            results.push(SongMetadata {
                title, artist, album, duration_seconds,
                path: path_str, modified_date, cover_path,
            });
        }
    }

    results.sort_by(|a, b| b.modified_date.cmp(&a.modified_date));
    results
}

/// Extract audio tags and cover art from a single file.
fn extract_metadata(
    path: &Path,
    file_name: &str,
    path_str: &str,
    cache_dir: &str,
) -> (String, String, String, f64, String) {
    let Ok(tagged_file) = lofty::read_from_path(path) else {
        return (file_name.to_string(), "Unknown Artist".into(), String::new(), 0.0, String::new());
    };

    let tag = tagged_file.primary_tag().or_else(|| tagged_file.first_tag());

    // Extract cover art
    let cover_path = tag
        .and_then(|t| t.pictures().first())
        .and_then(|pic| {
            let mut hasher = std::collections::hash_map::DefaultHasher::new();
            path_str.hash(&mut hasher);
            let out = format!("{}/{}.jpg", cache_dir, hasher.finish());
            std::fs::write(&out, pic.data()).ok().map(|_| out)
        })
        .unwrap_or_default();

    let title = tag.and_then(|t| t.title().map(|s| s.to_string()))
        .unwrap_or_else(|| file_name.to_string());
    let artist = tag.and_then(|t| t.artist().map(|s| s.to_string()))
        .unwrap_or_else(|| "Unknown Artist".into());
    let album = tag.and_then(|t| t.album().map(|s| s.to_string()))
        .unwrap_or_default();
    let duration = tagged_file.properties().duration().as_secs_f64();

    (title, artist, album, duration, cover_path)
}
