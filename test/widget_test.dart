import 'package:flutter_test/flutter_test.dart';
import 'package:smartscan_mlkit/app.dart';

void main() {
  testWidgets('Home screen renders app title', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartScanApp());
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue'), findsOneWidget);
  });
}
