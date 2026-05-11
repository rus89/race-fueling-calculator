// ABOUTME: F1b — recovery banner above the three-pane body.
// ABOUTME: Branches on planProvider error type + saveStatusProvider.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/plan_storage.dart';
import '../providers/plan_provider.dart';
import '../providers/planner_notifier.dart';
import '../providers/save_status_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

class BonkRecoveryBanner extends ConsumerWidget {
  const BonkRecoveryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the notifier directly so AsyncError on the storage load is
    // reachable here even when planProvider's `unwrapPrevious()` has
    // stripped the prior-error carry-over off a transient AsyncLoading
    // (Riverpod 3.x represents a rebuilt-on-prior-error provider as
    // AsyncLoading retaining the error; the planProvider intentionally
    // strips that, so we re-derive the canonical error from the notifier).
    final asyncState = ref.watch(plannerNotifierProvider);
    final asyncPlan = ref.watch(planProvider);
    final saveStatus = ref.watch(saveStatusProvider);
    final notifier = ref.read(plannerNotifierProvider.notifier);

    // Priority: load/engine errors trump save errors (a load failure means
    // the working state is unreliable; save failure with valid state is
    // recoverable by retriggering the save).
    //
    // Use `.error` over `.hasError` because Riverpod 3.x represents a
    // rebuilt-on-prior-error provider as AsyncLoading with the prior error
    // preserved (`.error` non-null, `.hasError` false). The recovery banner
    // must surface that case as well — the storage is still broken, the
    // user still needs the retry/discard affordance.
    final err = asyncState.error ?? asyncPlan.error;
    if (err != null) {
      if (err is PlanStorageException) {
        return _Banner(
          message: "Saved plan couldn't be read.",
          detail:
              'The on-disk plan is unreadable — the original bytes are '
              'backed up to a .bak file next to the slot. Retry to try again, '
              'or discard and start from the seed.',
          severity: _Severity.bad,
          actions: [
            _Action(label: 'Retry', onTap: () => notifier.retryLoad()),
            _Action(
              label: 'Discard and start fresh',
              onTap: notifier.discardCorruptedAndUseSeed,
            ),
          ],
        );
      }
      return _Banner(
        message: "Couldn't compute plan.",
        detail:
            'The engine failed to produce a plan from the current setup. '
            'Retry to recompute.',
        severity: _Severity.bad,
        actions: [_Action(label: 'Retry', onTap: () => notifier.retryLoad())],
      );
    }
    if (saveStatus == SaveStatus.failed) {
      return _Banner(
        message: 'Last save failed.',
        detail:
            'Your edits are still in memory but did not reach disk. '
            'Retry to flush them.',
        severity: _Severity.warn,
        actions: [
          _Action(
            // Re-emit the current state through the notifier to retrigger
            // the save chain. updateRaceConfig with identity edit suffices.
            label: 'Retry save',
            onTap: () => notifier.updateRaceConfig((c) => c),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

enum _Severity { warn, bad }

class _Action {
  const _Action({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.detail,
    required this.severity,
    required this.actions,
  });

  final String message;
  final String detail;
  final _Severity severity;
  final List<_Action> actions;

  Color get _sideRule => switch (severity) {
    _Severity.warn => BonkTokens.warn,
    _Severity.bad => BonkTokens.bad,
  };

  String get _severityWord => switch (severity) {
    _Severity.warn => 'WARNING',
    _Severity.bad => 'CRITICAL',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      label: '$_severityWord: $message $detail',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: BonkTokens.bg2,
            border: Border(
              left: BorderSide(color: _sideRule, width: 3),
              bottom: const BorderSide(color: BonkTokens.rule),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // Color-doctrine: severity word in ink, color via side rule.
                      '$_severityWord — $message',
                      style: BonkType.sans(
                        size: 13,
                        w: FontWeight.w600,
                      ).copyWith(color: BonkTokens.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: BonkType.sans(
                        size: 12,
                      ).copyWith(color: BonkTokens.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final a in actions)
                    OutlinedButton(onPressed: a.onTap, child: Text(a.label)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
