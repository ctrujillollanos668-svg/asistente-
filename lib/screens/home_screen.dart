import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../services/app_launcher_service.dart';
import '../services/assistant_brain.dart';
import '../services/background_voice_service.dart';
import '../services/permission_service.dart';
import '../services/preferences_service.dart';
import '../services/speech_service.dart';
import '../services/update_service.dart';
import '../services/nova_api_service.dart';
import '../services/code_push_service.dart';
import '../widgets/action_authorization_card.dart';
import '../widgets/permission_sheet.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/update_dialog.dart';
import '../widgets/voice_orb.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<ChatMessage> _messages = [];
  final SpeechService _speechService = SpeechService();
  final AppLauncherService _appLauncher = AppLauncherService();
  final AssistantBrain _brain = AssistantBrain();

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  OrbState _orbState = OrbState.idle;
  double _soundLevel = 0.0;
  String _liveSpokenText = "";
  bool _isMuted = false;
  String _assistantName = "Nova";

  List<String> get _quickSuggestions => [
        "Oye $_assistantName",
        "Abrir WhatsApp",
        "Abrir Instagram",
        "Pon música en YouTube",
        "Abrir TikTok",
        "Abrir la Cámara",
        "¿Qué hora es?",
        "Abrir Netflix",
        "¿Qué puedes hacer?",
        "Cuéntame un chiste",
      ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null);
    _initServices();
    CodePushService.syncInBackground();
    _checkSilentUpdate();
  }

  Future<void> _initServices() async {
    await _appLauncher.init();
    final name = await PreferencesService.getAssistantName();
    setState(() {
      _assistantName = name;
      _brain.assistantName = name;
    });

    _addInitialAssistantMessage(name);

    await _speechService.initializeSpeech(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          if (_orbState == OrbState.listening) {
            _onSpeechSessionEnded();
          }
        }
      },
      onError: (errorMsg) {
        if (!mounted) return;
        if (_orbState == OrbState.listening) {
          _onSpeechSessionEnded();
        }
      },
    );
    await _speechService.initializeTts();

    final bgEnabled = await PreferencesService.isBackgroundListeningEnabled();
    if (bgEnabled) {
      await BackgroundVoiceService.startService(name);
    }

    // Modo Manos Libres: si el permiso de micrófono ya está otorgado, empieza a escuchar solo
    final hasPerm = await PermissionService.hasMicrophonePermission();
    final autoListen = await PreferencesService.isAutoListeningEnabled();
    if (hasPerm && autoListen && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && _orbState == OrbState.idle) {
        _startListening();
      }
    }
  }

  void _onSpeechSessionEnded() {
    if (!mounted) return;
    if (_liveSpokenText.isNotEmpty && _liveSpokenText != "Escuchando...") {
      final textToProcess = _liveSpokenText;
      _liveSpokenText = "";
      _handleUserInput(textToProcess);
    } else {
      setState(() {
        _orbState = OrbState.idle;
        _liveSpokenText = "";
      });
      _autoListenIfHandsFree();
    }
  }

  Future<void> _autoListenIfHandsFree() async {
    final autoListen = await PreferencesService.isAutoListeningEnabled();
    if (autoListen && mounted && !_isMuted && _orbState == OrbState.idle) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && _orbState == OrbState.idle) {
        _startListening();
      }
    }
  }

  void _addInitialAssistantMessage(String name) {
    final welcome = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: "Soy **$name**. ¿Qué hacemos?",
      isUser: false,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(welcome);
    });
  }

  Future<void> _checkSilentUpdate() async {
    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo != null && updateInfo.hasUpdate && mounted) {
      UpdateDialog.show(context, updateInfo);
    }
  }

  Future<void> _manualCheckUpdate() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Buscando actualizaciones..."),
        duration: Duration(seconds: 1),
      ),
    );
    final updateInfo = await UpdateService.checkForUpdate(ignoreSkipped: true);
    if (!mounted) return;

    if (updateInfo != null && updateInfo.hasUpdate) {
      UpdateDialog.show(context, updateInfo);
    } else {
      final currentVer = await UpdateService.getCurrentVersion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("¡Ya tienes la versión más reciente instalada! (v$currentVer)"),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _openSettings() {
    SettingsDialog.show(
      context,
      currentName: _assistantName,
      onNameChanged: (newName) {
        setState(() {
          _assistantName = newName;
          _brain.assistantName = newName;
        });
        BackgroundVoiceService.updateNotification(newName);
      },
    );
  }

  @override
  void dispose() {
    _speechService.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleOrbTap() async {
    // REGLA N.º 1: Si está hablando, se detiene de inmediato y escucha al usuario
    if (_orbState == OrbState.speaking) {
      await _speechService.stopSpeaking();
      setState(() {
        _orbState = OrbState.idle;
      });
      _startListening();
      return;
    }

    if (_orbState == OrbState.listening) {
      await _stopListeningAndProcess();
      return;
    }

    final hasPerm = await PermissionService.hasMicrophonePermission();
    if (!hasPerm) {
      if (!mounted) return;
      final isPermDenied = await PermissionService.isPermanentlyDenied();
      if (!mounted) return;
      await PermissionSheet.show(
        context,
        isPermanentlyDenied: isPermDenied,
        onGranted: () async {
          await PreferencesService.setMicPermissionGranted();
          _startListening();
        },
      );
      return;
    }

    _startListening();
  }

  Future<void> _startListening() async {
    setState(() {
      _orbState = OrbState.listening;
      _liveSpokenText = "Escuchando...";
      _soundLevel = 0.0;
    });

    await _speechService.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _liveSpokenText = words;
        });

        if (isFinal && words.trim().isNotEmpty) {
          _handleUserInput(words);
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() {
          _soundLevel = level;
        });
      },
    );
  }

  Future<void> _stopListeningAndProcess() async {
    await _speechService.stopListening();
    if (_liveSpokenText.isNotEmpty && _liveSpokenText != "Escuchando...") {
      _handleUserInput(_liveSpokenText);
    } else {
      setState(() {
        _orbState = OrbState.idle;
        _liveSpokenText = "";
      });
    }
  }

  Future<void> _handleUserInput(String text) async {
    final cleanInput = text.trim();
    if (cleanInput.isEmpty) return;

    await _speechService.stopListening();

    // 1. Agregar mensaje del usuario
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: cleanInput,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _orbState = OrbState.thinking;
      _liveSpokenText = "";
    });
    _scrollToBottom();

    // 2. Procesar con el cerebro del asistente verificando permisos permanentes
    var brainResponse = _brain.processInput(
      cleanInput,
      (appName) => _appLauncher.isAppPreAuthorized(appName),
    );

    // Si no es una acción local o el cerebro local no entendió, consultar al backend Python
    if (brainResponse.action == null && (brainResponse.text == "¿Cómo?" || cleanInput.endsWith('?') || cleanInput.startsWith('cómo') || cleanInput.startsWith('como') || cleanInput.startsWith('por qué') || cleanInput.startsWith('por que'))) {
      final backendReply = await NovaApiService.queryBackend(cleanInput, _assistantName);
      if (backendReply != null && backendReply.isNotEmpty) {
        brainResponse = BrainResponse(text: backendReply);
      }
    }

    // Si el usuario ordenó cambiar el nombre por voz
    if (brainResponse.newAssistantName != null) {
      final newName = brainResponse.newAssistantName!;
      await PreferencesService.setAssistantName(newName);
      setState(() {
        _assistantName = newName;
      });
      BackgroundVoiceService.updateNotification(newName);
    }

    await Future.delayed(const Duration(milliseconds: 350));

    // 3. Crear mensaje de respuesta del asistente
    final assistantMsg = ChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      text: brainResponse.text,
      isUser: false,
      timestamp: DateTime.now(),
      action: brainResponse.action,
      authorizationStatus: brainResponse.requiresAuthorization
          ? AuthorizationStatus.pending
          : (brainResponse.action != null ? AuthorizationStatus.granted : AuthorizationStatus.none),
    );

    setState(() {
      _messages.add(assistantMsg);
      _orbState = _isMuted ? OrbState.idle : OrbState.speaking;
    });
    _scrollToBottom();

    // 4. Voz de salida
    if (!_isMuted) {
      await _speechService.speak(
        brainResponse.text,
        onDone: () async {
          if (!mounted) return;
          setState(() {
            _orbState = OrbState.idle;
          });

          // Modo Manos Libres: Vuelve a escuchar automáticamente tras responder
          _autoListenIfHandsFree();
        },
      );
    }

    // 5. Si ya estaba pre-autorizada la app, ejecutarla automáticamente
    if (brainResponse.action != null && !brainResponse.requiresAuthorization) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _appLauncher.executeAppAction(brainResponse.action!);
    }
  }



  Future<void> _handleAuthorizeAction(ChatMessage message, bool remember) async {
    if (message.action == null) return;
    final action = message.action!;

    setState(() {
      message.authorizationStatus = AuthorizationStatus.granted;
    });

    // Siempre recordar en almacenamiento permanente (una sola vez para siempre)
    await _appLauncher.rememberAuthorization(action.appName);

    if (!_isMuted) {
      await _speechService.speak("Acceso autorizado permanentemente. Abriendo ${action.appName}.");
    }

    await Future.delayed(const Duration(milliseconds: 400));
    await _appLauncher.executeAppAction(action);
  }

  void _handleRejectAction(ChatMessage message) {
    setState(() {
      message.authorizationStatus = AuthorizationStatus.rejected;
    });
    if (!_isMuted) {
      _speechService.speak("Entendido. Acción cancelada.");
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _speechService.isMuted = _isMuted;
    });
    if (_isMuted) {
      _speechService.stopSpeaking();
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _addInitialAssistantMessage(_assistantName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111420),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFF818CF8), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Asistente · $_assistantName",
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _getStatusColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Ajustes y Nombre",
            icon: const Icon(Icons.tune_rounded, color: Color(0xFFA78BFA)),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: "Buscar actualizaciones",
            icon: const Icon(Icons.system_update_rounded, color: Color(0xFF00F2FE)),
            onPressed: _manualCheckUpdate,
          ),
          IconButton(
            tooltip: _isMuted ? "Activar Voz" : "Silenciar Voz",
            icon: Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: _isMuted ? Colors.redAccent : const Color(0xFF94A3B8),
            ),
            onPressed: _toggleMute,
          ),
          IconButton(
            tooltip: "Limpiar conversación",
            icon: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF94A3B8)),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Área de Mensajes
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageItem(msg);
                },
              ),
            ),

            // Texto en vivo mientras escucha
            if (_orbState == OrbState.listening && _liveSpokenText.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2230),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00F2FE).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.graphic_eq_rounded, color: Color(0xFF00F2FE), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _liveSpokenText,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontStyle: FontStyle.italic,
                          fontSize: 13.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Chips de Sugerencias Rápidas
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickSuggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final suggestion = _quickSuggestions[i];
                  return ActionChip(
                    backgroundColor: const Color(0xFF1E2230),
                    side: const BorderSide(color: Color(0xFF334155)),
                    label: Text(
                      suggestion,
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                    ),
                    onPressed: () => _handleUserInput(suggestion),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Sección Inferior: Orbe de Voz y Barra de Entrada
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF111420),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Orbe de Voz Central
                  Center(
                    child: VoiceOrb(
                      state: _orbState,
                      soundLevel: _soundLevel,
                      onTap: _handleOrbTap,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getOrbSubtitle(),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Barra de texto opcional
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2230),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "Escribe o di «Oye $_assistantName»...",
                              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                _handleUserInput(val);
                                _textController.clear();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF6366F1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          onPressed: () {
                            if (_textController.text.trim().isNotEmpty) {
                              _handleUserInput(_textController.text);
                              _textController.clear();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    final isUser = msg.isUser;
    final timeStr = DateFormat('h:mm a').format(msg.timestamp);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF6366F1) : const Color(0xFF1E2230),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                timeStr,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                ),
              ),
            ),

            if (msg.action != null)
              ActionAuthorizationCard(
                action: msg.action!,
                status: msg.authorizationStatus,
                onAuthorize: (remember) => _handleAuthorizeAction(msg, remember),
                onReject: () => _handleRejectAction(msg),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_orbState) {
      case OrbState.listening:
        return const Color(0xFF00F2FE);
      case OrbState.thinking:
        return const Color(0xFFE040FB);
      case OrbState.speaking:
        return const Color(0xFF10B981);
      case OrbState.idle:
        return const Color(0xFF10B981);
    }
  }

  String _getStatusText() {
    switch (_orbState) {
      case OrbState.listening:
        return "Escuchando voz...";
      case OrbState.thinking:
        return "Pensando...";
      case OrbState.speaking:
        return "Hablando...";
      case OrbState.idle:
        return "En línea (Oye $_assistantName)";
    }
  }

  String _getOrbSubtitle() {
    switch (_orbState) {
      case OrbState.listening:
        return "Toca para terminar de hablar";
      case OrbState.thinking:
        return "Procesando...";
      case OrbState.speaking:
        return "El asistente te está hablando";
      case OrbState.idle:
        return "Di «Oye $_assistantName» o toca el orbe";
    }
  }
}
