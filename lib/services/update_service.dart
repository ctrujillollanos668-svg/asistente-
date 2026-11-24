import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String apkUrl;
  final String changelog;
  final bool hasUpdate;
  final bool isMandatory;

  AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.apkUrl,
    required this.changelog,
    required this.hasUpdate,
    this.isMandatory = false,
  });
}

class UpdateService {
  // URL oficial para consultar actualizaciones en GitHub
  static const String defaultCheckUrl =
      "https://raw.githubusercontent.com/ctrujillollanos668-svg/asistente-/main/version.json";

  static const String _keySkipVersion = 'update_skip_version';

  /// Obtiene la versión actual instalada en el dispositivo
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Marca que una versión ya fue instalada (el instalador se lanzó con éxito)
  /// para que no se vuelva a ofrecer la misma actualización.
  static Future<void> markVersionInstalled(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySkipVersion, version);
  }

  /// Revisa si una versión ya fue instalada/descargada
  static Future<String?> getSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySkipVersion);
  }

  /// Limpia la marca de versión saltada (útil al actualizar la app real)
  static Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySkipVersion);
  }

  /// Consulta si existe una versión más reciente
  static Future<AppUpdateInfo?> checkForUpdate({String? updateUrl, bool ignoreSkipped = false}) async {
    try {
      final currentVersion = await getCurrentVersion();
      final url = Uri.parse(updateUrl ?? defaultCheckUrl);

      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final latestVersion = (data['version'] ?? '1.0.0').toString();
        final apkUrl = (data['apkUrl'] ?? '').toString();
        final changelog = (data['changelog'] ?? 'Mejoras y corrección de errores.').toString();
        final mandatory = (data['mandatory'] ?? false) as bool;

        // Comparar con la versión real del APK instalado
        final hasUpdate = _isVersionGreater(latestVersion, currentVersion);

        // Si ya se instaló/descargó esta versión y no es una verificación manual forzada, no molestar
        if (hasUpdate && !ignoreSkipped) {
          final skipped = await getSkippedVersion();
          if (skipped == latestVersion) {
            // Ya se descargó e instaló (o se lanzó el instalador). No molestar.
            return AppUpdateInfo(
              currentVersion: currentVersion,
              latestVersion: latestVersion,
              apkUrl: apkUrl,
              changelog: changelog,
              hasUpdate: false, // ← Ya se gestionó
              isMandatory: mandatory,
            );
          }
        } else if (!hasUpdate) {
          // Si la versión actual ya es igual o mayor, limpiar cualquier marca vieja
          await clearSkippedVersion();
        }

        return AppUpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          apkUrl: apkUrl,
          changelog: changelog,
          hasUpdate: hasUpdate,
          isMandatory: mandatory,
        );
      }
    } catch (_) {
      // Si no hay internet o la URL no responde, no interrumpir el uso normal
    }
    return null;
  }

  /// Descarga el APK e inicia la instalación automática sobre la app actual
  static void downloadAndInstallApk({
    required String apkUrl,
    required String targetVersion,
    required Function(int progress) onProgress,
    required Function() onInstalling,
    required Function(String errorMessage) onError,
  }) {
    try {
      OtaUpdate().execute(apkUrl, destinationFilename: 'asistente_update.apk').listen(
        (OtaEvent event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final percent = int.tryParse(event.value ?? '0') ?? 0;
              onProgress(percent);
              break;

            case OtaStatus.INSTALLING:
              // Marcar la versión como "ya gestionada" cuando el sistema
              // abre el instalador. Así, si el usuario vuelve a la app
              // antes de que Android termine, no le vuelve a salir el diálogo.
              markVersionInstalled(targetVersion);
              onInstalling();
              break;

            case OtaStatus.INSTALLATION_DONE:
              markVersionInstalled(targetVersion);
              onInstalling();
              break;

            case OtaStatus.ALREADY_RUNNING_ERROR:
              onError("La descarga ya está en curso.");
              break;

            case OtaStatus.INSTALLATION_ERROR:
              onError("La instalación no pudo completarse.");
              break;

            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              onError("No se concedió el permiso para instalar aplicaciones desconocidas.");
              break;

            case OtaStatus.CANCELED:
              onError("Descarga cancelada.");
              break;

            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
              onError("Error al descargar la actualización: ${event.status}");
              break;
          }
        },
        onError: (e) {
          onError("Ocurrió un error en la actualización: $e");
        },
      );
    } catch (e) {
      onError("No se pudo iniciar la descarga: $e");
    }
  }

  /// Compara dos versiones semánticas (ej: "1.0.1" > "1.0.0")
  static bool _isVersionGreater(String remote, String current) {
    try {
      final remoteParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final length = remoteParts.length > currentParts.length ? remoteParts.length : currentParts.length;

      for (int i = 0; i < length; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
    } catch (_) {}
    return false;
  }
}
