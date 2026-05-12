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
import '../util/units.dart';
import '../widgets/aid_station_row.dart';
import '../widgets/field_shell.dart';
import '../widgets/inventory_row.dart';
import '../widgets/seg_control.dart';
import '../widgets/text_input.dart';

class SetupRail extends ConsumerWidget {
  /// Whether to paint the right-side rule that separates the rail from the
  /// canvas in the desktop three-pane layout. Mobile TabBarView places the
  /// rail as a tab child; suppressing the rule prevents a stray vertical
  /// line at the tab content's edge.
  final bool showSideRule;
  const SetupRail({super.key, this.showSideRule = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(plannerNotifierProvider);
    return asyncState.when(
      loading: () => Semantics(
        liveRegion: true,
        label: 'Loading planner',
        child: const Center(child: CircularProgressIndicator()),
      ),
      // The actionable recovery affordance lives in the BonkRecoveryBanner
      // (F1b). The rail signposts the banner rather than duplicating its
      // retry/discard controls. Exception details are intentionally not
      // interpolated — the banner carries typed-error bucketing; the rail
      // just stays non-empty. Layout-agnostic copy: the banner may render
      // above or beside the rail depending on viewport.
      error: (e, _) => Semantics(
        liveRegion: true,
        container: true,
        label: 'Setup unavailable — see recovery options.',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Setup unavailable — see recovery options.',
              style: BonkType.sans().copyWith(color: BonkTokens.ink2),
            ),
          ),
        ),
      ),
      data: (state) => _RailBody(state: state, showSideRule: showSideRule),
    );
  }
}

class _RailBody extends ConsumerWidget {
  final PlannerState state;
  final bool showSideRule;
  const _RailBody({required this.state, required this.showSideRule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(plannerNotifierProvider.notifier);
    return Container(
      key: const Key('setup-rail.outer'),
      decoration: BoxDecoration(
        border: showSideRule
            ? const Border(right: BorderSide(color: BonkTokens.rule))
            : null,
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
              // No labelText: BonkFieldShell renders the canonical label
              // ("Name") above the input AND exposes it via Semantics. A
              // floating labelText here would duplicate "Race name" inside
              // the OutlineInputBorder and truncate on narrow rail widths.
              child: BonkTextInput(
                key: const Key('setup.race_name'),
                value: state.raceConfig.name,
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

  // End-anchored: single optional decimal point, no trailing characters. The
  // anchor makes the intent self-documenting.
  static final _decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d*$'),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(plannerNotifierProvider).requireValue;
    final notifier = ref.read(plannerNotifierProvider.notifier);
    final isImperial = state.athleteProfile.unitSystem == UnitSystem.imperial;
    final massUnit = isImperial ? 'lb' : 'kg';
    final distUnit = isImperial ? 'mi' : 'km';

    // Storage stays canonical SI; convert at the I/O boundary only.
    // Defensive finite-positive guard: even if a non-finite or non-positive
    // bodyWeightKg slips past the model invariants (release-mode assert
    // elision, legacy blob loaded pre-finite guard), fall back to a safe
    // default rather than rendering "NaN" or crashing.
    final rawKg = state.athleteProfile.bodyWeightKg;
    final safeKg = (rawKg != null && rawKg.isFinite && rawKg > 0)
        ? rawKg
        : 70.0;
    final massDisplay = isImperial ? kgToLb(safeKg) : safeKg;
    // Imperial keeps one decimal so the field doesn't overwrite the user's
    // typed mid-edit precision (e.g. "158.7" lb round-trips to "158.7", not
    // "159"). Metric uses integer display because kg granularity is coarse
    // and one-decimal noise would clutter the rail.
    final massStr = isImperial
        ? massDisplay.toStringAsFixed(1)
        : '${massDisplay.round()}';

    final rawKm = state.raceConfig.distanceKm;
    final safeKm = (rawKm != null && rawKm.isFinite && rawKm > 0)
        ? rawKm
        : null;
    final String distDisplay;
    if (safeKm == null) {
      distDisplay = '';
    } else {
      final shown = isImperial ? kmToMi(safeKm) : safeKm;
      distDisplay = isImperial ? shown.toStringAsFixed(1) : '${shown.round()}';
    }

    return Row(
      children: [
        Expanded(
          child: BonkFieldShell(
            label: 'Body mass ($massUnit)',
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: BonkTextInput(
                    key: const Key('setup.body_mass'),
                    value: massStr,
                    monoFont: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [_decimalFormatter],
                    onChanged: (v) {
                      final typed = double.tryParse(v);
                      if (typed == null || typed <= 0) return;
                      final kg = isImperial ? lbToKg(typed) : typed;
                      notifier.updateAthleteProfile(
                        (p) => p.copyWith(bodyWeightKg: kg),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                ExcludeSemantics(
                  child: Text(
                    massUnit,
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
            label: 'Total distance ($distUnit)',
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: BonkTextInput(
                    key: const Key('setup.distance_km'),
                    value: distDisplay,
                    monoFont: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [_decimalFormatter],
                    onChanged: (v) {
                      if (v.isEmpty) {
                        // Sentinel-aware copyWith: passing null clears the
                        // field so the user can drop the distance entirely.
                        notifier.updateRaceConfig(
                          (c) => c.copyWith(distanceKm: null),
                        );
                        return;
                      }
                      final typed = double.tryParse(v);
                      if (typed == null) return;
                      final km = isImperial ? miToKm(typed) : typed;
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
