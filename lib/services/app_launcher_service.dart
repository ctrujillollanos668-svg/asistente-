import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import 'accessibility_service.dart';
import 'preferences_service.dart';

class AppLauncherService {
  final Set<String> _rememberedAuthorizations = <String>{};

  /// Carga desde almacenamiento persistente las autorizaciones previas
  Future<void> init() async {
    final list = await PreferencesService.getAuthorizedApps();
    _rememberedAuthorizations.clear();
    _rememberedAuthorizations.addAll(list.map((e) => e.toLowerCase()));
  }

  /// Verifica si una app ya cuenta con autorización previa guardada
  bool isAppPreAuthorized(String appName) {
    return _rememberedAuthorizations.contains(appName.toLowerCase());
  }

  /// Guarda la autorización para no volver a preguntar NUNCA MÁS (persistente en disco)
  Future<void> rememberAuthorization(String appName) async {
    _rememberedAuthorizations.add(appName.toLowerCase());
    await PreferencesService.authorizeApp(appName);
  }

  /// Revoca la autorización recordada de una app
  Future<void> revokeAuthorization(String appName) async {
    _rememberedAuthorizations.remove(appName.toLowerCase());
    await PreferencesService.revokeApp(appName);
  }

  /// Ejecuta la acción en la aplicación solicitada
  Future<bool> executeAppAction(AppAction action) async {
    try {
      switch (action.type) {
        case ActionType.whatsapp:
          return await _launchWhatsApp(action.payload);

        case ActionType.youtube:
          return await _launchYouTube(action.payload);

        case ActionType.spotify:
          return await _launchSpotify(action.payload);

        case ActionType.camera:
          return await _launchCamera();

        case ActionType.maps:
          return await _launchMaps(action.payload);

        case ActionType.browser:
          return await _launchBrowser(action.payload);

        case ActionType.dialer:
          return await _launchDialer(action.payload);

        case ActionType.email:
          return await _launchEmail(action.payload);

        case ActionType.generalApp:
          return await _launchGeneralApp(action.packageName);
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> _launchWhatsApp(String? query) async {
    // Si hay un mensaje o contacto, programamos el clic automático por Accesibilidad
    if (query != null && query.isNotEmpty) {
      await AccessibilityService.scheduleAutoSendWhatsApp();
    }
    String url = "whatsapp://send";
    if (query != null && query.isNotEmpty) {
      url = "whatsapp://send?text=${Uri.encodeComponent(query)}";
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    } else {
      return await _launchByPackage("com.whatsapp", "whatsapp://");
    }
  }

  Future<bool> _launchYouTube(String? query) async {
    if (query != null && query.isNotEmpty) {
      final appUri = Uri.parse("vnd.youtube://results?search_query=${Uri.encodeComponent(query)}");
      if (await canLaunchUrl(appUri)) {
        return await launchUrl(appUri);
      }
      final webUri = Uri.parse("https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}");
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      return await _launchByPackage("com.google.android.youtube", "youtube://");
    }
  }

  Future<bool> _launchSpotify(String? query) async {
    if (query != null && query.isNotEmpty) {
      final appUri = Uri.parse("spotify:search:${Uri.encodeComponent(query)}");
      if (await canLaunchUrl(appUri)) {
        return await launchUrl(appUri);
      }
      final webUri = Uri.parse("https://open.spotify.com/search/${Uri.encodeComponent(query)}");
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      return await _launchByPackage("com.spotify.music", "spotify://");
    }
  }

  Future<bool> _launchCamera() async {
    try {
      await LaunchApp.openApp(
        androidPackageName: 'com.android.camera',
        iosUrlScheme: 'camera://',
        openStore: false,
      );
      return true;
    } catch (_) {
      return await _launchByPackage("com.google.android.GoogleCamera", "camera://");
    }
  }

  Future<bool> _launchMaps(String? location) async {
    String query = location ?? "";
    final uri = Uri.parse("geo:0,0?q=${Uri.encodeComponent(query)}");
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    final webUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}");
    return await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Future<bool> _launchBrowser(String? urlOrQuery) async {
    String url = urlOrQuery ?? "https://www.google.com";
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      url = "https://www.google.com/search?q=${Uri.encodeComponent(url)}";
    }
    final uri = Uri.parse(url);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> _launchDialer(String? phoneNumber) async {
    final uri = Uri.parse("tel:${phoneNumber ?? ''}");
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  Future<bool> _launchEmail(String? recipient) async {
    final uri = Uri.parse("mailto:${recipient ?? ''}");
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  Future<bool> _launchGeneralApp(String packageName) async {
    try {
      await LaunchApp.openApp(
        androidPackageName: packageName,
        iosUrlScheme: '$packageName://',
        openStore: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _launchByPackage(String packageName, String iosScheme) async {
    try {
      await LaunchApp.openApp(
        androidPackageName: packageName,
        iosUrlScheme: iosScheme,
        openStore: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
