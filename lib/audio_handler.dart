import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'main.dart' as import_main;

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    // Combine multiple streams for a more robust PlaybackState
    _player.playbackEventStream.listen((_) => _updatePlaybackState());
    _player.playerStateStream.listen((_) => _updatePlaybackState());
    _player.positionStream.listen((_) => _updatePlaybackState());
    _player.bufferedPositionStream.listen((_) => _updatePlaybackState());
    _player.speedStream.listen((_) => _updatePlaybackState());
  }

  void _updatePlaybackState() {
    playbackState.add(_transformEvent(null));
  }

  PlaybackState _transformEvent(PlaybackEvent? event) {
    // Map just_audio state to audio_service state
    final playing = _player.playing;
    final processingState = _player.processingState;

    AudioProcessingState audioProcessingState;
    switch (processingState) {
      case ProcessingState.idle:
        audioProcessingState = AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        audioProcessingState = AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        audioProcessingState = AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        audioProcessingState = AudioProcessingState.ready;
        break;
      case ProcessingState.completed:
        audioProcessingState = AudioProcessingState.completed;
        break;
    }

    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.playPause,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: audioProcessingState,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: import_main.GlobalAudioService().currentlyPlaying ?? 0,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() async {
    await import_main.GlobalAudioService().playNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await import_main.GlobalAudioService().playPrevious();
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  // Method to set the file path and metadata
  Future<void> setAudioSource(String path, MediaItem item) async {
    try {
      await _player.setFilePath(path);

      // Wait for duration before publishing to queue/mediaItem so the system's
      // AudioMediaPlayerWrapper never sees a duration=0 mismatch (which breaks
      // media button dispatch from earphones).
      Duration? duration = _player.duration;
      duration ??= await _player.durationStream
          .firstWhere((d) => d != null, orElse: () => null)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      final finalItem = duration != null ? item.copyWith(duration: duration) : item;
      mediaItem.add(finalItem);
      queue.add([finalItem]);
    } catch (e) {
      // Fallback: publish item as-is so playback still works
      mediaItem.add(item);
      queue.add([item]);
      rethrow;
    }
  }

  AudioPlayer get player => _player;
}
