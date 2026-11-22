import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ActionAuthorizationCard extends StatefulWidget {
  final AppAction action;
  final AuthorizationStatus status;
  final Function(bool remember) onAuthorize;
  final VoidCallback onReject;

  const ActionAuthorizationCard({
    super.key,
    required this.action,
    required this.status,
    required this.onAuthorize,
    required this.onReject,
  });

  @override
  State<ActionAuthorizationCard> createState() => _ActionAuthorizationCardState();
}

class _ActionAuthorizationCardState extends State<ActionAuthorizationCard> {
  bool _rememberChoice = false;

  @override
  Widget build(BuildContext context) {
    final isPending = widget.status == AuthorizationStatus.pending;
    final isGranted = widget.status == AuthorizationStatus.granted;
    final isRejected = widget.status == AuthorizationStatus.rejected;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF10B981)
              : isRejected
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF8B5CF6).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: Icono de Seguridad y Título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getHeaderBadgeColor().withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getHeaderIcon(),
                  color: _getHeaderBadgeColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getHeaderTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Descripción de la Acción solicitada
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF12151E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _getAppIcon(widget.action.type),
                  color: Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.action.description,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isPending) ...[
            const SizedBox(height: 12),
            // Opción de recordar
            InkWell(
              onTap: () {
                setState(() {
                  _rememberChoice = !_rememberChoice;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberChoice,
                        activeColor: const Color(0xFF8B5CF6),
                        checkColor: Colors.white,
                        onChanged: (val) {
                          setState(() {
                            _rememberChoice = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Recordar autorización para esta app",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botones de Decisión
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Rechazar"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.onAuthorize(_rememberChoice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "Autorizar",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isGranted) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                SizedBox(width: 8),
                Text(
                  "Autorizado por el usuario. Aplicación ejecutada.",
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ] else if (isRejected) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.cancel, color: Color(0xFFEF4444), size: 18),
                SizedBox(width: 8),
                Text(
                  "Autorización denegada. Acción cancelada.",
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getHeaderBadgeColor() {
    switch (widget.status) {
      case AuthorizationStatus.granted:
        return const Color(0xFF10B981);
      case AuthorizationStatus.rejected:
        return const Color(0xFFEF4444);
      case AuthorizationStatus.pending:
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _getHeaderIcon() {
    switch (widget.status) {
      case AuthorizationStatus.granted:
        return Icons.lock_open_rounded;
      case AuthorizationStatus.rejected:
        return Icons.lock_outline_rounded;
      case AuthorizationStatus.pending:
      default:
        return Icons.security_rounded;
    }
  }

  String _getHeaderTitle() {
    switch (widget.status) {
      case AuthorizationStatus.granted:
        return "Acceso Autorizado";
      case AuthorizationStatus.rejected:
        return "Acceso Denegado";
      case AuthorizationStatus.pending:
      default:
        return "Solicitud de Autorización";
    }
  }

  IconData _getAppIcon(ActionType type) {
    switch (type) {
      case ActionType.whatsapp:
        return Icons.chat_bubble_rounded;
      case ActionType.youtube:
        return Icons.play_circle_fill_rounded;
      case ActionType.spotify:
        return Icons.music_note_rounded;
      case ActionType.camera:
        return Icons.camera_alt_rounded;
      case ActionType.maps:
        return Icons.map_rounded;
      case ActionType.browser:
        return Icons.language_rounded;
      case ActionType.dialer:
        return Icons.phone_rounded;
      case ActionType.email:
        return Icons.email_rounded;
      case ActionType.generalApp:
        return Icons.apps_rounded;
    }
  }
}
