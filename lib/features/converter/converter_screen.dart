import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../src/rust/api/format.dart' as rust_format;

class ConverterScreen extends StatefulWidget {
  final VoidCallback onSongDownloaded;

  const ConverterScreen({
    super.key,
    required this.onSongDownloaded,
  });

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  static const String _apiUrl = 'https://youtube-mp3-api-fgve.onrender.com';

  // State variables for file picking
  File? _selectedFile;
  String? _selectedFileName;
  int? _selectedFileSize;

  // State variables for recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  String? _recordedFilePath;

  // Target Format
  String _targetFormat = 'mp3'; // 'mp3' or 'm4a'

  // Conversion Status
  bool _isConverting = false;
  double _conversionProgress = 0.0;
  http.Client? _httpClient;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _httpClient?.close();
    super.dispose();
  }

  // --- Pick File ---
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4',
          'mkv',
          'avi',
          'mov',
          'wav',
          'flac',
          'ogg',
          'm4a',
          'mp3'
        ],
      );

      if (result != null && result.files.single.path != null) {
        // Reset recording if any
        _recordedFilePath = null;

        setState(() {
          _selectedFile = File(result.files.single.path!);
          _selectedFileName = result.files.single.name;
          _selectedFileSize = result.files.single.size;
        });
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e', Colors.red);
    }
  }

  // --- Audio Recording ---
  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _selectedFile = null;
          _selectedFileName = null;
          _recordedFilePath = path;
        });
      } else {
        _showSnackBar(
            'Microphone permission required to record audio.', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error starting recording: $e', Colors.red);
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      setState(() {
        _isPaused = true;
      });
    } catch (e) {
      _showSnackBar('Error pausing recording: $e', Colors.red);
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      setState(() {
        _isPaused = false;
      });
    } catch (e) {
      _showSnackBar('Error resuming recording: $e', Colors.red);
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _isPaused = false;
          _selectedFile = File(path);
          _selectedFileName = 'Voice Note Recording';
          _selectedFileSize = File(path).lengthSync();
        });
      }
    } catch (e) {
      _showSnackBar('Error stopping recording: $e', Colors.red);
    }
  }

  // --- Perform Conversion ---
  Future<void> _convertFile() async {
    if (_selectedFile == null) {
      _showSnackBar(
          'Please select a file or record audio first.', Colors.orange);
      return;
    }

    // Request storage permissions
    PermissionStatus status = PermissionStatus.denied;
    if (Platform.isAndroid) {
      if (await Permission.audio.isGranted) {
        status = PermissionStatus.granted;
      } else if (await Permission.storage.isGranted) {
        status = PermissionStatus.granted;
      } else {
        status = await Permission.audio.request();
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      }
    } else {
      status = PermissionStatus.granted;
    }

    if (!status.isGranted) {
      _showSnackBar('Storage permission required to save converted files.',
          Colors.orange);
      return;
    }

    setState(() {
      _isConverting = true;
      _conversionProgress = 0.0;
    });

    _httpClient = http.Client();

    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$_apiUrl/api/convert'));
      request.fields['format'] = _targetFormat;
      request.files
          .add(await http.MultipartFile.fromPath('file', _selectedFile!.path));

      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        final errText = await response.stream.bytesToString();
        throw Exception(
            'Failed to convert (code ${response.statusCode}): $errText');
      }

      final contentLength = response.contentLength ?? 0;
      final List<int> bytes = [];

      await for (var chunk in response.stream) {
        if (!_isConverting) throw Exception('Conversion cancelled');
        bytes.addAll(chunk);

        if (contentLength > 0) {
          setState(() {
            _conversionProgress = bytes.length / contentLength;
          });
        }
      }

      if (bytes.length < 1000) {
        throw Exception('Converted file is invalid or too small.');
      }

      // Save the file in the Music directory
      final String saveDirPath;
      if (Platform.isMacOS) {
        final home = Platform.environment['HOME'] ?? '';
        saveDirPath = '$home/Music';
      } else if (Platform.isAndroid) {
        saveDirPath = '/storage/emulated/0/Music';
      } else {
        throw Exception('Unsupported platform');
      }

      final saveDir = Directory(saveDirPath);
      await saveDir.create(recursive: true);

      // Clean filename
      String originalName = _selectedFileName ?? 'converted_file';
      if (originalName.contains('.')) {
        originalName = originalName.substring(0, originalName.lastIndexOf('.'));
      }
      originalName = rust_format.sanitizeFilename(name: originalName);
      if (originalName.isEmpty) originalName = 'converted_file';

      final finalFile = File('${saveDir.path}/$originalName.$_targetFormat');
      await finalFile.writeAsBytes(bytes);

      widget.onSongDownloaded();

      _showSnackBar(
          'Converted and saved: $originalName.$_targetFormat', Colors.green);

      // Clean up local temp voice recording if we recorded it
      if (_recordedFilePath != null) {
        try {
          final tempF = File(_recordedFilePath!);
          if (tempF.existsSync()) tempF.deleteSync();
        } catch (_) {}
        _recordedFilePath = null;
      }

      setState(() {
        _selectedFile = null;
        _selectedFileName = null;
        _selectedFileSize = null;
      });
    } catch (e) {
      if (_isConverting) {
        _showSnackBar('Conversion error: $e', Colors.red);
      }
    } finally {
      setState(() {
        _isConverting = false;
      });
      _httpClient?.close();
    }
  }

  void _cancelConversion() {
    setState(() {
      _isConverting = false;
    });
    _httpClient?.close();
    _showSnackBar('Conversion cancelled.', Colors.orange);
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Converter'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Info Header ---
            Text(
              'Transcode video or audio files directly on your Rust-powered API server.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // --- Voice Recorder Section ---
            Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mic,
                            color: Theme.of(context).primaryColor, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          'Record Voice Note',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isRecording) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Recording in progress...',
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                                _isPaused ? Icons.play_arrow : Icons.pause),
                            iconSize: 36,
                            color: AppColors.blue,
                            onPressed:
                                _isPaused ? _resumeRecording : _pauseRecording,
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            icon: const Icon(Icons.stop),
                            iconSize: 36,
                            color: Colors.red,
                            onPressed: _stopRecording,
                          ),
                        ],
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _startRecording,
                        icon: const Icon(Icons.mic),
                        label: const Text('Start Recording',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- File Picker Section ---
            Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.video_library_outlined,
                            color: AppColors.blue, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Select Local Media',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Browse Files',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Selected File Card ---
            if (_selectedFileName != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.audiotrack,
                        color: Theme.of(context).primaryColor, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFileName!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatSize(_selectedFileSize),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _selectedFile = null;
                          _selectedFileName = null;
                          _selectedFileSize = null;
                          _recordedFilePath = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // --- Format Picker ---
            const Text(
              'Select Target Format',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _targetFormat = 'mp3';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _targetFormat == 'mp3'
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _targetFormat == 'mp3'
                              ? Theme.of(context).primaryColor
                              : (isDark
                                  ? Colors.transparent
                                  : Colors.grey.shade300),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'MP3 (Audio)',
                          style: TextStyle(
                            color: _targetFormat == 'mp3'
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.black87),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _targetFormat = 'm4a';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _targetFormat == 'm4a'
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _targetFormat == 'm4a'
                              ? Theme.of(context).primaryColor
                              : (isDark
                                  ? Colors.transparent
                                  : Colors.grey.shade300),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'M4A (AAC Audio)',
                          style: TextStyle(
                            color: _targetFormat == 'm4a'
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.black87),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- Conversion Progress / Trigger Button ---
            if (_isConverting) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: _conversionProgress > 0 ? _conversionProgress : null,
                    color: Theme.of(context).primaryColor,
                    backgroundColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _conversionProgress > 0
                        ? 'Converting & Downloading: ${(_conversionProgress * 100).toStringAsFixed(0)}%'
                        : 'Uploading file to Rust transcoding server...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _cancelConversion,
                    child: const Text('Cancel Conversion',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _selectedFile != null ? _convertFile : null,
                icon: const Icon(Icons.transform),
                label: const Text(
                  'CONVERT & SAVE TO LIBRARY',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
