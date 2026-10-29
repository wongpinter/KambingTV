import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/models/channel.dart';
import 'package:opentv/widgets/channel_avatar.dart';

void main() {
  group('ChannelAvatar tests', () {
    test('getInitials extracts clean abbreviations', () {
      expect(ChannelAvatar.getInitials('TVRI'), 'TVRI');
      expect(ChannelAvatar.getInitials('CNN News'), 'CN');
      expect(ChannelAvatar.getInitials('HBO 2'), 'HBO2');
      expect(ChannelAvatar.getInitials('BeIN Sports 1'), 'BS1');
      expect(ChannelAvatar.getInitials('National Geographic Channel'), 'NGC');
      expect(ChannelAvatar.getInitials(''), 'TV');
    });

    testWidgets('renders placeholder when channel logo is null', (tester) async {
      const channel = Channel(
        name: 'Trans 7',
        url: 'http://test/stream.m3u8',
        group: 'Indonesia Channels',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: ChannelAvatar(channel: channel),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ChannelAvatar), findsOneWidget);
      expect(find.text('T7'), findsOneWidget);
    });

    test('isValidLogo detects dead and removed imgur logos', () {
      expect(ChannelAvatar.isValidLogo(null), isFalse);
      expect(ChannelAvatar.isValidLogo(''), isFalse);
      expect(ChannelAvatar.isValidLogo('https://i.imgur.com/o0DSsY1.png'), isFalse);
      expect(ChannelAvatar.isValidLogo('https://i.imgur.com/removed.png'), isFalse);
      expect(ChannelAvatar.isValidLogo('https://upload.wikimedia.org/valid.png'), isTrue);
    });

    testWidgets('renders placeholder when channel logo is a dead imgur link', (tester) async {
      const channel = Channel(
        name: 'Disney Jr. Latin America',
        url: 'http://test/disney.m3u8',
        group: 'Animation / Anime Channels',
        logo: 'https://i.imgur.com/o0DSsY1.png',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: ChannelAvatar(channel: channel),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ChannelAvatar), findsOneWidget);
      expect(find.text('DJL'), findsOneWidget);
    });
  });
}
