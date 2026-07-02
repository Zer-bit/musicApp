import 'package:flutter/material.dart';
import 'dart:io';

import '../../../../core/theme/app_colors.dart';
import '../../../../src/rust/api/trimmer.dart' as rust_trimmer;
import '../../../../src/rust/api/format.dart' as rust_format;

class TrimAudioDialog extends StatefulWidget {
  final String songPath;
  final String currentTitle;
  final String durationStr;
  final VoidCallback onStateChanged;

  const TrimAudioDialog({
    super.key,
    required this.songPath,
    required this.currentTitle,
    required this.durationStr,
    required this.onStateChanged,
  });

  static void show({
    required BuildContext context,
    required String songPath,
    required String currentTitle,
    required String durationStr,
    required VoidCallback onStateChanged,
  }) {
    showDialog(
      context: context,
      builder: (context) => TrimAudioDialog(
        songPath: songPath,
        currentTitle: currentTitle,
        durationStr: durationStr,
        onStateChanged: onStateChanged,
      ),
    );
  }

  @override
  State<TrimAudioDialog> createState() => _TrimAudioDialogState();
}

class _TrimAudioDialogState extends State<TrimAudioDialog> {
  late double _totalDuration;
  late double _startValue;
  late double _endValue;
  late TextEditingController _titleController;
  bool _isTrimming = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _totalDuration = _parseDuration(widget.durationStr);
    _startValue = 0.0;
    // Set default trim window to 30 seconds or the total duration if shorter
    _endValue = _totalDuration > 30.0 ? 30.0 : _totalDuration;
    _titleController = TextEditingController(text: '${widget.currentTitle}_trimmed');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  double _parseDuration(String durationStr) {
    try {
      final parts = durationStr.split(':');
      if (parts.length == 2) {
        final mins = int.tryParse(parts[0]) ?? 0;
        final secs = int.tryParse(parts[1]) ?? 0;
        return (mins * 60 + secs).toDouble();
      } else if (parts.length == 3) {
        final hrs = int.tryParse(parts[0]) ?? 0;
        final mins = int.tryParse(parts[1]) ?? 0;
        final secs = int.tryParse(parts[2]) ?? 0;
        return (hrs * 3600 + mins * 60 + secs).toDouble();
      }
    } catch (_) {}
    return 100.0; // fallback default
  }

  String _formatSeconds(double seconds) {
    return rust_format.formatDuration(seconds: seconds);
  }

  bool _isFormatSupported() {
    final pathLower = widget.songPath.toLowerCase();
    return pathLower.endsWith('.mp3') || pathLower.endsWith('.wav');
  }

  Future<void> _trimAudio() async {
    final pathLower = widget.songPath.toLowerCase();
    final ext = pathLower.endsWith('.mp3') ? '.mp3' : '.wav';
    
    final newName = _titleController.text.trim();
    if (newName.isEmpty) {
      setState(() {
        _errorMessage = 'Filename cannot be empty';
      });
      return;
    }

    if (_startValue >= _endValue) {
      setState(() {
        _errorMessage = 'Start time must be before end time';
      });
      return;
    }

    setState(() {
      _isTrimming = true;
      _errorMessage = null;
    });

    try {
      final sourceFile = File(widget.songPath);
      final dir = sourceFile.parent.path;
      final outPath = '$dir/$newName$ext';

      if (await File(outPath).exists()) {
        setState(() {
          _isTrimming = false;
          _errorMessage = 'A file with this name already exists';
        });
        return;
      }

      if (pathLower.endsWith('.mp3')) {
        await rust_trimmer.trimMp3(
          inputPath: widget.songPath,
          outputPath: outPath,
          startSecs: _startValue,
          endSecs: _endValue,
        );
      } else {
        await rust_trimmer.trimWav(
          inputPath: widget.songPath,
          outputPath: outPath,
          startSecs: _startValue,
          endSecs: _endValue,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio trimmed successfully: "$newName"'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onStateChanged();
      }
    } catch (e) {
      setState(() {
        _isTrimming = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = _isFormatSupported();
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final hintColor = textColor?.withOpacity(0.5) ?? Colors.grey;

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Trim Audio',
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!supported) ...[
              const Icon(Icons.info_outline, color: Colors.orange, size: 48),
              const SizedBox(height: 12),
              Text(
                'Trim is currently supported for MP3 and WAV files only.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'M4A and FLAC format support is coming in a future update.',
                textAlign: TextAlign.center,
                style: TextStyle(color: hintColor, fontSize: 12),
              ),
            ] else ...[
              // Input Name
              TextField(
                controller: _titleController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Output Filename',
                  labelStyle: const TextStyle(color: AppColors.purple),
                  hintText: 'Enter file name',
                  hintStyle: TextStyle(color: hintColor),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.purple),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.purple, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Range slider info labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start Time', style: TextStyle(color: hintColor, fontSize: 12)),
                      Text(
                        _formatSeconds(_startValue),
                        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('End Time', style: TextStyle(color: hintColor, fontSize: 12)),
                      Text(
                        _formatSeconds(_endValue),
                        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Slider widget
              RangeSlider(
                values: RangeValues(_startValue, _endValue),
                min: 0.0,
                max: _totalDuration,
                activeColor: AppColors.purple,
                inactiveColor: hintColor.withOpacity(0.2),
                onChanged: _isTrimming
                    ? null
                    : (values) {
                        setState(() {
                          _startValue = values.start;
                          _endValue = values.end;
                        });
                      },
              ),
              // Trim duration preview
              Text(
                'Selected Length: ${_formatSeconds(_endValue - _startValue)} / ${_formatSeconds(_totalDuration)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: hintColor, fontSize: 12),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_isTrimming) ...[
                const SizedBox(height: 20),
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.purple),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTrimming ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        if (supported)
          TextButton(
            onPressed: _isTrimming ? null : _trimAudio,
            child: const Text(
              'Trim',
              style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
