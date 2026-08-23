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

  static String? validateRequired(String minutes, String seconds) {
    if (minutes.trim().isEmpty && seconds.trim().isEmpty) {
      return 'Requis';
    }
    final secText = seconds.trim();
    if (secText.isNotEmpty) {
      final sec = int.tryParse(secText);
      if (sec == null || sec < 0 || sec > 59) {
        return 'Secondes : 0–59';
      }
    }
    return null;
  }
}
