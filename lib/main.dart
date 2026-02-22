import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'package:audio_service/audio_service.dart';
import 'audio_handler.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';

// ─────────────────────────────────────────────
//  GLOBAL AUDIO SERVICE (Shared across all screens)
// ─────────────────────────────────────────────
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
        if (loopMode != LoopMode.one) {
          playNext();
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
    } catch (e) {
      // Error initializing Bluetooth monitoring
    }
  }

  Future<void> _resumeAfterBluetoothReconnect() async {
    try {
      if (songIndexBeforeDisconnect == null) return;

      final songPath = currentPlaylist[songIndexBeforeDisconnect!]['path']!;

      await audioPlayer.setFilePath(songPath);

      if (positionBeforeDisconnect != null) {
        await audioPlayer.seek(positionBeforeDisconnect!);
      }

      await audioPlayer.setVolume(1.0);

      await audioPlayer.play();

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
      final handler = await _audioHandler;

      if (currentlyPlaying == index) {
        if (isPlaying) {
          await handler.pause();
        } else {
          await handler.play();
        }
        return;
      }

      if (onIncrementPlayCount != null) {
        onIncrementPlayCount!(path);
      }

      currentlyPlaying = index;
      currentPosition = Duration.zero;
      notifyListeners();

      final song = currentPlaylist[index];
      final title = song['title'] ?? 'Unknown';

      await handler.setAudioSource(
        path,
        MediaItem(
          id: path,
          title: title,
          artist: song['artist'] ?? 'Unknown Artist',
          duration: totalDuration,
        ),
      );

      await handler.play();

      await handler.play();
    } catch (e) {
      // Error playing song
    }
  }

  void playNext() {
    if (currentPlaylist.isEmpty || currentlyPlaying == null) return;

    // With loopMode.off, stop only after the last song; otherwise advance
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
        nextIndex =
            (DateTime.now().millisecondsSinceEpoch +
                DateTime.now().microsecond) %
            currentPlaylist.length;
      } while (nextIndex == currentlyPlaying && currentPlaylist.length > 1);
    } else {
      nextIndex = (currentlyPlaying! + 1) % currentPlaylist.length;
    }

    if (nextIndex < currentPlaylist.length) {
      playSong(currentPlaylist[nextIndex]['path']!, nextIndex);
    }
  }

  void playPrevious() {
    if (currentPlaylist.isEmpty || currentlyPlaying == null) return;

    if (currentPosition.inSeconds > 3) {
      if (isReady) audioPlayer.seek(Duration.zero);
      return;
    }

    int prevIndex;
    if (isShuffleOn) {
      do {
        prevIndex =
            (DateTime.now().millisecondsSinceEpoch +
                DateTime.now().microsecond) %
            currentPlaylist.length;
      } while (prevIndex == currentlyPlaying && currentPlaylist.length > 1);
    } else {
      prevIndex =
          (currentlyPlaying! - 1 + currentPlaylist.length) %
          currentPlaylist.length;
    }

    if (prevIndex < currentPlaylist.length) {
      playSong(currentPlaylist[prevIndex]['path']!, prevIndex);
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

    sleepTimer = Timer(duration, () {
      audioPlayer.stop();
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

// ─────────────────────────────────────────────
//  COLOR SCHEME (Moved up for clarity)
// ─────────────────────────────────────────────
class AppColors {
  // Purple shades
  static const Color purple = Color(0xFF9C27B0); // Deep Purple
  static const Color purpleLight = Color(0xFFBA68C8); // Light Purple
  static const Color purpleDark = Color(0xFF7B1FA2); // Dark Purple

  // Blue shades
  static const Color blue = Color(0xFF2196F3); // Blue
  static const Color blueLight = Color(0xFF64B5F6); // Light Blue
  static const Color blueDark = Color(0xFF1976D2); // Dark Blue

  // Accent colors
  static const Color accent = Color(0xFF00BCD4); // Cyan accent
  static const Color accentPink = Color(0xFFE91E63); // Pink accent

  // Backgrounds
  static const Color background = Colors.black;
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2A2A2A);

  // Gradients
  static LinearGradient get purpleBlueGradient => const LinearGradient(
    colors: [Color(0xFF9C27B0), Color(0xFF2196F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get bluePurpleGradient => const LinearGradient(
    colors: [Color(0xFF2196F3), Color(0xFF9C27B0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get lightGradient => const LinearGradient(
    colors: [Color(0xFFBA68C8), Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get darkGradient => const LinearGradient(
    colors: [Color(0xFF7B1FA2), Color(0xFF1976D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get accentGradient => const LinearGradient(
    colors: [Color(0xFFE91E63), Color(0xFF00BCD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Start the app immediately to avoid launch freeze
    runApp(const MyApp());

    // Initialize audio services in the background
    _initializeAudioServices();
  } catch (_) {
    // Silently handle startup errors
  }
}

Future<void> _initializeAudioServices() async {
  try {
    final audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.jezsic.music.playback',
        androidNotificationChannelName: 'Music Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'drawable/ic_music_notification',
        androidShowNotificationBadge: true,
      ),
    );

    await GlobalAudioService().initialize(audioHandler);
  } catch (_) {
    // Silently handle initialization errors
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jezsic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: AppColors.purple,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: AppColors.purple,
          secondary: AppColors.blue,
          surface: AppColors.surface,
        ),
      ),
      home: const LoadingScreen(),
    );
  }
}

// ── SPLASH SCREEN ──
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  // Vinyl spin
  late AnimationController _vinylController;
  // Glow pulse
  late AnimationController _glowController;
  late Animation<double> _glowAnim;
  // Text fade-in
  late AnimationController _textController;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;
  // Sound wave bars
  late AnimationController _waveController;
  // Exit scale
  late AnimationController _exitController;
  late Animation<double> _exitScale;

  static const int _barCount = 5;
  final List<double> _barPhases = List.generate(
    _barCount,
    (i) => i * (math.pi * 2 / _barCount),
  );

  @override
  void initState() {
    super.initState();

    // Vinyl record continuously spins
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Glow ring pulses in/out
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Sound wave bars animate
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Staggered text fade in
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // Exit animation (scale up + fade out)
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitScale = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeIn));

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Small delay before text appears
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _textController.forward();

    // Hold on screen (Reduced from 2200ms)
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    // WAIT for audio service to be ready before proceeding
    int timeout = 0;
    while (!GlobalAudioService().isReady && timeout < 5) {
      await Future.delayed(const Duration(milliseconds: 200));
      timeout++;
    }

    // Play exit animation
    _exitController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _vinylController.dispose();
    _glowController.dispose();
    _waveController.dispose();
    _textController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _vinylController,
          _glowAnim,
          _waveController,
          _titleFade,
          _subtitleFade,
          _exitController,
        ]),
        builder: (context, _) {
          final exitFade = 1.0 - _exitController.value;
          return Opacity(
            opacity: exitFade.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _exitScale.value,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Background radial gradient ──
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [const Color(0xFF2D0066), Colors.black],
                      ),
                    ),
                  ),

                  // ── Outer glow ring ──
                  Center(
                    child: Opacity(
                      opacity: _glowAnim.value * 0.35,
                      child: Container(
                        width: 260 * _glowAnim.value,
                        height: 260 * _glowAnim.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.shade400,
                              blurRadius: 72,
                              spreadRadius: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Vinyl record ──
                  Center(
                    child: GestureDetector(
                      onDoubleTap: () {},
                      child: Transform.rotate(
                        angle: _vinylController.value * 2 * math.pi,
                        child: CustomPaint(
                          size: const Size(180, 180),
                          painter: _VinylPainter(),
                        ),
                      ),
                    ),
                  ),

                  // ── Real app icon (centre, sits in vinyl label) ──
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.shade400.withValues(
                              alpha: 0.8,
                            ),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  // ── Sound wave bars (below the record) ──
                  Positioned(
                    bottom: size.height * 0.30,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(_barCount, (i) {
                        final phase = _barPhases[i];
                        final t = _waveController.value;
                        final height =
                            12.0 +
                            28.0 * (0.5 + 0.5 * math.sin(t * math.pi + phase));
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: 7,
                            height: height,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.deepPurple.shade400,
                                  Colors.purpleAccent.shade100,
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // ── App name + tagline ──
                  Positioned(
                    bottom: size.height * 0.18,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Opacity(
                          opacity: _titleFade.value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - _titleFade.value)),
                            child: const Text(
                              'Jezsic',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF9C27B0),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: _subtitleFade.value,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - _subtitleFade.value)),
                            child: Text(
                              'Your music, your world',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.purple.shade200,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  VINYL RECORD PAINTER
// ─────────────────────────────────────────────
class _VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer disc (near black)
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1A1A1A));

    // Grooves
    final groovePaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double r = radius * 0.38; r < radius * 0.96; r += 5.5) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // Purple sheen band
    final sheenPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          AppColors.purple.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sheenPaint);

    // Inner label circle
    canvas.drawCircle(
      center,
      radius * 0.30,
      Paint()..color = const Color(0xFF0D0D0D),
    );

    // Tiny spindle hole
    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF333333));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<Map<String, String>> _songs = [];
  final Map<String, int> _playCount = {}; // Track play count for each song
  final Map<String, String> _lyrics =
      {}; // Store lyrics for each song (path -> lyrics)
  final List<Map<String, dynamic>> _playlists = [
    {'name': 'Favorites', 'songs': <String>[], 'isSystem': true},
    {'name': 'Workout', 'songs': <String>[]},
    {'name': 'Chill', 'songs': <String>[]},
  ];

  // Cache the screen widgets so they're not recreated on every build
  late final List<Widget> _screens;

  void _updateSongs(List<Map<String, String>> songs) {
    setState(() {
      _songs.clear();
      _songs.addAll(songs);
      // Re-sync the audio service playlist so it has the updated list
      // (currentPlaylist is the same reference as _songs, so it's already updated)
    });
  }

  void _incrementPlayCount(String songPath) {
    setState(() {
      _playCount[songPath] = (_playCount[songPath] ?? 0) + 1;
      _updateFavorites();
    });
  }

  void _updateFavorites() {
    // Get top 10 most played songs
    final sortedSongs = _playCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top10 = sortedSongs.take(10).map((e) => e.key).toList();

    // Update Favorites playlist (index 0)
    setState(() {
      _playlists[0]['songs'] = top10;
    });
  }

  void _addPlaylist(String name) {
    setState(() {
      _playlists.add({'name': name, 'songs': <String>[]});
    });
  }

  void _removePlaylist(int index) {
    setState(() {
      _playlists.removeAt(index);
    });
  }

  void _addSongToPlaylist(int playlistIndex, String songPath) {
    setState(() {
      final songs = _playlists[playlistIndex]['songs'] as List<String>;
      if (!songs.contains(songPath)) {
        songs.add(songPath);
      }
    });
  }

  void _removeSongFromPlaylist(int playlistIndex, String songPath) {
    setState(() {
      final songs = _playlists[playlistIndex]['songs'] as List<String>;
      songs.remove(songPath);
    });
  }

  void _saveLyrics(String songPath, String lyrics) {
    setState(() {
      _lyrics[songPath] = lyrics;
    });
    _saveLyricsToCache();
  }

  Future<void> _saveLyricsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lyricsJson = jsonEncode(_lyrics);
      await prefs.setString('cached_lyrics', lyricsJson);
    } catch (e) {
      // Error saving lyrics
    }
  }

  Future<void> _loadLyricsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lyricsJson = prefs.getString('cached_lyrics');
      if (lyricsJson != null && lyricsJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(lyricsJson);
        setState(() {
          _lyrics.clear();
          decoded.forEach((key, value) {
            _lyrics[key] = value.toString();
          });
        });
      }
    } catch (e) {
      // Error loading lyrics
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLyricsFromCache();

    // Create screens once and cache them
    _screens = [
      AllSongsScreen(
        songs: _songs,
        onUpdateSongs: _updateSongs,
        playlists: _playlists,
        onAddSongToPlaylist: _addSongToPlaylist,
        onIncrementPlayCount: _incrementPlayCount,
        playCount: _playCount,
        lyrics: _lyrics,
        onSaveLyrics: _saveLyrics,
      ),
      PlaylistScreen(
        playlists: _playlists,
        allSongs: _songs,
        onAddPlaylist: _addPlaylist,
        onRemovePlaylist: _removePlaylist,
        onAddSongToPlaylist: _addSongToPlaylist,
        onRemoveSongFromPlaylist: _removeSongFromPlaylist,
        playCount: _playCount,
      ),
      BrowseSongsScreen(
        onSongDownloaded: () {
          // Refresh the song list when a new song is downloaded
          setState(() {});
        },
      ),
    ];

    // Create screens once and cache them
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _screens),
          ),
          // Global mini player - shows on all tabs
          const GlobalMiniPlayer(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.grey.shade900,
        selectedItemColor: AppColors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'All Songs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.playlist_play),
            label: 'Playlists',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_download),
            label: 'Browse',
          ),
        ],
      ),
    );
  }
}

class AllSongsScreen extends StatefulWidget {
  final List<Map<String, String>> songs;
  final Function(List<Map<String, String>>) onUpdateSongs;
  final List<Map<String, dynamic>> playlists;
  final Function(int, String) onAddSongToPlaylist;
  final Function(String) onIncrementPlayCount;
  final Map<String, int> playCount;
  final Map<String, String> lyrics;
  final Function(String, String) onSaveLyrics;

  const AllSongsScreen({
    super.key,
    required this.songs,
    required this.onUpdateSongs,
    required this.playlists,
    required this.onAddSongToPlaylist,
    required this.onIncrementPlayCount,
    required this.playCount,
    required this.lyrics,
    required this.onSaveLyrics,
  });

  @override
  State<AllSongsScreen> createState() => _AllSongsScreenState();
}

class _AllSongsScreenState extends State<AllSongsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep this widget alive

  final GlobalAudioService _audioService = GlobalAudioService();

  final TextEditingController _searchController = TextEditingController();
  bool _hasPermission = false;
  bool _isLoading = false;
  String _searchQuery = '';

  static const String _cachedSongsKey = 'cached_songs_list';
  static const String _lastScanTimeKey = 'last_scan_time';

  @override
  @override
  void initState() {
    super.initState();

    // Only set the callback, NOT the playlist
    _audioService.onIncrementPlayCount = widget.onIncrementPlayCount;

    // Listen to audio service changes
    _audioService.addListener(_onAudioServiceUpdate);

    // DEFER loading to avoid blocking transition animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedSongsOrScan();
    });
  }

  void _onAudioServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  // Load cached songs or scan if no cache exists
  Future<void> _loadCachedSongsOrScan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedSongsJson = prefs.getString(_cachedSongsKey);

      if (cachedSongsJson != null && cachedSongsJson.isNotEmpty) {
        // Load from cache
        final List<dynamic> decoded = jsonDecode(cachedSongsJson);
        final cachedSongs = decoded
            .map((item) => Map<String, String>.from(item as Map))
            .toList();

        // Sort songs by modification date (newest first)
        cachedSongs.sort((a, b) {
          int dateA = int.tryParse(a['modifiedDate'] ?? '0') ?? 0;
          int dateB = int.tryParse(b['modifiedDate'] ?? '0') ?? 0;
          return dateB.compareTo(dateA); // Descending order (newest first)
        });

        widget.onUpdateSongs(cachedSongs);

        setState(() {
          _hasPermission = true;
          _isLoading = false;
        });
      } else {
        // No cache, scan for songs
        await _requestPermissionAndScan();
      }
    } catch (e) {
      // Error loading cached songs
      await _requestPermissionAndScan();
    }
  }

  // Save songs to cache
  Future<void> _saveSongsToCache(List<Map<String, String>> songs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = jsonEncode(songs);
      await prefs.setString(_cachedSongsKey, songsJson);
      await prefs.setInt(
        _lastScanTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // Error saving songs to cache
    }
  }

  // Clear cache (for debugging or manual reset)
  // ignore: unused_element
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedSongsKey);
      await prefs.remove(_lastScanTimeKey);
    } catch (e) {
      // Error clearing cache
    }
  }

  Future<void> _requestPermissionAndScan() async {
    setState(() {
      _isLoading = true;
    });

    // Request notification permission for Android 13+ (for media controls)
    if (Platform.isAndroid) {
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }
    }

    // Request storage permission
    PermissionStatus status;

    if (await Permission.storage.isGranted) {
      status = PermissionStatus.granted;
    } else if (await Permission.audio.isGranted) {
      status = PermissionStatus.granted;
    } else if (await Permission.manageExternalStorage.isGranted) {
      status = PermissionStatus.granted;
    } else {
      // Try requesting permissions
      status = await Permission.storage.request();
      if (!status.isGranted) {
        status = await Permission.audio.request();
      }
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
    }

    setState(() {
      _hasPermission = status.isGranted;
    });

    if (_hasPermission) {
      await _scanForMusicFiles();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _scanForMusicFiles() async {
    try {
      List<Map<String, String>> foundSongs = [];
      Set<String> addedPaths = {}; // Track added files to avoid duplicates

      // Common music directories on Android
      List<String> musicPaths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
      ];

      for (String path in musicPaths) {
        Directory dir = Directory(path);
        if (await dir.exists()) {
          await _scanDirectory(dir, foundSongs, addedPaths);
        }
      }

      widget.onUpdateSongs(foundSongs);

      // Sort songs by modification date (newest first)
      foundSongs.sort((a, b) {
        int dateA = int.tryParse(a['modifiedDate'] ?? '0') ?? 0;
        int dateB = int.tryParse(b['modifiedDate'] ?? '0') ?? 0;
        return dateB.compareTo(dateA); // Descending order (newest first)
      });

      widget.onUpdateSongs(foundSongs);

      // Save to cache after scanning
      await _saveSongsToCache(foundSongs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${foundSongs.length} songs'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Error scanning files
    }
  }

  Future<void> _scanDirectory(
    Directory dir,
    List<Map<String, String>> songs,
    Set<String> addedPaths,
  ) async {
    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          String path = entity.path.toLowerCase();
          if (path.endsWith('.mp3') ||
              path.endsWith('.m4a') ||
              path.endsWith('.wav')) {
            // Skip if already added
            if (addedPaths.contains(entity.path)) {
              continue;
            }

            String fileName = entity.path.split('/').last;
            String title = fileName.replaceAll(
              RegExp(r'\.(mp3|m4a|wav)$', caseSensitive: false),
              '',
            );

            // Get file duration using a separate audio player
            String duration = '0:00';
            try {
              final tempPlayer = AudioPlayer();
              final audioDuration = await tempPlayer.setFilePath(entity.path);
              if (audioDuration != null) {
                final minutes = audioDuration.inMinutes;
                final seconds = audioDuration.inSeconds % 60;
                duration = '$minutes:${seconds.toString().padLeft(2, '0')}';
              }
              await tempPlayer.dispose();
            } catch (e) {
              // Error getting duration
            }

            // Get file modification date
            FileStat fileStat = await entity.stat();
            String modifiedDate = fileStat.modified.millisecondsSinceEpoch
                .toString();

            songs.add({
              'title': title,
              'artist': 'Unknown Artist',
              'path': entity.path,
              'duration': duration,
              'modifiedDate': modifiedDate,
            });

            addedPaths.add(entity.path);
          }
        }
      }
    } catch (e) {
      // Error scanning directory
    }
  }

  Future<void> _playSong(String path, int index) async {
    // Set the playlist as a COPY so clearing _songs doesn't interrupt playback
    _audioService.currentPlaylist = List.from(widget.songs);

    await _audioService.playSong(path, index);
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Sleep Timer', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_audioService.sleepTimer != null) ...[
              Text(
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
                  if (_audioService.sleepEndTime == null) {
                    return const Text(
                      '--:--',
                      style: TextStyle(color: Colors.white),
                    );
                  }
                  final remaining = _audioService.sleepEndTime!.difference(
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
                  _audioService.cancelSleepTimer();
                  Navigator.pop(context);
                  setState(() {});
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
                  _audioService.setSleepTimer(const Duration(minutes: 15));
                  Navigator.pop(context);
                  setState(() {});
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
                  _audioService.setSleepTimer(const Duration(minutes: 30));
                  Navigator.pop(context);
                  setState(() {});
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
                  _audioService.setSleepTimer(const Duration(minutes: 45));
                  Navigator.pop(context);
                  setState(() {});
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
                  _audioService.setSleepTimer(const Duration(hours: 1));
                  Navigator.pop(context);
                  setState(() {});
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

  void _showAddToPlaylistDialog(String songPath, String songTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Add to Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: widget.playlists.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No playlists available. Create one first!',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = widget.playlists[index];
                    final songs = playlist['songs'] as List<String>;
                    final isAdded = songs.contains(songPath);

                    return ListTile(
                      leading: Icon(
                        Icons.playlist_play,
                        color: isAdded ? AppColors.purple : Colors.grey,
                      ),
                      title: Text(
                        playlist['name'],
                        style: TextStyle(
                          color: isAdded ? AppColors.purple : Colors.white,
                        ),
                      ),
                      trailing: Icon(
                        isAdded ? Icons.check : Icons.add,
                        color: isAdded ? AppColors.purple : Colors.grey,
                      ),
                      onTap: () {
                        if (!isAdded) {
                          widget.onAddSongToPlaylist(index, songPath);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added to ${playlist['name']}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.purple),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteSongConfirmation(
    String songPath,
    String songTitle,
    int index,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Delete Song', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to permanently delete "$songTitle"? This cannot be undone.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final file = File(songPath);
                if (await file.exists()) {
                  await file.delete();

                  // Remove from song list
                  setState(() {
                    widget.songs.removeAt(index);
                    if (_audioService.currentlyPlaying == index) {
                      _audioService.audioPlayer.stop();
                      _audioService.currentlyPlaying = null;
                      _audioService.notifyListeners();
                    } else if (_audioService.currentlyPlaying != null &&
                        _audioService.currentlyPlaying! > index) {
                      _audioService.currentlyPlaying =
                          _audioService.currentlyPlaying! - 1;
                      _audioService.notifyListeners();
                    }
                  });

                  // Update cache after deletion
                  await _saveSongsToCache(widget.songs);

                  if (mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Deleted $songTitle'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('File not found'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting file: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLyricsDialog(String songPath, String songTitle) {
    final TextEditingController lyricsController = TextEditingController(
      text: widget.lyrics[songPath] ?? '',
    );
    final bool hasLyrics = widget.lyrics.containsKey(songPath);

    showDialog(
      context: context,
      builder: (context) {
        // Get screen size for responsive layout
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
                  color: AppColors.purple.withValues(alpha: 0.3),
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
                              'Lyrics',
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
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: lyricsController,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 14 : 16,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Type or paste lyrics here...\n\n'
                            'Verse 1:\n'
                            'Your lyrics...\n\n'
                            'Chorus:\n'
                            'Your lyrics...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                        border: InputBorder.none,
                      ),
                      textAlignVertical: TextAlignVertical.top,
                    ),
                  ),
                ),
                // Action buttons - Responsive layout
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  child: isSmallScreen && hasLyrics
                      ? Column(
                          children: [
                            // Remove button (full width on small screens)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  widget.onSaveLyrics(songPath, '');
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Lyrics removed'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
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
                            // Save button (full width on small screens)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final lyrics = lyricsController.text.trim();
                                  if (lyrics.isNotEmpty) {
                                    widget.onSaveLyrics(songPath, lyrics);
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
                                label: const Text('Save Lyrics'),
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
                                  onPressed: () {
                                    widget.onSaveLyrics(songPath, '');
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Lyrics removed'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
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
                                  final lyrics = lyricsController.text.trim();
                                  if (lyrics.isNotEmpty) {
                                    widget.onSaveLyrics(songPath, lyrics);
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
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioServiceUpdate);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Filter songs based on search query
    final filteredSongs = widget.songs.where((song) {
      final title = song['title']?.toLowerCase() ?? '';
      final artist = song['artist']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || artist.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Songs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.timer,
              color: _audioService.sleepTimer != null
                  ? AppColors.purple
                  : Colors.white,
            ),
            onPressed: _showSleepTimerDialog,
            tooltip: 'Sleep Timer',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _requestPermissionAndScan,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search songs...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: !_hasPermission
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Storage permission required',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Allow access to scan music files',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _requestPermissionAndScan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.purple,
                          ),
                          child: const Text('Grant Permission'),
                        ),
                      ],
                    ),
                  )
                : _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.purple),
                        SizedBox(height: 16),
                        Text(
                          'Scanning for music files...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : filteredSongs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.music_note
                              : Icons.search_off,
                          size: 60,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No music files found'
                              : 'No songs match your search',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Add MP3 files to Music or Download folder'
                              : 'Try a different search term',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        if (_searchQuery.isEmpty) const SizedBox(height: 16),
                        if (_searchQuery.isEmpty)
                          ElevatedButton.icon(
                            onPressed: _requestPermissionAndScan,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Scan Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.purple,
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredSongs.length,
                    // Optimize: Fixed item height for smoother scrolling
                    itemExtent: 72.0,
                    // Optimize: Reduce memory usage
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      // Find the original index in widget.songs
                      final originalIndex = widget.songs.indexOf(song);
                      final isCurrentSong =
                          _audioService.currentlyPlaying == originalIndex;
                      final isPlaying =
                          isCurrentSong && _audioService.isPlaying;

                      return ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: AppColors.purpleBlueGradient,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.music_note,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          song['title']!,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song['artist']!,
                          style: const TextStyle(color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          color: Colors.grey.shade900,
                          onSelected: (value) {
                            if (value == 'add_to_playlist') {
                              _showAddToPlaylistDialog(
                                song['path']!,
                                song['title']!,
                              );
                            } else if (value == 'lyrics') {
                              _showLyricsDialog(song['path']!, song['title']!);
                            } else if (value == 'delete') {
                              _showDeleteSongConfirmation(
                                song['path']!,
                                song['title']!,
                                originalIndex,
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'add_to_playlist',
                              child: Row(
                                children: [
                                  Icon(Icons.playlist_add, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text(
                                    'Add to Playlist',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'lyrics',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lyrics,
                                    color:
                                        widget.lyrics.containsKey(song['path'])
                                        ? AppColors.blue
                                        : Colors.white,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    widget.lyrics.containsKey(song['path'])
                                        ? 'Edit Lyrics'
                                        : 'Add Lyrics',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_forever, color: Colors.red),
                                  SizedBox(width: 12),
                                  Text(
                                    'Delete Song',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _playSong(song['path']!, originalIndex),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  GLOBAL MINI PLAYER (Shows on all screens)
// ─────────────────────────────────────────────
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
                      position:
                          Tween<Offset>(
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
          color: Colors.grey.shade900,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
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
                    gradient: AppColors.bluePurpleGradient,
                  ),
                  child: Icon(
                    _audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSong['title'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
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
                inactiveColor: Colors.grey.shade800,
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
                  color: Colors.white,
                  onPressed:
                      _audioService.currentPlaylist.isNotEmpty &&
                          _audioService.currentlyPlaying != null
                      ? () => _audioService.playPrevious()
                      : null,
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.purpleBlueGradient,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32,
                    ),
                    color: Colors.white,
                    onPressed:
                        _audioService.currentlyPlaying != null &&
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
                  color: Colors.white,
                  onPressed:
                      _audioService.currentPlaylist.isNotEmpty &&
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

// ─────────────────────────────────────────────
//  FULL-SCREEN NOW PLAYING / MEDIA PLAYER
// ─────────────────────────────────────────────
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
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
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
    final hasTrack =
        _audioService.currentlyPlaying != null &&
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
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0033), Color(0xFF000814)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Now Playing',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
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
                      color: Colors.grey.shade900,
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
                            gradient: const SweepGradient(
                              colors: [
                                Color(0xFF1A1A1A),
                                Color(0xFF2A2A2A),
                                Color(0xFF1A1A1A),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.purple.withValues(
                                  alpha: isPlaying ? 0.6 : 0.2,
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
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                );
                              }),
                              // Center label
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.purpleBlueGradient,
                                ),
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                  size: 36,
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
                        builder: (_, __) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(5, (i) {
                            final phase = i * 0.6;
                            final h =
                                6.0 +
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
                                  gradient: AppColors.purpleBlueGradient,
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
                      style: const TextStyle(
                        color: Colors.white,
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
                        inactiveTrackColor: Colors.grey.shade800,
                        thumbColor: Colors.white,
                        overlayColor: AppColors.blue.withValues(alpha: 0.2),
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
                      icon: const Icon(
                        Icons.skip_previous,
                        color: Colors.white,
                        size: 38,
                      ),
                      onPressed: hasTrack
                          ? () => _audioService.playPrevious()
                          : null,
                    ),
                    // Play / Pause (big)
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.purpleBlueGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.purple.withValues(alpha: 0.5),
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
                      icon: const Icon(
                        Icons.skip_next,
                        color: Colors.white,
                        size: 38,
                      ),
                      onPressed: hasTrack
                          ? () => _audioService.playNext()
                          : null,
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

class PlaylistScreen extends StatelessWidget {
  final List<Map<String, dynamic>> playlists;
  final List<Map<String, String>> allSongs;
  final Function(String) onAddPlaylist;
  final Function(int) onRemovePlaylist;
  final Function(int, String) onAddSongToPlaylist;
  final Function(int, String) onRemoveSongFromPlaylist;
  final Map<String, int> playCount;

  const PlaylistScreen({
    super.key,
    required this.playlists,
    required this.allSongs,
    required this.onAddPlaylist,
    required this.onRemovePlaylist,
    required this.onAddSongToPlaylist,
    required this.onRemoveSongFromPlaylist,
    required this.playCount,
  });

  void _showAddPlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'New Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.purple),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.purple),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onAddPlaylist(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Create',
              style: TextStyle(color: AppColors.purple),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Delete Playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${playlists[index]['name']}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              onRemovePlaylist(index);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPlaylistDialog(context),
          ),
        ],
      ),
      body: playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.playlist_play, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No playlists yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPlaylistDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Playlist'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                final songCount = (playlist['songs'] as List).length;
                final isSystemPlaylist = playlist['isSystem'] == true;

                return ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: isSystemPlaylist
                          ? AppColors.accentGradient
                          : AppColors.purpleBlueGradient,
                    ),
                    child: Icon(
                      isSystemPlaylist ? Icons.favorite : Icons.playlist_play,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    playlist['name'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '$songCount ${songCount == 1 ? 'song' : 'songs'}${isSystemPlaylist ? ' • Auto-updated' : ''}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: isSystemPlaylist
                      ? null
                      : PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          color: Colors.grey.shade900,
                          onSelected: (value) {
                            if (value == 'delete') {
                              _showDeleteConfirmation(context, index);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 12),
                                  Text(
                                    'Delete Playlist',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlaylistDetailScreen(
                          playlistName: playlist['name'],
                          playlistIndex: index,
                          songPaths: List<String>.from(playlist['songs']),
                          allSongs: allSongs,
                          onAddSong: (songPath) =>
                              onAddSongToPlaylist(index, songPath),
                          onRemoveSong: (songPath) =>
                              onRemoveSongFromPlaylist(index, songPath),
                          isSystemPlaylist: isSystemPlaylist,
                          playCount: playCount,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistName;
  final int playlistIndex;
  final List<String> songPaths;
  final List<Map<String, String>> allSongs;
  final Function(String) onAddSong;
  final Function(String) onRemoveSong;
  final bool isSystemPlaylist;
  final Map<String, int> playCount;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistName,
    required this.playlistIndex,
    required this.songPaths,
    required this.allSongs,
    required this.onAddSong,
    required this.onRemoveSong,
    this.isSystemPlaylist = false,
    required this.playCount,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep this widget alive

  final GlobalAudioService _audioService = GlobalAudioService();

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_onAudioServiceUpdate);
  }

  void _onAudioServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioServiceUpdate);
    super.dispose();
  }

  Future<void> _playSong(String path, int index) async {
    // Update the global service's playlist to this playlist's songs
    final playlistSongs = widget.allSongs
        .where((song) => widget.songPaths.contains(song['path']))
        .toList();
    _audioService.currentPlaylist = playlistSongs;

    await _audioService.playSong(path, index);
  }

  void _showAddSongsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Add Songs', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: widget.allSongs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No songs available',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.allSongs.length,
                  itemBuilder: (context, index) {
                    final song = widget.allSongs[index];
                    final isAdded = widget.songPaths.contains(song['path']);

                    return ListTile(
                      leading: Icon(
                        Icons.music_note,
                        color: isAdded ? AppColors.purple : Colors.grey,
                      ),
                      title: Text(
                        song['title']!,
                        style: TextStyle(
                          color: isAdded ? AppColors.purple : Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        isAdded ? Icons.check : Icons.add,
                        color: isAdded ? AppColors.purple : Colors.grey,
                      ),
                      onTap: () {
                        if (!isAdded) {
                          widget.onAddSong(song['path']!);
                          Navigator.pop(context);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${song['title']}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.purple),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final playlistSongs = widget.allSongs
        .where((song) => widget.songPaths.contains(song['path']))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: widget.isSystemPlaylist
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showAddSongsDialog,
                ),
              ],
      ),
      body: playlistSongs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_note, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    widget.isSystemPlaylist
                        ? 'Play songs to add them to Favorites'
                        : 'No songs in this playlist',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (!widget.isSystemPlaylist) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showAddSongsDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Songs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : ListView.builder(
              itemCount: playlistSongs.length,
              itemBuilder: (context, index) {
                final song = playlistSongs[index];
                // Check if this song is currently playing in the global service
                final songPath = song['path']!;
                final globalIndex = _audioService.currentPlaylist.indexWhere(
                  (s) => s['path'] == songPath,
                );
                final isCurrentSong =
                    globalIndex != -1 &&
                    _audioService.currentlyPlaying == globalIndex;
                final isPlaying = isCurrentSong && _audioService.isPlaying;

                return ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: AppColors.bluePurpleGradient,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.music_note,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    song['title']!,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    song['artist']!,
                    style: const TextStyle(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: widget.isSystemPlaylist
                      ? Text(
                          '${widget.playCount[song['path']] ?? 0} plays',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        )
                      : PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          color: Colors.grey.shade900,
                          onSelected: (value) {
                            if (value == 'remove') {
                              widget.onRemoveSong(song['path']!);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Removed ${song['title']}'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.remove_circle, color: Colors.red),
                                  SizedBox(width: 12),
                                  Text(
                                    'Remove from Playlist',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  onTap: () => _playSong(song['path']!, index),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────
//  BROWSE SONGS SCREEN (YouTube Search & Download)
// ─────────────────────────────────────────────
class BrowseSongsScreen extends StatefulWidget {
  final VoidCallback onSongDownloaded;

  const BrowseSongsScreen({super.key, required this.onSongDownloaded});

  @override
  State<BrowseSongsScreen> createState() => _BrowseSongsScreenState();
}

class _BrowseSongsScreenState extends State<BrowseSongsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();

  List<Video> _searchResults = [];
  bool _isSearching = false;
  bool _isDownloading = false;
  String _downloadingVideoId = '';
  String _downloadingVideoTitle = '';
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;

  // HTTP client for cancellable requests
  http.Client? _downloadClient;

  // API URL - Railway Production
  static const String apiUrl =
      'https://youtube-mp3-api-production.up.railway.app';

  @override
  void dispose() {
    _searchController.dispose();
    _yt.close();
    _downloadClient?.close();
    super.dispose();
  }

  Future<void> _searchYouTube(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final searchResults = await _yt.search.search(query);
      final videos = searchResults.take(20).toList();

      setState(() {
        _searchResults = videos;
        _isSearching = false;
      });
    } catch (e) {
      // Search failed
      setState(() {
        _isSearching = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  Future<void> _downloadFromAPI(Video video) async {
    if (_isDownloading) {
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadingVideoId = video.id.value;
      _downloadingVideoTitle = video.title;
      _downloadProgress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = 0;
    });

    // Create a new HTTP client for this download
    _downloadClient = http.Client();

    try {
      final videoUrl = 'https://www.youtube.com/watch?v=${video.id.value}';

      // Make request to your API with streaming
      final request = http.Request('POST', Uri.parse('$apiUrl/api/download'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'url': videoUrl});

      final streamedResponse = await _downloadClient!.send(request);

      if (streamedResponse.statusCode == 200) {
        // Get total size if available
        final contentLength = streamedResponse.contentLength ?? 0;

        // Collect bytes and track progress
        final List<int> bytes = [];
        int lastUpdateBytes = 0;
        int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;

        await for (var chunk in streamedResponse.stream) {
          // Check if download was cancelled
          if (!_isDownloading) {
            throw Exception('Download cancelled');
          }

          bytes.addAll(chunk);

          // Optimize: Update UI every 100KB OR every 200ms (whichever comes first)
          final now = DateTime.now().millisecondsSinceEpoch;
          final timeSinceUpdate = now - lastUpdateTime;
          final bytesSinceUpdate = bytes.length - lastUpdateBytes;

          if (bytesSinceUpdate > 102400 ||
              timeSinceUpdate > 200 ||
              contentLength == 0) {
            lastUpdateBytes = bytes.length;
            lastUpdateTime = now;

            setState(() {
              _downloadedBytes = bytes.length;
              _totalBytes = contentLength > 0 ? contentLength : bytes.length;
              if (_totalBytes > 0) {
                _downloadProgress = _downloadedBytes / _totalBytes;
              }
            });

            // Progress update happens in UI via setState
          }
        }

        // Final update
        setState(() {
          _downloadedBytes = bytes.length;
          _totalBytes = bytes.length;
          _downloadProgress = 1.0;
        });

        // Save the MP3 file
        final directory = Directory('/storage/emulated/0/Music');
        await directory.create(recursive: true);

        final fileName = _sanitizeFileName(video.title);
        final file = File('${directory.path}/$fileName.mp3');

        await file.writeAsBytes(bytes);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Downloaded: ${video.title}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Notify parent to refresh song list
        widget.onSongDownloaded();
      } else {
        throw Exception('API Error: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      if (mounted && _isDownloading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('cancelled')
                  ? 'Download cancelled'
                  : 'Download failed: $e',
            ),
            backgroundColor: e.toString().contains('cancelled')
                ? Colors.orange
                : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // Always reset state, even if there's an error
      _downloadClient?.close();
      _downloadClient = null;

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingVideoId = '';
          _downloadingVideoTitle = '';
          _downloadProgress = 0.0;
          _downloadedBytes = 0;
          _totalBytes = 0;
        });
      }
    }
  }

  void _cancelDownload() {
    if (_isDownloading) {
      setState(() {
        _isDownloading = false;
      });
      _downloadClient?.close();
      _downloadClient = null;
    }
  }

  String _sanitizeFileName(String fileName) {
    // Remove invalid characters for file names
    return fileName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Songs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search YouTube...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: _searchYouTube,
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),

          // Search results
          Expanded(
            child: _isSearching
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.purple),
                        SizedBox(height: 16),
                        Text(
                          'Searching YouTube...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 60,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Search for songs on YouTube',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Downloads will be saved to Music folder',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    // Optimize: Fixed item height for smoother scrolling
                    itemExtent: 88.0,
                    // Optimize: Reduce memory usage
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemBuilder: (context, index) {
                      final video = _searchResults[index];
                      final isDownloading =
                          _downloadingVideoId == video.id.value;

                      return ListTile(
                        leading: Container(
                          width: 80,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: video.thumbnails.mediumResUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(
                                      video.thumbnails.mediumResUrl,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.grey.shade800,
                          ),
                          child: video.thumbnails.mediumResUrl.isEmpty
                              ? const Icon(Icons.music_note, color: Colors.grey)
                              : null,
                        ),
                        title: Text(
                          video.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${video.author} • ${_formatDuration(video.duration)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isDownloading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.purple,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.download,
                                  color: AppColors.purple,
                                ),
                                onPressed: _isDownloading
                                    ? null
                                    : () => _downloadFromAPI(video),
                              ),
                      );
                    },
                  ),
          ),

          // Download progress indicator
          if (_isDownloading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title and cancel button
                  Row(
                    children: [
                      const Icon(
                        Icons.download,
                        color: AppColors.purple,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _downloadingVideoTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _downloadProgress > 0
                                  ? '${(_downloadProgress * 100).toStringAsFixed(1)}% complete'
                                  : 'Starting download...',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: _cancelDownload,
                        tooltip: 'Cancel download',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      backgroundColor: Colors.grey.shade800,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.blue,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _downloadProgress > 0
                            ? '${(_downloadProgress * 100).toStringAsFixed(1)}%'
                            : 'Starting...',
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Converting to MP3...',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
