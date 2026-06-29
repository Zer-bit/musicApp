import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:async';

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

  // Bluetooth auto-resume
  StreamSubscription<BluetoothAdapterState>? bluetoothSubscription;
  bool wasPlayingBeforeDisconnect = false;
  int? songIndexBeforeDisconnect;
  Duration? positionBeforeDisconnect;

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

    _initBluetoothMonitoring();
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

  void _initBluetoothMonitoring() {
    try {
      // Watch adapter-level on/off (e.g. BT toggled off entirely)
      bluetoothSubscription = FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.off ||
            state == BluetoothAdapterState.unavailable) {
          if (isPlaying) {
            wasPlayingBeforeDisconnect = true;
            songIndexBeforeDisconnect = currentlyPlaying;
            positionBeforeDisconnect = currentPosition;
          }
        } else if (state == BluetoothAdapterState.on) {
          if (wasPlayingBeforeDisconnect &&
              songIndexBeforeDisconnect != null &&
              songIndexBeforeDisconnect! < currentPlaylist.length) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              _resumeAfterBluetoothReconnect();
            });
          }
        }
      });

      // Watch individual device connect/disconnect (earphone plug in/out)
      FlutterBluePlus.events.onConnectionStateChanged.listen((event) {
        if (event.connectionState == BluetoothConnectionState.disconnected) {
          // Earphone disconnected — save state so we can resume on reconnect
          if (isPlaying) {
            wasPlayingBeforeDisconnect = true;
            songIndexBeforeDisconnect = currentlyPlaying;
            positionBeforeDisconnect = currentPosition;
          }
        } else if (event.connectionState == BluetoothConnectionState.connected) {
          // Earphone reconnected — resume if we were playing before
          if (wasPlayingBeforeDisconnect &&
              songIndexBeforeDisconnect != null &&
              songIndexBeforeDisconnect! < currentPlaylist.length) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              _resumeAfterBluetoothReconnect();
            });
          }
        }
      });
    } catch (e) {
      // Error initializing Bluetooth monitoring
    }
  }

  Future<void> _resumeAfterBluetoothReconnect() async {
    try {
      if (songIndexBeforeDisconnect == null) return;

      final song = currentPlaylist[songIndexBeforeDisconnect!];
      final songPath = song['path']!;

      final handler = await _audioHandler.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Audio handler not ready'),
      );

      await handler.setAudioSource(
        songPath,
        MediaItem(
          id: songPath,
          title: song['title'] ?? 'Unknown',
          artist: song['artist'] ?? 'Unknown Artist',
          duration: null,
        ),
      );

      if (positionBeforeDisconnect != null) {
        await handler.seek(positionBeforeDisconnect!);
      }

      await handler.play();

      currentlyPlaying = songIndexBeforeDisconnect;
      isPlaying = true;
      notifyListeners();

      wasPlayingBeforeDisconnect = false;
      songIndexBeforeDisconnect = null;
      positionBeforeDisconnect = null;
    } catch (e) {
      wasPlayingBeforeDisconnect = false;
      songIndexBeforeDisconnect = null;
      positionBeforeDisconnect = null;
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

    if (loopMode == LoopMode.off &&
        currentlyPlaying == currentPlaylist.length - 1 &&
        !isShuffleOn) {
      if (isReady) audioPlayer.stop();
      isPlaying = false;
      currentlyPlaying = null;
      notifyListeners();
      return;
    }

    int nextIndex;
    if (isShuffleOn) {
      do {
        nextIndex = (DateTime.now().millisecondsSinceEpoch + DateTime.now().microsecond) % currentPlaylist.length;
      } while (nextIndex == currentlyPlaying && currentPlaylist.length > 1);
    } else {
      nextIndex = (currentlyPlaying! + 1) % currentPlaylist.length;
    }

    if (nextIndex >= 0 && nextIndex < currentPlaylist.length) {
      final path = currentPlaylist[nextIndex]['path'];
      if (path != null && path.isNotEmpty) {
        await playSong(path, nextIndex);
      }
    }
  }

  Future<void> playPrevious() async {
    if (currentPlaylist.isEmpty || currentlyPlaying == null) return;

    if (currentPosition.inSeconds > 3) {
      if (isReady) audioPlayer.seek(Duration.zero);
      return;
    }

    int prevIndex;
    if (isShuffleOn) {
      do {
        prevIndex = (DateTime.now().millisecondsSinceEpoch + DateTime.now().microsecond) % currentPlaylist.length;
      } while (prevIndex == currentlyPlaying && currentPlaylist.length > 1);
    } else {
      prevIndex = (currentlyPlaying! - 1 + currentPlaylist.length) % currentPlaylist.length;
    }

    if (prevIndex >= 0 && prevIndex < currentPlaylist.length) {
      final path = currentPlaylist[prevIndex]['path'];
      if (path != null && path.isNotEmpty) {
        await playSong(path, prevIndex);
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
        audioPlayer.setLoopMode(LoopMode.off); // all-songs loop is handled by playNext()
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
    bluetoothSubscription?.cancel();
  }
}
