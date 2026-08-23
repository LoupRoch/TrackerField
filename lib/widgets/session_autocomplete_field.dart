import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/dictation_input_mode.dart';
import 'dictation_form_scope.dart';

class SessionAutocompleteField extends StatefulWidget {
  const SessionAutocompleteField({
    super.key,
    required this.labelText,
    required this.hintText,
    required this.suggestions,
    this.initialValue = '',
    this.validator,
    this.prefixIcon,
    this.suffixText,
    this.keyboardType,
    this.inputFormatters,
    this.dictationMode,
  });

  final String labelText;
  final String hintText;
  final List<String> suggestions;
  final String initialValue;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final String? suffixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final DictationInputMode? dictationMode;

  @override
  State<SessionAutocompleteField> createState() =>
      SessionAutocompleteFieldState();
}

class SessionAutocompleteFieldState extends State<SessionAutocompleteField> {
  /// Contrôleur fourni par [Autocomplete] (ne pas disposer ici).
  TextEditingController? _controller;
  FocusNode? _focusNode;
  VoidCallback? _focusListener;
  DictationTarget? _dictationTarget;
  DictationFormScopeState? _scope;

  String get value => _controller?.text.trim() ?? widget.initialValue.trim();

  void setValue(String text) {
    final controller = _controller;
    if (controller == null) return;
    controller.text = text;
    controller.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = DictationFormScopeState.of(context);
  }

  @override
  void dispose() {
    if (_focusNode != null && _focusListener != null) {
      _focusNode!.removeListener(_focusListener!);
    }
    if (_dictationTarget != null) {
      _scope?.unregisterTarget(_dictationTarget!);
    }
    super.dispose();
  }

  void _attachFocusListener(
    FocusNode focusNode,
    TextEditingController controller,
  ) {
    if (_focusNode != null && _focusListener != null) {
      _focusNode!.removeListener(_focusListener!);
    }
    _focusNode = focusNode;

    if (widget.dictationMode != null) {
      _dictationTarget ??= DictationTarget(
        focusNode: focusNode,
        mode: widget.dictationMode!,
        setText: setValue,
      );
    }

    _focusListener = () {
      if (focusNode.hasFocus && _dictationTarget != null) {
        _scope?.notifyFocus(_dictationTarget!);
      }
      if (!focusNode.hasFocus || widget.suggestions.isEmpty) return;
      final text = controller.text;
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    };
    focusNode.addListener(_focusListener!);
  }

  Widget? _buildSuffix() {
    if (widget.dictationMode == null || _dictationTarget == null) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.suffixText != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              widget.suffixText!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        DictationMicButton(target: _dictationTarget!, compact: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.initialValue),
      optionsBuilder: (textEditingValue) {
        if (widget.suggestions.isEmpty) {
          return const Iterable<String>.empty();
        }
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return widget.suggestions;
        return widget.suggestions.where(
          (s) => s.toLowerCase().contains(query),
        );
      },
      optionsMaxHeight: 220,
      fieldViewBuilder: (
        context,
        textEditingController,
        focusNode,
        onFieldSubmitted,
      ) {
        _controller = textEditingController;
        _attachFocusListener(focusNode, textEditingController);

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          onFieldSubmitted: (_) => onFieldSubmitted(),
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon,
            suffixText:
                widget.dictationMode == null ? widget.suffixText : null,
            suffixIcon: _buildSuffix(),
            border: const OutlineInputBorder(),
          ),
          validator: widget.validator,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 420),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
