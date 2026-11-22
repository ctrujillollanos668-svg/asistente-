import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyAssistantName = 'assistant_name';
  static const String _keyAuthorizedApps = 'authorized_apps';
  static const String _keyBackgroundListening = 'background_listening_enabled';
  static const String _keyMicPermissionGranted = 'mic_permission_granted';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Obtiene el nombre del asistente (por defecto "Jarvis")
  static Future<String> getAssistantName() async {
    final prefs = await _instance;
    return prefs.getString(_keyAssistantName) ?? "Jarvis";
  }

  /// Guarda el nuevo nombre personalizado del asistente
  static Future<void> setAssistantName(String name) async {
    final prefs = await _instance;
    await prefs.setString(_keyAssistantName, name.trim());
  }

  /// Comprueba si una app ya fue autorizada permanentemente
  static Future<bool> isAppAuthorized(String appName) async {
    final prefs = await _instance;
    final list = prefs.getStringList(_keyAuthorizedApps) ?? [];
    return list.map((e) => e.toLowerCase()).contains(appName.toLowerCase());
  }

  /// Guarda una aplicación como autorizada permanentemente (una sola vez para siempre)
  static Future<void> authorizeApp(String appName) async {
    final prefs = await _instance;
    final list = prefs.getStringList(_keyAuthorizedApps) ?? [];
    final lower = appName.toLowerCase();
    if (!list.map((e) => e.toLowerCase()).contains(lower)) {
      list.add(appName);
      await prefs.setStringList(_keyAuthorizedApps, list);
    }
  }

  /// Revoca la autorización de una aplicación
  static Future<void> revokeApp(String appName) async {
    final prefs = await _instance;
    final list = prefs.getStringList(_keyAuthorizedApps) ?? [];
    list.removeWhere((e) => e.toLowerCase() == appName.toLowerCase());
    await prefs.setStringList(_keyAuthorizedApps, list);
  }

  /// Obtiene la lista completa de aplicaciones autorizadas
  static Future<List<String>> getAuthorizedApps() async {
    final prefs = await _instance;
    return prefs.getStringList(_keyAuthorizedApps) ?? [];
  }

  /// Verifica si la escucha en segundo plano está activa
  static Future<bool> isBackgroundListeningEnabled() async {
    final prefs = await _instance;
    return prefs.getBool(_keyBackgroundListening) ?? true;
  }

  /// Activa o desactiva la escucha en segundo plano
  static Future<void> setBackgroundListeningEnabled(bool enabled) async {
    final prefs = await _instance;
    await prefs.setBool(_keyBackgroundListening, enabled);
  }

  /// Verifica si el permiso de micrófono ya fue concedido una vez
  static Future<bool> wasMicPermissionGranted() async {
    final prefs = await _instance;
    return prefs.getBool(_keyMicPermissionGranted) ?? false;
  }

  /// Marca que el permiso de micrófono fue concedido
  static Future<void> setMicPermissionGranted() async {
    final prefs = await _instance;
    await prefs.setBool(_keyMicPermissionGranted, true);
  }
}
