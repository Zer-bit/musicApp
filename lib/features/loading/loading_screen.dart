import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/services/audio_service.dart';
import '../home/home_screen.dart';
import 'vinyl_painter.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _vinylController;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;
  late AnimationController _textController;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;
  late AnimationController _waveController;
  late AnimationController _exitController;
  late Animation<double> _exitScale;

  static const int _barCount = 5;
  final List<double> _barPhases = List.generate(
    _barCount,
    (i) => i * (math.pi * 2 / _barCount),
  );

  @override
  void initState() {
    super.initState();

    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitScale = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeIn));

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    int timeout = 0;
    while (!GlobalAudioService().isReady && timeout < 50) {
      await Future.delayed(const Duration(milliseconds: 200));
      timeout++;
    }

    _exitController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, anim, anim2, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _vinylController.dispose();
    _glowController.dispose();
    _waveController.dispose();
    _textController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _vinylController,
          _glowAnim,
          _waveController,
          _titleFade,
          _subtitleFade,
          _exitController,
        ]),
        builder: (context, _) {
          final exitFade = 1.0 - _exitController.value;
          return Opacity(
            opacity: exitFade.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _exitScale.value,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  Center(
                    child: Opacity(
                      opacity: _glowAnim.value * 0.35,
                      child: Container(
                        width: 260 * _glowAnim.value,
                        height: 260 * _glowAnim.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).primaryColor,
                              blurRadius: 72,
                              spreadRadius: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: GestureDetector(
                      onDoubleTap: () {},
                      child: Transform.rotate(
                        angle: _vinylController.value * 2 * math.pi,
                        child: CustomPaint(
                          size: const Size(180, 180),
                          painter: VinylPainter(),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.8),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: size.height * 0.30,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(_barCount, (i) {
                        final phase = _barPhases[i];
                        final t = _waveController.value;
                        final height = 12.0 +
                            28.0 * (0.5 + 0.5 * math.sin(t * math.pi + phase));
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: 7,
                            height: height,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Positioned(
                    bottom: size.height * 0.18,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Opacity(
                          opacity: _titleFade.value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - _titleFade.value)),
                            child: Text(
                              'Jezsic',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.5),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: _subtitleFade.value,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - _subtitleFade.value)),
                            child: Text(
                              'Your music, your world',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.7),
                                letterSpacing: 2,
                                fontWeight: FontWeight.w300,
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
          );
        },
      ),
    );
  }
}
