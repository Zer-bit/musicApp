import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

void showAddToPlaylistDialog(
  BuildContext context,
  String songPath,
  String songTitle,
  List<Map<String, dynamic>> playlists,
  Function(int, String) onAddSongToPlaylist,
) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Text(
        'Add to Playlist',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: playlists.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No playlists available. Create one first!',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final songs = playlist['songs'] as List<String>;
                  final isAdded = songs.contains(songPath);

                  return ListTile(
                    leading: Icon(
                      Icons.playlist_play,
                      color: isAdded ? AppColors.purple : Colors.grey,
                    ),
                    title: Text(
                      playlist['name'],
                      style: TextStyle(
                        color: isAdded ? AppColors.purple : Colors.white,
                      ),
                    ),
                    trailing: Icon(
                      isAdded ? Icons.check : Icons.add,
                      color: isAdded ? AppColors.purple : Colors.grey,
                    ),
                    onTap: () {
                      if (!isAdded) {
                        onAddSongToPlaylist(index, songPath);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to ${playlist['name']}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(color: AppColors.purple),
          ),
        ),
      ],
    ),
  );
}
