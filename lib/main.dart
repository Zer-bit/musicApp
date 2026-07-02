import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:async';

import 'app.dart';
import 'core/audio_handler.dart';
import 'core/services/audio_service.dart';
import 'core/services/theme_service.dart';
import 'src/rust/frb_generated.dart';

export 'core/theme/app_colors.dart' show AppColors;
export 'core/services/audio_service.dart' show GlobalAudioService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await ThemeService().init();

  // runApp() MUST be called BEFORE AudioService.init().
  // AudioService.init() binds to MediaBrowserServiceCompat which requires
  // the Android Activity to be in the 'Started' state — only guaranteed
  // after runApp() has been called. Calling it before runApp() in release
  // mode (AOT) causes an immediate native crash ('jezsic has stopped').
  //
  // The LoadingScreen waits up to 10 seconds for the handler to be ready
  // before allowing any user interaction.
  runApp(const MyApp());

  // Fire-and-forget: audio init runs after the Activity is fully started.
  _initializeAudioServices();
}

Future<void> _initializeAudioServices() async {
  // Retry up to 3 times – transient failures on first launch are common
  // especially on Android where the MediaBrowser service binding can be slow.
  for (int attempt = 0; attempt < 3; attempt++) {
    try {
      final audioHandler = await AudioService.init(
        builder: () => MyAudioHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.example.jezsic.channel.audio',
          androidNotificationChannelName: 'Music Playback',
          androidNotificationChannelDescription: 'Jezsic music player controls',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: false,
          androidNotificationIcon: 'drawable/ic_music_notification',
          androidShowNotificationBadge: true,
        ),
      );

      await GlobalAudioService().initialize(audioHandler);
      return; // Success – exit retry loop
    } catch (e) {
      if (attempt < 2) {
        // Brief back-off before retry
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
      // On the last attempt, silently give up so the app still launches
    }
  }
}
