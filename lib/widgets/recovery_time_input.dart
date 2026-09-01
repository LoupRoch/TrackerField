import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/recovery_time.dart';

/// Saisie du temps de récupération : affichage, presets et molette Cupertino.
class RecoveryTimeInput extends StatefulWidget {
  const RecoveryTimeInput({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.label = 'Temps de récupération',
  });

  final String? initialValue;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  State<RecoveryTimeInput> createState() => RecoveryTimeInputState();
}

class RecoveryTimeInputState extends State<RecoveryTimeInput> {
  static const _presets = <({String label, Duration duration})>[
    (label: '30s', duration: Duration(seconds: 30)),
    (label: '1m00', duration: Duration(minutes: 1)),
    (label: '1m30', duration: Duration(minutes: 1, seconds: 30)),
    (label: '2m00', duration: Duration(minutes: 2)),
    (label: '3m00', duration: Duration(minutes: 3)),
  ];

  late String _value;

  @override
  void initState() {
    super.initState();
    _value = RecoveryTime.normalizeDisplay(widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant RecoveryTimeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != null) {
      _value = RecoveryTime.normalizeDisplay(widget.initialValue);
    }
  }

  String get value => _value;

  void _applyDuration(Duration duration) {
    final formatted = RecoveryTime.fromDuration(duration);
    setState(() => _value = formatted);
    widget.onChanged(formatted);
  }

  Future<void> _openPicker() async {
    final initial = RecoveryTime.toDuration(_value);

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) {
        return _RecoveryTimePickerSheet(
          initialMinutes: initial.inMinutes,
          initialSeconds: initial.inSeconds % 60,
          onConfirm: (duration) {
            _applyDuration(duration);
            Navigator.pop(popupContext);
          },
          onCancel: () => Navigator.pop(popupContext),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outline),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _value,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.unfold_more,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _presets)
              ActionChip(
                label: Text(preset.label),
                onPressed: () => _applyDuration(preset.duration),
                backgroundColor: _value == RecoveryTime.fromDuration(preset.duration)
                    ? colorScheme.primaryContainer
                    : null,
                labelStyle: TextStyle(
                  color: _value == RecoveryTime.fromDuration(preset.duration)
                      ? colorScheme.onPrimaryContainer
                      : null,
                  fontWeight: _value == RecoveryTime.fromDuration(preset.duration)
                      ? FontWeight.w600
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Molette minutes + secondes (0, 15, 30, 45 uniquement).
class _RecoveryTimePickerSheet extends StatefulWidget {
  const _RecoveryTimePickerSheet({
    required this.initialMinutes,
    required this.initialSeconds,
    required this.onConfirm,
    required this.onCancel,
  });

  final int initialMinutes;
  final int initialSeconds;
  final ValueChanged<Duration> onConfirm;
  final VoidCallback onCancel;

  @override
  State<_RecoveryTimePickerSheet> createState() =>
      _RecoveryTimePickerSheetState();
}

class _RecoveryTimePickerSheetState extends State<_RecoveryTimePickerSheet> {
  static const _maxMinutes = 59;

  late final FixedExtentScrollController _minuteController;
  late final FixedExtentScrollController _secondController;
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes.clamp(0, _maxMinutes);
    _seconds = RecoveryTime.snapSeconds(widget.initialSeconds);
    _minuteController = FixedExtentScrollController(initialItem: _minutes);
    _secondController = FixedExtentScrollController(
      initialItem: RecoveryTime.allowedSecondValues.indexOf(_seconds),
    );
  }

  @override
  void dispose() {
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  Duration get _currentDuration =>
      Duration(minutes: _minutes, seconds: _seconds);

  void _updateMinutes(int index) {
    setState(() => _minutes = index);
  }

  void _updateSeconds(int index) {
    setState(() => _seconds = RecoveryTime.allowedSecondValues[index]);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 400;
    final itemExtent = narrow ? 32.0 : 36.0;
    final digitStyle = TextStyle(fontSize: narrow ? 18 : 22);
    final separatorStyle = TextStyle(
      fontSize: narrow ? 18 : 20,
      fontWeight: FontWeight.bold,
    );

    return Container(
      height: 320,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: widget.onCancel,
                  child: const Text('Annuler'),
                ),
                CupertinoButton(
                  onPressed: () => widget.onConfirm(_currentDuration),
                  child: const Text('Valider'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _minuteController,
                        itemExtent: itemExtent,
                        squeeze: narrow ? 1.9 : 1.45,
                        onSelectedItemChanged: _updateMinutes,
                        children: List.generate(
                          _maxMinutes + 1,
                          (index) => Center(
                            child: Text(
                              index.toString().padLeft(2, '0'),
                              style: digitStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _secondController,
                        itemExtent: itemExtent,
                        squeeze: narrow ? 1.9 : 1.45,
                        onSelectedItemChanged: _updateSeconds,
                        children: [
                          for (final sec in RecoveryTime.allowedSecondValues)
                            Center(
                              child: Text(
                                sec.toString().padLeft(2, '0'),
                                style: digitStyle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Text(':', style: separatorStyle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
