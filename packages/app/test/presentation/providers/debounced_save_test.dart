// ABOUTME: Debouncer fires once per quiescent window with the latest payload.
// ABOUTME: Covers coalesce, gap-fires-twice, flush, and empty-flush no-op.
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/providers/debounced_save.dart';

void main() {
  test('coalesces rapid calls into one fire with the latest payload', () async {
    final fires = <int>[];
    final d = Debouncer<int>(const Duration(milliseconds: 50));
    d.run(1, (v) => fires.add(v));
    d.run(2, (v) => fires.add(v));
    d.run(3, (v) => fires.add(v));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fires, [3]);
  });

  test('two windows separated by gap fire twice', () async {
    final fires = <int>[];
    final d = Debouncer<int>(const Duration(milliseconds: 50));
    d.run(1, (v) => fires.add(v));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    d.run(2, (v) => fires.add(v));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fires, [1, 2]);
  });

  test('flush() fires immediately with pending payload', () async {
    final fires = <int>[];
    final d = Debouncer<int>(const Duration(milliseconds: 50));
    d.run(7, (v) => fires.add(v));
    d.flush();
    expect(fires, [7]);
  });

  test('flush() with no pending is a no-op', () {
    final fires = <int>[];
    final d = Debouncer<int>(const Duration(milliseconds: 50));
    d.flush();
    expect(fires, isEmpty);
  });

  test('dispose() cancels pending and prevents future fire', () async {
    // Locks the invariant that disposal kills the in-flight timer and
    // never fires the pending callback. Without this, a notifier teardown
    // mid-debounce-window leaks a save against disposed providers.
    final fires = <int>[];
    final d = Debouncer<int>(const Duration(milliseconds: 50));
    d.run(42, (v) => fires.add(v));
    d.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fires, isEmpty);
    expect(d.isDisposed, isTrue);
  });

  test('run() after dispose() is a no-op', () async {
    // A debouncer that's been disposed must not silently re-arm — the
    // notifier's onDispose hook would otherwise be defeated by a late
    // mutation routed through it.
    final fires = <int>[];
    final d = Debouncer<int>(const Duration(milliseconds: 50));
    d.dispose();
    d.run(7, (v) => fires.add(v));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fires, isEmpty);
    expect(d.hasPending, isFalse);
    expect(d.isDisposed, isTrue);
  });

  test('flush() after dispose() is a no-op', () {
    // flush() is the synchronous fire path; it must also short-circuit
    // post-disposal so user-explicit recovery paths can't fire against
    // disposed providers.
    final fires = <int>[];
    final d = Debouncer<int>(const Duration(milliseconds: 50));
    d.run(9, (v) => fires.add(v));
    d.dispose();
    d.flush();
    expect(fires, isEmpty);
    expect(d.isDisposed, isTrue);
  });
}
