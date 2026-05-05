// ABOUTME: Segmented control — pill row with active state filled in ink.
// ABOUTME: Used for discipline, strategy, and aid-station time/distance toggle.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class BonkSegControl<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  const BonkSegControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: BonkTokens.rule),
        color: BonkTokens.paper,
        borderRadius: BorderRadius.circular(BonkTokens.r),
      ),
      child: Row(
        children: [
          for (final (v, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: v == value ? BonkTokens.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(BonkTokens.r - 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 6,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style:
                            BonkType.sans(
                              size: 12,
                              w: v == value ? FontWeight.w500 : FontWeight.w400,
                            ).copyWith(
                              color: v == value
                                  ? BonkTokens.bg
                                  : BonkTokens.ink2,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
