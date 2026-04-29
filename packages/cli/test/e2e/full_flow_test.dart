// ABOUTME: Subprocess end-to-end test for `fuel plan generate --no-color`.
// ABOUTME: Uses FUEL_HOME override + temp dir to avoid polluting ~/.race-fueling/.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory tempHome;

  setUp(() {
    tempHome = Directory.systemTemp.createTempSync('fuel-e2e-');
  });

  tearDown(() {
    if (tempHome.existsSync()) {
      tempHome.deleteSync(recursive: true);
    }
  });

  Future<ProcessResult> runFuel(List<String> args) {
    return Process.run(
      Platform.resolvedExecutable,
      ['run', 'bin/fuel.dart', ...args],
      environment: {'FUEL_HOME': tempHome.path, 'NO_COLOR': ''},
    );
  }

  test('plan generate --no-color emits ASCII summary and zero ANSI escapes',
      () async {
    final setup = await runFuel([
      'profile',
      'setup',
      '--tolerance',
      '90',
      '--units',
      'metric',
      '--weight',
      '75',
    ]);
    expect(setup.exitCode, 0, reason: setup.stderr.toString());

    final create = await runFuel([
      'plan',
      'create',
      '--name',
      'e2e',
      '--duration',
      '2h',
      '--target',
      '75',
      '--interval',
      '30',
    ]);
    expect(create.exitCode, 0, reason: create.stderr.toString());

    final add = await runFuel([
      'plan',
      'products',
      'add',
      'Maurten Gel 100',
      '--plan',
      'e2e',
      '--quantity',
      '8',
    ]);
    expect(add.exitCode, 0, reason: add.stderr.toString());

    final gen = await runFuel(
      ['plan', 'generate', '--plan', 'e2e', '--no-color'],
    );

    expect(gen.exitCode, 0, reason: gen.stderr.toString());
    final out = gen.stdout.toString();
    expect(out, contains('=== SUMMARY ==='));
    expect(out.contains('\x1B'), isFalse);
  });
}
