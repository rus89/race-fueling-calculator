// ABOUTME: Generic Timer-based debouncer that fires the latest payload.
// ABOUTME: Used by PlannerNotifier to coalesce rapid save() calls.
import 'dart:async';

class Debouncer<T> {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;
  T? _pending;
  void Function(T)? _onFire;
  bool _hasPending = false;
  bool _disposed = false;

  /// Schedule [fn] to fire with [payload] after [delay] of quiescence.
  /// Subsequent calls within the window overwrite the pending payload.
  ///
  /// Disposed debouncers are inert — late mutations routed through a
  /// debouncer whose owning notifier has torn down silently no-op so the
  /// onDispose contract is not defeated.
  void run(T payload, void Function(T) fn) {
    if (_disposed) return;
    _pending = payload;
    _onFire = fn;
    _hasPending = true;
    _timer?.cancel();
    _timer = Timer(delay, _fire);
  }

  /// Fire the pending payload synchronously, if any. Used at dispose time
  /// or when an external invariant requires the write to land now (e.g.
  /// "Retry save" button, or destructive recovery in
  /// `discardCorruptedAndUseSeed`).
  ///
  /// Disposed debouncers no-op the synchronous fire path too, so a
  /// user-explicit recovery action that races a teardown can never fire
  /// against disposed providers.
  void flush() {
    if (_disposed) return;
    if (!_hasPending) return;
    _timer?.cancel();
    _fire();
  }

  void _fire() {
    if (!_hasPending) return;
    final p = _pending as T;
    final fn = _onFire;
    _hasPending = false;
    _pending = null;
    _timer = null;
    fn?.call(p);
  }

  bool get hasPending => _hasPending;

  /// Exposed for tests so the dispose-guard contract can be pinned without
  /// reflection. Production callers should not branch on disposal state.
  bool get isDisposed => _disposed;

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _onFire = null;
    _hasPending = false;
  }
}
