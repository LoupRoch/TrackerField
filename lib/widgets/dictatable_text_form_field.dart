import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/dictation_input_mode.dart';
import 'dictation_form_scope.dart';

/// Champ texte avec bouton micro et enregistrement pour dictée volume +.
class DictatableTextFormField extends StatefulWidget {
  const DictatableTextFormField({
    super.key,
    required this.controller,
    required this.mode,
    this.decoration,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final DictationInputMode mode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  State<DictatableTextFormField> createState() =>
      _DictatableTextFormFieldState();
}

class _DictatableTextFormFieldState extends State<DictatableTextFormField> {
  late final FocusNode _focusNode;
  late final DictationTarget _target;
  DictationFormScopeState? _scope;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _target = DictationTarget(
      focusNode: _focusNode,
      mode: widget.mode,
      setText: _applyDictation,
    );
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = DictationFormScopeState.of(context);
  }

  @override
  void dispose() {
    _scope?.unregisterTarget(_target);
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) return;
    _scope?.notifyFocus(_target);
  }

  void _applyDictation(String text) {
    widget.controller.text = text;
    widget.controller.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.decoration ?? const InputDecoration();
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.maxLines,
      validator: widget.validator,
      decoration: base.copyWith(
        suffixIcon: DictationMicButton(target: _target, compact: true),
      ),
    );
  }
}
