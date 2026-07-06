import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'core/services/theme_service.dart';
import 'features/loading/loading_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ThemeService _themeService = ThemeService();
  late AnimationController _fadeController;
  Brightness? _lastBrightness;
  Color _overlayColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    WidgetsBinding.instance.addObserver(this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeService.themeMode == ThemeMode.system) {
      setState(() {});
    }
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dark Theme (Original theme styling)
    final darkTheme = ThemeData.dark().copyWith(
      primaryColor: AppColors.purple,
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.purple,
        secondary: AppColors.blue,
        surface: AppColors.surface,
      ),
    );

    // Light Theme
    final lightTheme = ThemeData.light().copyWith(
      primaryColor: AppColors.purple,
      scaffoldBackgroundColor: Colors.white,
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.purple,
        secondary: AppColors.blue,
        surface: Colors.white,
      ),
    );

    // Resolve active theme data based on ThemeMode and system dispatcher brightness
    final systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = _themeService.themeMode == ThemeMode.dark ||
        (_themeService.themeMode == ThemeMode.system &&
            systemBrightness == Brightness.dark);
    final activeTheme = isDark ? darkTheme : lightTheme;
    final currentBrightness = activeTheme.brightness;

    // Detect theme brightness switches and trigger a smooth overlay transition
    if (_lastBrightness != null && _lastBrightness != currentBrightness) {
      _overlayColor = _lastBrightness == Brightness.dark
          ? AppColors.background
          : Colors.white;
      _fadeController.forward(from: 0.0);
    }
    _lastBrightness = currentBrightness;

    return MaterialApp(
      title: 'Void',
      debugShowCheckedModeBanner: false,
      theme: activeTheme,
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            AnimatedBuilder(
              animation: _fadeController,
              builder: (context, _) {
                final opacity = (1.0 - _fadeController.value).clamp(0.0, 1.0);
                if (opacity <= 0.001) {
                  return const SizedBox.shrink();
                }
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: _overlayColor.withOpacity(opacity),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
      home: const LoadingScreen(),
    );
  }
}
