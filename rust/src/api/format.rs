/// Utility formatters: duration, file size, URL detection, filename sanitization.

/// Format seconds into "M:SS" or "H:MM:SS".
#[flutter_rust_bridge::frb(sync)]
pub fn format_duration(seconds: f64) -> String {
    if seconds <= 0.0 || seconds.is_nan() || seconds.is_infinite() {
        return "0:00".to_string();
    }
    let total = seconds.round() as u64;
    let hrs = total / 3600;
    let mins = (total % 3600) / 60;
    let secs = total % 60;
    if hrs > 0 {
        format!("{}:{:02}:{:02}", hrs, mins, secs)
    } else {
        format!("{}:{:02}", mins, secs)
    }
}

/// Format bytes into a human-readable string (e.g. "3.2 MB").
#[flutter_rust_bridge::frb(sync)]
pub fn format_file_size(bytes: i64) -> String {
    const KB: f64 = 1024.0;
    const MB: f64 = KB * 1024.0;
    const GB: f64 = MB * 1024.0;
    let b = bytes as f64;
    if b >= GB {
        format!("{:.1} GB", b / GB)
    } else if b >= MB {
        format!("{:.1} MB", b / MB)
    } else if b >= KB {
        format!("{:.1} KB", b / KB)
    } else {
        format!("{} B", bytes)
    }
}

/// Check whether the input string is a YouTube URL.
#[flutter_rust_bridge::frb(sync)]
pub fn is_youtube_url(input: String) -> bool {
    let lower = input.to_lowercase();
    lower.contains("youtube.com") || lower.contains("youtu.be")
}

/// Remove invalid filesystem characters from a filename.
#[flutter_rust_bridge::frb(sync)]
pub fn sanitize_filename(name: String) -> String {
    name.chars()
        .filter(|c| c.is_alphanumeric() || c.is_whitespace() || *c == '-' || *c == '_')
        .collect::<String>()
        .trim()
        .to_string()
}

/// Sanitize a download filename (same rules as sanitize_filename).
#[flutter_rust_bridge::frb(sync)]
pub fn sanitize_download_filename(name: String) -> String {
    sanitize_filename(name)
}
