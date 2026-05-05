// ABOUTME: Renders a label + child input with consistent vertical spacing.
// ABOUTME: Wraps in Semantics(container, label) so screen readers associate
// ABOUTME: the visible label with the child input as one accessible field.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class BonkFieldShell extends StatelessWidget {
  final String label;
  final Widget child;
  const BonkFieldShell({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Text(label, style: BonkType.fieldLabel)),
          const SizedBox(height: BonkTokens.space6),
          child,
        ],
      ),
    );
  }
}
