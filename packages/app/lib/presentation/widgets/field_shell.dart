// ABOUTME: Renders a label + child input with consistent vertical spacing.
// ABOUTME: Used by every Setup-rail field to give labels the same treatment.
import 'package:flutter/material.dart';

import '../theme/typography.dart';

class BonkFieldShell extends StatelessWidget {
  final String label;
  final Widget child;
  const BonkFieldShell({super.key, required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: BonkType.fieldLabel),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
