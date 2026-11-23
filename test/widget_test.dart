import 'package:flutter_test/flutter_test.dart';
import 'package:asistente/main.dart';
import 'package:asistente/services/assistant_brain.dart';
import 'package:asistente/models/chat_message.dart';

void main() {
  testWidgets('Smoke test de inicio de Asistente', (WidgetTester tester) async {
    await tester.pumpWidget(const AsistenteApp());
    expect(find.textContaining('Asistente'), findsWidgets);
  });

  group('AssistantBrain - Pruebas de Flujo Multiturno y Acciones', () {
    late AssistantBrain brain;

    setUp(() {
      brain = AssistantBrain();
    });

    test('Flujo contextual de 2 pasos en WhatsApp', () {
      // Paso 1: "métete al whatsApp"
      final resp1 = brain.processInput('métete al whatsApp', (_) => true);
      expect(brain.activeContext, equals('whatsapp'));
      expect(resp1.action, isNull);
      expect(resp1.text, contains('chat de algún contacto'));

      // Paso 2: "al chat de pepito y dile que ya voy"
      final resp2 = brain.processInput('al chat de pepito y dile que ya voy', (_) => true);
      expect(brain.activeContext, isNull);
      expect(resp2.action, isNotNull);
      expect(resp2.action!.type, equals(ActionType.whatsapp));
      expect(resp2.action!.payload, contains('ya voy'));
    });

    test('Comando directo en una sola frase para WhatsApp', () {
      final resp = brain.processInput('entra a whatsapp al chat de pepito y dile hola', (_) => true);
      expect(resp.action, isNotNull);
      expect(resp.action!.type, equals(ActionType.whatsapp));
    });

    test('Comando de YouTube directo con búsqueda', () {
      final resp = brain.processInput('en youtube pon música de salsa', (_) => true);
      expect(resp.action, isNotNull);
      expect(resp.action!.type, equals(ActionType.youtube));
      expect(resp.action!.payload, contains('salsa'));
    });

    test('Comando de llamada telefónica', () {
      final resp = brain.processInput('llama a mamá', (_) => true);
      expect(resp.action, isNotNull);
      expect(resp.action!.type, equals(ActionType.dialer));
      expect(resp.action!.payload, equals('Mamá'));
    });
  });
}
