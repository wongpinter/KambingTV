import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/services/playlist_service.dart';
import 'package:tha_player/tha_player.dart';

void main() {
  group('PlaylistService.parseM3u', () {
    test('parses metadata, headers, and Widevine license configuration', () {
      final service = PlaylistService();
      addTearDown(service.dispose);

      final channels = service.parseM3u('''
#EXTM3U
#EXTVLCOPT:http-user-agent=TV Client
#EXTINF:-1 tvg-id="news.id" tvg-logo="https://example.com/logo.png" group-title="News",News One
#KODIPROP:inputstream.adaptive.license_type=com.widevine.alpha
#KODIPROP:inputstream.adaptive.license_key=https://license.example/key|Authorization=Bearer demo
https://stream.example/live.mpd
''');

      expect(channels, hasLength(1));
      final channel = channels.single;
      expect(channel.name, 'News One');
      expect(channel.id, 'news.id');
      expect(channel.group, 'News');
      expect(channel.headers['User-Agent'], 'TV Client');
      expect(channel.drm.type, ThaDrmType.widevine);
      expect(channel.drm.licenseUrl, 'https://license.example/key');
      expect(channel.drm.headers?['Authorization'], 'Bearer demo');
    });

    test('preserves headers declared before EXTINF and skips invalid URLs', () {
      final service = PlaylistService();
      addTearDown(service.dispose);

      final channels = service.parseM3u('''
#EXTINF:-1 group-title="General",Invalid channel
not-a-url
#EXTVLCOPT:http-referrer=https://origin.example/
#EXTINF:-1 group-title="General",Channel Two
https://stream.example/two.m3u8
''');

      expect(channels, hasLength(1));
      expect(channels.single.headers['Referer'], 'https://origin.example/');
    });

    test('parses generated dhanytv_live.m3u successfully', () async {
      final file = File('dhanytv_live.m3u');
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      final service = PlaylistService();
      addTearDown(service.dispose);
      final channels = service.parseM3u(content);

      expect(channels.length, equals(6695));
      final inews = channels.firstWhere((c) => c.id == 'iNews.id');
      expect(inews.name, contains('iNews'));
    });

    test('parses generated dhanytv_live_ott.m3u successfully', () async {
      final file = File('dhanytv_live_ott.m3u');
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      final service = PlaylistService();
      addTearDown(service.dispose);
      final channels = service.parseM3u(content);

      expect(channels.length, equals(6589));
    });

    test('automatically removes dead streams when filterDead is enabled', () {
      final service = PlaylistService();
      addTearDown(service.dispose);

      const m3uWithDead = '''
#EXTM3U
#EXTINF:-1 group-title="Indo",Live iNews
https://live.i-news.tv/hls/stream.m3u8
#EXTINF:-1 group-title="Indo",Dead MalingTV
https://mncmedia.malingtv.workers.dev/rcti.m3u8
#EXTINF:-1 group-title="Indo",Dead Indihome Internal
http://119.82.250.109:8080/nl.m3u8?id=1145
''';

      final filtered = service.parseM3u(m3uWithDead, filterDead: true);
      expect(filtered.length, equals(1));
      expect(filtered.single.name, equals('Live iNews'));

      final unfiltered = service.parseM3u(m3uWithDead, filterDead: false);
      expect(unfiltered.length, equals(3));
    });
  });
}
