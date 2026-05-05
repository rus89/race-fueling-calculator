// ABOUTME: Persistence interface for the working PlannerState plus the typed
// ABOUTME: exception load() throws when the underlying blob is unreadable.
import '../domain/planner_state.dart';

/// Thrown by [PlanStorage.load] when a stored blob exists but cannot be turned
/// back into a [PlannerState] — malformed JSON, wrong shape, schema mismatch,
/// or platform initialisation failure. [rawBytes] carries the offending string
/// when a JSON-parseable blob was present (so the F1 banner can offer
/// forensic / "view raw" recovery); [cause] / [causeStack] preserve the source
/// exception for L1 telemetry.
///
/// An empty drive (key absent) is NOT an error — [PlanStorage.load] returns
/// `null` in that case.
class PlanStorageException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? causeStack;
  final String? rawBytes;
  const PlanStorageException(
    this.message, {
    this.cause,
    this.causeStack,
    this.rawBytes,
  });

  @override
  String toString() =>
      'PlanStorageException: $message${cause == null ? '' : ' (cause: $cause)'}';
}

abstract interface class PlanStorage {
  /// Returns the stored [PlannerState], or `null` when the drive is empty
  /// (no value has ever been saved). Throws [PlanStorageException] when a
  /// value exists but cannot be deserialised — callers should surface this
  /// as a recoverable error rather than silently substituting a seed.
  Future<PlannerState?> load();
  Future<void> save(PlannerState state);
  Future<void> clear();
}
