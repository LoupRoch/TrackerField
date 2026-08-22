import 'package:flutter/material.dart';

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
  });

  final String labelText;
  final String hintText;
  final List<String> suggestions;
  final String initialValue;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final String? suffixText;

  @override
  State<SessionAutocompleteField> createState() =>
      SessionAutocompleteFieldState();
}

class SessionAutocompleteFieldState extends State<SessionAutocompleteField> {
  /// Contrôleur fourni par [Autocomplete] (ne pas disposer ici).
  TextEditingController? _controller;
  FocusNode? _focusNode;
  VoidCallback? _focusListener;

  String get value => _controller?.text.trim() ?? widget.initialValue.trim();

  @override
  void dispose() {
    if (_focusNode != null && _focusListener != null) {
      _focusNode!.removeListener(_focusListener!);
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
    _focusListener = () {
      if (!focusNode.hasFocus || widget.suggestions.isEmpty) return;
      // Force Autocomplete à recalculer les options au focus.
      final text = controller.text;
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    };
    focusNode.addListener(_focusListener!);
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
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon,
            suffixText: widget.suffixText,
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
