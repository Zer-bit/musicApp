import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'main.dart' as importMain;

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
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: audioProcessingState,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: 0,
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
    importMain.GlobalAudioService().playNext();
  }

  @override
  Future<void> skipToPrevious() async {
    importMain.GlobalAudioService().playPrevious();
  }

  @override
  Future<void> updateMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }

  // Method to set the file path and metadata
  Future<void> setAudioSource(String path, MediaItem item) async {
    updateMediaItem(item);
    try {
      await _player.setFilePath(path);
    } catch (e) {
      rethrow;
    }
  }

  AudioPlayer get player => _player;
}
