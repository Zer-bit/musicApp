import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

import 'package:audio_service/audio_service.dart';
import 'dart:async';
import '../../src/rust/api/playback.dart' as rust_playback;

import '../audio_handler.dart';

class GlobalAudioService {
  static final GlobalAudioService _instance = GlobalAudioService._internal();
  factory GlobalAudioService() => _instance;
  GlobalAudioService._internal();

  final Completer<MyAudioHandler> _handlerCompleter =
      Completer<MyAudioHandler>();
  Future<MyAudioHandler> get _audioHandler => _handlerCompleter.future;

  // AudioPlayer proxy for convenience - but must be used carefully
  // Better to use _audioHandler.then((h) => h.player)
  AudioPlayer? _player;
  AudioPlayer get audioPlayer => _player!;

  bool get isReady => _handlerCompleter.isCompleted;

  int? currentlyPlaying;
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;
  bool isShuffleOn = false;
  LoopMode loopMode = LoopMode.all;

  List<Map<String, String>> currentPlaylist = [];
  Function(String)? onIncrementPlayCount;

  // Sleep timer
  Timer? sleepTimer;
  DateTime? sleepEndTime;



  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  Future<void> initialize(MyAudioHandler handler) async {
    _player = handler.player;
    _handlerCompleter.complete(handler);

    handler.mediaItem.listen((item) {
      if (item != null) {
        final index = currentPlaylist.indexWhere((song) => song['path'] == item.id);
        if (index != -1 && currentlyPlaying != index) {
          currentlyPlaying = index;
          notifyListeners();
        }
      }
    });

    await _initAudioSession();

    audioPlayer.playerStateStream.listen((state) {
      isPlaying = state.playing;
      notifyListeners();
    });

    audioPlayer.positionStream
        .where((position) => position.inMilliseconds % 500 < 100)
        .listen((position) {
      currentPosition = position;
      notifyListeners();
    });

    audioPlayer.durationStream.listen((duration) {
      totalDuration = duration ?? Duration.zero;
      notifyListeners();
    });

    audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // LoopMode.one is handled by just_audio itself (player loops).
        // LoopMode.all / LoopMode.off: advance to next song via the handler
        // so the media notification stays in sync.
        if (loopMode != LoopMode.one) {
          _audioHandler.then((h) => h.skipToNext());
        }
      }
    });
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.becomingNoisyEventStream.listen((_) {
        audioPlayer.pause();
      });
    } catch (e) {
      // Error configuring audio session
    }
  }



  Future<void> playSong(String path, int index) async {
    try {
      // Use a timeout so a broken/uninitialized handler never hangs the UI
      // (which causes an ANR in release mode).
      final handler = await _audioHandler.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception(
          'Audio service not ready. Please restart the app.',
        ),
      );

      // Check if the requested song is already playing (by path)
      bool isSameSong = false;
      if (currentlyPlaying != null &&
          currentlyPlaying! < currentPlaylist.length) {
        if (currentPlaylist[currentlyPlaying!]['path'] == path) {
          isSameSong = true;
        }
      }

      if (isSameSong) {
        // Toggle based on actual player status to avoid sync issues
        if (audioPlayer.playing) {
          await handler.pause();
          isPlaying = false;
        } else {
          await handler.play();
          isPlaying = true;
        }
        // Sync index/ui in case it was called from a different playlist context
        if (currentlyPlaying != index) {
          currentlyPlaying = index;
          notifyListeners();
        }
        return;
      }

      if (onIncrementPlayCount != null) {
        onIncrementPlayCount!(path);
      }

      currentlyPlaying = index;
      currentPosition = Duration.zero;
      notifyListeners();

      if (index < 0 || index >= currentPlaylist.length) return;
      final song = currentPlaylist[index];
      final title = song['title'] ?? 'Unknown';

      await handler.setAudioSource(
        path,
        MediaItem(
          id: path,
          title: title,
          artist: song['artist'] ?? 'Unknown Artist',
          duration: null,
        ),
      );

      await handler.play();
    } catch (e) {
      // Error playing song
    }
  }

  Future<void> playNext() async {
    if (currentPlaylist.isEmpty || currentlyPlaying == null) return;

    String loopModeStr = 'off';
    if (loopMode == LoopMode.all) {
      loopModeStr = 'all';
    } else if (loopMode == LoopMode.one) {
      loopModeStr = 'one';
    }

    final result = rust_playback.nextSongIndex(
      currentIndex: currentlyPlaying!,
      playlistLength: currentPlaylist.length,
      isShuffle: isShuffleOn,
      loopMode: loopModeStr,
      timestampSeed: DateTime.now().millisecondsSinceEpoch,
    );

    if (result.found) {
      final path = currentPlaylist[result.index]['path'];
      if (path != null && path.isNotEmpty) {
        await playSong(path, result.index);
      }
    } else {
      if (isReady) audioPlayer.stop();
      isPlaying = false;
      currentlyPlaying = null;
      notifyListeners();
    }
  }

  Future<void> playPrevious() async {
    if (currentPlaylist.isEmpty || currentlyPlaying == null) return;

    final result = rust_playback.prevSongIndex(
      currentIndex: currentlyPlaying!,
      playlistLength: currentPlaylist.length,
      isShuffle: isShuffleOn,
      positionSeconds: currentPosition.inSeconds,
      timestampSeed: DateTime.now().millisecondsSinceEpoch,
    );

    if (result.found) {
      if (result.index == currentlyPlaying) {
        if (isReady) audioPlayer.seek(Duration.zero);
      } else {
        final path = currentPlaylist[result.index]['path'];
        if (path != null && path.isNotEmpty) {
          await playSong(path, result.index);
        }
      }
    }
  }

  void toggleShuffle() {
    isShuffleOn = !isShuffleOn;
    notifyListeners();
  }

  void toggleLoopMode() {
    switch (loopMode) {
      case LoopMode.off:
        loopMode = LoopMode.all;
        audioPlayer.setLoopMode(
            LoopMode.off); // all-songs loop is handled by playNext()
        break;
      case LoopMode.all:
        loopMode = LoopMode.one;
        audioPlayer.setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        loopMode = LoopMode.off;
        audioPlayer.setLoopMode(LoopMode.off);
        break;
    }
    notifyListeners();
  }

  void setSleepTimer(Duration duration) {
    sleepTimer?.cancel();

    sleepEndTime = DateTime.now().add(duration);

    sleepTimer = Timer(duration, () async {
      final handler = await _audioHandler;
      await handler.pause();
      // Force sync in case stream is slow
      isPlaying = false;
      sleepTimer = null;
      sleepEndTime = null;
      notifyListeners();
    });

    notifyListeners();
  }

  void cancelSleepTimer() {
    sleepTimer?.cancel();
    sleepTimer = null;
    sleepEndTime = null;
    notifyListeners();
  }

  void dispose() {
    _player?.dispose();
    sleepTimer?.cancel();
  }
}
