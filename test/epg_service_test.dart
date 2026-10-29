import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/models/epg_programme.dart';
import 'package:opentv/services/epg_service.dart';

void main() {
  group('parseXmltvRows', () {
    test('parses titles, descriptions, and XMLTV timezone offsets', () {
      final rows = parseXmltvRows('''
<tv>
  <programme start="20261028003000 +0700" stop="20261028013000 +0700" channel="news.id">
    <title lang="id">News &amp; Weather</title>
    <desc>Evening update</desc>
  </programme>
</tv>
''');

      expect(rows, hasLength(1));
      final programme = EpgProgramme.fromMap(rows.single);
      expect(programme.channelId, 'news.id');
      expect(programme.title, 'News & Weather');
      expect(programme.description, 'Evening update');
      expect(programme.start, DateTime.utc(2026, 10, 27, 17, 30));
      expect(programme.stop, DateTime.utc(2026, 10, 27, 18, 30));
    });

    test('skips malformed or incomplete programme entries', () {
      final rows = parseXmltvRows('''
<tv>
  <programme start="bad" stop="bad" channel="broken"><title>Broken</title></programme>
  <programme start="20261028003000 +0700" stop="20261028013000 +0700" channel="no-title"></programme>
  <programme start="20261028003000 +0700" stop="20261028013000 +0700" channel="valid"><title>Valid</title></programme>
</tv>
''');

      expect(rows, hasLength(1));
      expect(rows.single['channelId'], 'valid');
    });
  });

  group('EpgService decompression and directory', () {
    test('decodeResponseBody handles plain UTF-8 bytes', () {
      final text = '<tv><channel id="test"/></tv>';
      final bytes = text.codeUnits;
      expect(EpgService.decodeResponseBody(bytes), text);
    });

    test('decodeResponseBody automatically decompresses GZIP bytes', () {
      const xml = '<tv><title>Compressed Guide</title></tv>';
      final gzippedBytes = gzip.encode(utf8.encode(xml));
      expect(EpgService.decodeResponseBody(gzippedBytes), contains('Compressed Guide'));
    });

    test('countryEpgFeeds includes feeds from ge.m3uiptv.com directory', () {
      expect(EpgService.countryEpgFeeds.containsKey('id'), isTrue);
      expect(EpgService.countryEpgFeeds['id'], 'https://epg.lat/files/id.xml.gz');
      expect(EpgService.countryEpgFeeds.containsKey('us'), isTrue);
      expect(EpgService.countryEpgFeeds.containsKey('uk'), isTrue);
      expect(EpgService.countryEpgFeeds.containsKey('sg'), isTrue);
      expect(EpgService.countryEpgFeeds.containsKey('my'), isTrue);
    });
  });
}
