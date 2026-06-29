import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'features/loading/loading_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jezsic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: AppColors.purple,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.purple,
          secondary: AppColors.blue,
          surface: AppColors.surface,
        ),
      ),
      home: const LoadingScreen(),
    );
  }
}
