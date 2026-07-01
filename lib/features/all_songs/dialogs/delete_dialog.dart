import 'package:flutter/material.dart';
import '../../../../src/rust/api/file_ops.dart' as rust_file_ops;

import '../../../../core/services/audio_service.dart';

void showDeleteSongConfirmation({
  required BuildContext context,
  required String songPath,
  required String songTitle,
  required int index,
  required List<Map<String, String>> songs,
  required GlobalAudioService audioService,
  required Future<void> Function(List<Map<String, String>>) saveSongsToCache,
  required VoidCallback onStateChanged,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete Song',
          style:
              TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
      content: Text(
        'Are you sure you want to permanently delete "$songTitle"? This cannot be undone.',
        style: const TextStyle(color: Colors.grey),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            final messenger = ScaffoldMessenger.of(context);
            try {
              final deleteResult = await rust_file_ops.deleteFile(path: songPath);
              if (deleteResult.success) {
                songs.removeAt(index);
                if (audioService.currentlyPlaying == index) {
                  audioService.audioPlayer.stop();
                  audioService.currentlyPlaying = null;
                  audioService.notifyListeners();
                } else if (audioService.currentlyPlaying != null &&
                    audioService.currentlyPlaying! > index) {
                  audioService.currentlyPlaying =
                      audioService.currentlyPlaying! - 1;
                  audioService.notifyListeners();
                }

                onStateChanged();
                await saveSongsToCache(songs);

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Deleted $songTitle'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(deleteResult.error.isNotEmpty ? deleteResult.error : 'File not found'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Error deleting file: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
