import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

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
      backgroundColor: Colors.grey.shade900,
      title: const Text('Rename Song', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Song name',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.purple)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.purple)),
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
                      content: Text('Storage permission required to rename files'),
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

              final dir = sourceFile.parent.path;
              final ext = actualPath.contains('.')
                  ? actualPath.substring(actualPath.lastIndexOf('.'))
                  : '.m4a';
              final safeName = newName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
              if (safeName.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Invalid name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final newPath = '$dir/$safeName$ext';
              await sourceFile.copy(newPath);
              try {
                await sourceFile.delete();
              } catch (_) {}

              songs[index]['title'] = safeName;
              songs[index]['path'] = newPath;
              if (audioService.currentlyPlaying == index) {
                audioService.currentPlaylist[index]['title'] = safeName;
                audioService.currentPlaylist[index]['path'] = newPath;
              }
              for (final playlist in playlists) {
                final plSongs = playlist['songs'] as List<String>;
                final idx = plSongs.indexOf(actualPath);
                if (idx != -1) plSongs[idx] = newPath;
                final idx2 = plSongs.indexOf(songPath);
                if (idx2 != -1) plSongs[idx2] = newPath;
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
          child: const Text('Rename', style: TextStyle(color: AppColors.purple)),
        ),
      ],
    ),
  );
}
