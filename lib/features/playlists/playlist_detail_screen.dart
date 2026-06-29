import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/audio_service.dart';
import '../player/mini_player.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistName;
  final int playlistIndex;
  final List<String> songPaths;
  final List<Map<String, String>> allSongs;
  final Function(String) onAddSong;
  final Function(String) onRemoveSong;
  final bool isSystemPlaylist;
  final Map<String, int> playCount;
  final List<String> Function() getLatestSongPaths;

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
    required this.getLatestSongPaths,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep this widget alive

  final GlobalAudioService _audioService = GlobalAudioService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _playSong(String path, int index) async {
    // Always get the latest song paths to avoid stale data
    final latestPaths = widget.getLatestSongPaths();
    final playlistSongs = widget.allSongs
        .where((song) => latestPaths.contains(song['path']))
        .toList();
    _audioService.currentPlaylist = playlistSongs;
    _audioService.onIncrementPlayCount = null;

    final playlistIndex = playlistSongs.indexWhere((s) => s['path'] == path);
    if (playlistIndex == -1) return;

    await _audioService.playSong(path, playlistIndex);
  }

  void _showAddSongsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.white,
        title: Text('Add Songs', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
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
                    final isAdded = widget.getLatestSongPaths().contains(song['path']);

                    return ListTile(
                      leading: Icon(
                        Icons.music_note,
                        color: isAdded ? AppColors.purple : Colors.grey,
                      ),
                      title: Text(
                        song['title']!,
                        style: TextStyle(
                          color: isAdded ? AppColors.purple : Theme.of(context).textTheme.bodyLarge?.color,
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
    super.build(context);

    final latestPaths = widget.getLatestSongPaths();
    final playlistSongs = widget.allSongs
        .where((song) => latestPaths.contains(song['path']))
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
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'Search in playlist...',
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
            child: playlistSongs.isEmpty
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
                              ? (widget.isSystemPlaylist
                                    ? 'Play songs to add them to Favorites'
                                    : 'No songs in this playlist')
                              : 'No songs match your search',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        if (_searchQuery.isEmpty &&
                            !widget.isSystemPlaylist) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showAddSongsDialog,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Add Songs', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.purple,
                              foregroundColor: Colors.white,
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
                      final songPath = song['path']!;
                      final globalIndex = _audioService.currentPlaylist
                          .indexWhere((s) => s['path'] == songPath);
                      final isCurrentSong =
                          globalIndex != -1 &&
                          _audioService.currentlyPlaying == globalIndex;
                      final isPlaying =
                          isCurrentSong && _audioService.isPlaying;

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
                        trailing: widget.isSystemPlaylist
                            ? Text(
                                '${widget.playCount[song['path']] ?? 0} plays',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              )
                            : PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.grey,
                                ),
                                color: Theme.of(context).cardColor,
                                onSelected: (value) {
                                  if (value == 'remove') {
                                    widget.onRemoveSong(song['path']!);
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Removed ${song['title']}',
                                        ),
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
                                        Icon(
                                          Icons.remove_circle,
                                          color: Colors.red,
                                        ),
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
          ),
          const GlobalMiniPlayer(),
        ],
      ),
    );
  }
}
