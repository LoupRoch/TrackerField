import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Service singleton de reconnaissance vocale (hors-ligne si disponible).
class DictationService {
  DictationService._();

  static final DictationService instance = DictationService._();

  final SpeechToText _speech = SpeechToText();
  var _initialized = false;
  var _unavailable = false;
  var _listening = false;

  bool get isListening => _listening;
  bool get isUnavailable => _unavailable;

  Future<bool> ensureInitialized() async {
    if (_unavailable) return false;
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _listening = false;
          }
        },
        onError: (_) => _listening = false,
      );
      if (!_initialized) _unavailable = true;
      return _initialized;
    } catch (error, stack) {
      debugPrint('DictationService init failed: $error\n$stack');
      _unavailable = true;
      _initialized = false;
      return false;
    }
  }

  Future<String?> listen({
    Duration listenFor = const Duration(seconds: 12),
    String localeId = 'fr_FR',
  }) async {
    if (!await ensureInitialized()) return null;
    if (_listening) return null;

    final completer = Completer<String?>();
    var resultReceived = false;

    _listening = true;
    try {
      await _speech.listen(
        onResult: (result) {
          if (!result.finalResult) return;
          resultReceived = true;
          if (!completer.isCompleted) {
            completer.complete(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: listenFor,
          pauseFor: const Duration(seconds: 3),
          cancelOnError: true,
          partialResults: false,
        ),
      );
    } catch (error, stack) {
      debugPrint('DictationService listen failed: $error\n$stack');
      _listening = false;
      return null;
    }

    try {
      final text = await completer.future.timeout(
        listenFor + const Duration(seconds: 2),
        onTimeout: () => null,
      );
      return text;
    } finally {
      _listening = false;
      try {
        if (_speech.isListening) {
          await _speech.stop();
        }
      } catch (_) {}
      if (!resultReceived && !completer.isCompleted) {
        completer.complete(null);
      }
    }
  }

  Future<void> stop() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
    _listening = false;
  }
}
