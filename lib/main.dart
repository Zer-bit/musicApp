import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:io';
import 'dart:math' as math;

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
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.black,
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
          Colors.deepPurple.withOpacity(0.18),
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
        selectedItemColor: Colors.deepPurple,
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

  const AllSongsScreen({
    super.key,
    required this.songs,
    required this.onUpdateSongs,
    required this.playlists,
    required this.onAddSongToPlaylist,
    required this.onIncrementPlayCount,
    required this.playCount,
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

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
    _audioPlayer.positionStream.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });
    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        _totalDuration = duration ?? Duration.zero;
      });
    });
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Only auto-play next if not in repeat-one mode
        if (_loopMode != LoopMode.one) {
          _playNext();
        }
      }
    });
    _requestPermissionAndScan();
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

            songs.add({
              'title': title,
              'artist': 'Unknown Artist',
              'path': entity.path,
              'duration': duration,
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
                        color: isAdded ? Colors.deepPurple : Colors.grey,
                      ),
                      title: Text(
                        playlist['name'],
                        style: TextStyle(
                          color: isAdded ? Colors.deepPurple : Colors.white,
                        ),
                      ),
                      trailing: Icon(
                        isAdded ? Icons.check : Icons.add,
                        color: isAdded ? Colors.deepPurple : Colors.grey,
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
              style: TextStyle(color: Colors.deepPurple),
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
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
          PopupMenuButton<double>(
            icon: Icon(
              Icons.volume_up,
              color: _volumeBoost > 1.0 ? Colors.deepPurple : Colors.white,
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
                      const Icon(Icons.check, color: Colors.deepPurple, size: 20),
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
                      const Icon(Icons.check, color: Colors.deepPurple, size: 20),
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
                      const Icon(Icons.check, color: Colors.deepPurple, size: 20),
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
                            backgroundColor: Colors.deepPurple,
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
                        CircularProgressIndicator(color: Colors.deepPurple),
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
                              backgroundColor: Colors.deepPurple,
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredSongs.length,
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
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade400,
                                Colors.purple.shade800,
                              ],
                            ),
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
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade400,
                              Colors.purple.shade800,
                            ],
                          ),
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
                          color: _isShuffleOn ? Colors.deepPurple : Colors.grey,
                        ),
                        onPressed: _toggleShuffle,
                      ),
                      IconButton(
                        icon: Icon(
                          _getLoopIcon(),
                          color: _loopMode != LoopMode.off
                              ? Colors.deepPurple
                              : Colors.grey,
                        ),
                        onPressed: _toggleLoopMode,
                      ),
                      PopupMenuButton<double>(
                        icon: Icon(
                          Icons.volume_up,
                          color: _volumeBoost > 1.0 ? Colors.deepPurple : Colors.grey,
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
                                  const Icon(Icons.check, color: Colors.deepPurple, size: 20),
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
                                  const Icon(Icons.check, color: Colors.deepPurple, size: 20),
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
                                  const Icon(Icons.check, color: Colors.deepPurple, size: 20),
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
                      activeColor: Colors.deepPurple,
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
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade400,
                              Colors.purple.shade800,
                            ],
                          ),
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
              borderSide: BorderSide(color: Colors.deepPurple),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.deepPurple),
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
              style: TextStyle(color: Colors.deepPurple),
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
                      backgroundColor: Colors.deepPurple,
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
                      gradient: LinearGradient(
                        colors: isSystemPlaylist
                            ? [Colors.pink.shade400, Colors.red.shade800]
                            : [
                                Colors.deepPurple.shade400,
                                Colors.purple.shade800,
                              ],
                      ),
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
                        color: isAdded ? Colors.deepPurple : Colors.grey,
                      ),
                      title: Text(
                        song['title']!,
                        style: TextStyle(
                          color: isAdded ? Colors.deepPurple : Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        isAdded ? Icons.check : Icons.add,
                        color: isAdded ? Colors.deepPurple : Colors.grey,
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
              style: TextStyle(color: Colors.deepPurple),
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
                        backgroundColor: Colors.deepPurple,
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
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade400,
                          Colors.purple.shade800,
                        ],
                      ),
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
