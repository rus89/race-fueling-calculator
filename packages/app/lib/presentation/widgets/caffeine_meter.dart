// ABOUTME: 5-segment caffeine meter against the 6 mg/kg ceiling.
// ABOUTME: Hot state carries severity through both color (bad) and "· OVER" text in ink.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

const double _ceilingMgPerKg = 6.0;
const int _segs = 5;

class CaffeineMeter extends StatelessWidget {
  final double totalMg;
  final double bodyKg;
  const CaffeineMeter({super.key, required this.totalMg, required this.bodyKg});

  @override
  Widget build(BuildContext context) {
    assert(
      totalMg.isFinite && bodyKg.isFinite,
      'CaffeineMeter requires finite totalMg and bodyKg values',
    );
    assert(totalMg >= 0, 'CaffeineMeter requires non-negative totalMg');

    // Coerce non-finite or negative totalMg to 0 in release (where asserts strip)
    // so corrupt upstream data renders as zero-fill instead of NaN/Infinity.
    final mgEffective = (totalMg.isFinite && totalMg >= 0) ? totalMg : 0.0;
    // Catch NaN, -Infinity, Infinity, and <= 0 in one expression. Falls back
    // to the 70 kg default the spec defines for missing-bodyKg cases.
    final kg = (bodyKg.isFinite && bodyKg > 0) ? bodyKg : 70.0;
    final ceiling = kg * _ceilingMgPerKg;
    final mgPerKg = mgEffective / kg;
    // hot is gated by the actual mg/kg vs ceiling, not by the rounded segment
    // count. round() on 4.5 segments would otherwise false-fire OVER at 90%.
    final hot = mgPerKg >= _ceilingMgPerKg;
    final filled = hot
        ? _segs
        : (mgEffective / ceiling * _segs).clamp(0.0, _segs.toDouble()).round();
    final mgPerKgText = mgPerKg.toStringAsFixed(1);

    final semanticsLabel = hot
        ? 'Caffeine $mgPerKgText mg/kg, ceiling 6.0 mg/kg, over ceiling'
        : 'Caffeine $mgPerKgText mg/kg, ceiling 6.0 mg/kg';

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < _segs; i++)
                  Expanded(
                    child: Container(
                      key: i == _segs - 1 && hot
                          ? const Key('caf-seg-hot-4')
                          : null,
                      margin: const EdgeInsets.only(right: 3),
                      height: 10,
                      decoration: BoxDecoration(
                        color: i < filled
                            ? (hot ? BonkTokens.bad : BonkTokens.caf)
                            : BonkTokens.bg2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                text: mgPerKgText,
                style: BonkType.mono(size: 13),
                children: [
                  TextSpan(
                    text: ' mg/kg · ceiling 6.0',
                    style: BonkType.mono(
                      size: 11,
                    ).copyWith(color: BonkTokens.ink3),
                  ),
                  if (hot)
                    TextSpan(
                      text: ' · OVER',
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
    );
  }
}
