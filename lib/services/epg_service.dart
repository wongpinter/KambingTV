import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/epg_programme.dart';

class EpgService {
  static const defaultFeedUrl =
      'https://raw.githubusercontent.com/dhasap/dhanytv/main/epg.xml';
  static const indonesiaEpgUrl = 'https://epg.lat/files/id.xml.gz';
  static const feedUrl = defaultFeedUrl; // Backwards compatibility

  static const Map<String, String> countryEpgFeeds = {
    'id': 'https://epg.lat/files/id.xml.gz', // Indonesia
    'us': 'https://epg.lat/files/us.xml.gz', // United States
    'uk': 'https://epg.lat/files/uk.xml.gz', // United Kingdom
    'sg': 'https://epg.lat/files/sg.xml.gz', // Singapore
    'my': 'https://epg.lat/files/my.xml.gz', // Malaysia
    'in': 'https://epg.lat/files/in.xml.gz', // India
    'jp': 'https://epg.lat/files/jp.xml.gz', // Japan
    'kr': 'https://epg.lat/files/kr.xml.gz', // South Korea
    'de': 'https://epg.lat/files/de.xml.gz', // Germany
    'fr': 'https://epg.lat/files/fr.xml.gz', // France
    'es': 'https://epg.lat/files/es.xml.gz', // Spain
    'it': 'https://epg.lat/files/it.xml.gz', // Italy
    'br': 'https://epg.lat/files/br.xml.gz', // Brazil
    'ca': 'https://epg.lat/files/ca.xml.gz', // Canada
    'au': 'https://epg.lat/files/au.xml.gz', // Australia
    'tr': 'https://epg.lat/files/tr.xml.gz', // Turkey
    'sa': 'https://epg.lat/files/sa.xml.gz', // Saudi Arabia
    'ae': 'https://epg.lat/files/ae.xml.gz', // UAE
    'th': 'https://epg.lat/files/th.xml.gz', // Thailand
    'vn': 'https://epg.lat/files/vn.xml.gz', // Vietnam
    'ph': 'https://epg.lat/files/ph.xml.gz', // Philippines
    'nl': 'https://epg.lat/files/nl.xml.gz', // Netherlands
    'pl': 'https://epg.lat/files/pl.xml.gz', // Poland
    'pt': 'https://epg.lat/files/pt.xml.gz', // Portugal
    'ru': 'https://epg.lat/files/ru.xml.gz', // Russia
    'mx': 'https://epg.lat/files/mx.xml.gz', // Mexico
    'ar': 'https://epg.lat/files/ar.xml.gz', // Argentina
    'cl': 'https://epg.lat/files/cl.xml.gz', // Chile
    'co': 'https://epg.lat/files/co.xml.gz', // Colombia
    'za': 'https://epg.lat/files/za.xml.gz', // South Africa
    'nz': 'https://epg.lat/files/nz.xml.gz', // New Zealand
    'no': 'https://epg.lat/files/no.xml.gz', // Norway
    'se': 'https://epg.lat/files/se.xml.gz', // Sweden
    'dk': 'https://epg.lat/files/dk.xml.gz', // Denmark
    'fi': 'https://epg.lat/files/fi.xml.gz', // Finland
    'be': 'https://epg.lat/files/be.xml.gz', // Belgium
    'ch': 'https://epg.lat/files/ch.xml.gz', // Switzerland
    'at': 'https://epg.lat/files/at.xml.gz', // Austria
    'cz': 'https://epg.lat/files/cz.xml.gz', // Czech Republic
    'hu': 'https://epg.lat/files/hu.xml.gz', // Hungary
    'ro': 'https://epg.lat/files/ro.xml.gz', // Romania
    'gr': 'https://epg.lat/files/gr.xml.gz', // Greece
    'eg': 'https://epg.lat/files/eg.xml.gz', // Egypt
    'dz': 'https://epg.lat/files/dz.xml.gz', // Algeria
    'ma': 'https://epg.lat/files/ma.xml.gz', // Morocco
    'pe': 'https://epg.lat/files/pe.xml.gz', // Peru
    'uy': 'https://epg.lat/files/uy.xml.gz', // Uruguay
    'ec': 'https://epg.lat/files/ec.xml.gz', // Ecuador
    'cr': 'https://epg.lat/files/cr.xml.gz', // Costa Rica
    'pa': 'https://epg.lat/files/pa.xml.gz', // Panama
    'do': 'https://epg.lat/files/do.xml.gz', // Dominican Republic
  };

  final http.Client _client;

  EpgService({http.Client? client}) : _client = client ?? http.Client();

  /// Decodes raw response bytes, automatically decompressing if GZIP encoded.
  static String decodeResponseBody(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
      try {
        final decompressed = gzip.decode(bytes);
        return utf8.decode(decompressed, allowMalformed: true);
      } catch (_) {
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Fetches XMLTV programmes from a specific URL or country code.
  Future<List<EpgProgramme>> fetchProgrammes({
    String? url,
    String? countryCode,
  }) async {
    final targetUrl = url ??
        (countryCode != null ? countryEpgFeeds[countryCode.toLowerCase()] : null) ??
        defaultFeedUrl;

    final response = await _client.get(
      Uri.parse(targetUrl),
      headers: const {
        'Accept': 'application/xml, application/octet-stream, */*',
        'User-Agent': 'Mozilla/5.0 (compatible; KambingTV/1.0)',
      },
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('EPG request failed (${response.statusCode}) from $targetUrl');
    }

    final xmlString = decodeResponseBody(response.bodyBytes);
    final rows = await compute(parseXmltvRows, xmlString);
    return rows.map(EpgProgramme.fromMap).toList(growable: false);
  }

  /// Fetches and merges programmes from multiple EPG sources in parallel.
  Future<List<EpgProgramme>> fetchCombinedProgrammes({
    List<String>? urls,
  }) async {
    final feedUrls = urls ?? [defaultFeedUrl, indonesiaEpgUrl];
    final results = await Future.wait(
      feedUrls.map((feed) async {
        try {
          return await fetchProgrammes(url: feed);
        } catch (_) {
          return <EpgProgramme>[];
        }
      }),
    );

    final merged = <String, EpgProgramme>{};
    for (final list in results) {
      for (final programme in list) {
        final key = '${programme.channelId}:${programme.start.millisecondsSinceEpoch}';
        merged.putIfAbsent(key, () => programme);
      }
    }

    final combinedList = merged.values.toList();
    combinedList.sort((a, b) {
      final chComp = a.channelId.compareTo(b.channelId);
      return chComp != 0 ? chComp : a.start.compareTo(b.start);
    });
    return combinedList;
  }

  void dispose() => _client.close();
}

@visibleForTesting
List<Map<String, Object?>> parseXmltvRows(String source) {
  final document = XmlDocument.parse(source);
  final programmes = <Map<String, Object?>>[];

  for (final element in document.findAllElements('programme')) {
    final channelId = element.getAttribute('channel')?.trim();
    final start = _parseXmltvDate(element.getAttribute('start'));
    final stop = _parseXmltvDate(element.getAttribute('stop'));
    final titleElements = element.findElements('title');
    if (channelId == null ||
        start == null ||
        stop == null ||
        stop.isBefore(start) ||
        titleElements.isEmpty) {
      continue;
    }

    final title = titleElements.first.innerText.trim();
    if (title.isEmpty) continue;
    final descriptions = element.findElements('desc');
    final description = descriptions.isEmpty
        ? null
        : descriptions.first.innerText.trim();
    programmes.add({
      'channelId': channelId,
      'title': title,
      'start': start.millisecondsSinceEpoch,
      'stop': stop.millisecondsSinceEpoch,
      'description': description?.isEmpty == true ? null : description,
    });
  }

  programmes.sort((a, b) {
    final channelOrder = (a['channelId']! as String).compareTo(
      b['channelId']! as String,
    );
    return channelOrder != 0
        ? channelOrder
        : (a['start']! as int).compareTo(b['start']! as int);
  });
  return programmes;
}

DateTime? _parseXmltvDate(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{14})\s*([+-]\d{4})?$').firstMatch(value.trim());
  if (match == null) return null;

  final digits = match.group(1)!;
  final year = int.parse(digits.substring(0, 4));
  final month = int.parse(digits.substring(4, 6));
  final day = int.parse(digits.substring(6, 8));
  final hour = int.parse(digits.substring(8, 10));
  final minute = int.parse(digits.substring(10, 12));
  final second = int.parse(digits.substring(12, 14));

  final offset = match.group(2);
  final baseUtc = DateTime.utc(year, month, day, hour, minute, second);
  if (offset == null) return baseUtc;

  final sign = offset.startsWith('-') ? -1 : 1;
  final offsetHours = int.parse(offset.substring(1, 3));
  final offsetMinutes = int.parse(offset.substring(3, 5));
  final totalOffset = Duration(
    hours: offsetHours * sign,
    minutes: offsetMinutes * sign,
  );
  return baseUtc.subtract(totalOffset);
}
