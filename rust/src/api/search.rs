/// Search and sort algorithms for song lists.

/// Case-insensitive substring search on title and artist.
///
/// Returns indices of matching songs in the original list.
#[flutter_rust_bridge::frb]
pub fn search_songs(titles: Vec<String>, artists: Vec<String>, query: String) -> Vec<i32> {
    let q = query.to_lowercase();
    titles.iter().zip(artists.iter())
        .enumerate()
        .filter(|(_, (t, a))| t.to_lowercase().contains(&q) || a.to_lowercase().contains(&q))
        .map(|(i, _)| i as i32)
        .collect()
}

/// Sort songs and return sorted indices.
///
/// `sort_by`: `"title"`, `"artist"`, or `"date"` (default: newest first).
#[flutter_rust_bridge::frb]
pub fn sort_songs(
    titles: Vec<String>,
    artists: Vec<String>,
    modified_dates: Vec<i64>,
    sort_by: String,
) -> Vec<i32> {
    let mut idx: Vec<usize> = (0..titles.len()).collect();

    match sort_by.as_str() {
        "title" => idx.sort_by(|&a, &b| {
            titles[a].to_lowercase().cmp(&titles[b].to_lowercase())
        }),
        "artist" => idx.sort_by(|&a, &b| {
            artists[a].to_lowercase().cmp(&artists[b].to_lowercase())
        }),
        _ => idx.sort_by(|&a, &b| modified_dates[b].cmp(&modified_dates[a])),
    }

    idx.into_iter().map(|i| i as i32).collect()
}
