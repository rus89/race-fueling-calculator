// ABOUTME: Setup rail — left pane. Race / strategy / inventory / aid-stations.
// ABOUTME: All inputs route through PlannerNotifier; recompute is automatic.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import '../../domain/planner_state.dart';
import '../providers/planner_notifier.dart';
import '../providers/product_library_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/aid_station_row.dart';
import '../widgets/field_shell.dart';
import '../widgets/inventory_row.dart';
import '../widgets/seg_control.dart';
import '../widgets/text_input.dart';

class SetupRail extends ConsumerWidget {
  const SetupRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(plannerNotifierProvider);
    return asyncState.when(
      loading: () => Semantics(
        liveRegion: true,
        label: 'Loading planner',
        child: const Center(child: CircularProgressIndicator()),
      ),
      // PC-ERROR-UI: stub. F1 replaces with actionable banner per
      // PB-DATA-1 (JOURNAL Phase B Round 3 closeout). Exception details
      // are intentionally not interpolated — they could leak stack hints.
      error: (e, _) => Semantics(
        liveRegion: true,
        child: Center(
          child: Text(
            'Failed to load planner state. Please reload.',
            style: BonkType.sans(),
          ),
        ),
      ),
      data: (state) => _RailBody(state: state),
    );
  }
}

class _RailBody extends ConsumerWidget {
  final PlannerState state;
  const _RailBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(plannerNotifierProvider.notifier);
    return Container(
      // PC-RESPONSIVE: F1 will swap this hardcoded width for
      // BonkBreakpoint.setupRailWidth driven by MediaQuery.sizeOf(context).
      width: 320,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: BonkTokens.rule)),
        color: BonkTokens.bg,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Head
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('01 / SETUP', style: BonkType.railEyebrow),
                  const SizedBox(height: 4),
                  Text('Race parameters', style: BonkType.railTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Tune inputs. Plan recomputes live.',
                    style: BonkType.railSub,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: BonkTokens.rule),
            const _SectionLabel(label: 'RACE'),
            BonkFieldShell(
              label: 'Name',
              child: BonkTextInput(
                key: const Key('setup.race_name'),
                value: state.raceConfig.name,
                labelText: 'Race name',
                maxLength: 100,
                onChanged: (v) =>
                    notifier.updateRaceConfig((c) => c.copyWith(name: v)),
              ),
            ),
            const SizedBox(height: 12),
            const _DurationRow(),
            const SizedBox(height: 12),
            const _BodyMassAndDistanceRow(),
            const SizedBox(height: 12),
            BonkFieldShell(
              label: 'Discipline',
              child: BonkSegControl<Discipline>(
                key: const Key('setup.discipline'),
                value: state.raceConfig.discipline ?? Discipline.xcm,
                options: const [
                  (Discipline.xcm, 'MTB XCM'),
                  (Discipline.road, 'Road'),
                  (Discipline.run, 'Run'),
                  (Discipline.tri, 'Tri'),
                  (Discipline.ultra, 'Ultra'),
                ],
                onChanged: (d) =>
                    notifier.updateRaceConfig((c) => c.copyWith(discipline: d)),
              ),
            ),
            const Divider(height: 1, color: BonkTokens.rule),
            const _SectionLabel(label: 'CARB STRATEGY'),
            BonkFieldShell(
              label:
                  'Target intake — ${state.raceConfig.targetCarbsGPerHr.round()} g/hr',
              child: Slider(
                min: 30,
                max: 120,
                divisions: 18,
                value: state.raceConfig.targetCarbsGPerHr.clamp(30.0, 120.0),
                onChanged: (v) => notifier.updateRaceConfig(
                  (c) => c.copyWith(targetCarbsGPerHr: v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            BonkFieldShell(
              label:
                  'Gut-trained ceiling — ${state.athleteProfile.gutToleranceGPerHr.round()} g/hr',
              child: Slider(
                min: 30,
                max: 120,
                divisions: 18,
                value: state.athleteProfile.gutToleranceGPerHr.clamp(
                  30.0,
                  120.0,
                ),
                onChanged: (v) => notifier.updateAthleteProfile(
                  (p) => p.copyWith(gutToleranceGPerHr: v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            BonkFieldShell(
              label: 'Distribution',
              child: BonkSegControl<Strategy>(
                value: state.raceConfig.strategy,
                options: const [
                  (Strategy.frontLoad, 'Front-load'),
                  (Strategy.steady, 'Steady'),
                  (Strategy.backLoad, 'Back-load'),
                ],
                onChanged: (s) =>
                    notifier.updateRaceConfig((c) => c.copyWith(strategy: s)),
              ),
            ),
            const Divider(height: 1, color: BonkTokens.rule),
            const _InventorySection(),
            const Divider(height: 1, color: BonkTokens.rule),
            const _AidStationsSection(),
          ],
        ),
      ),
    );
  }
}

class _InventorySection extends ConsumerWidget {
  const _InventorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(plannerNotifierProvider).requireValue;
    final notifier = ref.read(plannerNotifierProvider.notifier);
    final library = ref.watch(productLibraryProvider);
    final selections = state.raceConfig.selectedProducts;
    final totalCount = selections.fold<int>(0, (a, s) => a + s.quantity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'INVENTORY ($totalCount items)'),
        for (final p in library)
          InventoryRow(
            product: p,
            count: selections
                .firstWhere(
                  (s) => s.productId == p.id,
                  orElse: () => ProductSelection(productId: p.id, quantity: 0),
                )
                .quantity,
            onChanged: (n) {
              // Preserve existing order on increment / decrement.
              // Removing a count zeroes the entry out; adding a
              // brand-new one appends.
              final List<ProductSelection> next;
              if (n == 0) {
                next = selections.where((s) => s.productId != p.id).toList();
              } else if (selections.any((s) => s.productId == p.id)) {
                next = [
                  for (final s in selections)
                    if (s.productId == p.id)
                      ProductSelection(productId: p.id, quantity: n)
                    else
                      s,
                ];
              } else {
                next = [
                  ...selections,
                  ProductSelection(productId: p.id, quantity: n),
                ];
              }
              notifier.updateRaceConfig(
                (c) => c.copyWith(selectedProducts: next),
              );
            },
          ),
      ],
    );
  }
}

class _AidStationsSection extends ConsumerWidget {
  const _AidStationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(plannerNotifierProvider).requireValue;
    final notifier = ref.read(plannerNotifierProvider.notifier);
    final library = ref.watch(productLibraryProvider);
    final stations = state.raceConfig.aidStations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'AID STATIONS'),
        if (stations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "No aid stations. You're carrying everything.",
              style: BonkType.sans(size: 12).copyWith(color: BonkTokens.ink3),
            ),
          ),
        for (var i = 0; i < stations.length; i++)
          Semantics(
            container: true,
            label: 'Aid station ${i + 1}',
            child: AidStationRow(
              key: ValueKey('aid-$i'),
              station: stations[i],
              library: library,
              onChanged: (next) {
                final updated = [...stations]..[i] = next;
                notifier.updateRaceConfig(
                  (c) => c.copyWith(aidStations: updated),
                );
              },
              onRemove: () {
                final updated = [...stations]..removeAt(i);
                notifier.updateRaceConfig(
                  (c) => c.copyWith(aidStations: updated),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            final mid = state.raceConfig.duration.inMinutes ~/ 2;
            final updated = [...stations, AidStation(timeMinutes: mid)];
            notifier.updateRaceConfig((c) => c.copyWith(aidStations: updated));
          },
          child: const Text('+ Add aid station'),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Semantics(
      header: true,
      child: Text(label, style: BonkType.sectionLabel),
    ),
  );
}

class _DurationRow extends ConsumerWidget {
  const _DurationRow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(plannerNotifierProvider).requireValue;
    final notifier = ref.read(plannerNotifierProvider.notifier);
    final dur = state.raceConfig.duration;
    final h = dur.inHours;
    final m = dur.inMinutes % 60;
    return BonkFieldShell(
      label: 'Duration',
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: BonkTextInput(
              key: const Key('setup.duration_hours'),
              value: '$h',
              monoFont: true,
              labelText: 'Hours',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                final newH = int.tryParse(v) ?? h;
                notifier.updateRaceConfig(
                  (c) => c.copyWith(
                    duration: Duration(hours: newH, minutes: m),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          ExcludeSemantics(
            child: Text(
              'h',
              style: BonkType.mono(size: 11).copyWith(color: BonkTokens.ink3),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: BonkTextInput(
              key: const Key('setup.duration_minutes'),
              value: '$m',
              monoFont: true,
              labelText: 'Minutes',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                final newM = int.tryParse(v) ?? m;
                notifier.updateRaceConfig(
                  (c) => c.copyWith(
                    duration: Duration(hours: h, minutes: newM),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          ExcludeSemantics(
            child: Text(
              'm',
              style: BonkType.mono(size: 11).copyWith(color: BonkTokens.ink3),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyMassAndDistanceRow extends ConsumerWidget {
  const _BodyMassAndDistanceRow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(plannerNotifierProvider).requireValue;
    final notifier = ref.read(plannerNotifierProvider.notifier);
    // PC-UNIT-CONVERSION: hardcoded to canonical SI units until F1 wires real
    // conversion. Imperial users see 'kg' / 'km' — accurate to the stored
    // value even if the user's unitSystem preference says otherwise. See
    // JOURNAL PB-Phase-C for the F1 follow-up.
    const unit = 'kg';
    const distUnit = 'km';
    return Row(
      children: [
        Expanded(
          child: BonkFieldShell(
            label: 'Body mass',
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: BonkTextInput(
                    key: const Key('setup.body_mass'),
                    value: '${state.athleteProfile.bodyWeightKg ?? 70}',
                    monoFont: true,
                    labelText: 'Body mass',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      final w = double.tryParse(v);
                      if (w != null && w > 0) {
                        notifier.updateAthleteProfile(
                          (p) => p.copyWith(bodyWeightKg: w),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                ExcludeSemantics(
                  child: Text(
                    unit,
                    style: BonkType.mono(
                      size: 11,
                    ).copyWith(color: BonkTokens.ink3),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: BonkFieldShell(
            label: 'Total distance',
            // PC-PRESERVE-DIST: RaceConfig.copyWith treats a null `distanceKm`
            // argument as "no change" (standard Dart pattern), so a user who
            // empties the field cannot clear the stored distance via this
            // input — the previous value is preserved. F1 will introduce
            // an explicit "clear distance" affordance or a sentinel-aware
            // copyWith if product needs the cleared state.
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: BonkTextInput(
                    key: const Key('setup.distance_km'),
                    value: state.raceConfig.distanceKm == null
                        ? ''
                        : '${state.raceConfig.distanceKm!.round()}',
                    monoFont: true,
                    labelText: 'Total distance',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (v) {
                      final km = double.tryParse(v);
                      notifier.updateRaceConfig(
                        (c) => c.copyWith(distanceKm: km),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                ExcludeSemantics(
                  child: Text(
                    distUnit,
                    style: BonkType.mono(
                      size: 11,
                    ).copyWith(color: BonkTokens.ink3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
