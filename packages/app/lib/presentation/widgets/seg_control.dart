// ABOUTME: Segmented control — pill row with active state filled in ink.
// ABOUTME: Keyboard-accessible (InkWell focus, Tab traversal) with Semantics roles.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class BonkSegControl<T extends Object> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  /// Optional label that names the seg control as a whole. When provided,
  /// the outer container is wrapped in a Semantics(container, label:) so
  /// screen readers announce the group ("Discipline, Trail selected, button").
  final String? groupLabel;

  const BonkSegControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.groupLabel,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
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
              child: Semantics(
                button: true,
                selected: v == value,
                inMutuallyExclusiveGroup: true,
                label: label,
                excludeSemantics: true,
                child: InkWell(
                  // Re-tap of the currently-selected option is a no-op so
                  // we don't trigger an unnecessary parent rebuild and a
                  // SharedPreferences write on every visit.
                  onTap: v != value ? () => onChanged(v) : null,
                  borderRadius: BorderRadius.circular(BonkTokens.r - 2),
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.focused)) {
                      return BonkTokens.ink.withValues(alpha: 0.12);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return BonkTokens.ink.withValues(alpha: 0.06);
                    }
                    return null;
                  }),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style:
                              BonkType.sans(
                                size: 12,
                                w: v == value
                                    ? FontWeight.w500
                                    : FontWeight.w400,
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
            ),
        ],
      ),
    );

    if (groupLabel != null) {
      return Semantics(container: true, label: groupLabel, child: container);
    }
    return container;
  }
}
