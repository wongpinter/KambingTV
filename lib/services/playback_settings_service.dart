import 'package:shared_preferences/shared_preferences.dart';
import 'package:tha_player/tha_player.dart';

/// Manages playback buffering resilience and network optimization settings.
class PlaybackSettingsService {
  static const String _lowBandwidthKey = 'low_bandwidth_mode';

  /// Loads whether Slow Connection / Data Saver mode is active.
  static Future<bool> isLowBandwidthMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lowBandwidthKey) ?? false;
  }

  /// Persists Slow Connection / Data Saver preference.
  static Future<void> setLowBandwidthMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lowBandwidthKey, enabled);
  }

  /// Returns optimized playback options designed for slow or unstable mobile/Wi-Fi connections.
  static ThaPlaybackOptions resilientPlaybackOptions() {
    return const ThaPlaybackOptions(
      maxRetryCount: -1, // Infinite resilient retries on packet drops / timeout
      initialRetryDelay: Duration(milliseconds: 500),
      maxRetryDelay: Duration(seconds: 4),
      autoRetry: true,
      rebufferTimeout: Duration(seconds: 15),
    );
  }

  /// Builds initial player preferences with dataSaver bitrate cap (800 kbps) when enabled.
  static ThaPlayerPreferences initialPreferences({required bool dataSaver}) {
    return ThaPlayerPreferences(
      dataSaver: dataSaver,
    );
  }
}
