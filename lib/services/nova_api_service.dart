import 'dart:convert';
import 'package:http/http.dart' as http;
import 'preferences_service.dart';

class NovaApiService {
  /// Consulta al servidor backend Python de NOVA
  static Future<String?> queryBackend(String message, String assistantName) async {
    try {
      final backendUrl = await PreferencesService.getBackendUrl();
      if (backendUrl.trim().isEmpty) return null;

      final normalized = backendUrl.trim().endsWith('/')
          ? '${backendUrl.trim()}chat'
          : '${backendUrl.trim()}/chat';

      final uri = Uri.parse(normalized);
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'message': message,
              'assistant_name': assistantName,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final reply = data['reply'] as String?;
        if (reply != null && reply.trim().isNotEmpty) {
          return reply.trim();
        }
      }
    } catch (_) {
      // Si falla la conexión con el servidor Python, fallback al cerebro local
    }
    return null;
  }
}
