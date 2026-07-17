import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/app_settings_service.dart';
import 'services/director_widget_service.dart';
import 'services/notification_service.dart';
import 'services/splash_theme_service.dart';
import 'screens/home_screen.dart';
import 'screens/director_widget_entry_screen.dart';
import 'theme/noti_theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().showBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService().initialize();

  runApp(const NotiApp());
}

class NotiApp extends StatefulWidget {
  const NotiApp({super.key});

  @override
  State<NotiApp> createState() => _NotiAppState();
}

class _NotiAppState extends State<NotiApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _splashThemeService = SplashThemeService();
  final _settingsService = AppSettingsService();
  final _directorWidgetService = DirectorWidgetService();
  int? _cachedSplashColor;
  StreamSubscription? _settingsSubscription;
  NotiThemePreset _preset = NotiThemePreset.main;
  NotiAppearance _appearance = NotiAppearance.light;

  @override
  void initState() {
    super.initState();
    _settingsSubscription = _settingsService.watchSettings().listen(
      _applySettings,
      onError: (_) {
        // Keep the last known appearance when Firestore is temporarily offline.
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _directorWidgetService.initialize(_openDirectorWidget).catchError((_) {
        // The app remains usable if a device does not support home widgets.
      });
    });
  }

  void _openDirectorWidget() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(builder: (_) => const DirectorWidgetEntryScreen()),
    );
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }

  void _applySettings(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final preset = NotiThemePreset.fromStorage(data['themePreset'] as String?);
    final appearance = NotiAppearance.fromStorage(
      data['appearanceMode'] as String?,
    );
    _applyTheme(preset, appearance);
  }

  void _applyTheme(NotiThemePreset preset, NotiAppearance appearance) {
    if (preset == _preset && appearance == _appearance) return;

    final palette = NotiPalette.forPreset(preset, appearance: appearance);
    _cacheSplashColor(
      appearance == NotiAppearance.dark
          ? palette.primaryContainer
          : palette.primary,
    );

    setState(() {
      _preset = preset;
      _appearance = appearance;
    });
  }

  void _cacheSplashColor(Color color) {
    final argbColor = color.toARGB32();
    if (_cachedSplashColor == argbColor) return;
    _cachedSplashColor = argbColor;

    _splashThemeService.cacheBackgroundColor(argbColor).catchError((_) {
      // The Flutter interface remains fully themed if native caching fails.
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Noti',
      // Keep MaterialApp's navigator and inherited widgets stable. Changing
      // ThemeData directly here can invalidate an open dialog during a remote
      // settings update, so the live theme is applied inside the app builder.
      theme: NotiTheme.build(NotiThemePreset.main),
      builder: (context, child) => Theme(
        data: NotiTheme.build(_preset, appearance: _appearance),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}
