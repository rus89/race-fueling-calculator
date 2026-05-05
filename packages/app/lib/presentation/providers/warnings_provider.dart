// ABOUTME: Convenience selector — flat list of warnings from the active plan.
// ABOUTME: Empty list when planProvider is loading or in error.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import 'plan_provider.dart';

final warningsProvider = Provider<List<Warning>>((ref) {
  final plan = ref.watch(planProvider);
  return plan.whenData((p) => p.warnings).value ?? const [];
});
