import 'dart:math';
import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';

class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({
    super.key,
    required this.channel,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.contain,
  });

  final Channel channel;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  static const List<List<Color>> _gradientPalettes = [
    [Color(0xFF0D282D), Color(0xFF13454C)], // Deep Teal / Cyan
    [Color(0xFF121E33), Color(0xFF1A3359)], // Midnight Slate / Blue
    [Color(0xFF201335), Color(0xFF381F5E)], // Deep Violet / Indigo
    [Color(0xFF0F2B20), Color(0xFF174B37)], // Emerald Dark
    [Color(0xFF2F1F10), Color(0xFF4C3119)], // Warm Amber / Ochre
    [Color(0xFF2E121E), Color(0xFF4C1D32)], // Wine / Plum
    [Color(0xFF1B2332), Color(0xFF28364F)], // Steel Slate
    [Color(0xFF1A2621), Color(0xFF253B32)], // Forest Pine
  ];

  static const List<Color> _accentColors = [
    Color(0xFF00D4AA), // Vibrant Teal
    Color(0xFF4DD0E1), // Cyan
    Color(0xFF81D4FA), // Sky Blue
    Color(0xFFB388FF), // Lavender
    Color(0xFFA7FFEB), // Mint
    Color(0xFFFFD54F), // Amber Gold
    Color(0xFFFF8A80), // Coral
    Color(0xFF69F0AE), // Spring Green
  ];

  static String getInitials(String name) {
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').trim();
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'TV';
    if (words.length == 1) {
      final word = words[0];
      return word.length <= 4 ? word.toUpperCase() : word.substring(0, 3).toUpperCase();
    }
    if (words.length == 2) {
      if (words[0].length <= 3 && RegExp(r'^\d+$').hasMatch(words[1])) {
        return '${words[0]}${words[1]}'.toUpperCase();
      }
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}${words[2][0]}'.toUpperCase();
  }

  static bool isValidLogo(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed.endsWith('/null')) {
      return false;
    }
    if (trimmed.contains('removed.png') ||
        trimmed.contains('/removed') ||
        trimmed.contains('o0DSsY1') ||
        trimmed.contains('yj8RNnG') ||
        trimmed.contains('JgHbDmF') ||
        trimmed.contains('KLYsKKC') ||
        trimmed.contains('sd7BX9H') ||
        trimmed.contains('sU8UPPY')) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    final hasLogo = isValidLogo(channel.logo);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: hasLogo
            ? Image.network(
                channel.logo!.trim(),
                fit: fit,
                headers: const {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                },
                errorBuilder: (_, _, _) => _buildPlaceholder(context, radius),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _buildPlaceholder(context, radius, loading: true);
                },
              )
            : _buildPlaceholder(context, radius),
      ),
    );
  }

  Widget _buildPlaceholder(
    BuildContext context,
    BorderRadius radius, {
    bool loading = false,
  }) {
    final hash = channel.name.hashCode.abs();
    final gradient = _gradientPalettes[hash % _gradientPalettes.length];
    final accent = _accentColors[hash % _accentColors.length];
    final initials = getInitials(channel.name);
    final flag = CategoryService.flagForCountry(channel.group);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background TV Watermark
          Positioned(
            right: -6,
            bottom: -6,
            child: Icon(
              Icons.live_tv_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          // Country / Category Flag Badge in Top-Right
          if (flag != '🌐')
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          // Center Initials or Loading Indicator
          Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        initials,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: max(13.0, (22 - (initials.length * 2)).toDouble()),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: accent,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 18,
                        height: 2,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
