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
}
