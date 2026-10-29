import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opentv/services/playback_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlaybackSettingsService tests', () {
    test('defaults to lowBandwidthMode false and persists changes', () async {
      expect(await PlaybackSettingsService.isLowBandwidthMode(), isFalse);

      await PlaybackSettingsService.setLowBandwidthMode(true);
      expect(await PlaybackSettingsService.isLowBandwidthMode(), isTrue);

      await PlaybackSettingsService.setLowBandwidthMode(false);
      expect(await PlaybackSettingsService.isLowBandwidthMode(), isFalse);
    });

    test('resilientPlaybackOptions configures infinite auto-retry and delays', () {
      final options = PlaybackSettingsService.resilientPlaybackOptions();
      expect(options.autoRetry, isTrue);
      expect(options.maxRetryCount, equals(-1));
      expect(options.initialRetryDelay, equals(const Duration(milliseconds: 500)));
      expect(options.maxRetryDelay, equals(const Duration(seconds: 4)));
      expect(options.rebufferTimeout, equals(const Duration(seconds: 15)));
    });

    test('initialPreferences builds dataSaver flag', () {
      final prefsTrue = PlaybackSettingsService.initialPreferences(dataSaver: true);
      expect(prefsTrue.dataSaver, isTrue);

      final prefsFalse = PlaybackSettingsService.initialPreferences(dataSaver: false);
      expect(prefsFalse.dataSaver, isFalse);
    });
  });
}
