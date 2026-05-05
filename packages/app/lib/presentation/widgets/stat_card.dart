// ABOUTME: One stat card from the canvas header — label, big mono value, sub.
// ABOUTME: Hero variant uses statHero typography; severity variants get side rule + glyph.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum StatSeverity { ok, warn, bad }

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final bool isHero;
  final StatSeverity? severity;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    this.isHero = false,
    this.severity,
  });

  Color _severityColor(StatSeverity s) {
    switch (s) {
      case StatSeverity.ok:
        return BonkTokens.ok;
      case StatSeverity.warn:
        return BonkTokens.warn;
      case StatSeverity.bad:
        return BonkTokens.bad;
    }
  }

  String _severityGlyph(StatSeverity s) {
    switch (s) {
      case StatSeverity.ok:
        return '✓';
      case StatSeverity.warn:
        return '!';
      case StatSeverity.bad:
        return '×';
    }
  }

  @override
  Widget build(BuildContext context) {
    final composedLabel =
        '$label: $value${unit ?? ''}'
        '${sub != null ? ", $sub" : ''}'
        '${severity != null ? ", ${severity!.name}" : ''}';

    return Semantics(
      container: true,
      label: composedLabel,
      child: ExcludeSemantics(
        child: Container(
          key: severity != null ? Key('stat-severity-${severity!.name}') : null,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: BonkTokens.paper,
            border: Border(
              left: BorderSide(
                width: severity != null ? 3 : 1,
                color: severity != null
                    ? _severityColor(severity!)
                    : BonkTokens.rule,
              ),
              top: const BorderSide(color: BonkTokens.rule),
              right: const BorderSide(color: BonkTokens.rule),
              bottom: const BorderSide(color: BonkTokens.rule),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (severity != null) ...[
                    Text(
                      _severityGlyph(severity!),
                      style: BonkType.mono(
                        size: 12,
                        w: FontWeight.w600,
                      ).copyWith(color: BonkTokens.ink),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(child: Text(label, style: BonkType.sectionLabel)),
                ],
              ),
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
                  style: BonkType.mono(
                    size: 10,
                  ).copyWith(color: BonkTokens.ink3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
