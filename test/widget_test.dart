import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/main.dart';

void main() {
  testWidgets('KambingTV app starts with the channel home screen', (
    tester,
  ) async {
    await tester.pumpWidget(const KambingTvApp());
    expect(find.text('Live TV'), findsOneWidget);
  });
}
