import 'dictation_input_mode.dart';

/// Normalise le texte reconnu par la dictée selon le type de champ.
class SpeechTextNormalizer {
  SpeechTextNormalizer._();

  static String normalize(String raw, DictationInputMode mode) {
    var text = raw.trim();
    if (text.isEmpty) return text;

    text = text.toLowerCase();
    text = text
        .replaceAll('virgule', ',')
        .replaceAll('point', mode == DictationInputMode.timeColon ? ':' : ',')
        .replaceAll('deux-points', ':')
        .replaceAll('deux points', ':');

    switch (mode) {
      case DictationInputMode.numericComma:
        text = text.replaceAll(RegExp(r'[^0-9,]'), '');
        return _singleComma(text);
      case DictationInputMode.timeColon:
        text = text.replaceAll(RegExp(r'[^0-9:]'), '');
        return _singleColon(text);
      case DictationInputMode.freeText:
        return raw.trim();
    }
  }

  static String _singleComma(String value) {
    final parts = value.split(',');
    if (parts.length <= 2) return value;
    return '${parts.first},${parts.sublist(1).join()}';
  }

  static String _singleColon(String value) {
    final parts = value.split(':');
    if (parts.length <= 2) return value;
    return '${parts.first}:${parts.sublist(1).join()}';
  }
}
