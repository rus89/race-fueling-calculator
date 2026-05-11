// ABOUTME: Fixed 44px header — brand + plan summary + save-status indicator.
// ABOUTME: Reads planProvider (AsyncValue<FuelingPlan>) for totals; saveStatusProvider for the indicator.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/plan_provider.dart';
import '../providers/planner_notifier.dart';
import '../providers/save_status_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

class BonkTopbar extends ConsumerWidget {
  const BonkTopbar({super.key});

  String _fmtTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${m}min';
  }

  // Color-doctrine: severity carried by the dot, text stays in ink/ink2/ink3.
  ({String label, Color dot}) _saveIndicator(SaveStatus s) {
    switch (s) {
      case SaveStatus.idle:
        return (label: '· auto-saved', dot: BonkTokens.accent);
      case SaveStatus.inFlight:
        return (label: '· saving…', dot: BonkTokens.ink3);
      case SaveStatus.failed:
        return (label: '· save failed', dot: BonkTokens.bad);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlan = ref.watch(planProvider);
    final asyncState = ref.watch(plannerNotifierProvider);
    final saveStatus = ref.watch(saveStatusProvider);
    final indicator = _saveIndicator(saveStatus);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: BonkTokens.bg,
        border: Border(bottom: BorderSide(color: BonkTokens.rule)),
      ),
      child: Row(
        children: [
          // Brand mark — lime dot with ink ring + ink center
          SizedBox(
            width: 18,
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: BonkTokens.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: BonkTokens.ink, width: 1.5),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: BonkTokens.ink,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Bonk',
            style: BonkType.sans(
              size: 13,
              w: FontWeight.w600,
            ).copyWith(letterSpacing: -0.2),
          ),
          const SizedBox(width: 6),
          Text(
            'v0.1 · race fueling planner',
            style: BonkType.mono(size: 11).copyWith(color: BonkTokens.ink3),
          ),
          const Spacer(),
          // Plan summary — only when planProvider has resolved AND notifier has state.
          // planProvider is AsyncValue<FuelingPlan> (PB-DATA-1); use hasValue, not != null.
          if (asyncPlan.hasValue && asyncState.hasValue) ...[
            Text(
              'Plan',
              style: BonkType.sans(size: 12).copyWith(color: BonkTokens.ink3),
            ),
            const SizedBox(width: 8),
            Text(
              '${asyncPlan.requireValue.summary.totalCarbs.round()}g · ${_fmtTime(asyncState.requireValue.raceConfig.duration)}',
              style: BonkType.mono(size: 12).copyWith(color: BonkTokens.ink2),
            ),
            const SizedBox(width: 12),
          ],
          // Save indicator: dot + status text. Visible whenever the notifier
          // has state (even if planProvider is AsyncError — saving may have
          // happened before the engine failed on a different code path).
          if (asyncState.hasValue) ...[
            Container(
              key: const Key('topbar.saveDot'),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: indicator.dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Semantics(
              liveRegion: saveStatus == SaveStatus.failed,
              child: Text(
                indicator.label,
                style: BonkType.sans(size: 12).copyWith(color: BonkTokens.ink3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
