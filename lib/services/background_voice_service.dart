import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(VoiceWakeTaskHandler());
}

class VoiceWakeTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Tarea en segundo plano iniciada
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Tarea de escucha periódica
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Tarea detenida
  }
}

class BackgroundVoiceService {
  static bool _isInitialized = false;

  /// Inicializa la configuración del Foreground Service
  static void initialize() {
    if (_isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'asistente_voice_channel',
        channelName: 'Servicio de Asistente de Voz',
        channelDescription: 'Mantiene al asistente activo para responder cuando lo llames por su nombre.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _isInitialized = true;
  }

  /// Inicia el servicio en segundo plano mostrando la notificación permanente
  static Future<void> startService(String assistantName) async {
    initialize();

    if (await FlutterForegroundTask.isRunningService) {
      await updateNotification(assistantName);
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '$assistantName está escuchando',
      notificationText: "Di «Oye $assistantName» para activar tu asistente.",
      callback: startCallback,
    );
  }

  /// Actualiza el texto de la notificación con el nuevo nombre
  static Future<void> updateNotification(String assistantName) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: '$assistantName está escuchando',
        notificationText: "Di «Oye $assistantName» para activar tu asistente.",
      );
    }
  }

  /// Detiene el servicio en segundo plano
  static Future<void> stopService() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// Comprueba si el servicio está corriendo
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}
