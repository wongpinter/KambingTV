import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/models/channel.dart';
import 'package:opentv/services/cast_manager.dart';
import 'package:dart_cast/dart_cast.dart';

void main() {
  group('CastManager tests', () {
    test('initializes with default state', () {
      final manager = CastManager.instance;
      expect(manager.isScanning.value, isFalse);
      expect(manager.isCasting, isFalse);
      expect(manager.connectedDevice.value, isNull);
      expect(manager.sessionState.value, equals(SessionState.disconnected));
      expect(manager.discoveredDevices.value, isEmpty);
      expect(manager.castingChannel.value, isNull);
    });

    test('detects correct media types from channel URLs', () {
      const hlsChannel = Channel(
        name: 'HLS Live Stream',
        url: 'https://example.com/live/playlist.m3u8',
        group: 'News',
      );
      expect(hlsChannel.url.endsWith('.m3u8'), isTrue);

      const mp4Channel = Channel(
        name: 'VOD Channel',
        url: 'https://example.com/videos/stream.mp4',
        group: 'Movies',
      );
      expect(mp4Channel.url.endsWith('.mp4'), isTrue);

      const tsChannel = Channel(
        name: 'Transport Stream',
        url: 'http://example.com:8080/live/user/pass/123.ts',
        group: 'General',
      );
      expect(tsChannel.url.endsWith('.ts'), isTrue);
    });
  });
}
