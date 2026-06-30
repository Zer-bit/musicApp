import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';

import '../../core/theme/app_colors.dart';
import '../../core/services/audio_service.dart';
import 'now_playing_screen.dart';

class GlobalMiniPlayer extends StatefulWidget {
  const GlobalMiniPlayer({super.key});

  @override
  State<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends State<GlobalMiniPlayer> {
  final GlobalAudioService _audioService = GlobalAudioService();

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_onAudioUpdate);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioUpdate);
    super.dispose();
  }

  void _onAudioUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  IconData _getLoopIcon() {
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
    if (_audioService.currentlyPlaying == null ||
        _audioService.currentPlaylist.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentSong =
        _audioService.currentPlaylist[_audioService.currentlyPlaying!];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const NowPlayingScreen(),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
              ),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).primaryColor,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      if (currentSong['coverPath'] != null &&
                          currentSong['coverPath']!.isNotEmpty &&
                          File(currentSong['coverPath']!).existsSync())
                        Positioned.fill(
                          child: Image.file(
                            File(currentSong['coverPath']!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      Positioned.fill(
                        child: Container(
                          color: currentSong['coverPath'] != null &&
                                  currentSong['coverPath']!.isNotEmpty &&
                                  File(currentSong['coverPath']!).existsSync()
                              ? Colors.black.withOpacity(0.4)
                              : Colors.transparent,
                          child: Icon(
                            _audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSong['title'] ?? 'Unknown',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_formatDuration(_audioService.currentPosition)} / ${_formatDuration(_audioService.totalDuration)}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: _audioService.isShuffleOn
                        ? AppColors.purple
                        : Colors.grey,
                  ),
                  onPressed: () => _audioService.toggleShuffle(),
                ),
                IconButton(
                  icon: Icon(
                    _getLoopIcon(),
                    color: _audioService.loopMode != LoopMode.off
                        ? AppColors.purple
                        : Colors.grey,
                  ),
                  onPressed: () => _audioService.toggleLoopMode(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    _audioService.audioPlayer.stop();
                    _audioService.currentlyPlaying = null;
                    _audioService.isPlaying = false;
                    _audioService.notifyListeners();
                  },
                  tooltip: 'Close player',
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: _audioService.currentPosition.inSeconds.toDouble(),
                max: _audioService.totalDuration.inSeconds.toDouble() > 0
                    ? _audioService.totalDuration.inSeconds.toDouble()
                    : 1,
                activeColor: AppColors.blue,
                inactiveColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
                onChanged: (value) async {
                  await _audioService.audioPlayer.seek(
                    Duration(seconds: value.toInt()),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 32),
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  onPressed: _audioService.currentPlaylist.isNotEmpty &&
                          _audioService.currentlyPlaying != null
                      ? () => _audioService.playPrevious()
                      : null,
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).primaryColor,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32,
                    ),
                    color: Colors.white,
                    onPressed: _audioService.currentlyPlaying != null &&
                            _audioService.currentlyPlaying! <
                                _audioService.currentPlaylist.length
                        ? () => _audioService.playSong(
                              currentSong['path']!,
                              _audioService.currentlyPlaying!,
                            )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 32),
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  onPressed: _audioService.currentPlaylist.isNotEmpty &&
                          _audioService.currentlyPlaying != null
                      ? () => _audioService.playNext()
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
