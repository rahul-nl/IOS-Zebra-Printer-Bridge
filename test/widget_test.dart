import 'package:flutter_test/flutter_test.dart';
import 'package:zebra_printer_bridge/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ZebraPrinterApp());
    expect(find.text('Zebra Printer Bridge'), findsOneWidget);
  });
}