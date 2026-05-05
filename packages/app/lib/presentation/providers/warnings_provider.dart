// ABOUTME: Convenience selector — flat list of warnings from the active plan.
// ABOUTME: Empty list when no plan is computed yet (state still loading).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import 'plan_provider.dart';

final warningsProvider = Provider<List<Warning>>((ref) {
  final plan = ref.watch(planProvider);
  return plan?.warnings ?? const [];
});
