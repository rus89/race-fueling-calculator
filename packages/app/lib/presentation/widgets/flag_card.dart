// ABOUTME: Severity-tagged warning card with side rule, ink severity label,
// ABOUTME: and composed Semantics. Color carries severity through the rule only.
import 'package:flutter/material.dart';
import 'package:race_fueling_core/core.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class FlagCard extends StatelessWidget {
  final Warning warning;
  const FlagCard({super.key, required this.warning});

  Color get _barColor =>
      warning.severity == Severity.critical ? BonkTokens.bad : BonkTokens.warn;

  String get _sevLabel =>
      warning.severity == Severity.critical ? 'CRITICAL' : 'ADVISORY';

  String get _sevSemanticsWord =>
      warning.severity == Severity.critical ? 'Critical' : 'Advisory';

  @override
  Widget build(BuildContext context) {
    // TODO(v1.2): replace ' — ' heuristic with structured Warning.title/detail
    // split — the validator's free-text format isn't enforced consistently.
    const separator = ' — ';
    final idx = warning.message.indexOf(separator);
    final title = idx < 0 ? warning.message : warning.message.substring(0, idx);
    final body = idx < 0
        ? ''
        : warning.message.substring(idx + separator.length);

    final semanticsLabel = body.isNotEmpty
        ? '$_sevSemanticsWord. $title. $body'
        : title.isEmpty
        ? _sevSemanticsWord
        : '$_sevSemanticsWord. $title';

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: BonkTokens.paper,
            border: Border(
              left: BorderSide(width: 3, color: _barColor),
              top: const BorderSide(color: BonkTokens.rule),
              right: const BorderSide(color: BonkTokens.rule),
              bottom: const BorderSide(color: BonkTokens.rule),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sevLabel,
                    style: BonkType.mono(
                      size: 9.5,
                      w: FontWeight.w600,
                    ).copyWith(color: BonkTokens.ink, letterSpacing: 0.6),
                  ),
                  const SizedBox(width: 8),
                  if (title.isNotEmpty)
                    Expanded(
                      child: Text(
                        title,
                        style: BonkType.sans(size: 13, w: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  body,
                  style: BonkType.sans(
                    size: 12,
                  ).copyWith(color: BonkTokens.ink2),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
