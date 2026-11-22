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

  /// Procesa la entrada del usuario reconociendo su nombre personalizado y comandos
  BrainResponse processInput(
    String rawInput,
    bool Function(String appName) isAppAuthorized,
  ) {
    String input = rawInput.trim();
    final lowerName = assistantName.toLowerCase();

    // 1. Detección y limpieza de la palabra clave de activación (Wake Word)
    final wakePrefixes = [
      'oye $lowerName',
      'hey $lowerName',
      'hola $lowerName',
      'ok $lowerName',
      'a ver $lowerName',
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
        "¿Dime, aquí estoy? ¿Qué necesitas que hagamos?",
        "¡A la orden! ¿En qué te colaboro?",
        "Te escucho fuerte y claro. Dime qué aplicación abrimos o qué consultamos.",
        "¡Aquí estoy! Dime qué necesitas.",
      ];
      return BrainResponse(
        text: wakeReplies[_random.nextInt(wakeReplies.length)],
      );
    }

    final effectiveInput = cleanCommand.isNotEmpty ? cleanCommand : input.toLowerCase();

    // 2. Comando por voz para cambiar su propio nombre
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

    // 3. Detección de Intent para abrir Aplicaciones
    final appAction = _detectAppAction(effectiveInput);
    if (appAction != null) {
      // Verificamos si la app ya fue autorizada permanentemente
      final isAuthorized = isAppAuthorized(appAction.appName);
      final needsAuth = !isAuthorized;
      final text = needsAuth
          ? "He preparado la acción para ${appAction.appName}. Como es la primera vez, ¿autorizas abrir la aplicación?"
          : "Abriendo ${appAction.appName}...";

      return BrainResponse(
        text: text,
        action: appAction,
        requiresAuthorization: needsAuth,
      );
    }

    // 4. Preguntas de Información / Utilidad
    if (effectiveInput.contains('hora') || effectiveInput.contains('qué horas') || effectiveInput.contains('que horas')) {
      final now = DateTime.now();
      final timeStr = DateFormat('h:mm a').format(now);
      return BrainResponse(
        text: "Son las $timeStr en este momento. ⏰",
      );
    }

    if (effectiveInput.contains('fecha') || effectiveInput.contains('qué día es') || effectiveInput.contains('que dia es')) {
      final now = DateTime.now();
      final dateStr = DateFormat('EEEE d \'de\' MMMM \'de\' yyyy', 'es_ES').format(now);
      return BrainResponse(
        text: "Hoy es $dateStr. 📅",
      );
    }

    // 5. Saludos e Identidad
    if (_matchesAny(effectiveInput, ['quién eres', 'quien eres', 'cómo te llamas', 'como te llamas'])) {
      return BrainResponse(
        text: "Me llamo **$assistantName**, tu asistente móvil inteligente. Puedes llamarme diciendo «Oye $assistantName». 🚀",
      );
    }

    if (_matchesAny(effectiveInput, ['hola', 'buenos días', 'buenas tardes', 'buenas noches', 'hey', 'que tal'])) {
      final greetings = [
        "¡Hola! Qué gusto saludarte. Soy $assistantName, ¿en qué te colaboro?",
        "¡Ey! Aquí estoy listo. Dime qué necesitas.",
        "¡Hola! Tu asistente a tu servicio. ¿Qué aplicación abrimos?",
      ];
      return BrainResponse(text: greetings[_random.nextInt(greetings.length)]);
    }

    if (_matchesAny(effectiveInput, ['cómo estás', 'como estas', 'cómo te va'])) {
      return BrainResponse(
        text: "¡Al 100% y con la energía al máximo! ¿Y tú qué tal? ¿Qué plan tenemos?",
      );
    }

    // 6. Entretenimiento: Chistes y Motivación
    if (_matchesAny(effectiveInput, ['chiste', 'cuéntame un chiste', 'hazme reír', 'un chiste'])) {
      final jokes = [
        "¿Qué le dice un semáforo a otro? ¡No me mires que me estoy cambiando! 😂",
        "¿Por qué los pájaros no usan WhatsApp? Porque ya tienen Twitter. 🐦",
        "¿Cuál es el colmo de un electricista? Que su esposa se llame Luz y los hijos le sigan la corriente. ⚡",
        "¿Qué hace una abeja en el gimnasio? ¡Zum-ba! 🐝",
      ];
      return BrainResponse(text: jokes[_random.nextInt(jokes.length)]);
    }

    if (_matchesAny(effectiveInput, ['consejo', 'motívame', 'motivación', 'frase'])) {
      final quotes = [
        "«La mejor forma de predecir el futuro es creándolo.» ¡A darle con todo hoy! 💪",
        "«El éxito es la suma de pequeños esfuerzos repetidos día tras día.» ¡Vas por buen camino!",
        "«No cuentes los días, haz que los días cuenten.» ¡Tú puedes con todo! ✨",
      ];
      return BrainResponse(text: quotes[_random.nextInt(quotes.length)]);
    }

    if (_matchesAny(effectiveInput, ['gracias', 'muchas gracias', 'te agradezco'])) {
      return BrainResponse(
        text: "¡Con muchísimo gusto! Para eso estamos. ¿Algo más en lo que pueda colaborar? 😊",
      );
    }

    if (_matchesAny(effectiveInput, ['actualizar', 'actualización', 'actualizacion', 'nueva versión', 'nueva version'])) {
      return BrainResponse(
        text: "Voy a comprobar si hay una nueva versión del asistente disponible para actualizar.",
      );
    }

    // Respuesta general
    return BrainResponse(
      text: "Entendido: «$rawInput». ¿Deseas que busque esto en la web o quieres que abramos alguna aplicación?",
    );
  }

  AppAction? _detectAppAction(String input) {
    // 1. WhatsApp con todas sus variantes de pronunciación y jerga
    final isWhatsApp = input.contains('whatsapp') ||
        input.contains('guasap') ||
        input.contains('wasap') ||
        input.contains('wsp') ||
        input.contains('whap') ||
        input.contains('wha') ||
        input.contains('whats') ||
        input.contains('wh') ||
        input.contains('mensaje a') ||
        input.contains('chat');

    if (isWhatsApp) {
      String? textPayload;
      if (input.contains('mensaje') || input.contains('diciendo')) {
        final parts = input.split(RegExp(r'(diciendo|mensaje|que)'));
        if (parts.length > 1) {
          textPayload = parts.last.trim();
        }
      }
      return AppAction(
        type: ActionType.whatsapp,
        appName: 'WhatsApp',
        packageName: 'com.whatsapp',
        payload: textPayload,
        description: textPayload != null && textPayload.isNotEmpty
            ? 'Abrir WhatsApp y redactar: "$textPayload"'
            : 'Abrir la aplicación WhatsApp',
      );
    }

    // 2. YouTube
    if (input.contains('youtube') || input.contains('yutub') || input.contains('yt') || input.contains('video') || input.contains('pon en youtube')) {
      String? query;
      final clean = input
          .replaceAll(RegExp(r'(abre|abrir|pon en|busca en|buscar en|en|video de|pon)\s+'), '')
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
    if (input.contains('cámara') || input.contains('camara') || input.contains('foto') || input.contains('fotos') || input.contains('selfie')) {
      return AppAction(
        type: ActionType.camera,
        appName: 'Cámara',
        packageName: 'com.android.camera',
        description: 'Abrir la Cámara del teléfono',
      );
    }

    // 5. Mapas / Navegación
    if (input.contains('mapa') || input.contains('mapas') || input.contains('maps') || input.contains('cómo llegar') || input.contains('como llegar') || input.contains('dónde queda') || input.contains('llevame') || input.contains('llévame')) {
      String? destination;
      final clean = input
          .replaceAll(RegExp(r'(abre|abrir|cómo llegar a|como llegar a|llévame a|llevame a|dónde queda)\s+'), '')
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
    if (input.startsWith('llama') || input.startsWith('marcar') || input.contains('teléfono') || input.contains('telefono')) {
      final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
      return AppAction(
        type: ActionType.dialer,
        appName: 'Teléfono',
        packageName: 'com.android.dialer',
        payload: digits.isNotEmpty ? digits : null,
        description: digits.isNotEmpty ? 'Llamar al número $digits' : 'Abrir el teclado telefónico',
      );
    }

    // 7. Navegador Web
    if (input.startsWith('busca ') || input.startsWith('buscar ') || input.contains('navegador') || input.contains('google')) {
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

  bool _matchesAny(String input, List<String> triggers) {
    for (final trigger in triggers) {
      if (input.contains(trigger)) return true;
    }
    return false;
  }
}
