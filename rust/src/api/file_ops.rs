use std::path::Path;
use super::models::{Playlist, RenameResult, DeleteResult};

/// Build a safe destination file path for renaming.
#[flutter_rust_bridge::frb(sync)]
pub fn build_rename_path(original_path: String, new_name: String) -> RenameResult {
    let source_path = Path::new(&original_path);
    if !source_path.exists() {
        return RenameResult {
            success: false,
            new_path: String::new(),
            error: "Source file does not exist".to_string(),
        };
    }

    let dir = match source_path.parent() {
        Some(p) => p.to_string_lossy().to_string(),
        None => return RenameResult {
            success: false,
            new_path: String::new(),
            error: "Could not resolve parent directory".to_string(),
        },
    };

    let ext = source_path
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("m4a");

    // Clean special filesystem characters
    let safe_name = new_name
        .chars()
        .filter(|c| c.is_alphanumeric() || c.is_whitespace() || *c == '-' || *c == '_')
        .collect::<String>()
        .trim()
        .to_string();

    if safe_name.is_empty() {
        return RenameResult {
            success: false,
            new_path: String::new(),
            error: "New name is invalid".to_string(),
        };
    }

    let new_path = format!("{}/{}.{}", dir, safe_name, ext);

    RenameResult {
        success: true,
        new_path,
        error: String::new(),
    }
}

/// Execute a physical file rename (copy + delete source).
#[flutter_rust_bridge::frb]
pub fn rename_file(original_path: String, new_path: String) -> RenameResult {
    let source = Path::new(&original_path);
    let dest = Path::new(&new_path);

    if !source.exists() {
        return RenameResult {
            success: false,
            new_path: String::new(),
            error: "Source file not found".to_string(),
        };
    }

    if dest.exists() {
        return RenameResult {
            success: false,
            new_path: String::new(),
            error: "A file with the new name already exists".to_string(),
        };
    }

    // Try to copy and then delete original file
    if let Err(e) = std::fs::copy(source, dest) {
        return RenameResult {
            success: false,
            new_path: String::new(),
            error: format!("Failed to copy file: {}", e),
        };
    }

    if let Err(e) = std::fs::remove_file(source) {
        // Log delete error but report success since destination file is created
        return RenameResult {
            success: true,
            new_path: new_path.clone(),
            error: format!("Renamed successfully, but failed to clean up original: {}", e),
        };
    }

    RenameResult {
        success: true,
        new_path,
        error: String::new(),
    }
}

/// Execute a physical file deletion.
#[flutter_rust_bridge::frb]
pub fn delete_file(path: String) -> DeleteResult {
    let file_path = Path::new(&path);
    if !file_path.exists() {
        return DeleteResult {
            success: false,
            error: "File not found on device".to_string(),
        };
    }

    match std::fs::remove_file(file_path) {
        Ok(_) => DeleteResult {
            success: true,
            error: String::new(),
        },
        Err(e) => DeleteResult {
            success: false,
            error: format!("Failed to delete file: {}", e),
        },
    }
}

/// Update a song path in all playlists when it is renamed.
#[flutter_rust_bridge::frb(sync)]
pub fn update_playlists_after_rename(
    playlists: Vec<Playlist>,
    old_path: String,
    new_path: String,
) -> Vec<Playlist> {
    playlists
        .into_iter()
        .map(|mut playlist| {
            playlist.songs = playlist
                .songs
                .into_iter()
                .map(|s| if s == old_path { new_path.clone() } else { s })
                .collect();
            playlist
        })
        .collect()
}
