import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';

void showSleepTimerDialog(
  BuildContext context,
  GlobalAudioService audioService,
  VoidCallback onStateChanged,
) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Text('Sleep Timer', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (audioService.sleepTimer != null) ...[
            const Text(
              'Timer active',
              style: TextStyle(
                color: AppColors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                if (audioService.sleepEndTime == null) {
                  return const Text(
                    '--:--',
                    style: TextStyle(color: Colors.white),
                  );
                }
                final remaining = audioService.sleepEndTime!.difference(
                  DateTime.now(),
                );
                if (remaining.isNegative) {
                  return const Text(
                    '00:00',
                    style: TextStyle(color: Colors.white),
                  );
                }
                final minutes = remaining.inMinutes;
                final seconds = remaining.inSeconds % 60;
                return Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                audioService.cancelSleepTimer();
                Navigator.pop(context);
                onStateChanged();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancel Timer'),
            ),
          ] else ...[
            const Text(
              'Stop playback after:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text(
                '15 minutes',
                style: TextStyle(color: Colors.white),
              ),
              leading: const Icon(Icons.timer, color: AppColors.purple),
              onTap: () {
                audioService.setSleepTimer(const Duration(minutes: 15));
                Navigator.pop(context);
                onStateChanged();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sleep timer set for 15 minutes'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text(
                '30 minutes',
                style: TextStyle(color: Colors.white),
              ),
              leading: const Icon(Icons.timer, color: AppColors.purple),
              onTap: () {
                audioService.setSleepTimer(const Duration(minutes: 30));
                Navigator.pop(context);
                onStateChanged();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sleep timer set for 30 minutes'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text(
                '45 minutes',
                style: TextStyle(color: Colors.white),
              ),
              leading: const Icon(Icons.timer, color: AppColors.purple),
              onTap: () {
                audioService.setSleepTimer(const Duration(minutes: 45));
                Navigator.pop(context);
                onStateChanged();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sleep timer set for 45 minutes'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text(
                '1 hour',
                style: TextStyle(color: Colors.white),
              ),
              leading: const Icon(Icons.timer, color: AppColors.purple),
              onTap: () {
                audioService.setSleepTimer(const Duration(hours: 1));
                Navigator.pop(context);
                onStateChanged();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sleep timer set for 1 hour'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.grey)),
        ),
      ],
    ),
  );
}
