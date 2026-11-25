import 'package:flutter/material.dart';
import '../services/background_voice_service.dart';
import '../services/preferences_service.dart';
import '../services/code_push_service.dart';

class SettingsDialog extends StatefulWidget {
  final String currentName;
  final Function(String newName) onNameChanged;

  const SettingsDialog({
    super.key,
    required this.currentName,
    required this.onNameChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentName,
    required Function(String newName) onNameChanged,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => SettingsDialog(
        currentName: currentName,
        onNameChanged: onNameChanged,
      ),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _nameController;
  late TextEditingController _backendController;
  bool _backgroundListening = true;
  bool _autoListening = true;
  List<String> _authorizedApps = [];

  final List<String> _popularNames = [
    "Nova",
    "Jarvis",
    "Siri",
    "Viernes",
    "Aura",
    "Sofía",
  ];

  int? _patchNumber;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _backendController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bg = await PreferencesService.isBackgroundListeningEnabled();
    final auto = await PreferencesService.isAutoListeningEnabled();
    final apps = await PreferencesService.getAuthorizedApps();
    final backendUrl = await PreferencesService.getBackendUrl();
    final patch = await CodePushService.getCurrentPatchNumber();
    setState(() {
      _backgroundListening = bg;
      _autoListening = auto;
      _authorizedApps = apps;
      _backendController.text = backendUrl;
      _patchNumber = patch;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _backendController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      await PreferencesService.setAssistantName(newName);
      await PreferencesService.setBackgroundListeningEnabled(_backgroundListening);
      await PreferencesService.setAutoListeningEnabled(_autoListening);
      await PreferencesService.setBackendUrl(_backendController.text.trim());

      if (_backgroundListening) {
        await BackgroundVoiceService.startService(newName);
      } else {
        await BackgroundVoiceService.stopService();
      }

      widget.onNameChanged(newName);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _revokeApp(String appName) async {
    await PreferencesService.revokeApp(appName);
    setState(() {
      _authorizedApps.remove(appName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF181B26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFFA78BFA), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Ajustes del Asistente",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Campo de Nombre
              const Text(
                "Nombre para llamarlo (Palabra clave)",
                style: TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 6),
              const Text(
                "Di «Oye [Nombre]» para que responda como Siri.",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111420),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.badge_rounded, color: Color(0xFF8B5CF6), size: 20),
                    hintText: "Ejemplo: Jarvis",
                    hintStyle: TextStyle(color: Color(0xFF64748B)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Sugerencias de Nombres
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _popularNames.map((name) {
                  return ActionChip(
                    backgroundColor: const Color(0xFF1E2230),
                    side: BorderSide(
                      color: _nameController.text == name ? const Color(0xFF8B5CF6) : const Color(0xFF334155),
                    ),
                    label: Text(
                      name,
                      style: TextStyle(
                        color: _nameController.text == name ? const Color(0xFFA78BFA) : const Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _nameController.text = name;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 12),

              // Switch de Escucha en Segundo Plano
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Modo Manos Libres (Escucha Continua)",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Escucha automáticamente al abrir la app y tras cada respuesta sin tener que presionar el micrófono.",
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoListening,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setState(() {
                        _autoListening = val;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Switch de Notificación y segundo plano
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Acceso en Segundo Plano",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Mantiene el acceso rápido con botón de hablar desde la barra de notificaciones.",
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _backgroundListening,
                    activeColor: const Color(0xFF8B5CF6),
                    onChanged: (val) {
                      setState(() {
                        _backgroundListening = val;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 12),

              // Servidor Backend de IA (Python)
              const Text(
                "Servidor de IA (Backend Python)",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 4),
              Text(
                "Opcional: Si tienes tu servidor Python en la nube o local, pon la URL aquí para respuestas con IA ilimitada.",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11.5),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111420),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: TextField(
                  controller: _backendController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.cloud_queue_rounded, color: Color(0xFF00F2FE), size: 20),
                    hintText: "Ejemplo: https://mi-backend.onrender.com",
                    hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 12),

              // Aplicaciones Autorizadas para Siempre
              const Text(
                "Permisos Guardados (Una sola vez)",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 6),
              Text(
                _authorizedApps.isEmpty
                    ? "Aún no has autorizado ninguna aplicación permanentemente."
                    : "Estas aplicaciones están autorizadas para abrirse automáticamente:",
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 10),

              if (_authorizedApps.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _authorizedApps.map((app) {
                    return Chip(
                      backgroundColor: const Color(0xFF1E2230),
                      label: Text(app, style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                      onDeleted: () => _revokeApp(app),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),

              // Estado de Shorebird Code Push
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2230),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFF00F2FE), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        CodePushService.isAvailable
                            ? (_patchNumber != null
                                ? "Code Push: Parche #$_patchNumber activo"
                                : "Code Push: Activo (Versión base)")
                            : "Code Push: Activo vía Shorebird",
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botones Guardar / Cancelar
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Cancelar", style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Guardar", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
