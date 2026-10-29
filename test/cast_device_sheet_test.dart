import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/models/channel.dart';
import 'package:opentv/widgets/cast_device_sheet.dart';

void main() {
  testWidgets('CastDeviceSheet displays header and scan state', (
    WidgetTester tester,
  ) async {
    const channel = Channel(
      name: 'TVRI Nasional',
      url: 'https://example.com/live.m3u8',
      group: 'Indonesia',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CastDeviceSheet(
            channel: channel,
            autoStartDiscovery: false,
          ),
        ),
      ),
    );

    expect(find.text('Cast to Screen'), findsOneWidget);
    expect(find.text('Google TV, Chromecast, DLNA, AirPlay'), findsOneWidget);
    expect(find.byIcon(Icons.cast), findsOneWidget);
  });
}
