// ABOUTME: Fixed 44px header — brand + plan summary + save-status indicator.
// ABOUTME: Reads planProvider (AsyncValue<FuelingPlan>) for totals; saveStatusProvider for the indicator.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/plan_provider.dart';
import '../providers/planner_notifier.dart';
import '../providers/save_status_provider.dart';
import '../theme/breakpoints.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

class BonkTopbar extends ConsumerWidget {
  const BonkTopbar({super.key});

  String _fmtTime(Duration d) {
    if (d.inMilliseconds <= 0) return '—';
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
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: BonkTokens.bg,
        border: Border(bottom: BorderSide(color: BonkTokens.rule)),
      ),
      child: Row(
        children: [
          // PB-A11Y: brand mark is decorative; Text('Bonk') is the AT name.
          ExcludeSemantics(
            child: SizedBox(
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
          Flexible(
            child: Text(
              'v0.1 · race fueling planner',
              style: BonkType.mono(size: 11).copyWith(color: BonkTokens.ink3),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
          // Right cluster: plan summary + save indicator + (optional) Checks
          // button. Wrap in Expanded + end-alignment so the cluster claims
          // the leftover space (replacing the previous Spacer) and clamp
          // each Text to one line. Each text node sits in a Flexible so
          // a 200% textScaler at narrow widths clips rather than throws a
          // RenderFlex overflow (F1c review MEDIUM#8).
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                // Plan summary — only when planProvider has resolved AND notifier has state.
                // planProvider is AsyncValue<FuelingPlan> (PB-DATA-1); use hasValue, not != null.
                if (asyncPlan.hasValue && asyncState.hasValue) ...[
                  Flexible(
                    child: Text(
                      'Plan',
                      style: BonkType.sans(
                        size: 12,
                      ).copyWith(color: BonkTokens.ink3),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Builder(
                      builder: (_) {
                        final totalCarbs =
                            asyncPlan.requireValue.summary.totalCarbs;
                        final carbsStr = totalCarbs.isFinite
                            ? totalCarbs.round().toString()
                            : '—';
                        final timeStr = _fmtTime(
                          asyncState.requireValue.raceConfig.duration,
                        );
                        return Text(
                          '${carbsStr}g · $timeStr',
                          style: BonkType.mono(
                            size: 12,
                          ).copyWith(color: BonkTokens.ink2),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Save indicator: dot + status text. The Semantics node is
                // always mounted with `liveRegion: true` so AT announces on
                // label change of a stable live-region root (mirrors the
                // pattern in recovery_banner.dart). Toggling liveRegion off
                // during the idle state silenced the inFlight→idle "·
                // auto-saved" transition — exactly the announcement screen-
                // reader users need to confirm a save landed. The visible
                // dot/text only render once the notifier has hydrated state.
                Flexible(
                  child: Semantics(
                    liveRegion: true,
                    child: asyncState.hasValue
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: Container(
                                  key: const Key('topbar.saveDot'),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: indicator.dot,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  indicator.label,
                                  style: BonkType.sans(
                                    size: 12,
                                  ).copyWith(color: BonkTokens.ink3),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                // F1c: at noDiagnostics / narrow widths the inline diagnostics
                // rail is hidden but the page is not in tab mode — surface a
                // way to open the endDrawer so checks remain reachable.
                // Mobile uses tabs.
                const _ChecksButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecksButton extends StatelessWidget {
  const _ChecksButton();

  @override
  Widget build(BuildContext context) {
    final bp = BonkBreakpoint.forWidth(MediaQuery.sizeOf(context).width);
    if (!bp.usesEndDrawerForDiagnostics) {
      return const SizedBox.shrink();
    }
    // Material TextButton.icon already exposes button semantics; a Tooltip
    // here supplies both the accessible label (via its `message`) and a
    // hover affordance for pointer users.
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: 'Open diagnostics',
        child: TextButton.icon(
          key: const Key('topbar.checksButton'),
          onPressed: () => Scaffold.of(context).openEndDrawer(),
          icon: const Icon(Icons.checklist, size: 16),
          label: const Text('Checks'),
          style: TextButton.styleFrom(
            foregroundColor: BonkTokens.ink,
            textStyle: BonkType.sans(size: 12, w: FontWeight.w600),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}
