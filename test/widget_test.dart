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

    test('Comando para abrir Instagram', () {
      final resp = brain.processInput('abre Instagram', (_) => true);
      expect(resp.action, isNotNull);
      expect(resp.action!.type, equals(ActionType.instagram));
    });

    test('Comando para abrir TikTok', () {
      final resp = brain.processInput('abre TikTok', (_) => true);
      expect(resp.action, isNotNull);
      expect(resp.action!.type, equals(ActionType.tiktok));
    });

    test('Comando para abrir Netflix', () {
      final resp = brain.processInput('inicia Netflix', (_) => true);
      expect(resp.action, isNotNull);
      expect(resp.action!.type, equals(ActionType.netflix));
    });

    test('Comando de ayuda / qué puedes hacer', () {
      final resp = brain.processInput('qué puedes hacer', (_) => true);
      expect(resp.text, contains('cualquier app'));
      expect(resp.text, contains('WhatsApp'));
    });

    test('Regla de interrupcion inmediata: para, stop, ya', () {
      final resp = brain.processInput('para', (_) => true);
      expect(resp.text, equals('Listo.'));
      final resp2 = brain.processInput('stop', (_) => true);
      expect(resp2.text, equals('Listo.'));
    });

    test('Preguntas no entendidas responden solo: ¿Cómo?', () {
      final resp = brain.processInput('asdfghjkl zxcvbnm', (_) => true);
      expect(resp.text, equals('¿Cómo?'));
    });

    test('Matemáticas directas concisas', () {
      final resp = brain.processInput('cuánto es 5 por 8', (_) => true);
      expect(resp.text, contains('40'));
    });
  });
}
