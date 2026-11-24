import 'dart:math';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';

class BrainResponse {
  final String text;
  final AppAction? action;
  final bool requiresAuthorization;
  final String? newAssistantName;

  BrainResponse({
    required this.text,
    this.action,
    this.requiresAuthorization = false,
    this.newAssistantName,
  });
}

class AssistantBrain {
  final Random _random = Random();
  String assistantName = "Nova";

  /// Memoria conversacional activa (Multi-turno / Estado de la conversación)
  String? activeContext; // 'whatsapp', 'youtube', 'spotify', 'dialer'
  String? contextContact; // Contacto recordado en el flujo
  String? lastSpokenAnswer; // Última respuesta para retomar ("sigue / continúa")

  // ══════════════════════════════════════════════════════════════════
  //  MAPA MAESTRO DE APLICACIONES  –  nombre → (ActionType, paquete)
  // ══════════════════════════════════════════════════════════════════
  static final Map<String, _AppInfo> _appCatalog = {
    // Redes Sociales
    'instagram':  _AppInfo(ActionType.instagram,  'com.instagram.android',           'Instagram'),
    'insta':      _AppInfo(ActionType.instagram,  'com.instagram.android',           'Instagram'),
    'ig':         _AppInfo(ActionType.instagram,  'com.instagram.android',           'Instagram'),
    'facebook':   _AppInfo(ActionType.facebook,   'com.facebook.katana',             'Facebook'),
    'face':       _AppInfo(ActionType.facebook,   'com.facebook.katana',             'Facebook'),
    'fb':         _AppInfo(ActionType.facebook,   'com.facebook.katana',             'Facebook'),
    'tiktok':     _AppInfo(ActionType.tiktok,     'com.zhiliaoapp.musically',        'TikTok'),
    'tik tok':    _AppInfo(ActionType.tiktok,     'com.zhiliaoapp.musically',        'TikTok'),
    'twitter':    _AppInfo(ActionType.twitter,    'com.twitter.android',             'Twitter/X'),
    'x':          _AppInfo(ActionType.twitter,    'com.twitter.android',             'Twitter/X'),
    'telegram':   _AppInfo(ActionType.telegram,   'org.telegram.messenger',          'Telegram'),
    'tele':       _AppInfo(ActionType.telegram,   'org.telegram.messenger',          'Telegram'),
    'snapchat':   _AppInfo(ActionType.snapchat,   'com.snapchat.android',            'Snapchat'),
    'snap':       _AppInfo(ActionType.snapchat,   'com.snapchat.android',            'Snapchat'),
    'pinterest':  _AppInfo(ActionType.pinterest,  'com.pinterest',                   'Pinterest'),
    'linkedin':   _AppInfo(ActionType.linkedin,   'com.linkedin.android',            'LinkedIn'),

    // Entretenimiento
    'netflix':    _AppInfo(ActionType.netflix,     'com.netflix.mediaclient',         'Netflix'),

    // Transporte
    'uber':       _AppInfo(ActionType.uber,        'com.ubercab',                    'Uber'),
    'waze':       _AppInfo(ActionType.waze,        'com.waze',                       'Waze'),

    // Utilidades del sistema
    'calculadora':_AppInfo(ActionType.calculator,  'com.google.android.calculator',  'Calculadora'),
    'ajustes':    _AppInfo(ActionType.settings,    'com.android.settings',           'Ajustes'),
    'configuración': _AppInfo(ActionType.settings, 'com.android.settings',           'Ajustes'),
    'configuracion': _AppInfo(ActionType.settings, 'com.android.settings',           'Ajustes'),
    'galería':    _AppInfo(ActionType.gallery,     'com.google.android.apps.photos', 'Galería'),
    'galeria':    _AppInfo(ActionType.gallery,     'com.google.android.apps.photos', 'Galería'),
    'fotos':      _AppInfo(ActionType.gallery,     'com.google.android.apps.photos', 'Galería'),
    'reloj':      _AppInfo(ActionType.clock,       'com.google.android.deskclock',   'Reloj'),
    'alarma':     _AppInfo(ActionType.clock,       'com.google.android.deskclock',   'Reloj/Alarma'),
    'temporizador':_AppInfo(ActionType.clock,      'com.google.android.deskclock',   'Reloj'),
    'calendario': _AppInfo(ActionType.calendar,    'com.google.android.calendar',    'Calendario'),
    'agenda':     _AppInfo(ActionType.calendar,    'com.google.android.calendar',    'Calendario'),
    'contactos':  _AppInfo(ActionType.contacts,    'com.google.android.contacts',    'Contactos'),
    'archivos':   _AppInfo(ActionType.fileManager, 'com.google.android.apps.nbu.files','Archivos'),
    'gestor de archivos': _AppInfo(ActionType.fileManager, 'com.google.android.apps.nbu.files','Archivos'),
    'notas':      _AppInfo(ActionType.notes,       'com.google.android.keep',        'Notas'),
    'keep':       _AppInfo(ActionType.notes,       'com.google.android.keep',        'Google Keep'),
  };

  static final List<MapEntry<String, _AppInfo>> _sortedAppCatalogEntries = () {
    final entries = _appCatalog.entries.toList();
    entries.sort((a, b) => b.key.length.compareTo(a.key.length));
    return entries;
  }();

  /// Procesa la entrada del usuario reconociendo el rol de NOVA
  BrainResponse processInput(
    String rawInput,
    bool Function(String appName) isAppAuthorized,
  ) {
    String input = rawInput.trim();
    final lowerName = assistantName.toLowerCase();

    // 1. Limpieza de Wake Word
    final wakePrefixes = [
      'oye $lowerName',
      'oiga $lowerName',
      'hey $lowerName',
      'hola $lowerName',
      'ok $lowerName',
      'a ver $lowerName',
      'dale $lowerName',
      'nova',
      lowerName,
    ];

    bool calledByName = false;
    String cleanCommand = input.toLowerCase();

    for (final prefix in wakePrefixes) {
      if (cleanCommand.startsWith(prefix)) {
        calledByName = true;
        cleanCommand = cleanCommand.substring(prefix.length).trim();
        if (cleanCommand.startsWith(',') || cleanCommand.startsWith('.')) {
          cleanCommand = cleanCommand.substring(1).trim();
        }
        break;
      }
    }

    // Si solo la llamaron por su nombre ("Nova" u "Oye Nova")
    if (calledByName && cleanCommand.isEmpty) {
      return _respond("Dime, ¿qué hacemos?");
    }

    final effectiveInput = cleanCommand.isNotEmpty ? cleanCommand : input.toLowerCase();

    // ══════════════════════════════════════════════════════════════════
    //  REGLA N.º 1: INTERRUPCIÓN Y CONTROL INMEDIATO
    // ══════════════════════════════════════════════════════════════════

    // Detención total ("para", "ya", "stop", "silencio", "cállate", "alto")
    if (_isStopCommand(effectiveInput)) {
      activeContext = null;
      contextContact = null;
      return _respond("Listo.");
    }

    // Corrección o espera ("no, esa no", "otra", "espera")
    if (_isWaitOrCorrection(effectiveInput)) {
      if (effectiveInput.contains('espera') || effectiveInput.contains('momento')) {
        return _respond("Te espero.");
      }
      return _respond("Entendido, ¿cuál prefieres?");
    }

    // Retomar ("sigue", "continúa")
    if (effectiveInput == 'sigue' || effectiveInput == 'continúa' || effectiveInput == 'continua' || effectiveInput == 'prosigue') {
      if (lastSpokenAnswer != null && lastSpokenAnswer!.isNotEmpty) {
        return _respond(lastSpokenAnswer!);
      }
      return _respond("¿Qué hacemos?");
    }

    // Cancelar contexto actual
    if (_matchesAny(effectiveInput, ['cancela', 'cancelar', 'olvídalo', 'olvidalo', 'nada', 'ninguna', 'déjalo', 'dejalo'])) {
      activeContext = null;
      contextContact = null;
      return _respond("Cancelado. ¿Qué hacemos?");
    }

    // ══════════════════════════════════════════════════════════════════
    //  MANEJO DE CONTEXTO ACTIVO (Segunda parte de la conversación)
    // ══════════════════════════════════════════════════════════════════
    if (activeContext != null) {
      final responseFromContext = _handleActiveContext(effectiveInput, isAppAuthorized);
      if (responseFromContext != null) {
        return responseFromContext;
      }
    }

    // Cambiar nombre por voz
    if (effectiveInput.contains('cámbiate el nombre a') ||
        effectiveInput.contains('cambiate el nombre a') ||
        effectiveInput.contains('tu nombre ahora es') ||
        effectiveInput.contains('ahora te llamas') ||
        effectiveInput.contains('llámate') ||
        effectiveInput.contains('llamate')) {
      final parts = effectiveInput.split(RegExp(r'(a|es|llámate|llamate)\s+'));
      if (parts.length > 1) {
        final newName = parts.last.trim().replaceAll('.', '');
        if (newName.isNotEmpty) {
          assistantName = newName[0].toUpperCase() + newName.substring(1);
          return BrainResponse(
            text: "Listo. A partir de ahora me llamo $assistantName.",
            newAssistantName: assistantName,
          );
        }
      }
    }

    // Capacidades / Ayuda
    if (_matchesAny(effectiveInput, ['qué puedes hacer', 'que puedes hacer', 'qué sabes hacer', 'que sabes hacer', 'ayuda', 'help', 'funciones', 'capacidades', 'qué haces', 'que haces'])) {
      return _respond(
        "Puedo abrir cualquier app (YouTube, WhatsApp, Instagram, Spotify, Mapas y más), "
        "hacer llamadas, reproducir música y responder cualquier pregunta. ¿Qué necesitas?",
      );
    }

    // ══════════════════════════════════════════════════════════════════
    //  DETECCIÓN DE ACCIONES EN APLICACIONES
    // ══════════════════════════════════════════════════════════════════
    final appAction = _detectAppAction(effectiveInput);
    if (appAction != null) {
      // Si la app es WhatsApp y no dio contacto ni mensaje
      if (appAction.type == ActionType.whatsapp && (appAction.payload == null || appAction.payload!.isEmpty)) {
        activeContext = 'whatsapp';
        return _respond("¿Quieres entrar al chat de algún contacto o hacer una llamada?");
      }

      // Si la app es YouTube y no dio video/música
      if (appAction.type == ActionType.youtube && (appAction.payload == null || appAction.payload!.isEmpty)) {
        activeContext = 'youtube';
        return _respond("¿Qué canción o video quieres reproducir?");
      }

      // Si la app es Spotify y no especificó música
      if (appAction.type == ActionType.spotify && (appAction.payload == null || appAction.payload!.isEmpty)) {
        activeContext = 'spotify';
        return _respond("¿Qué canción o lista deseas escuchar?");
      }

      final isAuthorized = isAppAuthorized(appAction.appName);
      final needsAuth = !isAuthorized;
      String text;
      if (needsAuth) {
        text = "¿Autorizas abrir ${appAction.appName}?";
      } else {
        if (appAction.type == ActionType.whatsapp && appAction.payload != null) {
          text = "Listo, abriendo WhatsApp: ${appAction.description}.";
        } else if (appAction.type == ActionType.youtube && appAction.payload != null) {
          text = "Listo, sonando «${appAction.payload}» en YouTube.";
        } else if (appAction.type == ActionType.spotify && appAction.payload != null) {
          text = "Listo, sonando «${appAction.payload}» en Spotify.";
        } else if (appAction.type == ActionType.dialer && appAction.payload != null) {
          text = "Listo, llamando a ${appAction.payload}.";
        } else if (appAction.type == ActionType.maps && appAction.payload != null) {
          text = "Listo, calculando ruta hacia ${appAction.payload}.";
        } else {
          text = "Listo, abriendo ${appAction.appName}.";
        }
      }

      return BrainResponse(
        text: text,
        action: appAction,
        requiresAuthorization: needsAuth,
      );
    }

    // ══════════════════════════════════════════════════════════════════
    //  MOTOR DE CONOCIMIENTO GENERAL (RESPONDE CUALQUIER COSA EN 1-2 FRASES)
    // ══════════════════════════════════════════════════════════════════

    // 1. Matemáticas y Cálculos directos
    final mathResult = _solveMath(effectiveInput);
    if (mathResult != null) {
      return _respond(mathResult);
    }

    // 2. Hora y Fecha
    if (effectiveInput.contains('hora') || effectiveInput.contains('qué horas') || effectiveInput.contains('que horas')) {
      final now = DateTime.now();
      final timeStr = DateFormat('h:mm a').format(now);
      return _respond("Son las $timeStr.");
    }

    if (effectiveInput.contains('fecha') || effectiveInput.contains('qué día es') || effectiveInput.contains('que dia es')) {
      final now = DateTime.now();
      final dateStr = DateFormat('EEEE d \'de\' MMMM', 'es_ES').format(now);
      return _respond("Hoy es $dateStr.");
    }

    // 3. Saludos e Identidad
    if (_matchesAny(effectiveInput, ['quién eres', 'quien eres', 'cómo te llamas', 'como te llamas'])) {
      return _respond("Soy $assistantName, tu asistente personal de voz. ¿Qué hacemos?");
    }

    if (_matchesAny(effectiveInput, ['hola', 'buenos días', 'buenos dias', 'buenas tardes', 'buenas noches', 'hey', 'que tal', 'qué tal'])) {
      return _respond("Hola. ¿Qué hacemos?");
    }

    if (_matchesAny(effectiveInput, ['cómo estás', 'como estas', 'cómo te va', 'como te va'])) {
      return _respond("Excelente y lista. ¿Qué hacemos?");
    }

    // 4. Chistes y Entretenimiento
    if (_matchesAny(effectiveInput, ['chiste', 'cuéntame un chiste', 'hazme reír', 'un chiste', 'cuentame un chiste'])) {
      final jokes = [
        "¿Qué le dice un semáforo a otro? No me mires que me estoy cambiando.",
        "¿Por qué los pájaros no usan WhatsApp? Porque ya tienen Twitter.",
        "¿Qué hace una abeja en el gimnasio? ¡Zum-ba!",
        "¿Por qué el celular fue al psicólogo? Porque perdió la conexión.",
      ];
      return _respond(jokes[_random.nextInt(jokes.length)]);
    }

    if (_matchesAny(effectiveInput, ['consejo', 'motívame', 'motivame', 'frase'])) {
      final quotes = [
        "La mejor forma de predecir el futuro es creándolo. ¡A darle con todo!",
        "El éxito es la suma de pequeños esfuerzos repetidos cada día.",
        "El único límite es el que tú te pongas.",
      ];
      return _respond(quotes[_random.nextInt(quotes.length)]);
    }

    if (_matchesAny(effectiveInput, ['gracias', 'muchas gracias', 'te agradezco'])) {
      return _respond("Con gusto. ¿Algo más?");
    }

    if (_matchesAny(effectiveInput, ['actualizar', 'actualización', 'actualizacion', 'nueva versión', 'nueva version'])) {
      return _respond("Comprobando actualizaciones...");
    }

    // 5. Ajustes rápidos del sistema (WiFi, Bluetooth, Linterna, etc.)
    if (effectiveInput.contains('wifi') || effectiveInput.contains('wi-fi') || effectiveInput.contains('bluetooth') || effectiveInput.contains('brillo') || effectiveInput.contains('sonido') || effectiveInput.contains('volumen')) {
      return BrainResponse(
        text: "Listo, abriendo Ajustes.",
        action: AppAction(
          type: ActionType.settings,
          appName: 'Ajustes',
          packageName: 'com.android.settings',
          description: 'Abrir Ajustes del teléfono',
        ),
        requiresAuthorization: !isAppAuthorized('Ajustes'),
      );
    }

    // 6. Consultas de Conocimiento General conocidas
    final knowledge = _answerKnowledge(effectiveInput);
    if (knowledge != null) {
      return _respond(knowledge);
    }

    // 7. Búsqueda web directa si pregunta algo como "busca X" o "qué es X"
    if (effectiveInput.startsWith('qué es ') || effectiveInput.startsWith('que es ') ||
        effectiveInput.startsWith('quién fue ') || effectiveInput.startsWith('quien fue ') ||
        effectiveInput.startsWith('cuántos ') || effectiveInput.startsWith('cuantos ') ||
        effectiveInput.startsWith('dónde está ') || effectiveInput.startsWith('donde esta ')) {
      final query = effectiveInput;
      return BrainResponse(
        text: "Buscando información sobre eso en la web.",
        action: AppAction(
          type: ActionType.browser,
          appName: 'Navegador Web',
          packageName: 'com.android.chrome',
          payload: query,
          description: 'Buscar: "$query"',
        ),
        requiresAuthorization: !isAppAuthorized('Navegador Web'),
      );
    }

    // REGLA: Si no entendió lo que dijo, pregunta solo: "¿Cómo?"
    return BrainResponse(text: "¿Cómo?");
  }

  BrainResponse _respond(String text) {
    lastSpokenAnswer = text;
    return BrainResponse(text: text);
  }

  /// Manejo de respuestas dentro de un contexto activo
  BrainResponse? _handleActiveContext(String input, bool Function(String appName) isAppAuthorized) {
    if (activeContext == 'whatsapp') {
      if (input.contains('solo abre') || input.contains('abre la app') || input == 'abrir') {
        activeContext = null;
        contextContact = null;
        return BrainResponse(
          text: "Listo, abriendo WhatsApp.",
          action: AppAction(
            type: ActionType.whatsapp,
            appName: 'WhatsApp',
            packageName: 'com.whatsapp',
            description: 'Abrir WhatsApp',
          ),
          requiresAuthorization: !isAppAuthorized('WhatsApp'),
        );
      }

      if (input.contains('llama') || input.contains('llamar') || input.contains('llamada')) {
        final contact = _extractContact(input) ?? contextContact ?? 'tu contacto';
        activeContext = null;
        contextContact = null;
        return BrainResponse(
          text: "Listo, llamando a $contact.",
          action: AppAction(
            type: ActionType.dialer,
            appName: 'Teléfono',
            packageName: 'com.android.dialer',
            payload: contact,
            description: 'Llamar a $contact',
          ),
          requiresAuthorization: !isAppAuthorized('Teléfono'),
        );
      }

      final contact = _extractContact(input) ?? contextContact;
      final message = _extractMessageText(input);

      activeContext = null;
      contextContact = null;

      final target = contact != null ? "a $contact" : "en el chat";
      return BrainResponse(
        text: "Listo, abriendo chat $target.",
        action: AppAction(
          type: ActionType.whatsapp,
          appName: 'WhatsApp',
          packageName: 'com.whatsapp',
          payload: message ?? contact,
          description: 'Enviar WhatsApp $target',
        ),
        requiresAuthorization: !isAppAuthorized('WhatsApp'),
      );
    }

    if (activeContext == 'youtube') {
      final query = input
          .replaceAll(RegExp(r'(pon|busca|buscar|reproduce|de|un|video de)\s+'), '')
          .trim();
      activeContext = null;
      final cleanQuery = query.isNotEmpty ? query : "música variada";
      return BrainResponse(
        text: "Listo, sonando «$cleanQuery» en YouTube.",
        action: AppAction(
          type: ActionType.youtube,
          appName: 'YouTube',
          packageName: 'com.google.android.youtube',
          payload: cleanQuery,
          description: 'Reproducir en YouTube: "$cleanQuery"',
        ),
        requiresAuthorization: !isAppAuthorized('YouTube'),
      );
    }

    if (activeContext == 'spotify') {
      final song = input
          .replaceAll(RegExp(r'(pon|reproduce|cancion de|canción de|música de|musica de)\s+'), '')
          .trim();
      activeContext = null;
      final cleanSong = song.isNotEmpty ? song : "éxitos";
      return BrainResponse(
        text: "Listo, sonando «$cleanSong» en Spotify.",
        action: AppAction(
          type: ActionType.spotify,
          appName: 'Spotify',
          packageName: 'com.spotify.music',
          payload: cleanSong,
          description: 'Poner en Spotify: "$cleanSong"',
        ),
        requiresAuthorization: !isAppAuthorized('Spotify'),
      );
    }

    return null;
  }

  AppAction? _detectAppAction(String input) {
    // 1. WhatsApp
    final isWhatsApp = input.contains('whatsapp') ||
        input.contains('guasap') ||
        input.contains('wasap') ||
        input.contains('wsp') ||
        input.contains('whap') ||
        input.contains('wha') ||
        input.contains('whats') ||
        (input.contains('mensaje a') && !input.contains('telegram')) ||
        (input.contains('escribe a') && !input.contains('telegram')) ||
        input.contains('escríbele a') ||
        input.contains('escribele a') ||
        input.contains('chat de') ||
        input.contains('chat con');

    if (isWhatsApp) {
      final contact = _extractContact(input);
      final message = _extractMessageText(input);

      String? payload;
      String description;
      if (message != null && contact != null) {
        payload = message;
        description = 'Enviar a $contact por WhatsApp: "$message"';
      } else if (message != null) {
        payload = message;
        description = 'Enviar por WhatsApp: "$message"';
      } else if (contact != null) {
        payload = contact;
        description = 'Abrir WhatsApp y buscar a $contact';
      } else {
        payload = null;
        description = 'Abrir WhatsApp';
      }

      return AppAction(
        type: ActionType.whatsapp,
        appName: 'WhatsApp',
        packageName: 'com.whatsapp',
        payload: payload,
        description: description,
      );
    }

    // 2. YouTube
    if (input.contains('youtube') || input.contains('yutub') || input.contains('pon en youtube') ||
        (input.contains('video') && !input.contains('tiktok'))) {
      String? query;
      final clean = input
          .replaceAll(RegExp(r'(abre|abrir|pon en|busca en|buscar en|en|video de|pon|reproduce)\s+'), '')
          .replaceAll('youtube', '')
          .replaceAll('yutub', '')
          .replaceAll('yt', '')
          .trim();
      if (clean.isNotEmpty) {
        query = clean;
      }
      return AppAction(
        type: ActionType.youtube,
        appName: 'YouTube',
        packageName: 'com.google.android.youtube',
        payload: query,
        description: query != null ? 'Abrir YouTube y buscar: "$query"' : 'Abrir YouTube',
      );
    }

    // 3. Spotify / Música
    if (input.contains('spotify') || input.contains('música') || input.contains('musica') || input.contains('canción') || input.contains('cancion') || input.contains('reproduce')) {
      String? song;
      final clean = input
          .replaceAll(RegExp(r'(abre|abrir|pon en|reproduce|cancion|canción|musica|música|pon)\s+'), '')
          .replaceAll('spotify', '')
          .trim();
      if (clean.isNotEmpty) {
        song = clean;
      }
      return AppAction(
        type: ActionType.spotify,
        appName: 'Spotify',
        packageName: 'com.spotify.music',
        payload: song,
        description: song != null ? 'Abrir Spotify y reproducir: "$song"' : 'Abrir Spotify',
      );
    }

    // 4. Cámara
    if (input.contains('cámara') || input.contains('camara') || input.contains('selfie') ||
        (input.contains('foto') && !input.contains('galería') && !input.contains('galeria') && !input.contains('fotos'))) {
      return AppAction(
        type: ActionType.camera,
        appName: 'Cámara',
        packageName: 'com.android.camera',
        description: 'Abrir la Cámara',
      );
    }

    // 5. Mapas / Navegación
    if (input.contains('mapa') || input.contains('mapas') || input.contains('maps') || input.contains('cómo llegar') || input.contains('como llegar') || input.contains('dónde queda') || input.contains('donde queda') || input.contains('llevame') || input.contains('llévame') || input.contains('navega')) {
      String? destination;
      final clean = input
          .replaceAll(RegExp(r'(abre|abrir|cómo llegar a|como llegar a|llévame a|llevame a|dónde queda|donde queda|navega a|navega hacia)\s+'), '')
          .replaceAll('google maps', '')
          .replaceAll('mapas', '')
          .replaceAll('mapa', '')
          .replaceAll('maps', '')
          .trim();
      if (clean.isNotEmpty) {
        destination = clean;
      }
      return AppAction(
        type: ActionType.maps,
        appName: 'Google Maps',
        packageName: 'com.google.android.apps.maps',
        payload: destination,
        description: destination != null ? 'Navegar en Mapas hacia: "$destination"' : 'Abrir Google Maps',
      );
    }

    // 6. Teléfono / Llamadas
    if (input.startsWith('llama') || input.startsWith('marcar') || input.contains('teléfono') || input.contains('telefono') || input.startsWith('marca al') || input.startsWith('marca a')) {
      final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
      String? contactName;
      if (digits.isEmpty) {
        contactName = _extractContact(input);
      }

      final label = contactName ?? (digits.isNotEmpty ? digits : null);

      return AppAction(
        type: ActionType.dialer,
        appName: 'Teléfono',
        packageName: 'com.android.dialer',
        payload: label,
        description: label != null ? 'Llamar a $label' : 'Abrir el teclado telefónico',
      );
    }

    // 7. Email / Correo
    if (input.contains('correo') || input.contains('email') || input.contains('mail') || input.contains('gmail')) {
      return AppAction(
        type: ActionType.email,
        appName: 'Correo',
        packageName: 'com.google.android.gm',
        description: 'Abrir el correo electrónico',
      );
    }

    // 8. Catálogo maestro de aplicaciones
    for (final entry in _sortedAppCatalogEntries) {
      final pattern = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(input)) {
        final info = entry.value;
        return AppAction(
          type: info.type,
          appName: info.displayName,
          packageName: info.packageName,
          description: 'Abrir ${info.displayName}',
        );
      }
    }

    // 9. Patrones genéricos: "abre X" / "inicia X"
    final openPatterns = RegExp(r'(abre|abrir|abrí|abrime|inicia|iniciar|lanza|lanzar|ejecuta|ejecutar|entra a|entrar a|abrele|meteme en|mete)\s+(.+)', caseSensitive: false);
    final openMatch = openPatterns.firstMatch(input);
    if (openMatch != null) {
      final appNameRaw = openMatch.group(2)!.trim().replaceAll(RegExp(r'^(el|la|los|las|mi|una?)\s+'), '');
      for (final entry in _sortedAppCatalogEntries) {
        if (appNameRaw.contains(entry.key) || entry.key.contains(appNameRaw)) {
          final info = entry.value;
          return AppAction(
            type: info.type,
            appName: info.displayName,
            packageName: info.packageName,
            description: 'Abrir ${info.displayName}',
          );
        }
      }
    }

    return null;
  }

  /// Resuelve operaciones matemáticas directas
  String? _solveMath(String input) {
    try {
      final clean = input.replaceAll('cuánto es', '').replaceAll('cuanto es', '').replaceAll('calcula', '').trim();
      
      // Porcentaje: "15% de 80" o "15 por ciento de 80"
      final percentMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|por ciento)\s+de\s+(\d+(?:\.\d+)?)').firstMatch(clean);
      if (percentMatch != null) {
        final p = double.parse(percentMatch.group(1)!);
        final n = double.parse(percentMatch.group(2)!);
        final res = (p / 100.0) * n;
        return "El $p% de $n es ${_formatNumber(res)}.";
      }

      // Multiplicación: "5 por 8" o "5 x 8" o "5 * 8"
      final multMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:por|x|\*)\s*(\d+(?:\.\d+)?)').firstMatch(clean);
      if (multMatch != null) {
        final a = double.parse(multMatch.group(1)!);
        final b = double.parse(multMatch.group(2)!);
        return "$a por $b es ${_formatNumber(a * b)}.";
      }

      // División: "100 entre 4" o "100 / 4"
      final divMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:entre|\/|dividido en|dividido entre)\s*(\d+(?:\.\d+)?)').firstMatch(clean);
      if (divMatch != null) {
        final a = double.parse(divMatch.group(1)!);
        final b = double.parse(divMatch.group(2)!);
        if (b == 0) return "No se puede dividir entre cero.";
        return "$a entre $b es ${_formatNumber(a / b)}.";
      }

      // Suma: "50 más 30" o "50 + 30"
      final sumMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:más|mas|\+)\s*(\d+(?:\.\d+)?)').firstMatch(clean);
      if (sumMatch != null) {
        final a = double.parse(sumMatch.group(1)!);
        final b = double.parse(sumMatch.group(2)!);
        return "$a más $b es ${_formatNumber(a + b)}.";
      }

      // Resta: "100 menos 35" o "100 - 35"
      final subMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:menos|\-)\s*(\d+(?:\.\d+)?)').firstMatch(clean);
      if (subMatch != null) {
        final a = double.parse(subMatch.group(1)!);
        final b = double.parse(subMatch.group(2)!);
        return "$a menos $b es ${_formatNumber(a - b)}.";
      }
    } catch (_) {}
    return null;
  }

  String _formatNumber(double n) {
    if (n == n.roundToDouble()) {
      return n.toInt().toString();
    }
    return n.toStringAsFixed(2);
  }

  /// Base de conocimiento rápido y respuestas concisas (1 a 2 oraciones)
  String? _answerKnowledge(String input) {
    // Capitales
    if (input.contains('capital de colombia')) return "La capital de Colombia es Bogotá.";
    if (input.contains('capital de francia')) return "La capital de Francia es París.";
    if (input.contains('capital de españa') || input.contains('capital de espana')) return "La capital de España es Madrid.";
    if (input.contains('capital de méxico') || input.contains('capital de mexico')) return "La capital de México es Ciudad de México.";
    if (input.contains('capital de estados unidos')) return "La capital de Estados Unidos es Washington D.C.";
    if (input.contains('capital de argentina')) return "La capital de Argentina es Buenos Aires.";
    if (input.contains('capital de perú') || input.contains('capital de peru')) return "La capital de Perú es Lima.";

    // Preguntas científicas / universales
    if (input.contains('planeta más grande') || input.contains('planeta mas grande')) return "Júpiter es el planeta más grande del sistema solar.";
    if (input.contains('velocidad de la luz')) return "La velocidad de la luz en el vacío es de aproximadamente 300.000 kilómetros por segundo.";
    if (input.contains('hueso más largo') || input.contains('hueso mas largo')) return "El fémur es el hueso más largo y fuerte del cuerpo humano.";
    if (input.contains('océano más grande') || input.contains('oceano mas grande')) return "El océano Pacífico es el más grande del mundo.";

    // Cocina / Tips rápidos
    if (input.contains('cocinar un huevo duro') || input.contains('huevo cocido')) return "Hierve el huevo en agua durante 9 a 10 minutos para que quede cocido perfecto.";
    if (input.contains('quitar manchas de café') || input.contains('mancha de cafe')) return "Aplica vinagre blanco o agua tibia con jabón de inmediato sobre la tela.";

    return null;
  }

  String? _extractContact(String input) {
    final contactRegex = RegExp(r'\b(contacto|chat de|chat con|a|al|con|para)\s+([a-záéíóúñ]+)', caseSensitive: false);
    final matches = contactRegex.allMatches(input);
    for (final m in matches) {
      final candidate = m.group(2)!.trim();
      final lower = candidate.toLowerCase();
      if (!['a', 'al', 'con', 'para', 'whatsapp', 'wasap', 'wsp', 'whap', 'wha', 'wh', 'el', 'la', 'un', 'una', 'mi', 'los', 'las', 'que', 'chat', 'de', 'telegram', 'teléfono', 'telefono', 'instagram', 'facebook', 'tiktok'].contains(lower)) {
        return candidate[0].toUpperCase() + candidate.substring(1);
      }
    }
    return null;
  }

  String? _extractMessageText(String input) {
    if (input.contains('diciendo') || input.contains('dile que') || input.contains('dile') || input.contains('escribe que') || input.contains('escribe') || input.contains('que ')) {
      final parts = input.split(RegExp(r'(diciendo|dile que|dile|escribe que|escribe|escríbele que|escribele que|mensaje)\s+', caseSensitive: false));
      if (parts.length > 1) {
        final text = parts.last.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  bool _isStopCommand(String input) {
    final trimmed = input.trim().toLowerCase();
    const stopWords = {'para', 'ya', 'stop', 'silencio', 'cállate', 'callate', 'alto', 'detente', 'basta', 'pausa', 'shh'};
    if (stopWords.contains(trimmed)) return true;
    const stopPhrases = [
      'para ya', 'ya para', 'cállate ya', 'callate ya', 'detente ya', 'alto ahí', 'alto ahi', 'para por favor'
    ];
    for (final p in stopPhrases) {
      if (trimmed == p) return true;
    }
    return false;
  }

  bool _isWaitOrCorrection(String input) {
    final trimmed = input.trim().toLowerCase();
    const waitWords = {
      'espera', 'espérate', 'esperate', 'un momento', 'espera un momento',
      'no esa no', 'esa no', 'otra', 'otro', 'esa otra'
    };
    return waitWords.contains(trimmed);
  }

  bool _matchesAny(String input, List<String> patterns) {
    for (final pattern in patterns) {
      if (input.contains(pattern)) return true;
    }
    return false;
  }
}

class _AppInfo {
  final ActionType type;
  final String packageName;
  final String displayName;

  const _AppInfo(this.type, this.packageName, this.displayName);
}
