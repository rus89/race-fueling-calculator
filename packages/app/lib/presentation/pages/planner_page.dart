// ABOUTME: The single page of v1.1 — Topbar + three-pane app body.
// ABOUTME: Wires SetupRail, PlanCanvas, DiagnosticsRail with responsive breakpoints.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class PlannerPage extends StatelessWidget {
  const PlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BonkTokens.bg,
      body: Center(child: Text('Bonk planner — coming online…')),
    );
  }
}
