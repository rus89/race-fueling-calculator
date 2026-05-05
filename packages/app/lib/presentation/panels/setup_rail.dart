// ABOUTME: Setup rail — left pane. Race / strategy / inventory / aid-stations.
// ABOUTME: All inputs route through PlannerNotifier; recompute is automatic.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import '../../domain/planner_state.dart';
import '../providers/planner_notifier.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/field_shell.dart';
import '../widgets/seg_control.dart';

class SetupRail extends ConsumerWidget {
  const SetupRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(plannerNotifierProvider);
    return asyncState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load: $e')),
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
              child: _BonkTextInput(
                key: const Key('setup.race_name'),
                value: state.raceConfig.name,
                onChanged: (v) =>
                    notifier.updateRaceConfig((c) => c.copyWith(name: v)),
              ),
            ),
            const SizedBox(height: 12),
            _DurationRow(state: state, notifier: notifier),
            const SizedBox(height: 12),
            _BodyMassAndDistanceRow(state: state, notifier: notifier),
            const SizedBox(height: 12),
            BonkFieldShell(
              label: 'Discipline',
              child: BonkSegControl<Discipline>(
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
            // Subsequent sections (carb strategy, inventory, aid stations) are
            // wired up in tasks C3-C5.
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Text(label, style: BonkType.sectionLabel),
  );
}

class _BonkTextInput extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final bool monoFont;
  const _BonkTextInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.keyboardType,
    this.monoFont = false,
  });

  @override
  State<_BonkTextInput> createState() => _BonkTextInputState();
}

class _BonkTextInputState extends State<_BonkTextInput> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_BonkTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      style: widget.monoFont ? BonkType.mono(size: 14) : BonkType.sans(),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        filled: true,
        fillColor: BonkTokens.paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BonkTokens.r),
          borderSide: const BorderSide(color: BonkTokens.rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BonkTokens.r),
          borderSide: const BorderSide(color: BonkTokens.rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BonkTokens.r),
          borderSide: const BorderSide(color: BonkTokens.ink),
        ),
      ),
    );
  }
}

class _DurationRow extends StatelessWidget {
  final PlannerState state;
  final PlannerNotifier notifier;
  const _DurationRow({required this.state, required this.notifier});
  @override
  Widget build(BuildContext context) {
    final dur = state.raceConfig.duration;
    final h = dur.inHours;
    final m = dur.inMinutes % 60;
    return BonkFieldShell(
      label: 'Duration',
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: _BonkTextInput(
              value: '$h',
              monoFont: true,
              keyboardType: TextInputType.number,
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
          Text(
            'h',
            style: BonkType.mono(size: 11).copyWith(color: BonkTokens.ink3),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: _BonkTextInput(
              value: '$m',
              monoFont: true,
              keyboardType: TextInputType.number,
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
          Text(
            'm',
            style: BonkType.mono(size: 11).copyWith(color: BonkTokens.ink3),
          ),
        ],
      ),
    );
  }
}

class _BodyMassAndDistanceRow extends StatelessWidget {
  final PlannerState state;
  final PlannerNotifier notifier;
  const _BodyMassAndDistanceRow({required this.state, required this.notifier});
  @override
  Widget build(BuildContext context) {
    final unit = state.athleteProfile.unitSystem == UnitSystem.imperial
        ? 'lb'
        : 'kg';
    final distUnit = state.athleteProfile.unitSystem == UnitSystem.imperial
        ? 'mi'
        : 'km';
    return Row(
      children: [
        Expanded(
          child: BonkFieldShell(
            label: 'Body mass',
            // PC-UNIT-CONVERSION: bodyWeightKg is canonical kg, but the
            // adjacent label flips to "lb" when unitSystem == imperial.
            // The displayed number is not converted, so an imperial user
            // sees a kg value labelled lb. F1 will add the kg<->lb
            // conversion when the unit toggle ships.
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: _BonkTextInput(
                    value: '${state.athleteProfile.bodyWeightKg ?? 70}',
                    monoFont: true,
                    keyboardType: TextInputType.number,
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
                Text(
                  unit,
                  style: BonkType.mono(
                    size: 11,
                  ).copyWith(color: BonkTokens.ink3),
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
            // PC-UNIT-CONVERSION: same kg/lb story applies for km/mi here.
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: _BonkTextInput(
                    value: state.raceConfig.distanceKm == null
                        ? ''
                        : '${state.raceConfig.distanceKm!.round()}',
                    monoFont: true,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final km = double.tryParse(v);
                      notifier.updateRaceConfig(
                        (c) => c.copyWith(distanceKm: km),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  distUnit,
                  style: BonkType.mono(
                    size: 11,
                  ).copyWith(color: BonkTokens.ink3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
