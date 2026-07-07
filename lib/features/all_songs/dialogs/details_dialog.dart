import 'dart:io';
import 'package:flutter/material.dart';

/// Shows a details dialog for a specific song/audio track.
void showSongDetailsDialog(BuildContext context, Map<String, String> song) {
  final path = song['path'] ?? 'Unknown';
  final file = File(path);
  
  final fileExists = file.existsSync();
  final int bytes = fileExists ? file.lengthSync() : 0;
  final lastModified = fileExists ? file.lastModifiedSync() : null;
  
  final sizeStr = _formatSize(bytes);
  final nameStr = path.split('/').last;
  final formatStr = path.contains('.') ? path.split('.').last.toUpperCase() : 'Unknown';
  
  final isDark = Theme.of(context).brightness == Brightness.dark;
  const accentColor = Color(0xFF854F6C);
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF191919) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.info_outline, color: accentColor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Track Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8F8F8) : Colors.black,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                context,
                'Title',
                song['title'] ?? 'Unknown',
                isDark,
              ),
              _buildDetailRow(
                context,
                'Artist',
                song['artist'] ?? 'Unknown',
                isDark,
              ),
              _buildDetailRow(
                context,
                'Duration',
                song['duration'] ?? 'Unknown',
                isDark,
              ),
              _buildDetailRow(
                context,
                'File Name',
                nameStr,
                isDark,
              ),
              _buildDetailRow(
                context,
                'Format',
                formatStr,
                isDark,
              ),
              _buildDetailRow(
                context,
                'File Size',
                sizeStr,
                isDark,
              ),
              _buildDetailRow(
                context,
                'Last Modified',
                lastModified != null ? _formatDateTime(lastModified) : 'Unknown',
                isDark,
              ),
              _buildDetailRow(
                context,
                'Storage Location',
                path,
                isDark,
                isPath: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: accentColor,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Widget _buildDetailRow(
  BuildContext context,
  String label,
  String value,
  bool isDark, {
  bool isPath = false,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF854F6C).withOpacity(0.8),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFFF8F8F8) : Colors.black87,
            fontFamily: isPath ? 'monospace' : null,
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1, color: Colors.grey),
      ],
    ),
  );
}

String _formatSize(int bytes) {
  if (bytes <= 0) return 'Unknown size';
  const suffixes = ['B', 'KB', 'MB', 'GB'];
  var i = 0;
  double size = bytes.toDouble();
  while (size >= 1024 && i < suffixes.length - 1) {
    size /= 1024;
    i++;
  }
  return '${size.toStringAsFixed(2)} ${suffixes[i]} ($bytes bytes)';
}

String _formatDateTime(DateTime dt) {
  final year = dt.year;
  final month = dt.month.toString().padLeft(2, '0');
  final day = dt.day.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  final second = dt.second.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute:$second';
}
