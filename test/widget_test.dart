import 'package:flutter_test/flutter_test.dart';
import 'package:radio_whitelabel/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Radio White-Label App renders root widget cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const RadioWhiteLabelApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RadioWhiteLabelApp), findsOneWidget);
  });
}
