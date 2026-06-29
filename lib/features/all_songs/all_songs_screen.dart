import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

import '../../core/theme/app_colors.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/theme_service.dart';
import '../tutorial/user_tutorial.dart';
import 'dialogs/sleep_timer_dialog.dart';
import 'dialogs/playlist_dialog.dart';
import 'dialogs/rename_dialog.dart';
import 'dialogs/delete_dialog.dart';
import 'dialogs/lyrics_dialog.dart';

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
  void initState() {
    super.initState();
    _audioService.onIncrementPlayCount = widget.onIncrementPlayCount;
    _audioService.addListener(_onAudioServiceUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedSongsOrScan();
    });
  }

  void _onAudioServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCachedSongsOrScan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedSongsJson = prefs.getString(_cachedSongsKey);

      if (cachedSongsJson != null && cachedSongsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedSongsJson);
        final cachedSongs = decoded
            .map((item) => Map<String, String>.from(item as Map))
            .toList();

        cachedSongs.sort((a, b) {
          int dateA = int.tryParse(a['modifiedDate'] ?? '0') ?? 0;
          int dateB = int.tryParse(b['modifiedDate'] ?? '0') ?? 0;
          return dateB.compareTo(dateA);
        });

        widget.onUpdateSongs(cachedSongs);

        setState(() {
          _hasPermission = true;
          _isLoading = false;
        });
      } else {
        await _requestPermissionAndScan();
      }
    } catch (e) {
      await _requestPermissionAndScan();
    }
  }

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

  Future<void> _requestPermissionAndScan() async {
    setState(() {
      _isLoading = true;
    });

    if (Platform.isAndroid) {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }

      final btConnect = await Permission.bluetoothConnect.status;
      if (!btConnect.isGranted) {
        await Permission.bluetoothConnect.request();
      }
      final btScan = await Permission.bluetoothScan.status;
      if (!btScan.isGranted) {
        await Permission.bluetoothScan.request();
      }
    }

    PermissionStatus status = PermissionStatus.denied;

    if (await Permission.audio.isGranted) {
      status = PermissionStatus.granted;
    } else if (await Permission.storage.isGranted) {
      status = PermissionStatus.granted;
    } else if (await Permission.manageExternalStorage.isGranted) {
      status = PermissionStatus.granted;
    } else {
      status = await Permission.audio.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
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
      Set<String> addedPaths = {};

      List<String> musicPaths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/DCIM',
      ];

      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          Directory root = extDir;
          for (int i = 0; i < 4; i++) {
            root = root.parent;
          }
          final rootPath = root.path;
          for (final sub in ['Music', 'Download', 'Downloads']) {
            final candidate = '$rootPath/$sub';
            if (!musicPaths.contains(candidate)) {
              musicPaths.add(candidate);
            }
          }
        }
      } catch (_) {}

      for (String path in musicPaths) {
        Directory dir = Directory(path);
        if (await dir.exists()) {
          await _scanDirectory(dir, foundSongs, addedPaths);
        }
      }

      foundSongs.sort((a, b) {
        int dateA = int.tryParse(a['modifiedDate'] ?? '0') ?? 0;
        int dateB = int.tryParse(b['modifiedDate'] ?? '0') ?? 0;
        return dateB.compareTo(dateA);
      });

      widget.onUpdateSongs(foundSongs);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
            if (addedPaths.contains(entity.path)) {
              continue;
            }

            String fileName = entity.path.split('/').last;
            String title = fileName.replaceAll(
              RegExp(r'\.(mp3|m4a|wav)$', caseSensitive: false),
              '',
            );

            const String duration = '0:00';

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
      // Error scanning directory
    }
  }

  Future<void> _playSong(String path, int index) async {
    _audioService.currentPlaylist = List.from(widget.songs);
    await _audioService.playSong(path, index);
  }

  void _showSleepTimerDialog() {
    showSleepTimerDialog(context, _audioService, () => setState(() {}));
  }

  void _showAddToPlaylistDialog(String songPath, String songTitle) {
    showAddToPlaylistDialog(
      context,
      songPath,
      songTitle,
      widget.playlists,
      widget.onAddSongToPlaylist,
    );
  }

  void _showRenameSongDialog(String songPath, String currentTitle, int index) {
    showRenameSongDialog(
      context: context,
      songPath: songPath,
      currentTitle: currentTitle,
      index: index,
      songs: widget.songs,
      playlists: widget.playlists,
      audioService: _audioService,
      saveSongsToCache: _saveSongsToCache,
      onStateChanged: () => setState(() {}),
    );
  }

  void _showDeleteSongConfirmation(String songPath, String songTitle, int index) {
    showDeleteSongConfirmation(
      context: context,
      songPath: songPath,
      songTitle: songTitle,
      index: index,
      songs: widget.songs,
      audioService: _audioService,
      saveSongsToCache: _saveSongsToCache,
      onStateChanged: () => setState(() {}),
    );
  }

  void _showLyricsDialog(String songPath, String songTitle) {
    showLyricsDialog(
      context: context,
      songPath: songPath,
      songTitle: songTitle,
      lyrics: widget.lyrics,
      onSaveLyrics: widget.onSaveLyrics,
    );
  }

  void _showThemeSelectionDialog(BuildContext context) {
    final themeService = ThemeService();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.white,
        title: Text(
          'Choose Theme',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'System Default',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              leading: Icon(
                Icons.brightness_auto,
                color: Theme.of(context).iconTheme.color,
              ),
              trailing: themeService.themeMode == ThemeMode.system
                  ? const Icon(Icons.check, color: AppColors.purple)
                  : null,
              onTap: () {
                themeService.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(
                'Light Mode',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              leading: Icon(
                Icons.light_mode,
                color: Theme.of(context).iconTheme.color,
              ),
              trailing: themeService.themeMode == ThemeMode.light
                  ? const Icon(Icons.check, color: AppColors.purple)
                  : null,
              onTap: () {
                themeService.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(
                'Dark Mode',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              leading: Icon(
                Icons.dark_mode,
                color: Theme.of(context).iconTheme.color,
              ),
              trailing: themeService.themeMode == ThemeMode.dark
                  ? const Icon(Icons.check, color: AppColors.purple)
                  : null,
              onTap: () {
                themeService.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.purple)),
          ),
        ],
      ),
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
    super.build(context);

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
            icon: const Icon(Icons.help_outline),
            onPressed: () => UserTutorialDialog.show(context),
            tooltip: 'User Guide',
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => _showThemeSelectionDialog(context),
            tooltip: 'Change Theme',
          ),
          IconButton(
            icon: Icon(
              Icons.timer,
              color: _audioService.sleepTimer != null
                  ? AppColors.purple
                  : Theme.of(context).iconTheme.color,
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
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
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade900
                    : Colors.grey.shade200,
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
                    itemExtent: 72.0,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      final originalIndex = widget.songs.indexOf(song);
                      final isCurrentSong =
                          _audioService.currentlyPlaying == originalIndex;
                      final isPlaying =
                          isCurrentSong && _audioService.isPlaying;
                      final bool hasSavedLyrics =
                          widget.lyrics[song['path']]?.isNotEmpty == true;

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
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
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
                          color: Theme.of(context).cardColor,
                          onSelected: (value) {
                            if (value == 'add_to_playlist') {
                              _showAddToPlaylistDialog(
                                song['path']!,
                                song['title']!,
                              );
                            } else if (value == 'rename') {
                              _showRenameSongDialog(song['path']!, song['title']!, originalIndex);
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
                                  Icon(Icons.playlist_add),
                                  SizedBox(width: 12),
                                  Text('Add to Playlist'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.drive_file_rename_outline),
                                  SizedBox(width: 12),
                                  Text('Rename Song'),
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
                                        hasSavedLyrics
                                        ? AppColors.blue
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    hasSavedLyrics
                                        ? 'Open Lyrics'
                                        : 'Add Lyrics',
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
