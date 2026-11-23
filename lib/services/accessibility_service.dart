import 'package:flutter/services.dart';

class AccessibilityService {
  static const MethodChannel _channel = MethodChannel('com.example.asistente/accessibility');

  /// Verifica si el servicio de accesibilidad para WhatsApp está activado
  static Future<bool> isAccessibilityEnabled() async {
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre la pantalla de Ajustes de Accesibilidad de Android
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  /// Programa el auto-envío para cuando WhatsApp se abra en pantalla
  static Future<void> scheduleAutoSendWhatsApp() async {
    try {
      await _channel.invokeMethod('scheduleAutoSendWhatsApp');
    } catch (_) {}
  }
}
