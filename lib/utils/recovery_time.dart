/// Utilitaires pour le format min:sec des temps de récupération.
class RecoveryTime {
  RecoveryTime._();

  /// Décompose une valeur « M:SS » ou « MM:SS » en minutes et secondes.
  static ({String minutes, String seconds}) parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return (minutes: '', seconds: '');
    }
    final parts = trimmed.split(':');
    if (parts.length == 1) {
      return (minutes: parts[0], seconds: '');
    }
    return (minutes: parts[0], seconds: parts[1]);
  }

  /// Assemble minutes et secondes en « M:SS » (secondes sur 2 chiffres).
  static String format(String minutes, String seconds) {
    final m = minutes.trim();
    final s = seconds.trim();
    if (m.isEmpty && s.isEmpty) return '';

    final minPart = m.isEmpty ? '0' : m;
    final secNum = int.tryParse(s.isEmpty ? '0' : s) ?? 0;
    final clampedSec = secNum.clamp(0, 59);
    return '$minPart:${clampedSec.toString().padLeft(2, '0')}';
  }

  /// Secondes autorisées pour la récupération (quarts de minute).
  static const allowedSecondValues = [0, 15, 30, 45];

  /// Ramène les secondes au quart de minute le plus proche (0, 15, 30 ou 45).
  static int snapSeconds(int seconds) {
    final clamped = seconds.clamp(0, 59);
    var closest = allowedSecondValues.first;
    var minDiff = (clamped - closest).abs();
    for (final candidate in allowedSecondValues) {
      final diff = (clamped - candidate).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = candidate;
      }
    }
    return closest;
  }

  /// Convertit une chaîne « M:SS » en [Duration].
  static Duration toDuration(String? value) {
    final parsed = parse(value ?? '');
    final minutes = int.tryParse(parsed.minutes) ?? 0;
    final seconds = int.tryParse(parsed.seconds) ?? 0;
    return Duration(
      minutes: minutes,
      seconds: snapSeconds(seconds),
    );
  }

  /// Formate une durée en « MM:SS » (affichage et saisie).
  static String fromDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = snapSeconds(duration.inSeconds % 60);
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Normalise une valeur existante pour l'affichage « MM:SS ».
  static String normalizeDisplay(String? value) {
    if (value == null || value.trim().isEmpty) return '00:00';
    return fromDuration(toDuration(value));
  }

  static String? validateRequired(String? value) {
    if (value == null || value.trim().isEmpty || value == '00:00') {
      return 'Requis';
    }
    return null;
  }

  static String? validateRequiredParts(String minutes, String seconds) {
    if (minutes.trim().isEmpty && seconds.trim().isEmpty) {
      return 'Requis';
    }
    final secText = seconds.trim();
    if (secText.isNotEmpty) {
      final sec = int.tryParse(secText);
      if (sec == null || !allowedSecondValues.contains(sec)) {
        return 'Secondes : 0, 15, 30 ou 45';
      }
    }
    return null;
  }
}
