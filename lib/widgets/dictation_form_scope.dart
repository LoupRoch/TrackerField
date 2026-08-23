import 'package:flutter/material.dart';

import '../services/dictation_service.dart';
import '../services/volume_dictation_trigger.dart';
import '../utils/dictation_input_mode.dart';
import '../utils/speech_text_normalizer.dart';

/// Cible de dictée enregistrée (champ actif ou dernier focus).
class DictationTarget {
  DictationTarget({
    required this.setText,
    required this.mode,
    this.focusNode,
  });

  final void Function(String text) setText;
  final DictationInputMode mode;
  final FocusNode? focusNode;
}

/// Portée de formulaire avec dictée vocale (micro + double volume +).
class DictationFormScope extends StatefulWidget {
  const DictationFormScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<DictationFormScope> createState() => DictationFormScopeState();
}

class DictationFormScopeState extends State<DictationFormScope> {
  DictationTarget? _activeTarget;
  var _dictating = false;

  bool get isDictating => _dictating;

  static DictationFormScopeState? of(BuildContext context) {
    return context.findAncestorStateOfType<DictationFormScopeState>();
  }

  void registerTarget(DictationTarget target) {
    _activeTarget = target;
  }

  void unregisterTarget(DictationTarget target) {
    if (identical(_activeTarget, target)) {
      _activeTarget = null;
    }
  }

  void notifyFocus(DictationTarget target) {
    _activeTarget = target;
  }

  Future<void> dictateTo(DictationTarget target) async {
    if (_dictating) return;
    setState(() => _dictating = true);
    _activeTarget = target;

    try {
      final raw = await DictationService.instance.listen();
      if (!mounted) return;
      if (raw == null || raw.trim().isEmpty) {
        if (DictationService.instance.isUnavailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Dictée indisponible. Relance l\'app (stop + run) pour charger le plugin micro.',
              ),
            ),
          );
        }
        return;
      }
      final normalized = SpeechTextNormalizer.normalize(raw, target.mode);
      if (normalized.isEmpty) return;
      target.setText(normalized);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de démarrer la dictée.')),
      );
    } finally {
      if (mounted) setState(() => _dictating = false);
    }
  }

  Future<void> _dictateActiveTarget() async {
    final target = _activeTarget;
    if (target == null) return;
    await dictateTo(target);
  }

  @override
  void initState() {
    super.initState();
    VolumeDictationTrigger.instance.start(_dictateActiveTarget);
  }

  @override
  void dispose() {
    VolumeDictationTrigger.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DictationScopeInherited(
      scope: this,
      isDictating: _dictating,
      child: widget.child,
    );
  }
}

class _DictationScopeInherited extends InheritedWidget {
  const _DictationScopeInherited({
    required this.scope,
    required this.isDictating,
    required super.child,
  });

  final DictationFormScopeState scope;
  final bool isDictating;

  @override
  bool updateShouldNotify(_DictationScopeInherited oldWidget) {
    return scope != oldWidget.scope || isDictating != oldWidget.isDictating;
  }
}

/// Bouton micro pour lancer la dictée sur un champ.
class DictationMicButton extends StatelessWidget {
  const DictationMicButton({
    super.key,
    required this.target,
    this.compact = false,
  });

  final DictationTarget target;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_DictationScopeInherited>();
    final scope = inherited?.scope;
    final dictating = inherited?.isDictating ?? false;

    return IconButton(
      tooltip: 'Dictée vocale (2× volume +)',
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      iconSize: compact ? 20 : 24,
      onPressed: scope == null || dictating
          ? null
          : () => scope.dictateTo(target),
      icon: dictating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.mic_none,
              color: Theme.of(context).colorScheme.primary,
            ),
    );
  }
}
