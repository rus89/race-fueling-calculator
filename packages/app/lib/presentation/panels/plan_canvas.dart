// ABOUTME: Center pane — race title, 6 stat cards, vertical timeline.
// ABOUTME: Reads plannerNotifierProvider + planProvider; surfaces AsyncError.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_fueling_core/core.dart';

import '../../domain/planner_state.dart';
import '../providers/plan_provider.dart';
import '../providers/planner_notifier.dart';
import '../providers/product_library_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/stat_card.dart';
import '../widgets/timeline_row.dart';

class PlanCanvas extends ConsumerWidget {
  const PlanCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(plannerNotifierProvider);
    final asyncPlan = ref.watch(planProvider);

    return asyncState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _ErrorFallback(error: e),
      data: (state) => asyncPlan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('02 / PLAN', style: BonkType.railEyebrow),
          const SizedBox(height: 4),
          Text(
            state.raceConfig.name.isEmpty
                ? 'Untitled race'
                : state.raceConfig.name,
            style: BonkType.sans(
              size: 32,
              w: FontWeight.w600,
            ).copyWith(letterSpacing: -0.5),
          ),
          const SizedBox(height: 22),
          _StatsGrid(plan: plan, target: state.raceConfig.targetCarbsGPerHr),
          const SizedBox(height: 28),
          _Timeline(plan: plan, state: state, productsById: productsById),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Plan unavailable — $error',
          style: BonkType.sans(size: 14).copyWith(color: BonkTokens.bad),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final FuelingPlan plan;
  final double target;
  const _StatsGrid({required this.plan, required this.target});

  @override
  Widget build(BuildContext context) {
    final summary = plan.summary;
    // PlanSummary.glucoseFructoseRatio is fructose/glucose. The Glu:Fru card
    // and the diagnostics RatioBar (E1) display glucose/fructose. Compute
    // glucose/fructose locally to stay consistent with §7.3 of the spec.
    final totalGlucose = plan.entries.fold<double>(
      0,
      (a, e) => a + e.carbsGlucose,
    );
    final totalFructose = plan.entries.fold<double>(
      0,
      (a, e) => a + e.carbsFructose,
    );
    final ratio = totalFructose > 0 ? totalGlucose / totalFructose : 0.0;
    final ratioOk = ratio >= 0.9 && ratio <= 1.5;
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
        flag: !ratioOk && ratio > 0 ? StatFlag.warn : null,
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final c in cards) Expanded(child: c)],
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
