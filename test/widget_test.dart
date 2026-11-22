import 'package:flutter_test/flutter_test.dart';
import 'package:asistente/main.dart';

void main() {
  testWidgets('Smoke test de inicio de Asistente', (WidgetTester tester) async {
    await tester.pumpWidget(const AsistenteApp());
    expect(find.textContaining('Asistente'), findsWidgets);
  });
}
