import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../core/theme/app_colors.dart';
import '../playlists/playlist_screen.dart';
import '../all_songs/all_songs_screen.dart';
import '../browse/browse_songs_screen.dart';
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
  final Map<String, String> _lyrics = {}; // Store lyrics for each song (path -> lyrics)
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
      final encoded = _playCount.map((k, v) => MapEntry(k, v.toString()));
      await prefs.setString('cached_play_count', jsonEncode(encoded));
    } catch (e) {
      // Error saving play count
    }
  }

  Future<void> _loadPlayCountFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('cached_play_count');
      if (json != null && json.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(json);
        setState(() {
          _playCount.clear();
          decoded.forEach((key, value) {
            _playCount[key] = int.tryParse(value.toString()) ?? 0;
          });
        });
        _updateFavorites();
      }
    } catch (e) {
      // Error loading play count
    }
  }

  void _updateFavorites() {
    final sortedSongs = _playCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top10 = sortedSongs.take(10).map((e) => e.key).toList();

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
      final songs = _playlists[playlistIndex]['songs'] as List<String>;
      if (!songs.contains(songPath)) {
        songs.add(songPath);
      }
    });
    _savePlaylists();
  }

  void _removeSongFromPlaylist(int playlistIndex, String songPath) {
    setState(() {
      final songs = _playlists[playlistIndex]['songs'] as List<String>;
      songs.remove(songPath);
    });
    _savePlaylists();
  }

  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = _playlists
          .where((p) => p['isSystem'] != true)
          .map((p) => {'name': p['name'], 'songs': p['songs']})
          .toList();
      await prefs.setString('cached_playlists', jsonEncode(toSave));
    } catch (e) {
      // Error saving playlists
    }
  }

  Future<void> _loadPlaylistsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('cached_playlists');
      if (json != null && json.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(json);
        setState(() {
          _playlists.removeWhere((p) => p['isSystem'] != true);
          for (final p in decoded) {
            _playlists.add({
              'name': p['name'],
              'songs': List<String>.from(p['songs']),
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

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [allSongsScreen, playlistScreen, browseSongsScreen],
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.white,
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
