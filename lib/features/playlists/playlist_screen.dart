import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../tutorial/user_tutorial.dart';
import 'playlist_detail_screen.dart';

class PlaylistScreen extends StatefulWidget {
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

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  void _showAddPlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.purple)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.purple)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.onAddPlaylist(controller.text.trim());
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Create', style: TextStyle(color: AppColors.purple)),
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
        title: const Text('Delete Playlist', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${widget.playlists[index]['name']}"?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              widget.onRemovePlaylist(index);
              Navigator.pop(context);
              setState(() {});
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
            icon: const Icon(Icons.help_outline),
            onPressed: () => UserTutorialDialog.show(context),
            tooltip: 'User Guide',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPlaylistDialog(context),
          ),
        ],
      ),
      body: widget.playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.playlist_play, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No playlists yet', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPlaylistDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Playlist'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: widget.playlists.length,
              itemBuilder: (context, index) {
                final playlist = widget.playlists[index];
                final songCount = (playlist['songs'] as List).length;
                final isSystemPlaylist = playlist['isSystem'] == true;

                return ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: isSystemPlaylist ? AppColors.accentGradient : AppColors.purpleBlueGradient,
                    ),
                    child: Icon(isSystemPlaylist ? Icons.favorite : Icons.playlist_play, color: Colors.white),
                  ),
                  title: Text(playlist['name'], style: const TextStyle(color: Colors.white)),
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
                            if (value == 'delete') _showDeleteConfirmation(context, index);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Delete Playlist', style: TextStyle(color: Colors.red)),
                              ]),
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
                          allSongs: widget.allSongs,
                          onAddSong: (songPath) {
                            widget.onAddSongToPlaylist(index, songPath);
                            setState(() {});
                          },
                          onRemoveSong: (songPath) {
                            widget.onRemoveSongFromPlaylist(index, songPath);
                            setState(() {});
                          },
                          isSystemPlaylist: isSystemPlaylist,
                          playCount: widget.playCount,
                          getLatestSongPaths: () => List<String>.from(widget.playlists[index]['songs']),
                        ),
                      ),
                    ).then((_) => setState(() {}));
                  },
                );
              },
            ),
    );
  }
}
