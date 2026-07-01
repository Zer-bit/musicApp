import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../../../../src/rust/api/file_ops.dart' as rust_file_ops;
import '../../../../src/rust/api/models.dart' as rust_models;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';

void showRenameSongDialog({
  required BuildContext context,
  required String songPath,
  required String currentTitle,
  required int index,
  required List<Map<String, String>> songs,
  required List<Map<String, dynamic>> playlists,
  required GlobalAudioService audioService,
  required Future<void> Function(List<Map<String, String>>) saveSongsToCache,
  required VoidCallback onStateChanged,
}) {
  final controller = TextEditingController(text: currentTitle);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Rename Song',
          style:
              TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
      content: TextField(
        controller: controller,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Song name',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.purple)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.purple)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            final newName = controller.text.trim();
            if (newName.isEmpty || newName == currentTitle) {
              navigator.pop();
              return;
            }
            navigator.pop();
            try {
              if (Platform.isAndroid) {
                final status = await Permission.manageExternalStorage.request();
                if (!status.isGranted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content:
                          Text('Storage permission required to rename files'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }

              File? sourceFile;
              String actualPath = songPath;
              if (await File(songPath).exists()) {
                sourceFile = File(songPath);
              } else {
                final altPath = songPath.endsWith('.mp3')
                    ? songPath.replaceAll('.mp3', '.m4a')
                    : songPath.replaceAll('.m4a', '.mp3');
                if (await File(altPath).exists()) {
                  sourceFile = File(altPath);
                  actualPath = altPath;
                }
              }

              if (sourceFile == null) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Song file not found on device'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final pathResult = rust_file_ops.buildRenamePath(
                originalPath: actualPath,
                newName: newName,
              );

              if (!pathResult.success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(pathResult.error),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final newPath = pathResult.newPath;
              final renameResult = await rust_file_ops.renameFile(
                originalPath: actualPath,
                newPath: newPath,
              );

              if (!renameResult.success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(renameResult.error),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final safeName = newPath.split('/').last.split('.').first;
              songs[index]['title'] = safeName;
              songs[index]['path'] = newPath;
              if (audioService.currentlyPlaying == index) {
                audioService.currentPlaylist[index]['title'] = safeName;
                audioService.currentPlaylist[index]['path'] = newPath;
              }

              final playlistModels = playlists
                  .map((p) => rust_models.Playlist(
                        name: p['name'] as String,
                        songs: List<String>.from(p['songs'] as List),
                        isSystem: p['isSystem'] == true,
                      ))
                  .toList();

              var updatedPlaylists = rust_file_ops.updatePlaylistsAfterRename(
                playlists: playlistModels,
                oldPath: actualPath,
                newPath: newPath,
              );

              if (songPath != actualPath) {
                updatedPlaylists = rust_file_ops.updatePlaylistsAfterRename(
                  playlists: updatedPlaylists,
                  oldPath: songPath,
                  newPath: newPath,
                );
              }

              for (int i = 0; i < playlists.length; i++) {
                playlists[i]['songs'] = updatedPlaylists[i].songs;
              }

              onStateChanged();
              await saveSongsToCache(songs);

              messenger.showSnackBar(
                SnackBar(
                  content: Text('Renamed to "$safeName"'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              debugPrint('❌ Rename error: $e');
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to rename: ${e.toString().replaceAll("FileSystemException: ", "")}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child:
              const Text('Rename', style: TextStyle(color: AppColors.purple)),
        ),
      ],
    ),
  );
}
