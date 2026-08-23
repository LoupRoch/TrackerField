import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

typedef DictationTriggerCallback = Future<void> Function();

/// Déclenche la dictée sur un double appui rapide sur volume +.
///
/// Utilise les variations de volume système (compatible iOS / Android).
class VolumeDictationTrigger {
  VolumeDictationTrigger._();

  static final VolumeDictationTrigger instance = VolumeDictationTrigger._();

  static const _doublePressWindow = Duration(milliseconds: 450);
  static const _minDelta = 0.001;

  DictationTriggerCallback? _onDoubleVolumeUp;
  StreamSubscription<double>? _subscription;
  DateTime? _lastVolumeUp;
  double? _lastVolume;
  var _active = false;
  var _restoring = false;

  Future<void> start(DictationTriggerCallback onDoubleVolumeUp) async {
    if (kIsWeb) return;
    if (_active) return;

    _onDoubleVolumeUp = onDoubleVolumeUp;
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      _lastVolume = await FlutterVolumeController.getVolume();
      _subscription = FlutterVolumeController.addListener(
        _onVolumeChanged,
        emitOnStart: true,
      );
      _active = true;
    } catch (_) {
      // Plugin indisponible (hot reload / plateforme) : la dictée reste via micro.
      _active = false;
      _onDoubleVolumeUp = null;
    }
  }

  Future<void> stop() async {
    if (!_active && _subscription == null) return;
    await _subscription?.cancel();
    _subscription = null;
    try {
      FlutterVolumeController.removeListener();
      await FlutterVolumeController.updateShowSystemUI(true);
    } catch (_) {}
    _onDoubleVolumeUp = null;
    _lastVolumeUp = null;
    _lastVolume = null;
    _active = false;
  }

  void _onVolumeChanged(double volume) {
    if (_restoring) {
      _lastVolume = volume;
      return;
    }

    final previous = _lastVolume;
    _lastVolume = volume;
    if (previous == null) return;

    final delta = volume - previous;
    // Volume + = hausse ; si déjà au max, iOS peut osciller légèrement.
    final isVolumeUp = delta > _minDelta ||
        (previous >= 0.99 && volume >= previous - 0.02);

    if (!isVolumeUp || delta < -_minDelta) return;

    final now = DateTime.now();
    if (_lastVolumeUp != null &&
        now.difference(_lastVolumeUp!) <= _doublePressWindow) {
      _lastVolumeUp = null;
      unawaited(_restoreAndTrigger(previous));
      return;
    }
    _lastVolumeUp = now;
  }

  Future<void> _restoreAndTrigger(double previousVolume) async {
    _restoring = true;
    try {
      // Annule en douceur la hausse de volume des deux appuis.
      await FlutterVolumeController.setVolume(previousVolume.clamp(0.0, 1.0));
    } catch (_) {}
    try {
      await _onDoubleVolumeUp?.call();
    } finally {
      _restoring = false;
    }
  }
}
