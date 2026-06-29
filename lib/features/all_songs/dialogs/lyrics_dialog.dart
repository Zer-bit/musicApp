import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

void _showRemoveLyricsConfirmation({
  required BuildContext dialogContext,
  required String songPath,
  required Function(String, String) onSaveLyrics,
}) {
  showDialog(
    context: dialogContext,
    builder: (confirmContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Remove Lyrics', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete the lyrics for this song?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(confirmContext);
              Navigator.pop(dialogContext);
              onSaveLyrics(songPath, '');
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('Lyrics removed'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      );
    },
  );
}

void showLyricsDialog({
  required BuildContext context,
  required String songPath,
  required String songTitle,
  required Map<String, String> lyrics,
  required Function(String, String) onSaveLyrics,
}) {
  final String initialLyrics = lyrics[songPath] ?? '';
  final TextEditingController lyricsController = TextEditingController(
    text: initialLyrics,
  );
  final bool hasLyrics = initialLyrics.isNotEmpty;

  showDialog(
    context: context,
    builder: (context) {
      bool isEditing = false;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final screenSize = MediaQuery.of(context).size;
          final isSmallScreen = screenSize.width < 400;
          final dialogWidth = screenSize.width * 0.9;
          final dialogHeight = screenSize.height * 0.7;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Container(
              width: dialogWidth > 500 ? 500 : dialogWidth,
              height: dialogHeight > 600 ? 600 : dialogHeight,
              decoration: BoxDecoration(
                gradient: AppColors.darkGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      gradient: AppColors.purpleBlueGradient,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lyrics,
                          color: Colors.white,
                          size: isSmallScreen ? 24 : 28,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Lyrics' : 'Lyrics',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                songTitle,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: isSmallScreen ? 12 : 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Lyrics editor
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: lyricsController,
                        maxLines: null,
                        expands: true,
                        readOnly: !isEditing,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 14 : 16,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: isEditing
                              ? 'Type or paste lyrics here...\n\n'
                                'Verse 1:\n'
                                'Your lyrics...\n\n'
                                'Chorus:\n'
                                'Your lyrics...'
                              : 'No lyrics saved for this song.',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                          border: InputBorder.none,
                        ),
                        textAlignVertical: TextAlignVertical.top,
                      ),
                    ),
                  ),
                  // Action buttons
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: !isEditing
                        // View Mode buttons
                        ? (isSmallScreen && hasLyrics
                            ? Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showRemoveLyricsConfirmation(
                                        dialogContext: context,
                                        songPath: songPath,
                                        onSaveLyrics: onSaveLyrics,
                                      ),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      label: const Text('Remove'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setDialogState(() {
                                          isEditing = true;
                                        });
                                      },
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Edit Lyrics'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  if (hasLyrics)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _showRemoveLyricsConfirmation(
                                          dialogContext: context,
                                          songPath: songPath,
                                          onSaveLyrics: onSaveLyrics,
                                        ),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        label: const Text('Remove'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (hasLyrics) const SizedBox(width: 8),
                                  Expanded(
                                    flex: hasLyrics ? 2 : 1,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setDialogState(() {
                                          isEditing = true;
                                        });
                                      },
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Edit'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ))
                        // Edit Mode buttons
                        : (isSmallScreen
                            ? Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        lyricsController.text = initialLyrics;
                                        setDialogState(() {
                                          isEditing = false;
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.cancel_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Cancel'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.grey.shade400,
                                        side: BorderSide(color: Colors.grey.shade600),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final lyricsText = lyricsController.text.trim();
                                        if (lyricsText.isNotEmpty) {
                                          onSaveLyrics(songPath, lyricsText);
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('✓ Lyrics saved'),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Please enter some lyrics',
                                              ),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.save, size: 18),
                                      label: const Text('Save'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        lyricsController.text = initialLyrics;
                                        setDialogState(() {
                                          isEditing = false;
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.cancel_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Cancel'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.grey.shade400,
                                        side: BorderSide(color: Colors.grey.shade600),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final lyricsText = lyricsController.text.trim();
                                        if (lyricsText.isNotEmpty) {
                                          onSaveLyrics(songPath, lyricsText);
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('✓ Lyrics saved'),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Please enter some lyrics',
                                              ),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.save, size: 18),
                                      label: const Text('Save'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
