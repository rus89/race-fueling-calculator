// ABOUTME: The single page of v1.1 — Topbar + three-pane responsive body.
// ABOUTME: Uses BonkBreakpoint to drop diagnostics rail (1380) and setup rail (880).
import 'package:flutter/material.dart';

import '../panels/diagnostics_rail.dart';
import '../panels/plan_canvas.dart';
import '../panels/setup_rail.dart';
import '../theme/breakpoints.dart';
import '../theme/tokens.dart';
import '../widgets/recovery_banner.dart';
import '../widgets/topbar.dart';

class PlannerPage extends StatelessWidget {
  const PlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BonkTokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            const BonkTopbar(),
            const BonkRecoveryBanner(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final bp = BonkBreakpoint.forWidth(c.maxWidth);
                  if (bp == BonkBreakpoint.mobile) {
                    return const _MobileBody();
                  }
                  return Row(
                    children: [
                      if (bp.showsSetupRail)
                        SizedBox(
                          width: bp.setupRailWidth,
                          child: const SetupRail(),
                        ),
                      const Expanded(child: PlanCanvas()),
                      if (bp.showsDiagnosticsRail)
                        SizedBox(
                          width: bp.diagnosticsRailWidth,
                          child: const DiagnosticsRail(),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // F1c — Checks drawer for noDiagnostics/narrow widths. Inline
      // diagnostics rail hides <1380; an EndDrawer hosts it instead.
      // Topbar exposes a "Checks" button to open it at those widths.
      endDrawer: const _DiagnosticsEndDrawer(),
    );
  }
}

class _MobileBody extends StatelessWidget {
  const _MobileBody();
  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Setup'),
              Tab(text: 'Plan'),
              Tab(text: 'Diagnostics'),
            ],
          ),
          // The rails' side-rule decoration is the desktop seam between panels;
          // inside a TabBarView it reads as a stray vertical line at the tab
          // content's edge. Mobile tabs opt out.
          Expanded(
            child: TabBarView(
              children: [
                SetupRail(showSideRule: false),
                PlanCanvas(),
                DiagnosticsRail(showSideRule: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsEndDrawer extends StatelessWidget {
  const _DiagnosticsEndDrawer();

  @override
  Widget build(BuildContext context) {
    // The endDrawer is registered unconditionally; the Topbar's Checks
    // button — the only UI affordance that opens it — is gated by
    // [BonkBreakpoint.usesEndDrawerForDiagnostics] so wide/medium (inline
    // rail visible) and mobile (tabs) never reach this surface in practice.
    return const Drawer(
      width: 380,
      backgroundColor: BonkTokens.bg,
      child: SafeArea(child: DiagnosticsRail()),
    );
  }
}
