import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';

void main() {
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

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade900],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, size: 100, color: Colors.white),
              SizedBox(height: 24),
              Text(
                'Jezsic',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<Map<String, String>> _songs = [];

  void _updateSongs(List<Map<String, String>> songs) {
    setState(() {
      _songs.clear();
      _songs.addAll(songs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      AllSongsScreen(songs: _songs, onUpdateSongs: _updateSongs),
      const PlaylistScreen(),
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
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'All Songs'),
          BottomNavigationBarItem(icon: Icon(Icons.playlist_play), label: 'Playlists'),
        ],
      ),
    );
  }
}

class AllSongsScreen extends StatefulWidget {
  final List<Map<String, String>> songs;
  final Function(List<Map<String, String>>) onUpdateSongs;

  const AllSongsScreen({super.key, required this.songs, required this.onUpdateSongs});

  @override
  State<AllSongsScreen> createState() => _AllSongsScreenState();
}

class _AllSongsScreenState extends State<AllSongsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _currentlyPlaying;
  bool _hasPermission = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndScan();
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
      
      // Common music directories on Android
      List<String> musicPaths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Music',
        '/sdcard/Download',
      ];

      for (String path in musicPaths) {
        Directory dir = Directory(path);
        if (await dir.exists()) {
          await _scanDirectory(dir, foundSongs);
        }
      }

      widget.onUpdateSongs(foundSongs);
    } catch (e) {
      print('Error scanning files: $e');
    }
  }

  Future<void> _scanDirectory(Directory dir, List<Map<String, String>> songs) async {
    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          String path = entity.path.toLowerCase();
          if (path.endsWith('.mp3') || path.endsWith('.m4a') || path.endsWith('.wav')) {
            String fileName = entity.path.split('/').last;
            String title = fileName.replaceAll(RegExp(r'\.(mp3|m4a|wav)$'), '');
            
            songs.add({
              'title': title,
              'artist': 'Unknown Artist',
              'path': entity.path,
              'duration': '0:00',
            });
          }
        }
      }
    } catch (e) {
      print('Error scanning directory ${dir.path}: $e');
    }
  }

  Future<void> _playSong(String path, int index) async {
    try {
      if (_currentlyPlaying == index) {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
      } else {
        await _audioPlayer.setFilePath(path);
        await _audioPlayer.play();
        setState(() {
          _currentlyPlaying = index;
        });
      }
    } catch (e) {
      print('Error playing song: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Songs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _requestPermissionAndScan,
          ),
        ],
      ),
      body: !_hasPermission
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
                      Text('Scanning for music files...', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : widget.songs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.music_note, size: 60, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No music files found', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Text(
                            'Add MP3 files to Music or Download folder',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
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
                      itemCount: widget.songs.length,
                      itemBuilder: (context, index) {
                        final song = widget.songs[index];
                        final isPlaying = _currentlyPlaying == index && _audioPlayer.playing;
                        
                        return ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                colors: [Colors.deepPurple.shade400, Colors.purple.shade800],
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
                          trailing: Text(
                            song['duration']!,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          onTap: () => _playSong(song['path']!, index),
                        );
                      },
                    ),
    );
  }
}

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playlists = [
      {'name': 'Favorites', 'count': '0 songs'},
      {'name': 'Workout', 'count': '0 songs'},
      {'name': 'Chill', 'count': '0 songs'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.purple.shade800],
                ),
              ),
              child: const Icon(Icons.playlist_play, color: Colors.white),
            ),
            title: Text(playlists[index]['name']!, style: const TextStyle(color: Colors.white)),
            subtitle: Text(playlists[index]['count']!, style: const TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            onTap: () {},
          );
        },
      ),
    );
  }
}
