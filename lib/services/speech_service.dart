import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isSpeechInitialized = false;
  bool _isTtsInitialized = false;
  bool isMuted = false;

  bool get isListening => _speechToText.isListening;

  /// Inicializa el motor de Reconocimiento de Voz (STT)
  Future<bool> initializeSpeech({
    Function(String status)? onStatus,
    Function(String error)? onError,
  }) async {
    if (_isSpeechInitialized) return true;
    try {
      _isSpeechInitialized = await _speechToText.initialize(
        onStatus: onStatus,
        onError: (errorNotification) {
          if (onError != null) {
            onError(errorNotification.errorMsg);
          }
        },
      );
      return _isSpeechInitialized;
    } catch (e) {
      return false;
    }
  }

  /// Inicializa el motor de Voz de Salida (TTS)
  Future<void> initializeTts() async {
    if (_isTtsInitialized) return;
    try {
      await _flutterTts.setLanguage('es-ES');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isTtsInitialized = true;
    } catch (_) {
      // Fallback a configuración por defecto
    }
  }

  /// Comienza a escuchar al usuario
  Future<void> startListening({
    required Function(String words, bool isFinal) onResult,
    Function(double soundLevel)? onSoundLevelChange,
  }) async {
    if (!_isSpeechInitialized) {
      final initialized = await initializeSpeech();
      if (!initialized) return;
    }

    // Detener TTS si estaba hablando
    await stopSpeaking();

    await _speechToText.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevelChange,
      listenOptions: stt.SpeechListenOptions(
        localeId: 'es_ES',
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  /// Detiene la escucha
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }

  /// Hace que el asistente hable en voz alta
  Future<void> speak(
    String text, {
    Function()? onStart,
    Function()? onDone,
  }) async {
    if (isMuted) return;

    if (!_isTtsInitialized) {
      await initializeTts();
    }

    if (onStart != null) {
      _flutterTts.setStartHandler(onStart);
    }
    if (onDone != null) {
      _flutterTts.setCompletionHandler(onDone);
    }

    final cleanText = _sanitizeForTts(text);
    if (cleanText.trim().isEmpty) return;

    await _flutterTts.speak(cleanText);
  }

  /// Detiene la voz del asistente
  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  String _sanitizeForTts(String text) {
    return text.replaceAll('*', '').replaceAll('`', '').replaceAll('#', '');
  }

  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
  }
}
