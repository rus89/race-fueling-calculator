// ABOUTME: One row in the timeline — clock + dual bar + items + cumulative.
// ABOUTME: Renders sip-bottle, drink-start, gel/chew, and aid-station markers.
import 'package:flutter/material.dart';
import 'package:race_fueling_core/core.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class TimelineRow extends StatelessWidget {
  final PlanEntry entry;
  final double targetG;
  final double peakG;
  final Map<String, Product> productsById;

  const TimelineRow({
    super.key,
    required this.entry,
    required this.targetG,
    required this.peakG,
    required this.productsById,
  });

  String _fmtClock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _fmtElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '+${h}h${m.toString().padLeft(2, '0')}' : '+${m}m';
  }

  String _composedLabel() {
    final clock = _fmtClock(entry.timeMark);
    final elapsed = _fmtElapsed(entry.timeMark);
    final buf = StringBuffer('Time $clock ($elapsed), ');
    buf.write(
      '${entry.carbsTotal.toStringAsFixed(0)}g of '
      '${targetG.toStringAsFixed(0)}g target',
    );
    if (entry.aidStation != null) {
      final n = entry.aidStation!.refill.length;
      buf.write(', aid station refill $n item${n == 1 ? "" : "s"}');
    }
    buf.write(', ${entry.cumulativeCarbs.round()}g cumulative');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final stepCarbs = entry.carbsTotal;
    final pct = peakG > 0 ? (stepCarbs / peakG).clamp(0.0, 1.0) : 0.0;
    final targetPct = peakG > 0 ? (targetG / peakG).clamp(0.0, 1.0) : 0.0;
    final hasNonDrinkItems = entry.products.any((s) => !s.isDrinkStart);
    final hasSipping =
        entry.effectiveDrinkCarbs > 0 &&
        !entry.products.any((s) => s.isDrinkStart);

    return Semantics(
      container: true,
      label: _composedLabel(),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: BonkTokens.rule2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time column
              SizedBox(
                width: 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtClock(entry.timeMark),
                      style: BonkType.mono(size: 12),
                    ),
                    Text(
                      _fmtElapsed(entry.timeMark),
                      style: BonkType.mono(
                        size: 10,
                      ).copyWith(color: BonkTokens.ink3),
                    ),
                  ],
                ),
              ),
              // Bar column
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;
                        return SizedBox(
                          height: 14,
                          child: Stack(
                            children: [
                              // target band underlay
                              Container(
                                key: const Key('bar.target'),
                                width: w * targetPct,
                                height: 6,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: BonkTokens.rule,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // actual fill
                              Container(
                                key: const Key('bar.actual'),
                                width: w * pct,
                                height: 8,
                                margin: const EdgeInsets.only(top: 3),
                                decoration: BoxDecoration(
                                  color: BonkTokens.accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${stepCarbs.toStringAsFixed(0)}g / ${targetG.toStringAsFixed(0)}g',
                        style: BonkType.mono(size: 10),
                      ),
                    ),
                  ],
                ),
              ),
              // Items column (flex)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasSipping)
                      _ItemLine(
                        type: ProductType.liquid,
                        label: 'sipping bottle',
                        stats:
                            '${entry.effectiveDrinkCarbs.toStringAsFixed(0)}g / 15m',
                        dim: true,
                      ),
                    for (final s in entry.products)
                      _ItemLine(
                        type:
                            productsById[s.productId]?.type ?? ProductType.gel,
                        label: s.productName,
                        stats: () {
                          final p = productsById[s.productId];
                          if (p == null) return '';
                          final c = (p.carbsPerServing * s.servings)
                              .toStringAsFixed(0);
                          final caf = p.caffeineMg > 0
                              ? ' · ${p.caffeineMg.round()}mg caf'
                              : '';
                          return '${c}g$caf';
                        }(),
                      ),
                    if (!hasNonDrinkItems &&
                        !hasSipping &&
                        entry.aidStation == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '— sip water —',
                          style: BonkType.mono(
                            size: 11,
                          ).copyWith(color: BonkTokens.ink3),
                        ),
                      ),
                    if (entry.aidStation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 14,
                              color: BonkTokens.warn,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Aid station — refill '
                              '${entry.aidStation!.refill.length} '
                              'item${entry.aidStation!.refill.length == 1 ? "" : "s"}',
                              style: BonkType.mono(
                                size: 11,
                                w: FontWeight.w600,
                              ).copyWith(color: BonkTokens.ink),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Cumulative column
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: '${entry.cumulativeCarbs.round()}',
                        style: BonkType.mono(size: 16, w: FontWeight.w500),
                        children: [
                          TextSpan(
                            text: 'g',
                            style: BonkType.mono(
                              size: 11,
                            ).copyWith(color: BonkTokens.ink3),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'cumulative',
                      style: BonkType.mono(
                        size: 9.5,
                      ).copyWith(color: BonkTokens.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  final ProductType type;
  final String label;
  final String stats;
  final bool dim;
  const _ItemLine({
    required this.type,
    required this.label,
    required this.stats,
    this.dim = false,
  });
  @override
  Widget build(BuildContext context) {
    // TODO(F1-DOTS-SHAPE): item dots are color-only; per PC-DOT-COLORS,
    // migrate to shape-encoded glyphs in F1 polish.
    Color dotColor;
    switch (type) {
      case ProductType.gel:
        dotColor = BonkTokens.accent;
        break;
      case ProductType.liquid:
        dotColor = BonkTokens.hydro;
        break;
      case ProductType.chew:
        dotColor = BonkTokens.warn;
        break;
      case ProductType.solid:
      case ProductType.realFood:
        dotColor = BonkTokens.fru;
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: BonkType.sans(
                size: 12,
              ).copyWith(color: dim ? BonkTokens.ink3 : BonkTokens.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(stats, style: BonkType.mono(size: 11)),
        ],
      ),
    );
  }
}
