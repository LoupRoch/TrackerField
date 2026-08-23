import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Palettes de couleurs disponibles dans les paramètres.
enum AppColorPalette {
  deepOrange('Orange', Colors.deepOrange),
  blue('Bleu', Colors.blue),
  teal('Turquoise', Colors.teal),
  green('Vert', Colors.green),
  indigo('Indigo', Colors.indigo),
  purple('Violet', Colors.purple),
  red('Rouge', Colors.red),
  brown('Brun', Colors.brown);

  const AppColorPalette(this.label, this.seedColor);

  final String label;
  final Color seedColor;

  static AppColorPalette fromName(String? name) {
    return AppColorPalette.values.firstWhere(
      (p) => p.name == name,
      orElse: () => AppColorPalette.deepOrange,
    );
  }
}

class SettingsProvider extends ChangeNotifier {
  SettingsProvider();

  static const _keyGranolas = 'settings_show_granolas';
  static const _keyPalette = 'settings_color_palette';

  SharedPreferences? _prefs;
  var _ready = false;
  var _showGranolas = true;
  AppColorPalette _palette = AppColorPalette.deepOrange;

  bool get isReady => _ready;
  bool get showGranolas => _showGranolas;
  AppColorPalette get palette => _palette;
  Color get seedColor => _palette.seedColor;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _showGranolas = _prefs?.getBool(_keyGranolas) ?? true;
    _palette = AppColorPalette.fromName(_prefs?.getString(_keyPalette));
    _ready = true;
    notifyListeners();
  }

  Future<void> setShowGranolas(bool value) async {
    if (_showGranolas == value) return;
    _showGranolas = value;
    await _prefs?.setBool(_keyGranolas, value);
    notifyListeners();
  }

  Future<void> setPalette(AppColorPalette value) async {
    if (_palette == value) return;
    _palette = value;
    await _prefs?.setString(_keyPalette, value.name);
    notifyListeners();
  }
}
