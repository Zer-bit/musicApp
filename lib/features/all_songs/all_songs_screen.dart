import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

import '../../src/rust/api/scanner.dart' as rust_scanner;
import '../../src/rust/api/search.dart' as rust_search;
import '../../src/rust/api/format.dart' as rust_format;
import '../../core/theme/app_colors.dart';
import '../../core/services/audio_service.dart';
import '../tutorial/user_tutorial.dart';
import 'dialogs/playlist_dialog.dart';
import 'dialogs/rename_dialog.dart';
import 'dialogs/delete_dialog.dart';
import 'dialogs/lyrics_dialog.dart';
import 'dialogs/trim_dialog.dart';
import 'dialogs/details_dialog.dart';
import '../settings/settings_screen.dart';

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
  State<AllSongsScreen> createState() => AllSongsScreenState();
}

class AllSongsScreenState extends State<AllSongsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep this widget alive

  /// Called externally (e.g. from HomeScreen after a download) to silently
  /// rescan the storage and refresh the song list without user interaction.
  Future<void> triggerScan() async {
    if (_hasPermission) {
      await _scanForMusicFiles();
    }
  }

  final GlobalAudioService _audioService = GlobalAudioService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _hasPermission = false;
  bool _isLoading = false;
  String _searchQuery = '';

  static const String _cachedSongsKey = 'cached_songs_list';
  static const String _lastScanTimeKey = 'last_scan_time';
  List<Map<String, String>>? _rustFilteredSongs;
  String _rustFilteredQuery = '';

  @override
  void initState() {
    super.initState();
    _audioService.onIncrementPlayCount = widget.onIncrementPlayCount;
    _audioService.addListener(_onAudioServiceUpdate);
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedSongsOrScan();
    });
  }

  void _onAudioServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _runRustSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _rustFilteredSongs = null;
          _rustFilteredQuery = '';
        });
      }
      return;
    }

    try {
      final titles = widget.songs.map((s) => s['title'] ?? '').toList();
      final artists = widget.songs.map((s) => s['artist'] ?? '').toList();

      final indices = await rust_search.searchSongs(
        titles: titles,
        artists: artists,
        query: query,
      );

      if (mounted && _searchQuery == query) {
        setState(() {
          _rustFilteredSongs = indices.map((idx) => widget.songs[idx]).toList();
          _rustFilteredQuery = query;
        });
      }
    } catch (e) {
      // Fallback is handled in build()
    }
  }

  @override
  void didUpdateWidget(AllSongsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songs != oldWidget.songs) {
      if (_searchQuery.isNotEmpty) {
        _runRustSearch(_searchQuery);
      } else {
        _rustFilteredSongs = null;
        _rustFilteredQuery = '';
      }
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

        try {
          final titles = cachedSongs.map((s) => s['title'] ?? '').toList();
          final artists = cachedSongs.map((s) => s['artist'] ?? '').toList();
          final dates = cachedSongs.map((s) => int.tryParse(s['modifiedDate'] ?? '0') ?? 0).toList();

          final indices = await rust_search.sortSongs(
            titles: titles,
            artists: artists,
            modifiedDates: Int64List.fromList(dates),
            sortBy: 'date',
          );

          final sortedSongs = indices.map((idx) => cachedSongs[idx]).toList();
          widget.onUpdateSongs(sortedSongs);
        } catch (e) {
          cachedSongs.sort((a, b) {
            int dateA = int.tryParse(a['modifiedDate'] ?? '0') ?? 0;
            int dateB = int.tryParse(b['modifiedDate'] ?? '0') ?? 0;
            return dateB.compareTo(dateA);
          });
          widget.onUpdateSongs(cachedSongs);
        }

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

  Future<bool> _showCustomPermissionDialog({
    required String title,
    required String description,
    required bool isManual,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF8F8F8) : Colors.black;
    const accentColor = Color(0xFF854F6C);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF191919) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security_outlined, color: accentColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          description,
          style: TextStyle(color: textColor, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: accentColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isManual ? 'Configure' : 'Accept',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _requestPermissionAndScan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (Platform.isAndroid) {
        final notifStatus = await Permission.notification.status;
        if (!notifStatus.isGranted) {
          final accepted = await _showCustomPermissionDialog(
            title: 'Notification Access Required',
            description: 'Void needs permission to display background audio playback control notifications in your notification tray and lock screen.',
            isManual: false,
          );
          if (accepted) {
            await Permission.notification.request();
          }
        }

        final btConnect = await Permission.bluetoothConnect.status;
        if (!btConnect.isGranted) {
          final accepted = await _showCustomPermissionDialog(
            title: 'Bluetooth Connect Required',
            description: 'Void needs permission to connect to bluetooth audio devices, allowing seamless play/pause transitions when headphones disconnect.',
            isManual: false,
          );
          if (accepted) {
            await Permission.bluetoothConnect.request();
            await Permission.bluetoothScan.request();
          }
        }
      }
    } catch (_) {}

    bool hasStorage = false;

    // Check current storage permissions
    final audioStatus = await Permission.audio.status;
    final storageStatus = await Permission.storage.status;
    final manageStatus = await Permission.manageExternalStorage.status;

    if (audioStatus.isGranted || storageStatus.isGranted || manageStatus.isGranted) {
      hasStorage = true;
    } else {
      final bool accepted = await _showCustomPermissionDialog(
        title: 'Storage Access Required',
        description: 'Void needs access to your device\'s local storage to scan, index, and organize your music files. All processing is completed 100% locally.',
        isManual: Platform.isAndroid && (await Permission.manageExternalStorage.status.isDenied || storageStatus.isPermanentlyDenied),
      );

      if (accepted) {
        if (Platform.isAndroid) {
          // Attempt standard permission prompts
          var status = await Permission.audio.request();
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          if (!status.isGranted) {
            status = await Permission.manageExternalStorage.request();
          }

          // If still not granted, navigate user to the system settings toggle page manually
          if (!status.isGranted) {
            final configure = await _showCustomPermissionDialog(
              title: 'Manual Activation Required',
              description: 'Storage permission has been denied. To proceed, please enable Storage access manually inside your system settings toggle page.',
              isManual: true,
            );
            if (configure) {
              await openAppSettings();
            }
          }

          final finalAudio = await Permission.audio.status;
          final finalStorage = await Permission.storage.status;
          final finalManage = await Permission.manageExternalStorage.status;
          hasStorage = finalAudio.isGranted || finalStorage.isGranted || finalManage.isGranted;
        } else {
          final status = await Permission.storage.request();
          hasStorage = status.isGranted;
        }
      }
    }

    setState(() {
      _hasPermission = hasStorage;
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
      String extRoot = '';
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          Directory root = extDir;
          for (int i = 0; i < 4; i++) {
            root = root.parent;
          }
          extRoot = root.path;
        }
      } catch (_) {}

      final musicPaths = await rust_scanner.buildScanPaths(
        basePath: '/storage/emulated/0',
        externalRoot: extRoot,
      );

      // Call Rust native library to scan directory and extract audio metadata
      final tempDir = await getTemporaryDirectory();
      final rustSongs = await rust_scanner.scanMusicFiles(
        directories: musicPaths,
        cacheDir: tempDir.path,
      );

      final List<Map<String, String>> foundSongs = rustSongs.map((s) {
        return {
          'title': s.title,
          'artist': s.artist.isEmpty ? 'Unknown Artist' : s.artist,
          'album': s.album,
          'path': s.path,
          'duration': rust_format.formatDuration(seconds: s.durationSeconds),
          'modifiedDate': s.modifiedDate.toString(),
          'coverPath': s.coverPath,
        };
      }).toList();

      List<Map<String, String>> sortedSongs = foundSongs;
      try {
        final titles = foundSongs.map((s) => s['title'] ?? '').toList();
        final artists = foundSongs.map((s) => s['artist'] ?? '').toList();
        final dates = foundSongs.map((s) => int.tryParse(s['modifiedDate'] ?? '0') ?? 0).toList();

        final indices = await rust_search.sortSongs(
          titles: titles,
          artists: artists,
          modifiedDates: Int64List.fromList(dates),
          sortBy: 'date',
        );

        sortedSongs = indices.map((idx) => foundSongs[idx]).toList();
      } catch (e) {
        foundSongs.sort((a, b) {
          int dateA = int.tryParse(a['modifiedDate'] ?? '0') ?? 0;
          int dateB = int.tryParse(b['modifiedDate'] ?? '0') ?? 0;
          return dateB.compareTo(dateA);
        });
        sortedSongs = foundSongs;
      }

      final oldSongs = List<Map<String, String>>.from(widget.songs);

      widget.onUpdateSongs(sortedSongs);
      await _saveSongsToCache(sortedSongs);

      // Keep the audio service playlist in sync if we are playing from All Songs
      if (_audioService.currentlyPlaying != null) {
        bool isPlayingAllSongs = false;
        if (_audioService.currentPlaylist.length == oldSongs.length) {
          isPlayingAllSongs = true;
          for (int i = 0; i < oldSongs.length; i++) {
            if (_audioService.currentPlaylist[i]['path'] != oldSongs[i]['path']) {
              isPlayingAllSongs = false;
              break;
            }
          }
        }
        if (isPlayingAllSongs) {
          _audioService.currentPlaylist = List.from(sortedSongs);
          final playingItem = _audioService.audioPlayer.sequenceState?.currentSource?.tag as MediaItem?;
          if (playingItem != null) {
            final newIdx = sortedSongs.indexWhere((s) => s['path'] == playingItem.id);
            if (newIdx != -1) {
              _audioService.currentlyPlaying = newIdx;
            }
          }
        }
      }

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

  Future<void> _playSong(String path, int index) async {
    _audioService.currentPlaylist = List.from(widget.songs);
    await _audioService.playSong(path, index);
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

  void _showDeleteSongConfirmation(
      String songPath, String songTitle, int index) {
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

  void _showTrimAudioDialog(
      String songPath, String currentTitle, String durationStr) {
    TrimAudioDialog.show(
      context: context,
      songPath: songPath,
      currentTitle: currentTitle,
      durationStr: durationStr,
      onStateChanged: () async {
        await _scanForMusicFiles();
      },
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

  void _showSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          audioService: _audioService,
          onScanLibrary: _requestPermissionAndScan,
        ),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioServiceUpdate);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final filteredSongs = _searchQuery.isEmpty
        ? widget.songs
        : ((_rustFilteredSongs != null && _rustFilteredQuery == _searchQuery)
            ? _rustFilteredSongs!
            : widget.songs.where((song) {
                final title = song['title']?.toLowerCase() ?? '';
                final artist = song['artist']?.toLowerCase() ?? '';
                final query = _searchQuery.toLowerCase();
                return title.contains(query) || artist.contains(query);
              }).toList());

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
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsScreen,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'Search songs...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus)
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _rustFilteredSongs = null;
                            _rustFilteredQuery = '';
                          });
                          _searchFocusNode.unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).cardColor
                    : Colors.grey.shade100,
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
                _runRustSearch(value);
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
                            itemExtent: 72.0,
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            itemBuilder: (context, index) {
                              final song = filteredSongs[index];
                              final originalIndex = widget.songs.indexOf(song);
                              final isCurrentSong =
                                  _audioService.currentlyPlaying ==
                                      originalIndex;
                              final isPlaying =
                                  isCurrentSong && _audioService.isPlaying;
                              final bool hasSavedLyrics =
                                  widget.lyrics[song['path']]?.isNotEmpty ==
                                      true;

                              return ListTile(
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey.shade200,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: song['coverPath'] != null &&
                                          song['coverPath']!.isNotEmpty &&
                                          File(song['coverPath']!).existsSync()
                                      ? Image.file(
                                          File(song['coverPath']!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Container(
                                            decoration: BoxDecoration(
                                              gradient: AppColors.purpleBlueGradient,
                                            ),
                                            child: Icon(
                                              isPlaying ? Icons.pause : Icons.music_note,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            gradient: AppColors.purpleBlueGradient,
                                          ),
                                          child: Icon(
                                            isPlaying ? Icons.pause : Icons.music_note,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                                title: Text(
                                  song['title']!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color),
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
                                  icon: const Icon(Icons.more_vert,
                                      color: Colors.grey),
                                  color: Theme.of(context).cardColor,
                                  onSelected: (value) {
                                    if (value == 'add_to_playlist') {
                                      _showAddToPlaylistDialog(
                                        song['path']!,
                                        song['title']!,
                                      );
                                    } else if (value == 'rename') {
                                      _showRenameSongDialog(song['path']!,
                                          song['title']!, originalIndex);
                                    } else if (value == 'lyrics') {
                                      _showLyricsDialog(
                                          song['path']!, song['title']!);
                                    } else if (value == 'delete') {
                                      _showDeleteSongConfirmation(
                                        song['path']!,
                                        song['title']!,
                                        originalIndex,
                                      );
                                    } else if (value == 'trim') {
                                      _showTrimAudioDialog(
                                        song['path']!,
                                        song['title']!,
                                        song['duration'] ?? '0:00',
                                      );
                                    } else if (value == 'details') {
                                      showSongDetailsDialog(
                                        context,
                                        song,
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
                                    const PopupMenuItem(
                                      value: 'trim',
                                      child: Row(
                                        children: [
                                          Icon(Icons.cut),
                                          SizedBox(width: 12),
                                          Text('Trim Audio'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'lyrics',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.lyrics,
                                            color: hasSavedLyrics
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
                                      value: 'details',
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline),
                                          SizedBox(width: 12),
                                          Text('Details'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_forever,
                                              color: Colors.red),
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
                                onTap: () =>
                                    _playSong(song['path']!, originalIndex),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
