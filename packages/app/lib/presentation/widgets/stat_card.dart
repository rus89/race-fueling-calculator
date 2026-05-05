// ABOUTME: One stat card from the canvas header — label, big mono value, sub.
// ABOUTME: Hero variant uses statHero typography; flag variants get side rule.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum StatFlag { ok, warn, bad }

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final bool isHero;
  final StatFlag? flag;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    this.isHero = false,
    this.flag,
  });

  Color _flagColor(StatFlag f) {
    switch (f) {
      case StatFlag.ok:
        return BonkTokens.ok;
      case StatFlag.warn:
        return BonkTokens.warn;
      case StatFlag.bad:
        return BonkTokens.bad;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: flag != null ? Key('stat-flag-${flag!.name}') : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: BonkTokens.paper,
        border: Border(
          left: BorderSide(
            width: flag != null ? 3 : 1,
            color: flag != null ? _flagColor(flag!) : BonkTokens.rule,
          ),
          top: const BorderSide(color: BonkTokens.rule),
          right: const BorderSide(color: BonkTokens.rule),
          bottom: const BorderSide(color: BonkTokens.rule),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: BonkType.sectionLabel),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              text: value,
              style: isHero ? BonkType.statHero : BonkType.statValue,
              children: [
                if (unit != null && unit!.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: BonkType.mono(
                      size: isHero ? 14 : 11,
                    ).copyWith(color: BonkTokens.ink3),
                  ),
              ],
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: BonkType.mono(size: 10).copyWith(color: BonkTokens.ink3),
            ),
          ],
        ],
      ),
    );
  }
}
