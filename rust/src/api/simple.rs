use std::path::Path;
use walkdir::WalkDir;
use lofty::{TaggedFileExt, AudioFile, Accessor};

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Metadata extracted from an audio file.
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

/// Recursively scan directories for audio files and extract metadata.
/// Runs on a native OS thread — never blocks the Dart UI.
#[flutter_rust_bridge::frb]
pub fn scan_music_files(directories: Vec<String>, cache_dir: String) -> Vec<SongMetadata> {
    let extensions = ["mp3", "m4a", "wav", "flac", "ogg", "aac"];
    let mut results = Vec::new();
    let mut seen_paths = std::collections::HashSet::new();

    for dir_path in &directories {
        let dir = Path::new(dir_path);
        if !dir.exists() || !dir.is_dir() {
            continue;
        }

        for entry in WalkDir::new(dir)
            .follow_links(false)
            .into_iter()
            .filter_map(|e| e.ok())
        {
            if !entry.file_type().is_file() {
                continue;
            }

            let path = entry.path();
            let ext = path
                .extension()
                .and_then(|e| e.to_str())
                .unwrap_or("")
                .to_lowercase();

            if !extensions.contains(&ext.as_str()) {
                continue;
            }

            let path_str = path.to_string_lossy().to_string();
            if seen_paths.contains(&path_str) {
                continue;
            }
            seen_paths.insert(path_str.clone());

            // Get file modification time
            let modified_date = std::fs::metadata(path)
                .and_then(|m| m.modified())
                .map(|t| {
                    t.duration_since(std::time::UNIX_EPOCH)
                        .unwrap_or_default()
                        .as_millis() as i64
                })
                .unwrap_or(0);

            // Extract filename for fallback title
            let file_name = path
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("Unknown")
                .to_string();

            // Try to read audio metadata
            let mut cover_path = String::new();
            use std::hash::{Hash, Hasher};

            let (title, artist, album, duration_seconds) = match lofty::read_from_path(path) {
                Ok(tagged_file) => {
                    let tag = tagged_file.primary_tag().or_else(|| tagged_file.first_tag());

                    if let Some(t) = tag {
                        let pictures = t.pictures();
                        if let Some(pic) = pictures.first() {
                            let mut hasher = std::collections::hash_map::DefaultHasher::new();
                            path_str.hash(&mut hasher);
                            let file_hash = hasher.finish();
                            let out_path = format!("{}/{}.jpg", cache_dir, file_hash);
                            if std::fs::write(&out_path, pic.data()).is_ok() {
                                cover_path = out_path;
                            }
                        }
                    }

                    let title = tag
                        .and_then(|t| t.title().map(|s| s.to_string()))
                        .unwrap_or_else(|| file_name.clone());

                    let artist = tag
                        .and_then(|t| t.artist().map(|s| s.to_string()))
                        .unwrap_or_else(|| "Unknown Artist".to_string());

                    let album = tag
                        .and_then(|t| t.album().map(|s| s.to_string()))
                        .unwrap_or_default();

                    let duration = tagged_file
                        .properties()
                        .duration()
                        .as_secs_f64();

                    (title, artist, album, duration)
                }
                Err(_) => (file_name, "Unknown Artist".to_string(), String::new(), 0.0),
            };

            results.push(SongMetadata {
                title,
                artist,
                album,
                duration_seconds,
                path: path_str,
                modified_date,
                cover_path,
            });
        }
    }

    // Sort by modification date, newest first
    results.sort_by(|a, b| b.modified_date.cmp(&a.modified_date));
    results
}

/// Search songs by a case-insensitive substring match on title and artist.
/// Returns indices of matching songs in the original list.
#[flutter_rust_bridge::frb]
pub fn search_songs(
    titles: Vec<String>,
    artists: Vec<String>,
    query: String,
) -> Vec<i32> {
    let query_lower = query.to_lowercase();
    let mut indices = Vec::new();

    for (i, (title, artist)) in titles.iter().zip(artists.iter()).enumerate() {
        if title.to_lowercase().contains(&query_lower)
            || artist.to_lowercase().contains(&query_lower)
        {
            indices.push(i as i32);
        }
    }

    indices
}

/// Sort songs and return sorted indices.
/// `sort_by` can be "title", "artist", or "date".
#[flutter_rust_bridge::frb]
pub fn sort_songs(
    titles: Vec<String>,
    artists: Vec<String>,
    modified_dates: Vec<i64>,
    sort_by: String,
) -> Vec<i32> {
    let len = titles.len();
    let mut indices: Vec<usize> = (0..len).collect();

    match sort_by.as_str() {
        "title" => {
            indices.sort_by(|&a, &b| {
                titles[a]
                    .to_lowercase()
                    .cmp(&titles[b].to_lowercase())
            });
        }
        "artist" => {
            indices.sort_by(|&a, &b| {
                artists[a]
                    .to_lowercase()
                    .cmp(&artists[b].to_lowercase())
            });
        }
        "date" | _ => {
            indices.sort_by(|&a, &b| modified_dates[b].cmp(&modified_dates[a]));
        }
    }

    indices.into_iter().map(|i| i as i32).collect()
}
