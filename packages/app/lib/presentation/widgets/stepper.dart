// ABOUTME: Three-element stepper — minus / mono count / plus.
// ABOUTME: 28×28 visual with 44×44 hit area; Semantics adjustable role.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class BonkStepper extends StatelessWidget {
  final int value;
  final int min;

  /// Default max=30 fits per-product inventory counts; specify explicitly
  /// for other use cases (e.g. minutes, distance, body weight).
  final int max;
  final ValueChanged<int> onChanged;

  /// Optional context label. When provided, screen readers announce
  /// "$semanticLabel, $value" (e.g. "Maurten Gel 100 quantity, 5") so the
  /// adjustable value carries the field name.
  final String? semanticLabel;

  /// Optional addressing prefix for tests. When set, the minus and plus tap
  /// targets carry `Key('$keyPrefix.minus')` and `Key('$keyPrefix.plus')`.
  final String? keyPrefix;

  const BonkStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 30,
    this.semanticLabel,
    this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > min;
    final canIncrement = value < max;

    Widget btn(String label, VoidCallback? onTap, {Key? key}) {
      final enabled = onTap != null;
      return Padding(
        key: key,
        // 8px padding on each side expands a 28×28 visual to a 44×44
        // hit area without changing the design rail.
        padding: const EdgeInsets.all(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BonkTokens.rSm),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              border: Border.all(
                color: enabled ? BonkTokens.rule : BonkTokens.rule2,
              ),
              color: enabled ? BonkTokens.paper : BonkTokens.bg2,
              borderRadius: BorderRadius.circular(BonkTokens.rSm),
            ),
            child: Center(
              child: Text(
                label,
                style: BonkType.mono(
                  size: 14,
                ).copyWith(color: enabled ? BonkTokens.ink : BonkTokens.ink3),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: semanticLabel == null ? '$value' : '$semanticLabel, $value',
      value: '$value',
      increasedValue: canIncrement ? '${value + 1}' : null,
      decreasedValue: canDecrement ? '${value - 1}' : null,
      onIncrease: canIncrement ? () => onChanged(value + 1) : null,
      onDecrease: canDecrement ? () => onChanged(value - 1) : null,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            btn(
              '−',
              canDecrement ? () => onChanged(value - 1) : null,
              key: keyPrefix != null ? Key('$keyPrefix.minus') : null,
            ),
            Container(
              width: 36,
              alignment: Alignment.center,
              child: Text('$value', style: BonkType.mono(size: 13)),
            ),
            btn(
              '+',
              canIncrement ? () => onChanged(value + 1) : null,
              key: keyPrefix != null ? Key('$keyPrefix.plus') : null,
            ),
          ],
        ),
      ),
    );
  }
}
