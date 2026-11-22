import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Verifica si el permiso de micrófono está otorgado
  static Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Solicita el permiso de micrófono al sistema operativo
  static Future<PermissionStatus> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status;
  }

  /// Verifica si el permiso fue denegado permanentemente
  static Future<bool> isPermanentlyDenied() async {
    final status = await Permission.microphone.status;
    return status.isPermanentlyDenied;
  }

  /// Abre la pantalla de Ajustes de la aplicación en el dispositivo
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
