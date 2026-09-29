import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/common/splash_screen.dart';
import 'services/push_service.dart';
import 'widgets/floating_ai_button.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  unawaited(PushService.instance.init());

  runApp(const FandomVerseApp());
}

class FandomVerseApp extends StatelessWidget {
  const FandomVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fandom Verse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      navigatorKey: FanAssistant.navigatorKey,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.topLeft,
          children: [
            child ?? const SizedBox.shrink(),
            const Positioned.fill(child: FloatingAiOverlay()),
          ],
        );
      },
      home: const SplashScreen(),
    );
  }
}
