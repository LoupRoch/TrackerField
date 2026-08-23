import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/recovery_time.dart';

/// Saisie du temps de récupération en deux champs numériques (min / sec).
class RecoveryTimeField extends StatefulWidget {
  const RecoveryTimeField({
    super.key,
    this.initialValue = '',
    this.required = false,
  });

  final String initialValue;
  final bool required;

  @override
  RecoveryTimeFieldState createState() => RecoveryTimeFieldState();
}

class RecoveryTimeFieldState extends State<RecoveryTimeField> {
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;

  @override
  void initState() {
    super.initState();
    final parsed = RecoveryTime.parse(widget.initialValue);
    _minutesController = TextEditingController(text: parsed.minutes);
    _secondsController = TextEditingController(text: parsed.seconds);
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  String get value =>
      RecoveryTime.format(_minutesController.text, _secondsController.text);

  String? validate() {
    if (!widget.required) return null;
    return RecoveryTime.validateRequired(
      _minutesController.text,
      _secondsController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Temps de récupération',
        border: OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Min',
                hintText: '0',
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.next,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              ':',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _secondsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Sec',
                hintText: '00',
                border: InputBorder.none,
                isDense: true,
              ),
              validator: (_) => validate(),
            ),
          ),
        ],
      ),
    );
  }
}
