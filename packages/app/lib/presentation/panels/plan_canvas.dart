// ABOUTME: Center pane — race title, 6 stat cards, vertical timeline.
// ABOUTME: Reads plannerNotifierProvider + planProvider; surfaces AsyncError.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_fueling_core/core.dart';

import '../../data/plan_storage.dart';
import '../../domain/planner_state.dart';
import '../providers/plan_provider.dart';
import '../providers/planner_notifier.dart';
import '../providers/product_library_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/stat_card.dart';
import '../widgets/timeline_row.dart';

// Sports-nutrition consensus: dual-source carbs absorb best at glucose:fructose
// in the 1:0.7 to 1:1.2 band — equivalently, glucose/fructose 0.9 to 1.5.
const double _ratioOkLow = 0.9;
const double _ratioOkHigh = 1.5;

class PlanCanvas extends ConsumerWidget {
  const PlanCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(plannerNotifierProvider);
    final asyncPlan = ref.watch(planProvider);

    return asyncState.when(
      loading: () => Center(
        child: Semantics(
          liveRegion: true,
          label: 'Loading plan',
          child: const CircularProgressIndicator(),
        ),
      ),
      error: (e, st) => _ErrorFallback(error: e),
      data: (state) => asyncPlan.when(
        loading: () => Center(
          child: Semantics(
            liveRegion: true,
            label: 'Loading plan',
            child: const CircularProgressIndicator(),
          ),
        ),
        error: (e, st) => _ErrorFallback(error: e),
        data: (plan) => _Body(state: state, plan: plan),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final PlannerState state;
  final FuelingPlan plan;
  const _Body({required this.state, required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(productLibraryProvider);
    final productsById = {for (final p in library) p.id: p};
    final isEmpty = plan.entries.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('02 / PLAN', style: BonkType.railEyebrow),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(
              state.raceConfig.name.isEmpty
                  ? 'Untitled race'
                  : state.raceConfig.name,
              style: BonkType.sans(
                size: 32,
                w: FontWeight.w600,
              ).copyWith(letterSpacing: -0.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 22),
          if (isEmpty)
            const _EmptyState()
          else ...[
            _StatsGrid(plan: plan, target: state.raceConfig.targetCarbsGPerHr),
            const SizedBox(height: 28),
            _Timeline(plan: plan, state: state, productsById: productsById),
          ],
        ],
      ),
    );
  }
}

class _ErrorFallback extends StatelessWidget {
  final Object error;
  const _ErrorFallback({required this.error});

  @override
  Widget build(BuildContext context) {
    // Typed-error bucketing matching BonkRecoveryBanner: PlanStorageException
    // is a storage-layer failure (saved blob unreadable), anything else is
    // an engine-layer failure. The banner above the three-pane body is the
    // canonical recovery affordance — the canvas just signposts it.
    // PlanStorageException.toString() excludes rawBytes, so debugPrint is
    // safe for L1 telemetry; users see the static copy. kDebugMode guard
    // matches the planner_notifier pattern — release builds stay silent.
    if (kDebugMode) debugPrint('PlanCanvas error: $error');
    final message = error is PlanStorageException
        ? 'Saved plan unreadable — see recovery options.'
        : "Couldn't compute plan — see recovery options.";
    return Center(
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 4, height: 32, color: BonkTokens.bad),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  style: BonkType.sans(
                    size: 14,
                  ).copyWith(color: BonkTokens.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final FuelingPlan plan;
  final double target;
  const _StatsGrid({required this.plan, required this.target});

  // Canvas-local wrap threshold: NOT the page breakpoint. The canvas sits
  // inside the three-pane layout, so its own width is what governs whether
  // six stat cards fit in one row. At sub-880 px canvas widths, drop to a
  // 2-up Wrap.
  static const double _statsWrapBelow = 880;

  @override
  Widget build(BuildContext context) {
    final summary = plan.summary;
    // PlanSummary.glucoseFructoseRatio is fructose/glucose. The Glu:Fru card
    // and the diagnostics RatioBar (E1) display glucose/fructose, so consume
    // PlanSummary.glucoseToFructoseRatio (the inverse) to stay consistent
    // with §7.3 of the spec.
    final ratio = summary.glucoseToFructoseRatio;
    final ratioOk = ratio >= _ratioOkLow && ratio <= _ratioOkHigh;
    final cards = [
      StatCard(
        label: 'Avg carbs / hr',
        value: summary.averageGPerHr.toStringAsFixed(0),
        unit: 'g',
        sub: 'target ${target.round()}',
        isHero: true,
      ),
      StatCard(
        label: 'Total carbs',
        value: summary.totalCarbs.toStringAsFixed(0),
        unit: 'g',
      ),
      StatCard(
        label: 'Glu : Fru',
        value: ratio == 0 || !ratio.isFinite
            ? '—'
            : '${ratio.toStringAsFixed(2)}:1',
        severity: !ratioOk && ratio > 0 ? StatSeverity.warn : null,
      ),
      StatCard(
        label: 'Caffeine',
        value: summary.totalCaffeineMg.toStringAsFixed(0),
        unit: 'mg',
      ),
      StatCard(
        label: 'Fluid w/ fuel',
        value: (summary.totalWaterMl / 1000).toStringAsFixed(1),
        unit: 'L',
      ),
      StatCard(
        label: 'Items',
        value: plan.entries
            .fold<int>(0, (a, e) => a + e.products.length)
            .toString(),
      ),
    ];
    // Cards have varying intrinsic heights (the hero card uses statHero at
    // size 36; non-hero cards use statValue at size 20). A fixed-aspect
    // GridView clips the hero. Row + Expanded + IntrinsicHeight lets the
    // tallest card set the row height and stretches the others to match.
    // F1c-RESPONSIVE: below _statsWrapBelow the six-card Row overflows;
    // switch to a 2-up Wrap so cards stack into three rows at mobile
    // viewports.
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= _statsWrapBelow) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final card in cards) Expanded(child: card)],
            ),
          );
        }
        const spacing = BonkTokens.space4;
        // 2-up grid: subtract the single inter-card gap from total width and
        // halve. Floor at 0 so a degenerate maxWidth doesn't blow up.
        final cardWidth = ((c.maxWidth - spacing) / 2).clamp(
          0.0,
          double.infinity,
        );
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    // Empty-state fires when plan.entries is empty — in practice when the
    // user has cleared duration or hasn't started yet. F1c review HIGH#1
    // removed the destructive "Reset to seed plan" button (it overwrote
    // healthy in-progress work) and replaced it with copy that points the
    // user at the Setup rail/tab where they can actually fix the cause.
    const subhead =
        'Set a duration and add at least one product in Setup to compute '
        'your plan.';
    return Semantics(
      container: true,
      label: 'No plan yet. $subhead',
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                'No plan yet.',
                style: BonkType.sans(
                  size: 20,
                  w: FontWeight.w600,
                ).copyWith(color: BonkTokens.ink),
              ),
            ),
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: Text(
                subhead,
                style: BonkType.sans(size: 13).copyWith(color: BonkTokens.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final FuelingPlan plan;
  final PlannerState state;
  final Map<String, Product> productsById;
  const _Timeline({
    required this.plan,
    required this.state,
    required this.productsById,
  });

  @override
  Widget build(BuildContext context) {
    final stepHrs = (state.raceConfig.intervalMinutes ?? 15) / 60.0;
    final perStepTarget = state.raceConfig.targetCarbsGPerHr * stepHrs;
    final peak = plan.entries.isEmpty
        ? perStepTarget
        : [
            ...plan.entries.map((e) => e.carbsTotal),
            perStepTarget * 1.2,
          ].reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BonkTokens.rule)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 64),
                SizedBox(
                  width: 160,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0g',
                        style: BonkType.mono(
                          size: 9.5,
                        ).copyWith(color: BonkTokens.ink3),
                      ),
                      Text(
                        '${(peak / 2).round()}g',
                        style: BonkType.mono(
                          size: 9.5,
                        ).copyWith(color: BonkTokens.ink3),
                      ),
                      Text(
                        '${peak.round()}g',
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
          for (final entry in plan.entries)
            TimelineRow(
              entry: entry,
              targetG: perStepTarget,
              peakG: peak,
              productsById: productsById,
            ),
        ],
      ),
    );
  }
}
