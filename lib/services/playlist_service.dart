import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import 'dead_streams.dart';

class PlaylistService {
  static const liveAssetPath = 'assets/dhanytv_live.m3u';
  static const liveOttAssetPath = 'assets/dhanytv_live_ott.m3u';
  static const playlistUrl =
      'https://raw.githubusercontent.com/dhasap/dhanytv/main/dhanytv.m3u';
  static const iptvOrgIndonesiaUrl =
      'https://iptv-org.github.io/iptv/countries/id.m3u';
  static const iptvOrgGlobalUrl =
      'https://iptv-org.github.io/iptv/index.m3u';
  static const epgUrl =
      'https://raw.githubusercontent.com/dhasap/dhanytv/main/epg.xml';

  final http.Client _client;

  PlaylistService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Channel>> fetchChannels({
    String? sourceUrl,
    bool preferAsset = true,
    bool filterDead = true,
  }) async {
    final targetUrl = sourceUrl ?? playlistUrl;
    if (preferAsset && sourceUrl == null) {
      try {
        final assetContent = await rootBundle.loadString(liveAssetPath);
        final channels = parseM3u(assetContent, filterDead: filterDead);
        if (channels.isNotEmpty) {
          return channels;
        }
      } catch (_) {
        // Fall back to remote network request if asset is missing or in tests
      }
    }

    final response = await _client
        .get(Uri.parse(targetUrl), headers: const {'Accept': 'text/plain'})
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) {
      throw Exception('Playlist request failed (${response.statusCode})');
    }
    return parseM3u(utf8.decode(response.bodyBytes), filterDead: filterDead);
  }

  Future<List<Channel>> fetchFromUrl(String url, {bool filterDead = true}) async {
    final response = await _client
        .get(Uri.parse(url), headers: const {'Accept': 'text/plain'})
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) {
      throw Exception('Request to $url failed (${response.statusCode})');
    }
    return parseM3u(utf8.decode(response.bodyBytes), filterDead: filterDead);
  }

  List<Channel> parseM3u(String source, {bool filterDead = true}) {
    final channels = <Channel>[];
    String? info;
    String? licenseType;
    String? licenseKey;
    final headers = <String, String>{};
    final licenseHeaders = <String, String>{};

    void resetEntry() {
      info = null;
      licenseType = null;
      licenseKey = null;
      headers.clear();
      licenseHeaders.clear();
    }

    for (final rawLine in const LineSplitter().convert(source)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#EXTM3U')) continue;

      if (line.startsWith('#EXTINF:')) {
        if (info != null) resetEntry();
        info = line.substring('#EXTINF:'.length);
      } else if (line.startsWith('#EXTHTTP:')) {
        _readJsonHeaders(line.substring('#EXTHTTP:'.length), headers);
      } else if (line.startsWith('#EXTVLCOPT:')) {
        _readVlcOption(line.substring('#EXTVLCOPT:'.length), headers);
      } else if (line.startsWith('#KODIPROP:')) {
        _readKodiProperty(
          line.substring('#KODIPROP:'.length),
          headers,
          licenseHeaders,
          (type, key) {
            licenseType = type ?? licenseType;
            licenseKey = key ?? licenseKey;
          },
        );
      } else if (!line.startsWith('#') && info != null) {
        final uri = Uri.tryParse(line);
        if (uri?.hasScheme == true &&
            (uri!.scheme == 'http' || uri.scheme == 'https')) {
          if (!filterDead || !isDeadStreamUrl(line)) {
            channels.add(
              Channel.fromPlaylistEntry(
                info: info!,
                url: line,
                headers: headers,
                licenseType: licenseType,
                licenseKey: licenseKey,
                licenseHeaders: licenseHeaders,
              ),
            );
          }
        }
        resetEntry();
      }
    }
    return channels;
  }

  void _readJsonHeaders(String json, Map<String, String> headers) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          headers[entry.key] = entry.value.toString();
        }
      }
    } on FormatException {
      // A malformed optional header line should not invalidate the playlist.
    }
  }

  void _readVlcOption(String option, Map<String, String> headers) {
    final separator = option.indexOf('=');
    if (separator < 1) return;
    final name = option.substring(0, separator).trim().toLowerCase();
    final value = option.substring(separator + 1).trim();
    switch (name) {
      case 'http-user-agent':
        headers['User-Agent'] = value;
      case 'http-referrer':
      case 'http-referer':
        headers['Referer'] = value;
      case 'http-origin':
        headers['Origin'] = value;
    }
  }

  void _readKodiProperty(
    String property,
    Map<String, String> headers,
    Map<String, String> licenseHeaders,
    void Function(String? type, String? key) setLicense,
  ) {
    final separator = property.indexOf('=');
    if (separator < 1) return;
    final name = property.substring(0, separator).trim().toLowerCase();
    final value = property.substring(separator + 1).trim();
    if (name.endsWith('.license_type')) {
      setLicense(value, null);
    } else if (name.endsWith('.license_key')) {
      setLicense(null, value);
    } else if (name.endsWith('.stream_headers')) {
      for (final item in value.split('|')) {
        final colon = item.indexOf('=');
        if (colon > 0) {
          headers[item.substring(0, colon).trim()] = item
              .substring(colon + 1)
              .trim();
        }
      }
    }
  }

  void dispose() => _client.close();
}
