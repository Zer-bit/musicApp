import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math' as math;
import 'dart:io';
import '../../src/rust/api/format.dart' as rust_format;

import '../../core/theme/app_colors.dart';
import '../../core/services/audio_service.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  final GlobalAudioService _audioService = GlobalAudioService();
  late AnimationController _albumArtController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _albumArtController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _audioService.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _albumArtController.dispose();
    _waveController.dispose();
    _audioService.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  String _format(Duration d) {
    return rust_format.formatDuration(seconds: d.inSeconds.toDouble());
  }

  IconData _loopIcon() {
    switch (_audioService.loopMode) {
      case LoopMode.off:
        return Icons.repeat;
      case LoopMode.all:
        return Icons.repeat;
      case LoopMode.one:
        return Icons.repeat_one;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTrack = _audioService.currentlyPlaying != null &&
        _audioService.currentPlaylist.isNotEmpty;
    final song = hasTrack
        ? _audioService.currentPlaylist[_audioService.currentlyPlaying!]
        : <String, String>{};
    final title = song['title'] ?? 'Not Playing';
    final isPlaying = _audioService.isPlaying;
    final position = _audioService.currentPosition;
    final duration = _audioService.totalDuration;
    final maxSec = duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        size: 32,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Now Playing',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    // Sleep timer button
                    PopupMenuButton<int>(
                      icon: Icon(
                        Icons.timer,
                        color: _audioService.sleepEndTime != null
                            ? AppColors.purple
                            : Colors.grey,
                      ),
                      color: Theme.of(context).cardColor,
                      tooltip: 'Sleep Timer',
                      offset: const Offset(0, 40),
                      onSelected: (minutes) {
                        if (minutes == 0) {
                          _audioService.cancelSleepTimer();
                        } else {
                          _audioService.setSleepTimer(
                            Duration(minutes: minutes),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Sleep timer set for $minutes minutes',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 15,
                          child: Text(
                            '15 minutes',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 30,
                          child: Text(
                            '30 minutes',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 45,
                          child: Text(
                            '45 minutes',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 60,
                          child: Text(
                            '1 hour',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 0,
                          child: Text(
                            'Cancel Timer',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Album art (spinning vinyl) ──
              Expanded(
                flex: 5,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _albumArtController,
                    builder: (context, _) {
                      return Transform.rotate(
                        angle: isPlaying
                            ? _albumArtController.value * 2 * math.pi
                            : 0,
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFE2E8F0),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.purple.withOpacity(
                                  isPlaying ? 0.6 : 0.2,
                                ),
                                blurRadius: isPlaying ? 40 : 20,
                                spreadRadius: isPlaying ? 8 : 2,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Grooves
                              ...List.generate(6, (i) {
                                final r = 50.0 + i * 22.0;
                                return Container(
                                  width: r * 2,
                                  height: r * 2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.05),
                                      width: 1,
                                    ),
                                  ),
                                );
                              }),
                              // Center label
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).primaryColor,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: song['coverPath'] != null &&
                                        song['coverPath']!.isNotEmpty &&
                                        File(song['coverPath']!).existsSync()
                                    ? Image.file(
                                        File(song['coverPath']!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(
                                          Icons.music_note,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.music_note,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Song info & wave bars ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    // Wave bars (animated when playing)
                    if (isPlaying)
                      AnimatedBuilder(
                        animation: _waveController,
                        builder: (_, w) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(5, (i) {
                            final phase = i * 0.6;
                            final h = 6.0 +
                                14.0 *
                                    (0.5 +
                                        0.5 *
                                            math.sin(
                                              _waveController.value * math.pi +
                                                  phase,
                                            ));
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Container(
                                width: 4,
                                height: h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasTrack
                          ? '${_audioService.currentlyPlaying! + 1} of ${_audioService.currentPlaylist.length}'
                          : '',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Progress slider ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        activeTrackColor: AppColors.blue,
                        inactiveTrackColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                        thumbColor: Theme.of(context).primaryColor,
                        overlayColor:
                            Theme.of(context).primaryColor.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: position.inSeconds.toDouble().clamp(0.0, maxSec),
                        max: maxSec,
                        onChanged: hasTrack
                            ? (v) => _audioService.audioPlayer.seek(
                                  Duration(seconds: v.toInt()),
                                )
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _format(position),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _format(duration),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Control buttons ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Shuffle
                    IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: _audioService.isShuffleOn
                            ? AppColors.purple
                            : Colors.grey,
                        size: 26,
                      ),
                      onPressed: () => _audioService.toggleShuffle(),
                    ),
                    // Previous
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        size: 38,
                      ),
                      onPressed:
                          hasTrack ? () => _audioService.playPrevious() : null,
                    ),
                    // Play / Pause (big)
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).primaryColor,
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                        onPressed: hasTrack
                            ? () => _audioService.playSong(
                                  song['path']!,
                                  _audioService.currentlyPlaying!,
                                )
                            : null,
                      ),
                    ),
                    // Next
                    IconButton(
                      icon: Icon(
                        Icons.skip_next,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        size: 38,
                      ),
                      onPressed:
                          hasTrack ? () => _audioService.playNext() : null,
                    ),
                    // Loop
                    IconButton(
                      icon: Icon(
                        _loopIcon(),
                        color: _audioService.loopMode != LoopMode.off
                            ? AppColors.purple
                            : Colors.grey,
                        size: 26,
                      ),
                      onPressed: () => _audioService.toggleLoopMode(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
