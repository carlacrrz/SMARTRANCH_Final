import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ranch/main.dart';

void main() {
  testWidgets('SmartRanchApp renders dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartRanchApp());
    await tester.pump();

    // Verify app title renders
    expect(find.text('Smart Ranch'), findsOneWidget);

    // Verify demo indicator is shown
    expect(find.text('Demo'), findsOneWidget);
  });
}
