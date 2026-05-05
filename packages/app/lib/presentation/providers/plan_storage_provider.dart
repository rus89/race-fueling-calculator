// ABOUTME: Provider for the PlanStorage instance (overridable in tests).
// ABOUTME: Default value is PlanStorageLocal; tests override with a fake.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/plan_storage.dart';
import '../../data/plan_storage_local.dart';

final planStorageProvider = Provider<PlanStorage>((ref) => PlanStorageLocal());
