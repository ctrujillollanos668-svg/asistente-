import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';

class PermissionSheet extends StatelessWidget {
  final bool isPermanentlyDenied;
  final VoidCallback onGranted;

  const PermissionSheet({
    super.key,
    required this.isPermanentlyDenied,
    required this.onGranted,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isPermanentlyDenied,
    required VoidCallback onGranted,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PermissionSheet(
        isPermanentlyDenied: isPermanentlyDenied,
        onGranted: onGranted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: Color(0xFF181B26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Color(0xFF818CF8),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Permiso de Micrófono",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isPermanentlyDenied
                ? "El permiso de micrófono fue denegado de forma permanente. Para que el asistente pueda escucharte, por favor actívalo desde los Ajustes de la aplicación."
                : "Para que tu asistente pueda escucharte y responder con voz, necesita tu autorización para acceder al micrófono. Tu audio solo se utiliza cuando activas la escucha.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    "Ahora no",
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (isPermanentlyDenied) {
                      await PermissionService.openSettings();
                    } else {
                      final status = await PermissionService.requestMicrophonePermission();
                      if (status.isGranted) {
                        onGranted();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    isPermanentlyDenied ? "Abrir Ajustes" : "Autorizar",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
