import 'package:flutter_test/flutter_test.dart';
import 'package:green_cycle/main.dart';

void main() {
  testWidgets('renders navigation destinations', (tester) async {
    await tester.pumpWidget(const GreenCycleApp());
    await tester.pump();

    expect(find.text('Harita'), findsOneWidget);
    expect(find.text('Teslim'), findsOneWidget);
    expect(find.text('Ödüller'), findsOneWidget);
  });
}
