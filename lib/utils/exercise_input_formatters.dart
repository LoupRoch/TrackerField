import 'package:flutter/services.dart';

/// Filtres réutilisables pour les champs de saisie d'exercice.
class ExerciseInputFormatters {
  ExerciseInputFormatters._();

  static final numericComma = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
  ];

  static final timeColon = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
  ];
}
