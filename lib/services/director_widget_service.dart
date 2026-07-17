import 'package:flutter/services.dart';

class DirectorWidgetService {
  static const MethodChannel _channel = MethodChannel(
    'org.ciani01.noti/director_widget',
  );

  Future<void> initialize(void Function() onOpen) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openDirectorSongDelivery') onOpen();
    });

    final launchedFromWidget =
        await _channel.invokeMethod<bool>('getLaunchAction') ?? false;
    if (launchedFromWidget) onOpen();
  }
}
