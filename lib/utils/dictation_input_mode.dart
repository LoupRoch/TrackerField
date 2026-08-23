/// Mode de saisie pour filtrer / normaliser la dictée vocale.
enum DictationInputMode {
  /// Chiffres et virgule (distance, chrono).
  numericComma,

  /// Chiffres et deux-points (temps mm:ss).
  timeColon,

  /// Texte libre (notes).
  freeText,
}
