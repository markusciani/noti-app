import 'dart:io';

import 'package:flutter/services.dart';

class SplashThemeService {
  static const _channel = MethodChannel('org.ciani01.noti/splash_theme');

  Future<void> cacheBackgroundColor(int argbColor) async {
    if (!Platform.isAndroid) return;

    await _channel.invokeMethod<void>('cacheBackgroundColor', {
      'argbColor': argbColor,
    });
  }
}
