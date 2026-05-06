// ABOUTME: Glucose:Fructose split bar with bullseye marker (1.25 = 1:0.8) and
// ABOUTME: shaded OK band (0.9–1.5) — same band PlanCanvas warns on.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

const double _ratioIdeal = 1.25;
const double _ratioOkLow = 0.9;
const double _ratioOkHigh = 1.5;

double _shareForRatio(double r) => r / (1 + r);

class RatioBar extends StatelessWidget {
  final double glucose;
  final double fructose;
  const RatioBar({super.key, required this.glucose, required this.fructose});

  @override
  Widget build(BuildContext context) {
    assert(
      glucose.isFinite && fructose.isFinite,
      'RatioBar requires finite glucose and fructose values',
    );
    assert(
      glucose >= 0 && fructose >= 0,
      'RatioBar requires non-negative glucose and fructose values',
    );

    final hasFructose = fructose > 0;
    final hasAnyCarb = glucose > 0 || fructose > 0;
    final ratio = hasFructose ? glucose / fructose : 0.0;
    final glucoseShare = hasFructose
        ? (glucose / (glucose + fructose)).clamp(0.0, 1.0)
        : 1.0;

    final idealShare = _shareForRatio(_ratioIdeal);
    final okLowShare = _shareForRatio(_ratioOkLow);
    final okHighShare = _shareForRatio(_ratioOkHigh);

    final ratioText = hasFructose ? ratio.toStringAsFixed(2) : '—';
    final semanticsLabel = hasFructose
        ? 'Carb sources ratio $ratioText to 1, '
              'Glucose ${glucose.round()} grams, '
              'Fructose ${fructose.round()} grams, '
              'ideal 1.25, OK band 0.9 to 1.5'
        : hasAnyCarb
        ? 'Carb sources ratio not available, '
              'Glucose ${glucose.round()} grams, no fructose'
        : 'Carb sources not available, no glucose, no fructose';

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                if (!hasAnyCarb) {
                  return SizedBox(
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: BonkTokens.bg2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }
                return SizedBox(
                  height: 18,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: w * glucoseShare,
                            decoration: const BoxDecoration(
                              color: BonkTokens.glu,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(4),
                                bottomLeft: Radius.circular(4),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: BonkTokens.fru,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(4),
                                  bottomRight: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        left: w * okLowShare,
                        width: w * (okHighShare - okLowShare),
                        top: -3,
                        bottom: -3,
                        child: IgnorePointer(
                          child: Container(
                            key: const Key('ratio.okBand'),
                            decoration: BoxDecoration(
                              color: BonkTokens.ink.withValues(alpha: 0.12),
                              border: Border.symmetric(
                                vertical: BorderSide(
                                  color: BonkTokens.ink.withValues(alpha: 0.45),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: w * idealShare - 1,
                        top: -3,
                        bottom: -3,
                        width: 2,
                        child: Container(
                          key: const Key('ratio.idealMarker'),
                          color: BonkTokens.ink,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _LegendItem(
                  color: BonkTokens.glu,
                  label: 'Glucose ${glucose.round()}g',
                ),
                _LegendItem(
                  color: BonkTokens.fru,
                  label: 'Fructose ${fructose.round()}g',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      ratioText,
                      style: BonkType.mono(size: 28, w: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Text(': 1', style: BonkType.mono(size: 14)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'ideal 1.25 · OK 0.9–1.5',
                    style: BonkType.mono(
                      size: 11,
                    ).copyWith(color: BonkTokens.ink3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: BonkType.mono(size: 11)),
      ],
    );
  }
}
