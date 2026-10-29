import 'package:tha_player/tha_player.dart';

class Channel {
  const Channel({
    required this.name,
    required this.url,
    this.id,
    this.logo,
    this.group = 'Other',
    this.headers = const {},
    this.drm = const ThaDrmConfig(type: ThaDrmType.none),
  });

  final String name;
  final String url;
  final String? id;
  final String? logo;
  final String group;
  final Map<String, String> headers;
  final ThaDrmConfig drm;

  factory Channel.fromPlaylistEntry({
    required String info,
    required String url,
    required Map<String, String> headers,
    required String? licenseType,
    required String? licenseKey,
    required Map<String, String> licenseHeaders,
  }) {
    final comma = info.indexOf(',');
    final attributes = comma < 0 ? info : info.substring(0, comma);
    final name = comma < 0 ? url : info.substring(comma + 1).trim();
    final values = <String, String>{};
    for (final match in RegExp(r'([\w-]+)="([^"]*)"').allMatches(attributes)) {
      values[match.group(1)!] = match.group(2)!;
    }

    final drm = _parseDrm(licenseType, licenseKey, licenseHeaders);
    return Channel(
      name: name.isEmpty ? 'Unknown channel' : name,
      url: url,
      id: values['tvg-id'],
      logo: _cleanLogo(values['tvg-logo']),
      group: values['group-title']?.trim().isNotEmpty == true
          ? values['group-title']!.trim()
          : 'Other',
      headers: Map.unmodifiable(headers),
      drm: drm,
    );
  }

  static String? _cleanLogo(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed.endsWith('/null')) {
      return null;
    }
    if (trimmed.contains('removed.png') ||
        trimmed.contains('/removed') ||
        trimmed.contains('o0DSsY1') ||
        trimmed.contains('yj8RNnG') ||
        trimmed.contains('JgHbDmF') ||
        trimmed.contains('KLYsKKC') ||
        trimmed.contains('sd7BX9H') ||
        trimmed.contains('sU8UPPY')) {
      return null;
    }
    return trimmed;
  }

  static ThaDrmConfig _parseDrm(
    String? type,
    String? key,
    Map<String, String> headers,
  ) {
    if (type == null || key == null || key.isEmpty) {
      return const ThaDrmConfig(type: ThaDrmType.none);
    }

    final normalizedType = type.toLowerCase();
    final parts = key.split('|');
    final licenseUri = Uri.tryParse(parts.first.trim());
    final requestHeaders = <String, String>{...headers};
    for (final part in parts.skip(1)) {
      final separator = part.indexOf('=');
      if (separator > 0) {
        requestHeaders[part.substring(0, separator).trim()] = part
            .substring(separator + 1)
            .trim();
      }
    }
    if (normalizedType.contains('widevine')) {
      return ThaDrmConfig(
        type: ThaDrmType.widevine,
        licenseUrl: licenseUri?.hasScheme == true ? licenseUri.toString() : key,
        headers: Map.unmodifiable(requestHeaders),
      );
    }
    if (normalizedType.contains('clearkey')) {
      return ThaDrmConfig(
        type: ThaDrmType.clearKey,
        clearKey: key,
        headers: Map.unmodifiable(requestHeaders),
      );
    }
    return const ThaDrmConfig(type: ThaDrmType.none);
  }
}
