// ABOUTME: Three-element stepper — minus / mono count / plus.
// ABOUTME: Used in the inventory list to set per-product quantity.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class BonkStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const BonkStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 30,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, VoidCallback? onTap) => InkWell(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: BonkTokens.rule),
          color: BonkTokens.paper,
          borderRadius: BorderRadius.circular(BonkTokens.rSm),
        ),
        child: Center(child: Text(label, style: BonkType.mono(size: 14))),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn('−', value > min ? () => onChanged(value - 1) : null),
        Container(
          width: 36,
          alignment: Alignment.center,
          child: Text('$value', style: BonkType.mono(size: 13)),
        ),
        btn('+', value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}
