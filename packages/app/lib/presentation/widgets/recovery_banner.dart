// ABOUTME: F1b — recovery banner above the three-pane body.
// ABOUTME: Branches on loadErrorProvider + saveStatusProvider; stable liveRegion root.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/plan_storage.dart';
import '../providers/plan_provider.dart';
import '../providers/planner_notifier.dart';
import '../providers/save_status_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

// Banner stays mounted (even on happy path) so the live region's stable
// node lets AT announce on label change. Do NOT conditionalize this in
// PlannerPage.
class BonkRecoveryBanner extends ConsumerWidget {
  const BonkRecoveryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Priority: load/engine errors trump save errors (a load failure means
    // the working state is unreliable; save failure with valid state is
    // recoverable by retriggering the save).
    //
    // loadErrorProvider exposes the un-unwrapped error from the planner
    // notifier (the planProvider's `unwrapPrevious()` strips it). The
    // recovery banner must surface that case — the storage is still broken,
    // the user still needs the retry/discard affordance.
    final loadError = ref.watch(loadErrorProvider);
    final saveStatus = ref.watch(saveStatusProvider);
    final notifier = ref.read(plannerNotifierProvider.notifier);

    final body = _bodyFor(loadError, saveStatus, notifier, ref);
    final label = _labelFor(loadError, saveStatus);

    // Stable Semantics node — mounted on every build regardless of branch.
    // AT live regions announce on label change of a stable node, not on
    // insertion, so this wrapper must NOT be conditional.
    return Semantics(
      liveRegion: true,
      container: true,
      label: label,
      child: body,
    );
  }

  Widget _bodyFor(
    Object? loadError,
    SaveStatus saveStatus,
    PlannerNotifier notifier,
    WidgetRef ref,
  ) {
    if (loadError != null) {
      if (loadError is PlanStorageException) {
        // Retry first — safe action before destructive.
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
        actions: [_Action(label: 'Retry save', onTap: notifier.retrySave)],
      );
    }
    return const SizedBox.shrink();
  }

  // Composes the live-region label. Empty on happy path; populated on error
  // branches so AT announces the new state on transition.
  String _labelFor(Object? loadError, SaveStatus saveStatus) {
    if (loadError != null) {
      if (loadError is PlanStorageException) {
        return 'CRITICAL: '
            "Saved plan couldn't be read. "
            'The on-disk plan is unreadable — the original bytes are '
            'backed up to a .bak file next to the slot. Retry to try again, '
            'or discard and start from the seed.';
      }
      return 'CRITICAL: '
          "Couldn't compute plan. "
          'The engine failed to produce a plan from the current setup. '
          'Retry to recompute.';
    }
    if (saveStatus == SaveStatus.failed) {
      return 'WARNING: Last save failed. '
          'Your edits are still in memory but did not reach disk. '
          'Retry to flush them.';
    }
    return '';
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
    // No ExcludeSemantics here — Material OutlinedButton, Text, etc. expose
    // their own semantics naturally. The parent stable Semantics wrapper
    // (in BonkRecoveryBanner.build) carries the live region; the children
    // are still navigable / tappable to assistive tech.
    return Container(
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
                // The header text (severity word + message) is already in
                // the parent's live-region label; exclude its inner
                // semantics so AT doesn't double-announce on banner mount.
                ExcludeSemantics(
                  child: Text(
                    // Color-doctrine: severity word in ink, color via side rule.
                    '$_severityWord — $message',
                    style: BonkType.sans(
                      size: 13,
                      w: FontWeight.w600,
                    ).copyWith(color: BonkTokens.ink),
                  ),
                ),
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: Text(
                    detail,
                    style: BonkType.sans(
                      size: 12,
                    ).copyWith(color: BonkTokens.ink2),
                  ),
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
                OutlinedButton(
                  onPressed: a.onTap,
                  // Pin foregroundColor against future M3 theme changes so
                  // 4.5:1 contrast against bg2 stays guaranteed.
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BonkTokens.ink,
                  ),
                  child: Text(a.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
