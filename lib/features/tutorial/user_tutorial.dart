import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class TutorialSlide {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Gradient iconGradient;

  const TutorialSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.iconGradient,
  });
}

class UserTutorialDialog extends StatefulWidget {
  const UserTutorialDialog({super.key});

  /// Displays the interactive tutorial dialog.
  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const UserTutorialDialog();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * animation.value,
            sigmaY: 8 * animation.value,
          ),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<UserTutorialDialog> createState() => _UserTutorialDialogState();
}

class _UserTutorialDialogState extends State<UserTutorialDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialSlide> _slides = [
    TutorialSlide(
      icon: Icons.music_note_rounded,
      title: "Welcome to Void",
      subtitle: "Premium Audio Player & Downloader",
      description:
          "Void combines offline local audio playback with online YouTube downloads. Let's take a quick 1-minute tour of the key features to get you started!",
      iconGradient: AppColors.purpleBlueGradient,
    ),
    TutorialSlide(
      icon: Icons.library_music_rounded,
      title: "Local Library",
      subtitle: "Scan & Manage Audio Files",
      description:
          "Tap the Settings gear icon at the top of the All Songs tab to scan your device storage for music. Tap any track's options (...) to rename/delete, view size and path details, or write/edit lyrics.",
      iconGradient: AppColors.bluePurpleGradient,
    ),
    TutorialSlide(
      icon: Icons.playlist_play_rounded,
      title: "Custom Playlists",
      subtitle: "Organize & Auto-Favorites",
      description:
          "Create and organize custom folders in the Playlists tab. The system also tracks your top 10 most played tracks and compiles them automatically under the Favorites playlist.",
      iconGradient: AppColors.accentGradient,
    ),
    TutorialSlide(
      icon: Icons.cloud_download_rounded,
      title: "Search & Downloader",
      subtitle: "Offline Media Browser",
      description:
          "Paste a YouTube link or type keywords in the Browse tab to search. Hit the Download button to stream and save tracks as offline audio files directly to your device.",
      iconGradient: AppColors.lightGradient,
    ),
    TutorialSlide(
      icon: Icons.bluetooth_connected_rounded,
      title: "Smart Features",
      subtitle: "Bluetooth & Sleep Timers",
      description:
          "Enjoy background controls. Playback automatically pauses when headphones disconnect and resumes when reconnected. Tap the Settings gear icon to set a sleep timer.",
      iconGradient: AppColors.darkGradient,
    ),
    TutorialSlide(
      icon: Icons.swap_horizontal_circle_rounded,
      title: "Local Converter",
      subtitle: "Transcode Video & Recording",
      description:
          "Extract audio losslessly from local MP4 video container to M4A instantly. You can also record voice notes, name them immediately, and transcode to MP3 entirely offline.",
      iconGradient: AppColors.purpleBlueGradient,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Responsive design dimensions
    final double dialogWidth = size.width * (isLandscape ? 0.6 : 0.85);
    final double dialogHeight = size.height * (isLandscape ? 0.85 : 0.7);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth.clamp(300.0, 480.0),
          height: dialogHeight.clamp(400.0, 580.0),
          decoration: BoxDecoration(
            color: const Color(0xFF080808).withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.purple.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with title and Skip button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: AppColors.purpleBlueGradient,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Void Guide',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              // Page Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 2),
                          // Premium glowing icon container
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: slide.iconGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: (slide.iconGradient as LinearGradient)
                                      .colors
                                      .first
                                      .withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              slide.icon,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(flex: 2),
                          // Title & Subtitle
                          Text(
                            slide.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            slide.subtitle,
                            style: const TextStyle(
                              color: AppColors.blueLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Spacer(flex: 1),
                          // Scrollable body description to avoid any overflow issues
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                slide.description,
                                style: TextStyle(
                                  color: Colors.grey.shade300,
                                  fontSize: 14,
                                  height: 1.5,
                                  letterSpacing: 0.1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom control section
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    AnimatedOpacity(
                      opacity: _currentPage > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _currentPage == 0,
                        child: TextButton(
                          onPressed: _previousPage,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade400,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),

                    // Page Dots Indicator
                    Row(
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          height: 6.0,
                          width: _currentPage == index ? 18.0 : 6.0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3.0),
                            gradient: _currentPage == index
                                ? AppColors.purpleBlueGradient
                                : LinearGradient(
                                    colors: [
                                      Colors.grey.shade800,
                                      Colors.grey.shade800
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),

                    // Next / Finish Button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: AppColors.purpleBlueGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.purple.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _currentPage == _slides.length - 1
                              ? 'Finish'
                              : 'Next',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
