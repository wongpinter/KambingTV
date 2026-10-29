import 'package:flutter/services.dart';

class BackgroundPlaybackService {
  static const _channel = MethodChannel('com.opentv.opentv/background_playback');

  static Future<void> start(String title) async {
    try {
      await _channel.invokeMethod('start', {'title': title});
    } catch (_) {
      // Ignored on non-Android platforms or during widget tests
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {
      // Ignored on non-Android platforms or during widget tests
    }
  }
}
