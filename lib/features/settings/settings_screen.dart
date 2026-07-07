import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/audio_service.dart';
import '../all_songs/dialogs/sleep_timer_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final GlobalAudioService audioService;
  final VoidCallback onScanLibrary;

  const SettingsScreen({
    super.key,
    required this.audioService,
    required this.onScanLibrary,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _accentColor = Color(0xFF854F6C);
  
  final ThemeService _themeService = ThemeService();
  String _defaultFormat = 'mp3';
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultFormat = _prefs.getString('converter_default_format') ?? 'mp3';
    });
  }

  Future<void> _setDefaultFormat(String format) async {
    await _prefs.setString('converter_default_format', format);
    setState(() {
      _defaultFormat = format;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFF8F8F8) : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF191919) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // --- Section: Preferences ---
          _buildSectionHeader('PREFERENCES'),
          _buildSettingsCard([
            _buildThemeOptionTile(context, isDark),
            const Divider(height: 1, color: Colors.grey),
            _buildFormatOptionTile(context, isDark),
            const Divider(height: 1, color: Colors.grey),
            _buildSleepTimerTile(context, isDark),
          ], isDark),

          const SizedBox(height: 24),

          // --- Section: Storage & Library ---
          _buildSectionHeader('STORAGE & REFRESH'),
          _buildSettingsCard([
            ListTile(
              leading: const Icon(Icons.sync_outlined, color: _accentColor),
              title: Text(
                'Scan Audio Files',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Scan storage folders for new songs',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onScanLibrary();
              },
            ),
          ], isDark),

          const SizedBox(height: 24),

          // --- Section: Legal & Compliance ---
          _buildSectionHeader('LEGAL & COMPLIANCE'),
          _buildSettingsCard([
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: _accentColor),
              title: Text(
                'Privacy Policy',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Understand how we protect your offline data',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () => _showPrivacyPolicy(context, isDark, textColor),
            ),
            const Divider(height: 1, color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.gavel_outlined, color: _accentColor),
              title: Text(
                'Terms of Service',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Agreement on personal use rules',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () => _showTermsOfService(context, isDark, textColor),
            ),
            const Divider(height: 1, color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: _accentColor),
              title: Text(
                'Open Source Licenses',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Software and library credits',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () => _showLicenses(context, isDark, textColor),
            ),
            const Divider(height: 1, color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.copyright_outlined, color: _accentColor),
              title: Text(
                'Application License (MIT)',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Read Void open source distribution terms',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () => _showMitLicense(context, isDark, textColor),
            ),
          ], isDark),

          const SizedBox(height: 32),

          // --- Section: About ---
          Center(
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentColor.withOpacity(0.15),
                  ),
                  child: const Icon(
                    Icons.audiotrack,
                    color: _accentColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Void Player & Converter',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Developed by solo developer @Zer-bit',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Version 1.0.0 • Pure-Rust Core • Open Source',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Licensed under MIT',
                  style: TextStyle(
                    color: _accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _accentColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildThemeOptionTile(BuildContext context, bool isDark) {
    final themeStr = _themeService.themeMode == ThemeMode.system
        ? 'System'
        : _themeService.themeMode == ThemeMode.dark
            ? 'Dark'
            : 'Light';

    return ListTile(
      leading: const Icon(Icons.palette_outlined, color: _accentColor),
      title: Text(
        'App Theme',
        style: TextStyle(
          color: isDark ? const Color(0xFFF8F8F8) : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text('Current theme: $themeStr', style: const TextStyle(color: Colors.grey)),
      trailing: DropdownButton<ThemeMode>(
        value: _themeService.themeMode,
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        underline: const SizedBox(),
        onChanged: (ThemeMode? value) {
          if (value != null) {
            setState(() {
              _themeService.setThemeMode(value);
            });
          }
        },
        items: const [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('System Default'),
          ),
          DropdownMenuItem(
            value: ThemeMode.light,
            child: Text('Light Mode'),
          ),
          DropdownMenuItem(
            value: ThemeMode.dark,
            child: Text('Dark Mode'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOptionTile(BuildContext context, bool isDark) {
    return ListTile(
      leading: const Icon(Icons.swap_horiz_outlined, color: _accentColor),
      title: Text(
        'Default Convert Format',
        style: TextStyle(
          color: isDark ? const Color(0xFFF8F8F8) : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text('Currently set to: ${_defaultFormat.toUpperCase()}', style: const TextStyle(color: Colors.grey)),
      trailing: DropdownButton<String>(
        value: _defaultFormat,
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        underline: const SizedBox(),
        onChanged: (String? value) {
          if (value != null) {
            _setDefaultFormat(value);
          }
        },
        items: const [
          DropdownMenuItem(
            value: 'mp3',
            child: Text('MP3'),
          ),
          DropdownMenuItem(
            value: 'm4a',
            child: Text('M4A (AAC)'),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTimerTile(BuildContext context, bool isDark) {
    final hasActiveTimer = widget.audioService.sleepTimer != null;
    final statusStr = hasActiveTimer ? 'Active' : 'Inactive';

    return ListTile(
      leading: Icon(
        Icons.timer_outlined,
        color: hasActiveTimer ? AppColors.purple : _accentColor,
      ),
      title: Text(
        'Sleep Timer',
        style: TextStyle(
          color: isDark ? const Color(0xFFF8F8F8) : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text('Timer status: $statusStr', style: const TextStyle(color: Colors.grey)),
      onTap: () {
        showSleepTimerDialog(context, widget.audioService, () {
          setState(() {});
        });
      },
    );
  }

  void _showPrivacyPolicy(BuildContext context, bool isDark, Color textColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF191919) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.privacy_tip_outlined, color: _accentColor),
            const SizedBox(width: 10),
            Text('Privacy Policy', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'At Void, we treat your privacy with extreme responsibility. The app works entirely offline.',
                style: TextStyle(color: textColor, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildBulletPoint('1. On-Device Native Processing',
                  'All audio indexing, recording, conversions, and metadata slicing are done natively using a pure compiled Rust FFI backend. No audio tracks are uploaded or sent to servers.',
                  textColor),
              _buildBulletPoint('2. Zero Tracking',
                  'We do not collect personal profiles, device locations, search queries, or analytics. Your playlist files stay securely stored in local device cache.',
                  textColor),
              _buildBulletPoint('3. Offline Integrity',
                  'Since no database syncs to external systems, your favorite songs, play counts, and customized lyrics are completely local to your device.',
                  textColor),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _accentColor),
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context, bool isDark, Color textColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF191919) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.gavel_outlined, color: _accentColor),
            const SizedBox(width: 10),
            Text('Terms of Service', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please read this agreement before using Void:',
                style: TextStyle(color: textColor, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildBulletPoint('1. Personal Use Guidelines',
                  'Void is designed strictly for private, non-commercial, personal entertainment purposes. Commercial scaling or public execution of processed media is forbidden.',
                  textColor),
              _buildBulletPoint('2. Content Responsibility',
                  'You hold full legal responsibility for files you record, transcode, or search. Ensure you possess proper copyright license authorizations before storing media on your disk.',
                  textColor),
              _buildBulletPoint('3. Software Disclaimers',
                  'Void provides media playback and transcoding services "as is" without warranty or representations of correct container decoding or hardware acceleration.',
                  textColor),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _accentColor),
            onPressed: () => Navigator.pop(context),
            child: const Text('Agree', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLicenses(BuildContext context, bool isDark, Color textColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF191919) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: _accentColor),
            const SizedBox(width: 10),
            Text('Software Licenses', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Void is built with high-quality open-source components:',
                style: TextStyle(color: textColor, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildBulletPoint('Rust Native Engine', 'symphonia, mp4-rust, shine-rs, lofty-rs, walkdir', textColor),
              _buildBulletPoint('Dart-Rust FFI Bridge', 'flutter_rust_bridge (fzyzcjy)', textColor),
              _buildBulletPoint('Audio Playback Service', 'just_audio, audio_service (Ryan Heise)', textColor),
              _buildBulletPoint('Recording Library', 'record_audio (mArC01)', textColor),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _accentColor),
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMitLicense(BuildContext context, bool isDark, Color textColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF191919) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.copyright_outlined, color: _accentColor),
            const SizedBox(width: 10),
            Text('MIT License', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Copyright (c) 2026 Void Developers',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 12),
              Text(
                'Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _accentColor),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String title, String desc, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 6, color: _accentColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 14.0),
            child: Text(
              desc,
              style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
