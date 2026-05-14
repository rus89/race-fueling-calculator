// ABOUTME: Single-line text input with Bonk styling and proper accessible name.
// ABOUTME: Preserves cursor position when external value changes mid-edit.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class BonkTextInput extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final bool monoFont;

  /// Surfaces as the floating Material label and the field's accessible name.
  final String? labelText;

  /// Optional hard cap on the input length. Null = no limit.
  final int? maxLength;

  /// Optional input formatters (e.g. digits-only filter).
  final List<TextInputFormatter>? inputFormatters;

  const BonkTextInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.keyboardType,
    this.monoFont = false,
    this.labelText,
    this.maxLength,
    this.inputFormatters,
  });

  @override
  State<BonkTextInput> createState() => _BonkTextInputState();
}

class _BonkTextInputState extends State<BonkTextInput> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.value,
  );
  late final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(BonkTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _ctrl.text != widget.value) {
      // Cursor-preserving in-focus guard: while the user is typing, an
      // upstream state echo that rounds the typed value (e.g. "158.7" lb →
      // 71.989 kg stored → "159" lb rendered) must not clobber the
      // in-progress text. Resume syncing once the field loses focus.
      if (_focusNode.hasFocus) return;
      final oldSel = _ctrl.selection;
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: oldSel.isValid && oldSel.end <= widget.value.length
            ? oldSel
            : TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      style: widget.monoFont ? BonkType.mono(size: 14) : BonkType.sans(),
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.labelText,
        // Hide the maxLength counter — the cap is silent and the helper text
        // would push fields below 44pt and clutter the rail.
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 10,
        ),
        filled: true,
        fillColor: BonkTokens.paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BonkTokens.r),
          borderSide: const BorderSide(color: BonkTokens.rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BonkTokens.r),
          borderSide: const BorderSide(color: BonkTokens.ink3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BonkTokens.r),
          borderSide: const BorderSide(color: BonkTokens.ink, width: 2.0),
        ),
      ),
    );
  }
}
