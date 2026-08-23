import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Résultat d'une tentative de dictée.
class DictationResult {
  const DictationResult.ok(this.text)
      : errorMessage = null,
        isOk = true;

  const DictationResult.error(this.errorMessage)
      : text = null,
        isOk = false;

  final String? text;
  final String? errorMessage;
  final bool isOk;
}

/// Service singleton de reconnaissance vocale.
class DictationService {
  DictationService._();

  static final DictationService instance = DictationService._();

  final SpeechToText _speech = SpeechToText();
  var _initialized = false;
  var _listening = false;
  String? _lastError;

  bool get isListening => _listening;
  String? get lastError => _lastError;

  Future<bool> ensureInitialized({bool forceRetry = false}) async {
    if (_initialized && !forceRetry) return true;
    if (forceRetry) {
      _initialized = false;
      _lastError = null;
    }

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _listening = false;
          }
        },
        onError: (error) {
          _listening = false;
          _lastError = error.errorMsg;
          debugPrint('SpeechToText error: ${error.errorMsg}');
        },
      );
      _initialized = available;
      if (!available) {
        _lastError =
            'Reconnaissance vocale indisponible sur cet appareil. '
            'Installe / active « Speech Services by Google » (ou l\'app Google), '
            'puis vérifie qu\'un clavier vocal fonctionne ailleurs.';
      }
      return available;
    } catch (error, stack) {
      debugPrint('DictationService init failed: $error\n$stack');
      _initialized = false;
      final message = error.toString();
      if (message.contains('recognizerNotAvailable')) {
        _lastError =
            'Reconnaissance vocale indisponible sur cet appareil. '
            'Installe / active « Speech Services by Google », puis réessaie.';
      } else if (message.toLowerCase().contains('permission') ||
          message.toLowerCase().contains('denied')) {
        _lastError =
            'Permission micro refusée. Autorise le micro dans les réglages de l\'appareil.';
      } else {
        _lastError = 'Impossible d\'initialiser la dictée : $error';
      }
      return false;
    }
  }

  Future<DictationResult> listen({
    Duration listenFor = const Duration(seconds: 12),
    String preferredLocale = 'fr_FR',
  }) async {
    if (!await ensureInitialized(forceRetry: !_initialized)) {
      return DictationResult.error(
        _lastError ?? 'Dictée indisponible sur cet appareil.',
      );
    }
    if (_listening) {
      return const DictationResult.error('Une dictée est déjà en cours.');
    }

    final locales = await _speech.locales();
    String? localeId;
    for (final locale in locales) {
      if (locale.localeId == preferredLocale ||
          locale.localeId.startsWith('fr')) {
        localeId = locale.localeId;
        break;
      }
    }
    localeId ??= locales.isNotEmpty ? locales.first.localeId : preferredLocale;

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
      return DictationResult.error('Échec du démarrage de la dictée : $error');
    }

    try {
      final text = await completer.future.timeout(
        listenFor + const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (text == null || text.trim().isEmpty) {
        return const DictationResult.error(
          'Aucun texte reconnu. Réessaie en parlant plus clairement.',
        );
      }
      return DictationResult.ok(text.trim());
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
