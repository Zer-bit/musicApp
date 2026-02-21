import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';

// App Color Scheme - Blue & Purple Fusion
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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

// ─────────────────────────────────────────────
//  SPLASH SCREEN
// ─────────────────────────────────────────────
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

    // Hold on screen
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    // Play exit animation
    _exitController.forward();
    await Future.delayed(const Duration(milliseconds: 450));
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
                    child: Transform.rotate(
                      angle: _vinylController.value * 2 * math.pi,
                      child: CustomPaint(
                        size: const Size(180, 180),
                        painter: _VinylPainter(),
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
                            color: Colors.deepPurple.shade400.withOpacity(0.8),
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
          AppColors.purple.withOpacity(0.18),
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
  final Map<String, String> _lyrics = {}; // Store lyrics for each song (path -> lyrics)
  final List<Map<String, dynamic>> _playlists = [
    {'name': 'Favorites', 'songs': <String>[], 'isSystem': true},
    {'name': 'Workout', 'songs': <String>[]},
    {'name': 'Chill', 'songs': <String>[]},
  ];

  void _updateSongs(List<Map<String, String>> songs) {
    setState(() {
      _songs.clear();
      _songs.addAll(songs);
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
      print('Error saving lyrics: $e');
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
      print('Error loading lyrics: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLyricsFromCache();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
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

    return Scaffold(
      body: screens[_selectedIndex],
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

class _AllSongsScreenState extends State<AllSongsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();
  int? _currentlyPlaying;
  bool _hasPermission = false;
  bool _isLoading = false;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isShuffleOn = false;
  LoopMode _loopMode = LoopMode.off;
  String _searchQuery = '';
  double _volumeBoost = 1.0; // 1.0 = 100%, 1.5 = 150%, 2.0 = 200%
  
  // Sleep timer
  Timer? _sleepTimer;
  DateTime? _sleepEndTime;

  // Bluetooth auto-resume
  StreamSubscription<BluetoothAdapterState>? _bluetoothSubscription;
  bool _wasPlayingBeforeDisconnect = false;
  int? _songIndexBeforeDisconnect;
  Duration? _positionBeforeDisconnect;

  static const String _cachedSongsKey = 'cached_songs_list';
  static const String _lastScanTimeKey = 'last_scan_time';

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    
    // Optimize: Batch state updates and reduce frequency
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
    
    // Optimize: Only update position every 500ms instead of every frame
    _audioPlayer.positionStream
        .where((position) => position.inMilliseconds % 500 < 100)
        .listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
    
    _audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration ?? Duration.zero;
        });
      }
    });
    
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Only auto-play next if not in repeat-one mode
        if (_loopMode != LoopMode.one) {
          _playNext();
        }
      }
    });
    _loadCachedSongsOrScan();
    _initBluetoothMonitoring();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      // This enables better audio quality and loudness management
    } catch (e) {
      print('Error configuring audio session: $e');
    }
  }

  void _initBluetoothMonitoring() {
    try {
      _bluetoothSubscription = FlutterBluePlus.adapterState.listen((state) {
        print('Bluetooth state changed: $state');
        
        if (state == BluetoothAdapterState.off || state == BluetoothAdapterState.unavailable) {
          // Bluetooth disconnected
          if (_isPlaying) {
            print('Bluetooth disconnected while playing - saving state');
            _wasPlayingBeforeDisconnect = true;
            _songIndexBeforeDisconnect = _currentlyPlaying;
            _positionBeforeDisconnect = _currentPosition;
          }
        } else if (state == BluetoothAdapterState.on) {
          // Bluetooth reconnected
          if (_wasPlayingBeforeDisconnect && 
              _songIndexBeforeDisconnect != null && 
              _songIndexBeforeDisconnect! < widget.songs.length) {
            print('Bluetooth reconnected - resuming playback');
            
            // Wait a bit for Bluetooth audio to be ready
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                _resumeAfterBluetoothReconnect();
              }
            });
          }
        }
      });
    } catch (e) {
      print('Error initializing Bluetooth monitoring: $e');
    }
  }

  Future<void> _resumeAfterBluetoothReconnect() async {
    try {
      if (_songIndexBeforeDisconnect == null) return;
      
      final songPath = widget.songs[_songIndexBeforeDisconnect!]['path']!;
      
      print('Resuming song: $songPath at position: $_positionBeforeDisconnect');
      
      // Set the song
      await _audioPlayer.setFilePath(songPath);
      
      // Seek to previous position if available
      if (_positionBeforeDisconnect != null) {
        await _audioPlayer.seek(_positionBeforeDisconnect!);
      }
      
      // Apply volume boost
      double effectiveVolume = _volumeBoost;
      if (_volumeBoost > 1.0) {
        effectiveVolume = 1.0 + ((_volumeBoost - 1.0) * 0.85);
      }
      await _audioPlayer.setVolume(effectiveVolume);
      
      // Start playing
      await _audioPlayer.play();
      
      setState(() {
        _currentlyPlaying = _songIndexBeforeDisconnect;
        _isPlaying = true;
      });
      
      // Reset the saved state
      _wasPlayingBeforeDisconnect = false;
      _songIndexBeforeDisconnect = null;
      _positionBeforeDisconnect = null;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth reconnected - Resuming playback'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error resuming after Bluetooth reconnect: $e');
      _wasPlayingBeforeDisconnect = false;
      _songIndexBeforeDisconnect = null;
      _positionBeforeDisconnect = null;
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
        
        final lastScanTime = prefs.getInt(_lastScanTimeKey) ?? 0;
        final lastScanDate = DateTime.fromMillisecondsSinceEpoch(lastScanTime);
        
        print('Loaded ${cachedSongs.length} songs from cache (last scan: $lastScanDate)');
        
        setState(() {
          _hasPermission = true;
          _isLoading = false;
        });
      } else {
        // No cache, scan for songs
        await _requestPermissionAndScan();
      }
    } catch (e) {
      print('Error loading cached songs: $e');
      // If cache fails, scan for songs
      await _requestPermissionAndScan();
    }
  }

  // Save songs to cache
  Future<void> _saveSongsToCache(List<Map<String, String>> songs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = jsonEncode(songs);
      await prefs.setString(_cachedSongsKey, songsJson);
      await prefs.setInt(_lastScanTimeKey, DateTime.now().millisecondsSinceEpoch);
      print('Saved ${songs.length} songs to cache');
    } catch (e) {
      print('Error saving songs to cache: $e');
    }
  }

  // Clear cache (for debugging or manual reset)
  // ignore: unused_element
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedSongsKey);
      await prefs.remove(_lastScanTimeKey);
      print('Cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  Future<void> _requestPermissionAndScan() async {
    setState(() {
      _isLoading = true;
    });

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
      print('Error scanning files: $e');
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
              print('Error getting duration for ${entity.path}: $e');
            }

            // Get file modification date
            FileStat fileStat = await entity.stat();
            String modifiedDate = fileStat.modified.millisecondsSinceEpoch.toString();

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
      print('Error scanning directory ${dir.path}: $e');
    }
  }

  Future<void> _playSong(String path, int index) async {
    try {
      print('=== Attempting to play: $path ===');

      // If same song, toggle play/pause
      if (_currentlyPlaying == index) {
        if (_isPlaying) {
          print('Pausing...');
          await _audioPlayer.pause();
        } else {
          print('Resuming...');
          await _audioPlayer.play();
        }
        return;
      }

      // Increment play count for the new song
      widget.onIncrementPlayCount(path);

      // Play new song
      print('Stopping previous song...');
      await _audioPlayer.stop();

      // Update UI immediately
      setState(() {
        _currentlyPlaying = index;
        _currentPosition = Duration.zero;
      });

      print('Setting file path...');
      await _audioPlayer.setFilePath(path);

      // Apply volume boost with smart limiting to prevent distortion
      // Use a softer curve for higher volumes to reduce clipping
      double effectiveVolume = _volumeBoost;
      if (_volumeBoost > 1.0) {
        // Apply a compression curve: reduces the boost slightly at peaks
        // This helps prevent harsh clipping while maintaining loudness
        effectiveVolume = 1.0 + ((_volumeBoost - 1.0) * 0.85);
      }
      
      print('Setting volume boost to ${_volumeBoost * 100}% (effective: ${(effectiveVolume * 100).toInt()}%)...');
      await _audioPlayer.setVolume(effectiveVolume);

      // Enable audio session for better quality
      await _audioPlayer.setSpeed(1.0); // Ensure normal playback speed

      print('Starting playback...');
      await _audioPlayer.play();

      print('=== Playback started successfully ===');
      print('Audio output: ${_audioPlayer.audioSource}');
    } catch (e, stackTrace) {
      print('=== ERROR playing song ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot play: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _playNext() {
    if (widget.songs.isEmpty || _currentlyPlaying == null) return;

    // If loop mode is off, stop playback (don't auto-play next)
    if (_loopMode == LoopMode.off) {
      _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
      return;
    }

    // If we're at the last song and loop all is not on, stop
    if (_loopMode != LoopMode.all &&
        _currentlyPlaying == widget.songs.length - 1 &&
        !_isShuffleOn) {
      _audioPlayer.stop();
      setState(() {
        _currentlyPlaying = null;
      });
      return;
    }

    int nextIndex;
    if (_isShuffleOn) {
      // Generate random index different from current
      do {
        nextIndex =
            (DateTime.now().millisecondsSinceEpoch +
                DateTime.now().microsecond) %
            widget.songs.length;
      } while (nextIndex == _currentlyPlaying && widget.songs.length > 1);
    } else {
      nextIndex = (_currentlyPlaying! + 1) % widget.songs.length;
    }

    if (nextIndex < widget.songs.length) {
      _playSong(widget.songs[nextIndex]['path']!, nextIndex);
    }
  }

  void _playPrevious() {
    if (widget.songs.isEmpty || _currentlyPlaying == null) return;

    // If more than 3 seconds into song, restart it
    if (_currentPosition.inSeconds > 3) {
      _audioPlayer.seek(Duration.zero);
      return;
    }

    int prevIndex;
    if (_isShuffleOn) {
      // Generate random index different from current
      do {
        prevIndex =
            (DateTime.now().millisecondsSinceEpoch +
                DateTime.now().microsecond) %
            widget.songs.length;
      } while (prevIndex == _currentlyPlaying && widget.songs.length > 1);
    } else {
      prevIndex =
          (_currentlyPlaying! - 1 + widget.songs.length) % widget.songs.length;
    }

    if (prevIndex < widget.songs.length) {
      _playSong(widget.songs[prevIndex]['path']!, prevIndex);
    }
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffleOn = !_isShuffleOn;
    });
  }

  void _toggleLoopMode() {
    setState(() {
      switch (_loopMode) {
        case LoopMode.off:
          _loopMode = LoopMode.all;
          break;
        case LoopMode.all:
          _loopMode = LoopMode.one;
          _audioPlayer.setLoopMode(LoopMode.one);
          break;
        case LoopMode.one:
          _loopMode = LoopMode.off;
          _audioPlayer.setLoopMode(LoopMode.off);
          break;
      }
    });
  }

  IconData _getLoopIcon() {
    switch (_loopMode) {
      case LoopMode.off:
        return Icons.repeat;
      case LoopMode.all:
        return Icons.repeat;
      case LoopMode.one:
        return Icons.repeat_one;
    }
  }

  void _updateVolumeBoost(double value) {
    setState(() {
      _volumeBoost = value;
    });
    
    // Apply volume boost with smart limiting to prevent distortion
    double effectiveVolume = value;
    if (value > 1.0) {
      // Apply a compression curve for volumes above 100%
      // This reduces harsh clipping while maintaining perceived loudness
      effectiveVolume = 1.0 + ((value - 1.0) * 0.85);
    }
    
    _audioPlayer.setVolume(effectiveVolume);
  }

  String _getVolumeBoostLabel() {
    if (_volumeBoost == 1.0) return 'Normal';
    if (_volumeBoost == 1.5) return 'Boost';
    return 'Max Boost';
  }

  void _setSleepTimer(Duration duration) {
    // Cancel existing timer if any
    _sleepTimer?.cancel();
    
    setState(() {
      _sleepEndTime = DateTime.now().add(duration);
    });

    _sleepTimer = Timer(duration, () {
      // Stop the music when timer expires
      _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _sleepTimer = null;
        _sleepEndTime = null;
      });

      // Show notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sleep timer finished - Music stopped'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sleep timer set for ${_formatSleepDuration(duration)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    setState(() {
      _sleepTimer = null;
      _sleepEndTime = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sleep timer cancelled'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  String _formatSleepDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  String _getRemainingTime() {
    if (_sleepEndTime == null) return '';
    
    final remaining = _sleepEndTime!.difference(DateTime.now());
    if (remaining.isNegative) return '0m';
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Sleep Timer',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sleepTimer != null) ...[
              Text(
                'Timer active: ${_getRemainingTime()} remaining',
                style: const TextStyle(
                  color: AppColors.purple,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _cancelSleepTimer();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Cancel Timer'),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'Set timer duration:',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildTimerOption(context, '15 minutes', const Duration(minutes: 15)),
            const SizedBox(height: 8),
            _buildTimerOption(context, '30 minutes', const Duration(minutes: 30)),
            const SizedBox(height: 8),
            _buildTimerOption(context, '45 minutes', const Duration(minutes: 45)),
            const SizedBox(height: 8),
            _buildTimerOption(context, '1 hour', const Duration(hours: 1)),
            const SizedBox(height: 8),
            _buildTimerOption(context, '2 hours', const Duration(hours: 2)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerOption(BuildContext context, String label, Duration duration) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        _setSleepTimer(duration);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.purple,
        minimumSize: const Size(double.infinity, 48),
      ),
      child: Text(label),
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
                    if (_currentlyPlaying == index) {
                      _audioPlayer.stop();
                      _currentlyPlaying = null;
                    } else if (_currentlyPlaying != null &&
                        _currentlyPlaying! > index) {
                      _currentlyPlaying = _currentlyPlaying! - 1;
                    }
                  });

                  // Update cache after deletion
                  await _saveSongsToCache(widget.songs);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deleted $songTitle'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('File not found'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.purpleBlueGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lyrics, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lyrics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            songTitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
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
                    ),
                  ],
                ),
              ),
              // Lyrics editor
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type or paste lyrics here...\n\n'
                          'Verse 1:\n'
                          'Your lyrics...\n\n'
                          'Chorus:\n'
                          'Your lyrics...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),
              ),
              // Action buttons
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
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
                          icon: const Icon(Icons.delete_outline, size: 20),
                          label: const Text('Remove'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    if (hasLyrics) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
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
                                content: Text('Please enter some lyrics'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save, size: 20),
                        label: const Text('Save Lyrics'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    _sleepTimer?.cancel();
    _bluetoothSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Sleep Timer
          IconButton(
            icon: Icon(
              Icons.bedtime,
              color: _sleepTimer != null ? AppColors.purple : Colors.white,
            ),
            tooltip: _sleepTimer != null 
                ? 'Timer: ${_getRemainingTime()}'
                : 'Sleep Timer',
            onPressed: _showSleepTimerDialog,
          ),
          // Volume Boost
          PopupMenuButton<double>(
            icon: Icon(
              Icons.volume_up,
              color: _volumeBoost > 1.0 ? AppColors.purple : Colors.white,
            ),
            color: Colors.grey.shade900,
            offset: const Offset(0, 50),
            tooltip: _getVolumeBoostLabel(),
            onSelected: (value) {
              _updateVolumeBoost(value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 1.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '100% - Normal',
                      style: TextStyle(color: Colors.white),
                    ),
                    if (_volumeBoost == 1.0)
                      const Icon(Icons.check, color: AppColors.purple, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 1.5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '150% - Boost',
                      style: TextStyle(color: Colors.white),
                    ),
                    if (_volumeBoost == 1.5)
                      const Icon(Icons.check, color: AppColors.purple, size: 20),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 2.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '200% - Max Boost',
                      style: TextStyle(color: Colors.white),
                    ),
                    if (_volumeBoost == 2.0)
                      const Icon(Icons.check, color: AppColors.purple, size: 20),
                  ],
                ),
              ),
            ],
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
                          _searchQuery.isEmpty ? Icons.music_note : Icons.search_off,
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
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        if (_searchQuery.isEmpty)
                          const SizedBox(height: 16),
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
                      final isCurrentSong = _currentlyPlaying == originalIndex;
                      final isPlaying = isCurrentSong && _isPlaying;

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
                              _showLyricsDialog(
                                song['path']!,
                                song['title']!,
                              );
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
                                    color: widget.lyrics.containsKey(song['path'])
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
          // Mini player at bottom
          if (_currentlyPlaying != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
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
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentlyPlaying != null &&
                                      _currentlyPlaying! < widget.songs.length
                                  ? widget.songs[_currentlyPlaying!]['title']!
                                  : 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
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
                          color: _isShuffleOn ? AppColors.purple : Colors.grey,
                        ),
                        onPressed: _toggleShuffle,
                      ),
                      IconButton(
                        icon: Icon(
                          _getLoopIcon(),
                          color: _loopMode != LoopMode.off
                              ? AppColors.purple
                              : Colors.grey,
                        ),
                        onPressed: _toggleLoopMode,
                      ),
                      PopupMenuButton<double>(
                        icon: Icon(
                          Icons.volume_up,
                          color: _volumeBoost > 1.0 ? AppColors.purple : Colors.grey,
                        ),
                        color: Colors.grey.shade900,
                        offset: const Offset(0, -150),
                        tooltip: _getVolumeBoostLabel(),
                        onSelected: (value) {
                          _updateVolumeBoost(value);
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 1.0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '100% - Normal',
                                  style: TextStyle(color: Colors.white),
                                ),
                                if (_volumeBoost == 1.0)
                                  const Icon(Icons.check, color: AppColors.purple, size: 20),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 1.5,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '150% - Boost',
                                  style: TextStyle(color: Colors.white),
                                ),
                                if (_volumeBoost == 1.5)
                                  const Icon(Icons.check, color: AppColors.purple, size: 20),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 2.0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '200% - Max Boost',
                                  style: TextStyle(color: Colors.white),
                                ),
                                if (_volumeBoost == 2.0)
                                  const Icon(Icons.check, color: AppColors.purple, size: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                    ),
                    child: Slider(
                      value: _currentPosition.inSeconds.toDouble(),
                      max: _totalDuration.inSeconds.toDouble() > 0
                          ? _totalDuration.inSeconds.toDouble()
                          : 1,
                      activeColor: AppColors.blue,
                      inactiveColor: Colors.grey.shade800,
                      onChanged: (value) async {
                        await _audioPlayer.seek(
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
                            widget.songs.isNotEmpty && _currentlyPlaying != null
                            ? _playPrevious
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
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 32,
                          ),
                          color: Colors.white,
                          onPressed:
                              _currentlyPlaying != null &&
                                  _currentlyPlaying! < widget.songs.length
                              ? () => _playSong(
                                  widget.songs[_currentlyPlaying!]['path']!,
                                  _currentlyPlaying!,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 32),
                        color: Colors.white,
                        onPressed:
                            widget.songs.isNotEmpty && _currentlyPlaying != null
                            ? _playNext
                            : null,
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

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _currentlyPlaying;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSong(String path, int index) async {
    try {
      if (_currentlyPlaying == index) {
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();

      setState(() {
        _currentlyPlaying = index;
      });
    } catch (e) {
      print('Error playing song: $e');
    }
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
                final isCurrentSong = _currentlyPlaying == index;
                final isPlaying = isCurrentSong && _isPlaying;

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

  const BrowseSongsScreen({
    super.key,
    required this.onSongDownloaded,
  });

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
  static const String apiUrl = 'https://youtube-mp3-api-production.up.railway.app';

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
      print('Searching YouTube for: $query');
      
      final searchResults = await _yt.search.search(query);
      final videos = searchResults.take(20).toList();

      setState(() {
        _searchResults = videos;
        _isSearching = false;
      });

      print('Found ${videos.length} results');
    } catch (e) {
      print('Search error: $e');
      setState(() {
        _isSearching = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  Future<void> _downloadFromAPI(Video video) async {
    if (_isDownloading) {
      print('Already downloading, ignoring request');
      return;
    }

    print('=== Starting download for: ${video.title} ===');

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
      
      print('Requesting download from API: $videoUrl');
      print('API URL: $apiUrl');

      // Make request to your API with streaming
      final request = http.Request('POST', Uri.parse('$apiUrl/api/download'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'url': videoUrl});

      final streamedResponse = await _downloadClient!.send(request);

      print('API Response Status: ${streamedResponse.statusCode}');
      print('Content-Length: ${streamedResponse.contentLength}');

      if (streamedResponse.statusCode == 200) {
        // Get total size if available
        final contentLength = streamedResponse.contentLength ?? 0;
        
        print('Total size: ${contentLength > 0 ? _formatBytes(contentLength) : "Unknown"}');

        // Collect bytes and track progress
        final List<int> bytes = [];
        int lastUpdateBytes = 0;
        int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
        
        await for (var chunk in streamedResponse.stream) {
          // Check if download was cancelled
          if (!_isDownloading) {
            print('Download cancelled by user');
            throw Exception('Download cancelled');
          }

          bytes.addAll(chunk);
          
          // Optimize: Update UI every 100KB OR every 200ms (whichever comes first)
          final now = DateTime.now().millisecondsSinceEpoch;
          final timeSinceUpdate = now - lastUpdateTime;
          final bytesSinceUpdate = bytes.length - lastUpdateBytes;
          
          if (bytesSinceUpdate > 102400 || timeSinceUpdate > 200 || contentLength == 0) {
            lastUpdateBytes = bytes.length;
            lastUpdateTime = now;
            
            setState(() {
              _downloadedBytes = bytes.length;
              _totalBytes = contentLength > 0 ? contentLength : bytes.length;
              if (_totalBytes > 0) {
                _downloadProgress = _downloadedBytes / _totalBytes;
              }
            });

            print('Downloaded: ${_formatBytes(_downloadedBytes)}${contentLength > 0 ? " / ${_formatBytes(_totalBytes)}" : ""} (${(_downloadProgress * 100).toStringAsFixed(1)}%)');
          }
        }

        // Final update
        setState(() {
          _downloadedBytes = bytes.length;
          _totalBytes = bytes.length;
          _downloadProgress = 1.0;
        });

        print('Download complete: ${_formatBytes(bytes.length)}');

        // Save the MP3 file
        final directory = Directory('/storage/emulated/0/Music');
        await directory.create(recursive: true);
        
        final fileName = _sanitizeFileName(video.title);
        final file = File('${directory.path}/$fileName.mp3');
        
        print('Saving to: ${file.path}');
        await file.writeAsBytes(bytes);
        
        print('✓ File saved successfully: ${file.path}');
        print('=== Download completed successfully ===');
        
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
        final errorBody = await streamedResponse.stream.bytesToString();
        print('API Error Body: $errorBody');
        throw Exception('API Error: ${streamedResponse.statusCode}');
      }
      
    } catch (e, stackTrace) {
      print('=== Download error ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted && _isDownloading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('cancelled') 
                ? 'Download cancelled' 
                : 'Download failed: $e'),
            backgroundColor: e.toString().contains('cancelled') 
                ? Colors.orange 
                : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // Always reset state, even if there's an error
      print('Resetting download state...');
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
      print('Download state reset complete');
    }
  }

  void _cancelDownload() {
    print('Cancelling download...');
    if (_isDownloading) {
      setState(() {
        _isDownloading = false;
      });
      _downloadClient?.close();
      _downloadClient = null;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
                          final isDownloading = _downloadingVideoId == video.id.value;

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
                                  ? const Icon(
                                      Icons.music_note,
                                      color: Colors.grey,
                                    )
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
                    color: Colors.black.withOpacity(0.3),
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
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
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
