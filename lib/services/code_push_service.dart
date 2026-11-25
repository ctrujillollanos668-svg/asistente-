import 'dart:developer' as developer;
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Servicio encargado de gestionar las actualizaciones silenciosas (Code Push)
/// a través de la infraestructura de Shorebird.
class CodePushService {
  static final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Indica si la app está corriendo con el motor de Shorebird habilitado.
  static bool get isAvailable => _updater.isAvailable;

  /// Obtiene el número de parche activo actualmente en el dispositivo.
  static Future<int?> getCurrentPatchNumber() async {
    if (!_updater.isAvailable) return null;
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }

  /// Revisa si hay parches nuevos y los descarga silenciosamente en segundo plano.
  /// No interrumpe al usuario ni muestra diálogos molestos.
  /// El parche se aplicará automáticamente la próxima vez que se abra la app.
  static Future<bool> syncInBackground() async {
    if (!_updater.isAvailable) return false;

    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        developer.log('Shorebird: Descargando parche silencioso en segundo plano...');
        await _updater.update();
        developer.log('Shorebird: Parche descargado con éxito. Se aplicará al reiniciar la app.');
        return true;
      }
    } catch (e) {
      developer.log('Shorebird: Error al verificar parche: $e');
    }
    return false;
  }
}
