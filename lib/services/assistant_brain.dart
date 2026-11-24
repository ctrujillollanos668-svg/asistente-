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
  String assistantName = "Jarvis";

  /// Memoria conversacional activa (Multi-turno / Estado de la conversación)
  String? activeContext; // 'whatsapp', 'youtube', 'spotify', 'dialer'
  String? contextContact; // Contacto recordado en el flujo

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

  /// Procesa la entrada del usuario reconociendo su nombre personalizado, contexto y comandos
  BrainResponse processInput(
    String rawInput,
    bool Function(String appName) isAppAuthorized,
  ) {
    String input = rawInput.trim();
    final lowerName = assistantName.toLowerCase();

    // 1. Detección y limpieza de la palabra clave de activación (Wake Word)
    final wakePrefixes = [
      'oye $lowerName',
      'oiga $lowerName',
      'hey $lowerName',
      'hola $lowerName',
      'ok $lowerName',
      'a ver $lowerName',
      'dale $lowerName',
      'parce $lowerName',
      'mira $lowerName',
      'ey $lowerName',
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

    // Si solo lo llamaron por su nombre ("Jarvis" u "Oye Jarvis")
    if (calledByName && cleanCommand.isEmpty) {
      final wakeReplies = [
        "¡Qué más! Aquí estoy, dime qué necesitas y lo hacemos ya. 🚀",
        "¡A la orden! ¿En qué te colaboro? Puedo abrir cualquier app, hacer llamadas, buscar info...",
        "Te escucho fuerte y claro. Dime qué aplicación abrimos o qué consultamos. 💪",
        "¡Aquí estoy! Pídeme lo que quieras: WhatsApp, YouTube, Instagram, llamadas, lo que sea.",
        "¡Bacán! Dime y lo hacemos. Puedo abrir cualquier app de tu teléfono. ✨",
      ];
      return BrainResponse(
        text: wakeReplies[_random.nextInt(wakeReplies.length)],
      );
    }

    final effectiveInput = cleanCommand.isNotEmpty ? cleanCommand : input.toLowerCase();

    // 2. Comando para cancelar el contexto actual
    if (_matchesAny(effectiveInput, ['cancela', 'cancelar', 'olvídalo', 'olvidalo', 'nada', 'ninguna', 'dejalo', 'déjalo'])) {
      activeContext = null;
      contextContact = null;
      return BrainResponse(
        text: "De acuerdo, cancelado. ¿Qué otra cosa hacemos? 😎",
      );
    }

    // 3. Procesamiento en caso de CONTEXTO ACTIVO (Segunda parte de la conversación)
    if (activeContext != null) {
      final responseFromContext = _handleActiveContext(effectiveInput, isAppAuthorized);
      if (responseFromContext != null) {
        return responseFromContext;
      }
    }

    // 4. Comando por voz para cambiar su propio nombre
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
            text: "¡Perfecto! A partir de ahora mi nombre es **$assistantName**. Cuando me necesites, solo di «Oye $assistantName». ✨",
            newAssistantName: assistantName,
          );
        }
      }
    }

    // 5. ¿Qué puedes hacer? / Ayuda / Capacidades
    if (_matchesAny(effectiveInput, ['qué puedes hacer', 'que puedes hacer', 'qué sabes hacer', 'que sabes hacer', 'ayuda', 'help', 'funciones', 'capacidades', 'qué haces', 'que haces', 'para qué sirves', 'para que sirves'])) {
      return BrainResponse(
        text: "¡Puedo hacer de todo! Aquí van algunas cosas:\n\n"
            "📱 **Redes Sociales** – Abrir WhatsApp, Instagram, Facebook, TikTok, Twitter/X, Telegram, Snapchat, Pinterest, LinkedIn\n"
            "🎵 **Entretenimiento** – YouTube, Spotify, Netflix\n"
            "📞 **Comunicación** – Llamar a contactos, enviar correos\n"
            "🗺️ **Navegación** – Google Maps, Waze, Uber\n"
            "📷 **Multimedia** – Cámara, Galería de fotos\n"
            "🔧 **Utilidades** – Calculadora, Reloj/Alarma, Calendario, Notas, Archivos, Ajustes\n"
            "🌐 **Web** – Buscar cualquier cosa en Google\n"
            "🤖 **Personalización** – Cambiar mi nombre, contarte chistes, motivarte\n\n"
            "Solo dime «Abre [app]» o pídeme lo que necesites. ¡Soy tu asistente completo! 🔥",
      );
    }

    // 6. Detección de Intent para abrir Aplicaciones o iniciar flujo contextual
    final appAction = _detectAppAction(effectiveInput);
    if (appAction != null) {
      // Si la app es WhatsApp y el usuario NO especificó contacto ni mensaje
      if (appAction.type == ActionType.whatsapp && (appAction.payload == null || appAction.payload!.isEmpty)) {
        activeContext = 'whatsapp';
        return BrainResponse(
          text: "He preparado WhatsApp. ¿Quieres entrar al chat de algún contacto para escribirle o prefieres que hagamos una llamada? 📱",
        );
      }

      // Si la app es YouTube y el usuario NO especificó video/música
      if (appAction.type == ActionType.youtube && (appAction.payload == null || appAction.payload!.isEmpty)) {
        activeContext = 'youtube';
        return BrainResponse(
          text: "YouTube listo. ¿Qué música, artista o video quieres reproducir? 🎬",
        );
      }

      // Si la app es Spotify y no especificó música
      if (appAction.type == ActionType.spotify && (appAction.payload == null || appAction.payload!.isEmpty)) {
        activeContext = 'spotify';
        return BrainResponse(
          text: "Spotify preparado. ¿Qué canción o lista deseas escuchar? 🎧",
        );
      }

      final isAuthorized = isAppAuthorized(appAction.appName);
      final needsAuth = !isAuthorized;
      String text;
      if (needsAuth) {
        text = "He preparado la acción para **${appAction.appName}**. Como es la primera vez, ¿autorizas abrir la aplicación? 🔐";
      } else {
        if (appAction.payload != null && appAction.payload!.isNotEmpty) {
          if (appAction.type == ActionType.whatsapp) {
            text = "¡Dale! Abriendo WhatsApp: ${appAction.description}... 📲";
          } else if (appAction.type == ActionType.youtube) {
            text = "¡A reproducir! Buscando «${appAction.payload}» en YouTube... 🎵";
          } else if (appAction.type == ActionType.spotify) {
            text = "¡Suena! Poniendo «${appAction.payload}» en Spotify... 🎶";
          } else if (appAction.type == ActionType.dialer) {
            text = "Preparando llamada para ${appAction.payload}... 📞";
          } else {
            text = "¡Abriendo ${appAction.appName}! Un momento... ⚡";
          }
        } else {
          text = "¡Abriendo ${appAction.appName}! Un momento... ⚡";
        }
      }

      return BrainResponse(
        text: text,
        action: appAction,
        requiresAuthorization: needsAuth,
      );
    }

    // 7. Preguntas de Información / Utilidad
    if (effectiveInput.contains('hora') || effectiveInput.contains('qué horas') || effectiveInput.contains('que horas')) {
      final now = DateTime.now();
      final timeStr = DateFormat('h:mm a').format(now);
      return BrainResponse(
        text: "Son las $timeStr en este momento. ⏰",
      );
    }

    if (effectiveInput.contains('fecha') || effectiveInput.contains('qué día es') || effectiveInput.contains('que dia es') || effectiveInput.contains('qué día') || effectiveInput.contains('que dia')) {
      final now = DateTime.now();
      final dateStr = DateFormat('EEEE d \'de\' MMMM \'de\' yyyy', 'es_ES').format(now);
      return BrainResponse(
        text: "Hoy es $dateStr. 📅",
      );
    }

    // 8. Saludos e Identidad
    if (_matchesAny(effectiveInput, ['quién eres', 'quien eres', 'cómo te llamas', 'como te llamas'])) {
      return BrainResponse(
        text: "Me llamo **$assistantName**, tu asistente móvil avanzado. 🤖\n\n"
            "Puedo abrir cualquier app de tu teléfono, hacer llamadas, enviar mensajes, buscar en internet y mucho más.\n"
            "Llámame diciendo «Oye $assistantName» y listo. 🚀",
      );
    }

    if (_matchesAny(effectiveInput, ['hola', 'buenos días', 'buenos dias', 'buenas tardes', 'buenas noches', 'hey', 'que tal', 'qué tal', 'ey', 'epa'])) {
      final greetings = [
        "¡Hola! ¿Qué más? Soy $assistantName, tu asistente a full. ¿Qué abrimos hoy? 🔥",
        "¡Ey! Aquí estoy listo para lo que necesites. Dime qué hacemos. 💪",
        "¡Hola! Tu asistente al servicio. ¿Qué aplicación abrimos o qué información necesitas? ✨",
        "¡Qué más pues! Aquí $assistantName, listo pa' lo que sea. 🚀",
      ];
      return BrainResponse(text: greetings[_random.nextInt(greetings.length)]);
    }

    if (_matchesAny(effectiveInput, ['cómo estás', 'como estas', 'cómo te va', 'como te va', 'qué onda', 'que onda'])) {
      return BrainResponse(
        text: "¡Al 100% y con la energía al máximo! ¿Y tú qué tal? ¿Qué plan tenemos? 💥",
      );
    }

    // 9. Entretenimiento: Chistes y Motivación
    if (_matchesAny(effectiveInput, ['chiste', 'cuéntame un chiste', 'hazme reír', 'un chiste', 'cuentame un chiste'])) {
      final jokes = [
        "¿Qué le dice un semáforo a otro? ¡No me mires que me estoy cambiando! 😂",
        "¿Por qué los pájaros no usan WhatsApp? Porque ya tienen Twitter. 🐦",
        "¿Cuál es el colmo de un electricista? Que su esposa se llame Luz y los hijos le sigan la corriente. ⚡",
        "¿Qué hace una abeja en el gimnasio? ¡Zum-ba! 🐝",
        "¿Por qué el celular fue al psicólogo? Porque perdió la conexión. 📱😂",
        "¿Qué le dice un 0 a un 8? ¡Bonito cinturón! 😄",
        "¿Cuál es el animal más viejo del mundo? La cebra, porque está en blanco y negro. 🦓",
      ];
      return BrainResponse(text: jokes[_random.nextInt(jokes.length)]);
    }

    if (_matchesAny(effectiveInput, ['consejo', 'motívame', 'motivame', 'motivación', 'motivacion', 'frase', 'frase motivacional'])) {
      final quotes = [
        "«La mejor forma de predecir el futuro es creándolo.» ¡A darle con todo hoy! 💪",
        "«El éxito es la suma de pequeños esfuerzos repetidos día tras día.» ¡Vas por buen camino!",
        "«No cuentes los días, haz que los días cuenten.» ¡Tú puedes con todo! ✨",
        "«El único límite es el que tú te pongas.» ¡Dale que se puede! 🔥",
        "«Cada día es una nueva oportunidad para ser increíble.» ¡A romperla! 💥",
      ];
      return BrainResponse(text: quotes[_random.nextInt(quotes.length)]);
    }

    if (_matchesAny(effectiveInput, ['gracias', 'muchas gracias', 'te agradezco', 'vale gracias', 'genial gracias'])) {
      final thanks = [
        "¡Con muchísimo gusto! Para eso estamos. ¿Algo más en lo que pueda colaborar? 😊",
        "¡De nada, parce! ¿Qué más hacemos? 💪",
        "¡Siempre a la orden! Dime si necesitas algo más. ✨",
      ];
      return BrainResponse(text: thanks[_random.nextInt(thanks.length)]);
    }

    if (_matchesAny(effectiveInput, ['actualizar', 'actualización', 'actualizacion', 'nueva versión', 'nueva version', 'update'])) {
      return BrainResponse(
        text: "Voy a comprobar si hay una nueva versión del asistente disponible para actualizar. 🔄",
      );
    }

    // 10. Matemáticas básicas
    if (_matchesAny(effectiveInput, ['cuánto es', 'cuanto es', 'cuánto da', 'cuanto da', 'calcula'])) {
      return BrainResponse(
        text: "¡Para cálculos avanzados voy a abrir la calculadora! 🧮",
        action: AppAction(
          type: ActionType.calculator,
          appName: 'Calculadora',
          packageName: 'com.google.android.calculator',
          description: 'Abrir la Calculadora',
        ),
        requiresAuthorization: !isAppAuthorized('Calculadora'),
      );
    }

    // 11. Detección si menciona contactos en general
    if (effectiveInput.contains('contacto') || effectiveInput.contains('mamá') || effectiveInput.contains('mama') || effectiveInput.contains('papá') || effectiveInput.contains('papa') || effectiveInput.contains('novia') || effectiveInput.contains('novio') || effectiveInput.contains('hermano') || effectiveInput.contains('hermana') || effectiveInput.contains('amigo') || effectiveInput.contains('amiga')) {
      activeContext = 'whatsapp';
      contextContact = _extractContact(effectiveInput);
      return BrainResponse(
        text: "Entendido. ¿Deseas que le escribamos por WhatsApp, Telegram o prefieres llamarle por teléfono? 📱",
      );
    }

    // 12. Despedidas
    if (_matchesAny(effectiveInput, ['adiós', 'adios', 'chao', 'nos vemos', 'hasta luego', 'bye', 'chau'])) {
      final farewells = [
        "¡Hasta luego! Cuando me necesites, solo di «Oye $assistantName». ¡Cuídate! 👋",
        "¡Chao! Aquí estaré cuando quieras. ¡Que te vaya bacán! ✌️",
        "¡Nos vemos! Recuerda que estoy siempre disponible para ti. 🚀",
      ];
      return BrainResponse(text: farewells[_random.nextInt(farewells.length)]);
    }

    // Respuestas conversacionales naturales (fallback inteligente)
    final smartFallbacks = [
      "Te escucho. ¿Quieres que abra alguna app? Puedo abrir WhatsApp, Instagram, YouTube, TikTok, Netflix, o lo que necesites. 📱",
      "Comprendido. Dime qué aplicación quieres que abra o qué información necesitas. ¡Estoy pa' lo que sea! 💪",
      "Aquí estoy listo. Puedo abrir cualquier app, hacer llamadas, buscar en internet o contarte un chiste. ¿Qué hacemos? 🚀",
      "No estoy seguro de qué necesitas. ¿Quieres que abra alguna aplicación o que busque algo? Di «Ayuda» para ver todo lo que puedo hacer. ✨",
    ];
    return BrainResponse(
      text: smartFallbacks[_random.nextInt(smartFallbacks.length)],
    );
  }

  /// Maneja respuestas cuando el usuario ya estaba en un flujo (ej: ya pidió WhatsApp y ahora da el mensaje o contacto)
  BrainResponse? _handleActiveContext(String input, bool Function(String appName) isAppAuthorized) {
    if (activeContext == 'whatsapp') {
      // Si el usuario pide simplemente abrir la app
      if (input.contains('solo abre') || input.contains('abre la app') || input.contains('entra a la app') || input == 'abrir') {
        activeContext = null;
        contextContact = null;
        return BrainResponse(
          text: "¡Abriendo WhatsApp! 📲",
          action: AppAction(
            type: ActionType.whatsapp,
            appName: 'WhatsApp',
            packageName: 'com.whatsapp',
            description: 'Abrir WhatsApp',
          ),
          requiresAuthorization: !isAppAuthorized('WhatsApp'),
        );
      }

      // Si pide hacer una llamada
      if (input.contains('llama') || input.contains('llamar') || input.contains('llamada')) {
        final contact = _extractContact(input) ?? contextContact ?? 'tu contacto';
        activeContext = null;
        contextContact = null;
        return BrainResponse(
          text: "Preparando llamada para $contact... 📞",
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

      // Si pide por Telegram en vez de WhatsApp
      if (input.contains('telegram')) {
        activeContext = null;
        contextContact = null;
        return BrainResponse(
          text: "¡Dale! Abriendo Telegram... ✈️",
          action: AppAction(
            type: ActionType.telegram,
            appName: 'Telegram',
            packageName: 'org.telegram.messenger',
            description: 'Abrir Telegram',
          ),
          requiresAuthorization: !isAppAuthorized('Telegram'),
        );
      }

      // Si pide escribir o entrar a un chat
      final contact = _extractContact(input) ?? contextContact;
      final message = _extractMessageText(input);

      activeContext = null;
      contextContact = null;

      final targetDescription = contact != null ? "a $contact" : "en el chat";
      final msgPart = message != null ? " con el mensaje: «$message»" : "";

      return BrainResponse(
        text: "Entrando a WhatsApp para escribir $targetDescription$msgPart... 📲",
        action: AppAction(
          type: ActionType.whatsapp,
          appName: 'WhatsApp',
          packageName: 'com.whatsapp',
          payload: message ?? contact,
          description: 'Enviar WhatsApp $targetDescription',
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
        text: "¡A reproducir! Buscando «$cleanQuery» en YouTube... 🎬",
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
        text: "¡Suena! Poniendo «$cleanSong» en Spotify... 🎧",
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
    // ═══════════════════════════════════════════════════════════
    //  1. WhatsApp con todas sus variantes, contactos y mensajes
    // ═══════════════════════════════════════════════════════════
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

    // ═══════════════════════════════════════════════════════════
    //  2. YouTube
    // ═══════════════════════════════════════════════════════════
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

    // ═══════════════════════════════════════════════════════════
    //  3. Spotify / Música
    // ═══════════════════════════════════════════════════════════
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

    // ═══════════════════════════════════════════════════════════
    //  4. Cámara
    // ═══════════════════════════════════════════════════════════
    if (input.contains('cámara') || input.contains('camara') || input.contains('selfie') ||
        (input.contains('foto') && !input.contains('galería') && !input.contains('galeria') && !input.contains('fotos'))) {
      return AppAction(
        type: ActionType.camera,
        appName: 'Cámara',
        packageName: 'com.android.camera',
        description: 'Abrir la Cámara del teléfono',
      );
    }

    // ═══════════════════════════════════════════════════════════
    //  5. Mapas / Navegación
    // ═══════════════════════════════════════════════════════════
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

    // ═══════════════════════════════════════════════════════════
    //  6. Teléfono / Llamadas
    // ═══════════════════════════════════════════════════════════
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

    // ═══════════════════════════════════════════════════════════
    //  7. Email / Correo
    // ═══════════════════════════════════════════════════════════
    if (input.contains('correo') || input.contains('email') || input.contains('mail') || input.contains('gmail')) {
      return AppAction(
        type: ActionType.email,
        appName: 'Correo',
        packageName: 'com.google.android.gm',
        description: 'Abrir el correo electrónico',
      );
    }

    // ═══════════════════════════════════════════════════════════
    //  8. CATÁLOGO GENERAL – busca en el mapa maestro de apps
    //  (Ordenado por longitud descendente y con límites de palabra para evitar falsos positivos)
    // ═══════════════════════════════════════════════════════════
    for (final entry in _sortedAppCatalogEntries) {
      // Usar delimitador de palabras (\b) para que 'x' no coincida dentro de 'netflix', o 'fb' dentro de otra palabra
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

    // ═══════════════════════════════════════════════════════════
    //  9. Detectar patrones genéricos "abre [X]" / "abrir [X]" / "inicia [X]"
    // ═══════════════════════════════════════════════════════════
    final openPatterns = RegExp(r'(abre|abrir|abrí|abrime|inicia|iniciar|lanza|lanzar|ejecuta|ejecutar|entra a|entrar a|abrele|meteme en|mete)\s+(.+)', caseSensitive: false);
    final openMatch = openPatterns.firstMatch(input);
    if (openMatch != null) {
      final appNameRaw = openMatch.group(2)!.trim().replaceAll(RegExp(r'^(el|la|los|las|mi|una?)\s+'), '');
      // Buscar en catálogo por nombre
      for (final entry in _appCatalog.entries) {
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

    // ═══════════════════════════════════════════════════════════
    //  10. Navegador Web (fallback de búsqueda)
    // ═══════════════════════════════════════════════════════════
    if (input.startsWith('busca ') || input.startsWith('buscar ') || input.contains('navegador') || input.contains('google') || input.contains('internet')) {
      final query = input
          .replaceAll(RegExp(r'(busca en google|buscar en google|busca en internet|buscar en internet|busca|buscar)\s+'), '')
          .trim();
      return AppAction(
        type: ActionType.browser,
        appName: 'Navegador Web',
        packageName: 'com.android.chrome',
        payload: query.isNotEmpty ? query : null,
        description: query.isNotEmpty ? 'Buscar en la web: "$query"' : 'Abrir el navegador',
      );
    }

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

  bool _matchesAny(String input, List<String> patterns) {
    for (final pattern in patterns) {
      if (input.contains(pattern)) return true;
    }
    return false;
  }
}

/// Clase auxiliar para el catálogo de apps
class _AppInfo {
  final ActionType type;
  final String packageName;
  final String displayName;

  const _AppInfo(this.type, this.packageName, this.displayName);
}
