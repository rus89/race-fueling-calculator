// ABOUTME: Persistence interface for the working PlannerState.
// ABOUTME: Implemented by PlanStorageLocal (shared_preferences) for v1.1.
import '../domain/planner_state.dart';

abstract interface class PlanStorage {
  Future<PlannerState?> load();
  Future<void> save(PlannerState state);
  Future<void> clear();
}
