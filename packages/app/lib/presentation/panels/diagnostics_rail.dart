// ABOUTME: Right pane — carb-source ratio bar, caffeine meter, flag list.
// ABOUTME: Branches on planProvider AsyncValue (PB-DATA-1) — loading / error / data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/plan_provider.dart';
import '../providers/planner_notifier.dart';
import '../providers/warnings_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/caffeine_meter.dart';
import '../widgets/flag_card.dart';
import '../widgets/ratio_bar.dart';

class DiagnosticsRail extends ConsumerWidget {
  // F1-RAIL-MIN-WIDTH: this panel needs ≥360px outer (320px inner after the
  // 20px horizontal padding) so RatioBar's 200% textScaler bound is honored.
  // F1's responsive layout must allocate ≥360px for this rail.
  const DiagnosticsRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlan = ref.watch(planProvider);
    final asyncState = ref.watch(plannerNotifierProvider);
    final warnings = ref.watch(warningsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: BonkTokens.bg,
        border: Border(left: BorderSide(color: BonkTokens.rule)),
      ),
      child: asyncPlan.when(
        loading: () => Center(
          child: Semantics(
            liveRegion: true,
            label: 'Loading diagnostics',
            child: const CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) {
          // F1-ERROR-COPY: replace static copy with typed-error bucketing.
          debugPrint('DiagnosticsRail error: $error');
          return const _ErrorFallback();
        },
        data: (plan) {
          final state = asyncState.requireValue;
          final bodyKg = state.athleteProfile.bodyWeightKg ?? 70;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('03 / DIAGNOSTICS', style: BonkType.railEyebrow),
                const SizedBox(height: 4),
                Text('Checks', style: BonkType.railTitle),
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Text('CARB SOURCES', style: BonkType.sectionLabel),
                ),
                const SizedBox(height: 10),
                RatioBar(
                  glucose: plan.summary.totalGlucose,
                  fructose: plan.summary.totalFructose,
                ),
                const SizedBox(height: 22),
                Semantics(
                  header: true,
                  child: Text(
                    'CAFFEINE — ${plan.summary.totalCaffeineMg.isFinite ? plan.summary.totalCaffeineMg.round() : 0} MG',
                    style: BonkType.sectionLabel,
                  ),
                ),
                const SizedBox(height: 10),
                CaffeineMeter(
                  totalMg: plan.summary.totalCaffeineMg,
                  bodyKg: bodyKg,
                ),
                const SizedBox(height: 22),
                Semantics(
                  header: true,
                  child: Text(
                    'FLAGS (${warnings.length})',
                    style: BonkType.sectionLabel,
                  ),
                ),
                const SizedBox(height: 10),
                if (warnings.isEmpty)
                  const _AllClearCard()
                else
                  for (final w in warnings) FlagCard(warning: w),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();
  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'All clear. All checks pass. Plan looks executable.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: BonkTokens.paper,
            border: Border.fromBorderSide(BorderSide(color: BonkTokens.rule)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: BonkTokens.ok,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '✓',
                style: BonkType.mono(
                  size: 12,
                  w: FontWeight.w600,
                ).copyWith(color: BonkTokens.ink),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'All checks pass. Plan looks executable.',
                  style: BonkType.sans(size: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback();
  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Diagnostics unavailable. Please reload.',
      child: ExcludeSemantics(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: BonkTokens.paper,
                border: Border(
                  left: BorderSide(width: 3, color: BonkTokens.bad),
                  top: BorderSide(color: BonkTokens.rule),
                  right: BorderSide(color: BonkTokens.rule),
                  bottom: BorderSide(color: BonkTokens.rule),
                ),
              ),
              child: Text(
                'Diagnostics unavailable. Please reload.',
                style: BonkType.sans(size: 13).copyWith(color: BonkTokens.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
