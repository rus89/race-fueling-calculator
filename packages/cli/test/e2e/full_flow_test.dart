// ABOUTME: Subprocess end-to-end test for `fuel plan generate` no-color paths.
// ABOUTME: Uses FUEL_HOME override + temp dir to avoid polluting ~/.race-fueling/.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  // Resolve packages/cli root regardless of where `dart test` is invoked.
  // `Directory.current` is the package root when invoked from inside
  // packages/cli, and the workspace root when invoked from the repo root.
  final cwd = Directory.current.path;
  final packageRoot =
      p.basename(cwd) == 'cli' && p.basename(p.dirname(cwd)) == 'packages'
          ? cwd
          : p.join(cwd, 'packages', 'cli');

  late Directory tempHome;

  setUp(() {
    tempHome = Directory.systemTemp.createTempSync('fuel-e2e-');
  });

  tearDown(() {
    if (tempHome.existsSync()) {
      tempHome.deleteSync(recursive: true);
    }
  });

  Future<ProcessResult> runFuel(
    List<String> args, {
    Map<String, String> extraEnv = const {},
  }) {
    return Process.run(
      Platform.resolvedExecutable,
      ['run', 'bin/fuel.dart', ...args],
      workingDirectory: packageRoot,
      environment: {
        'FUEL_HOME': tempHome.path,
        ...extraEnv,
      },
    );
  }

  Future<void> seedPlan() async {
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
  }

  void expectNoColorOutputContract(String stdout) {
    expect(stdout, contains('=== SUMMARY ==='));
    expect(stdout.contains('\x1B'), isFalse, reason: 'no ANSI escapes');
    expect(stdout.contains('│'), isFalse,
        reason: 'no Unicode box-drawing under no-color');
    expect(stdout.contains('─'), isFalse,
        reason: 'no Unicode divider under no-color');
    expect(stdout.contains('═'), isFalse,
        reason: 'no Unicode banner under no-color');
    expect(stdout.contains('\r'), isFalse, reason: 'LF line endings only');
  }

  test('plan generate --no-color emits ASCII summary and zero ANSI escapes',
      () async {
    await seedPlan();

    final gen = await runFuel(
      ['plan', 'generate', '--plan', 'e2e', '--no-color'],
    );

    expect(gen.exitCode, 0, reason: gen.stderr.toString());
    expectNoColorOutputContract(gen.stdout.toString());
  });

  test('plan generate honors NO_COLOR=1 env var without --no-color flag',
      () async {
    await seedPlan();

    final gen = await runFuel(
      ['plan', 'generate', '--plan', 'e2e'],
      extraEnv: {'NO_COLOR': '1'},
    );

    expect(gen.exitCode, 0, reason: gen.stderr.toString());
    expectNoColorOutputContract(gen.stdout.toString());
  });
}
