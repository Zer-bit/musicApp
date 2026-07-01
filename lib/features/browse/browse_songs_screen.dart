import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

import '../../core/theme/app_colors.dart';
import '../../src/rust/api/format.dart' as rust_format;
import '../../core/services/notification_service.dart';
import '../tutorial/user_tutorial.dart';

class BrowseSongsScreen extends StatefulWidget {
  final VoidCallback onSongDownloaded;

  const BrowseSongsScreen({super.key, required this.onSongDownloaded});

  @override
  State<BrowseSongsScreen> createState() => _BrowseSongsScreenState();
}

class _BrowseSongsScreenState extends State<BrowseSongsScreen>
    with WidgetsBindingObserver {
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

  // API URL - Render Production
  static const String apiUrl = 'https://youtube-mp3-api-fgve.onrender.com';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep download alive when app goes to background
    // The HTTP client continues running as long as we don't cancel it
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _yt.close();
    // Only close client if not actively downloading
    if (!_isDownloading) {
      _downloadClient?.close();
    }
    super.dispose();
  }

  bool _isYouTubeUrl(String input) {
    return rust_format.isYoutubeUrl(input: input);
  }

  Future<void> _searchYouTube(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      // If it's a URL, fetch that specific video instead of searching
      if (_isYouTubeUrl(query.trim())) {
        final video = await _yt.videos.get(query.trim());
        setState(() {
          _searchResults = [video];
          _isSearching = false;
        });
        return;
      }

      final searchResults = await _yt.search.search(query);
      final videos = searchResults.take(20).toList();

      setState(() {
        _searchResults = videos;
        _isSearching = false;
      });
    } catch (e) {
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

    // Show foreground notification to keep download alive in background
    DownloadNotificationService.show(video.title,
        body: 'Downloading... Please wait');

    // Request battery optimization exemption to keep network alive
    if (Platform.isAndroid) {
      try {
        final status = await Permission.ignoreBatteryOptimizations.status;
        if (!status.isGranted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      } catch (_) {}
    }

    // Create a new HTTP client for this download
    _downloadClient = http.Client();

    try {
      final videoUrl = 'https://www.youtube.com/watch?v=${video.id.value}';

      debugPrint('🌐 Attempting to download: ${video.title}');
      debugPrint('🌐 Video URL: $videoUrl');
      debugPrint('🌐 API URL: $apiUrl');

      // Make request to your API with streaming and timeout
      final request = http.Request('POST', Uri.parse('$apiUrl/api/download'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'audio/mpeg, audio/mp4, audio/webm, audio/*';
      request.body = jsonEncode({'url': videoUrl});

      // Step 1: Call API - server streams MP3 directly with retry
      http.StreamedResponse? apiResponse;
      int retries = 0;
      while (retries < 3) {
        try {
          _downloadClient = http.Client();
          final req = http.Request('POST', Uri.parse('$apiUrl/api/download'));
          req.headers['Content-Type'] = 'application/json';
          req.headers['Accept'] = 'audio/mpeg, audio/mp4, audio/webm, audio/*';
          req.headers['Connection'] = 'keep-alive';
          req.body = jsonEncode({'url': videoUrl});
          apiResponse = await _downloadClient!.send(req).timeout(
                const Duration(minutes: 5),
                onTimeout: () => throw Exception('Connection timeout.'),
              );
          break; // success
        } catch (e) {
          retries++;
          if (retries >= 3) rethrow;
          debugPrint('Retry $retries after error: $e');
          await Future.delayed(Duration(seconds: retries * 2));
          _downloadClient?.close();
        }
      }

      if (apiResponse == null) {
        throw Exception('Failed to connect to download service.');
      }

      if (apiResponse.statusCode == 429) {
        await apiResponse.stream.bytesToString();
        throw Exception(
            'Too many requests. Please wait a moment and try again.');
      } else if (apiResponse.statusCode == 404) {
        throw Exception(
            'API endpoint not found. The download service may be unavailable.');
      } else if (apiResponse.statusCode >= 500) {
        final body = await apiResponse.stream.bytesToString();
        throw Exception(
            'Server error (${apiResponse.statusCode}). Details: $body');
      } else if (apiResponse.statusCode != 200) {
        final body = await apiResponse.stream.bytesToString();
        throw Exception('API Error ${apiResponse.statusCode}: $body');
      }

      // Server streams m4a binary directly
      final contentType = apiResponse.headers['content-type'] ?? '';
      if (contentType.contains('application/json')) {
        final body = await apiResponse.stream.bytesToString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        throw Exception(json['error'] ?? 'Unknown error');
      }

      final disposition = apiResponse.headers['content-disposition'] ?? '';
      String apiTitle = _sanitizeFileName(video.title);
      String fileExt = 'm4a';
      if (disposition.contains('filename=')) {
        final match = RegExp(r'filename="?([^"]+)"?').firstMatch(disposition);
        if (match != null) {
          final fname = match.group(1)!;
          apiTitle = fname.contains('.')
              ? fname.substring(0, fname.lastIndexOf('.'))
              : fname;
          fileExt = fname.contains('.') ? fname.split('.').last : 'm4a';
        }
      }

      final contentLength = apiResponse.contentLength ?? 0;
      final List<int> bytes = [];
      int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;

      await for (var chunk in apiResponse.stream) {
        if (!_isDownloading) throw Exception('Download cancelled');
        bytes.addAll(chunk);

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastUpdateTime > 200) {
          lastUpdateTime = now;
          setState(() {
            _downloadedBytes = bytes.length;
            _totalBytes = contentLength > 0 ? contentLength : bytes.length;
            _downloadProgress =
                _totalBytes > 0 ? _downloadedBytes / _totalBytes : 0;
          });
        }
      }

      setState(() {
        _downloadedBytes = bytes.length;
        _totalBytes = bytes.length;
        _downloadProgress = 1.0;
      });

      if (bytes.length < 1000) {
        throw Exception(
            'Downloaded file is too small. The URL may have expired.');
      }

      // Save file
      final String saveDirPath;
      if (Platform.isMacOS) {
        final home = Platform.environment['HOME'] ?? '';
        saveDirPath = '$home/Music';
      } else if (Platform.isAndroid) {
        saveDirPath = '/storage/emulated/0/Music';
      } else {
        throw Exception('Unsupported platform');
      }

      final directory = Directory(saveDirPath);
      await directory.create(recursive: true);

      final file = File('${directory.path}/$apiTitle.$fileExt');
      await file.writeAsBytes(bytes);

      widget.onSongDownloaded();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: ${video.title}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout error: $e');
      if (mounted && _isDownloading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connection timeout. Please check your internet connection and try again.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on SocketException catch (e) {
      debugPrint('❌ Network error: $e');
      if (mounted && _isDownloading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connection lost. The download was interrupted. Please try again.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Download error: $e');
      if (mounted && _isDownloading) {
        final msg = e.toString().replaceAll('Exception: ', '');
        String userMessage;

        if (msg.contains('cancelled')) {
          userMessage = 'Download cancelled.';
        } else if (msg.contains('429') || msg.contains('Too many requests')) {
          userMessage =
              'Too many requests. Please wait a moment and try again.';
        } else if (msg.contains('unavailable') ||
            msg.contains('Video unavailable')) {
          userMessage =
              'This video is unavailable or restricted in your region.';
        } else if (msg.contains('timeout') || msg.contains('timed out')) {
          userMessage =
              'Download timed out. The server may be busy, please try again.';
        } else if (msg.contains('500') || msg.contains('Server error')) {
          userMessage = 'Server error. Please try again in a moment.';
        } else if (msg.contains('404')) {
          userMessage =
              'Download service not found. Please check your connection.';
        } else if (msg.contains('too small')) {
          userMessage = 'Download failed - file was empty. Please try again.';
        } else if (msg.contains('Sign in') || msg.contains('bot')) {
          userMessage =
              'YouTube is blocking the download. Please try again later.';
        } else if (msg.contains('copyright') || msg.contains('blocked')) {
          userMessage =
              'This video cannot be downloaded due to copyright restrictions.';
        } else {
          userMessage = 'Download failed. Please try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor:
                msg.contains('cancelled') ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Always reset state, even if there's an error
      DownloadNotificationService.dismiss();
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
    return rust_format.sanitizeDownloadFilename(name: fileName);
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    return rust_format.formatDuration(seconds: duration.inSeconds.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Songs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => UserTutorialDialog.show(context),
            tooltip: 'User Guide',
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
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'Search YouTube...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchResults = [];
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.search, color: AppColors.purple),
                      onPressed: () => _searchYouTube(_searchController.text),
                    ),
                  ],
                ),
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
                        itemExtent: 88.0,
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
                                  ? const Icon(Icons.music_note,
                                      color: Colors.grey)
                                  : null,
                            ),
                            title: Text(
                              video.title,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
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
                color: Theme.of(context).cardColor,
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
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
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
                            const SizedBox(height: 2),
                            const Text(
                              'This may take 1-2 minutes, please wait...',
                              style: TextStyle(
                                color: AppColors.purpleLight,
                                fontSize: 11,
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
