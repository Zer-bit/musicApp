import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../src/rust/api/playlist.dart' as rust_playlist;
import '../../src/rust/api/models.dart' as rust_models;
import '../playlists/playlist_screen.dart';
import '../all_songs/all_songs_screen.dart';
import '../browse/browse_songs_screen.dart';
import '../converter/converter_screen.dart';
import '../player/mini_player.dart';
import '../tutorial/user_tutorial.dart';

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
    _savePlayCount();
  }

  Future<void> _savePlayCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _playCount.entries
          .map((e) => rust_models.PlayCountEntry(path: e.key, count: e.value))
          .toList();
      final json = rust_playlist.serializePlayCounts(entries: entries);
      await prefs.setString('cached_play_count', json);
    } catch (e) {
      // Error saving play count
    }
  }

  Future<void> _loadPlayCountFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('cached_play_count');
      if (json != null && json.isNotEmpty) {
        final entries = rust_playlist.deserializePlayCounts(json: json);
        setState(() {
          _playCount.clear();
          for (final entry in entries) {
            _playCount[entry.path] = entry.count;
          }
        });
        _updateFavorites();
      }
    } catch (e) {
      // Error loading play count
    }
  }

  void _updateFavorites() {
    final entries = _playCount.entries
        .map((e) => rust_models.PlayCountEntry(path: e.key, count: e.value))
        .toList();
    final top10 = rust_playlist.computeFavorites(entries: entries, limit: 10);
    setState(() {
      _playlists[0]['songs'] = top10;
    });
  }

  void _addPlaylist(String name) {
    setState(() {
      _playlists.add({'name': name, 'songs': <String>[]});
    });
    _savePlaylists();
  }

  void _removePlaylist(int index) {
    setState(() {
      _playlists.removeAt(index);
    });
    _savePlaylists();
  }

  void _addSongToPlaylist(int playlistIndex, String songPath) {
    setState(() {
      final p = _playlists[playlistIndex];
      final playlistModel = rust_models.Playlist(
        name: p['name'] as String,
        songs: List<String>.from(p['songs'] as List),
        isSystem: p['isSystem'] == true,
      );
      final updated = rust_playlist.addSongToPlaylist(
        playlist: playlistModel,
        songPath: songPath,
      );
      _playlists[playlistIndex]['songs'] = updated.songs;
    });
    _savePlaylists();
  }

  void _removeSongFromPlaylist(int playlistIndex, String songPath) {
    setState(() {
      final p = _playlists[playlistIndex];
      final playlistModel = rust_models.Playlist(
        name: p['name'] as String,
        songs: List<String>.from(p['songs'] as List),
        isSystem: p['isSystem'] == true,
      );
      final updated = rust_playlist.removeSongFromPlaylist(
        playlist: playlistModel,
        songPath: songPath,
      );
      _playlists[playlistIndex]['songs'] = updated.songs;
    });
    _savePlaylists();
  }

  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistModels = _playlists
          .map((p) => rust_models.Playlist(
                name: p['name'] as String,
                songs: List<String>.from(p['songs'] as List),
                isSystem: p['isSystem'] == true,
              ))
          .toList();
      final json = rust_playlist.serializePlaylists(playlists: playlistModels);
      await prefs.setString('cached_playlists', json);
    } catch (e) {
      // Error saving playlists
    }
  }

  Future<void> _loadPlaylistsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('cached_playlists');
      if (json != null && json.isNotEmpty) {
        final playlistModels = rust_playlist.deserializePlaylists(json: json);
        setState(() {
          _playlists.removeWhere((p) => p['isSystem'] != true);
          for (final p in playlistModels) {
            _playlists.add({
              'name': p.name,
              'songs': p.songs,
            });
          }
        });
      }
    } catch (e) {
      // Error loading playlists
    }
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
      final entries = _lyrics.entries
          .map((e) => rust_models.LyricsEntry(path: e.key, lyrics: e.value))
          .toList();
      final json = rust_playlist.serializeLyrics(entries: entries);
      await prefs.setString('cached_lyrics', json);
    } catch (e) {
      // Error saving lyrics
    }
  }

  Future<void> _loadLyricsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('cached_lyrics');
      if (json != null && json.isNotEmpty) {
        final entries = rust_playlist.deserializeLyrics(json: json);
        setState(() {
          _lyrics.clear();
          for (final entry in entries) {
            _lyrics[entry.path] = entry.lyrics;
          }
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
    _loadPlaylistsFromCache();
    _loadPlayCountFromCache();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstOpen();
    });
  }

  Future<void> _checkFirstOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstOpen = prefs.getBool('is_first_open') ?? true;
      if (isFirstOpen) {
        if (mounted) {
          UserTutorialDialog.show(context);
          await prefs.setBool('is_first_open', false);
        }
      }
    } catch (e) {
      debugPrint('Error checking first open: $e');
    }
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Exit App',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to exit Void?',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Exit',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistScreen = PlaylistScreen(
      playlists: _playlists,
      allSongs: _songs,
      onAddPlaylist: _addPlaylist,
      onRemovePlaylist: _removePlaylist,
      onAddSongToPlaylist: _addSongToPlaylist,
      onRemoveSongFromPlaylist: _removeSongFromPlaylist,
      playCount: _playCount,
    );

    final allSongsScreen = AllSongsScreen(
      songs: _songs,
      onUpdateSongs: _updateSongs,
      playlists: _playlists,
      onAddSongToPlaylist: _addSongToPlaylist,
      onIncrementPlayCount: _incrementPlayCount,
      playCount: _playCount,
      lyrics: _lyrics,
      onSaveLyrics: _saveLyrics,
    );

    final browseSongsScreen = BrowseSongsScreen(
      onSongDownloaded: () {
        setState(() {});
      },
    );

    final converterScreen = ConverterScreen(
      onSongDownloaded: () {
        setState(() {});
      },
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                allSongsScreen,
                playlistScreen,
                browseSongsScreen,
                converterScreen
              ],
            ),
          ),
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
        backgroundColor: Theme.of(context).cardColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType
            .fixed, // ensures 4 items look good and don't shift/hide
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
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horizontal_circle_outlined),
            label: 'Converter',
          ),
        ],
      ),
    ),
  );
}
}
