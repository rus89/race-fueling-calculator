// ABOUTME: Tests for the PlanCommand — create, list, show, delete, products,
// ABOUTME: and generate subcommands covering flag validation and persistence.
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:race_fueling_cli/src/cli/exit_codes.dart';
import 'package:race_fueling_cli/src/cli/runner.dart';
import 'package:race_fueling_cli/src/commands/plan_command.dart';
import 'package:race_fueling_cli/src/storage/file_storage_adapter.dart';
import 'package:race_fueling_core/core.dart';
import 'package:test/test.dart';

import '../support/capture.dart';

void main() {
  late Directory tempDir;
  late FileStorageAdapter storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('race_fueling_plan_test_');
    storage = FileStorageAdapter(baseDir: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  CommandRunner<void> buildRunner({
    bool isTty = false,
    String? Function()? readLine,
  }) {
    return CommandRunner<void>('fuel', 'test')
      ..addCommand(
        PlanCommand(storage, isTty: () => isTty, readLine: readLine),
      );
  }

  Future<void> seedProfile({double? weightKg = 70.0}) async {
    await storage.saveProfile(AthleteProfile(
      gutToleranceGPerHr: 85.0,
      unitSystem: UnitSystem.metric,
      bodyWeightKg: weightKg,
    ));
  }

  group('plan create', () {
    test('persists a plan with the expected slug and defaults', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h30m',
          '--target',
          '75',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
      expect(captured.stdout, contains('Plan "foo" created.'));
      expect(captured.stdout, contains('fuel plan products add'));

      final loaded = await storage.loadPlan('foo');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Foo');
      expect(loaded.duration, const Duration(hours: 3, minutes: 30));
      expect(loaded.targetCarbsGPerHr, 75.0);
      expect(loaded.strategy, Strategy.steady);
      expect(loaded.timelineMode, TimelineMode.timeBased);
      expect(loaded.selectedProducts, isEmpty);
    });

    test('rejects unparseable --duration with kExitUsage', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          'banana',
          '--target',
          '75',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('--duration'));
      expect(await storage.listPlans(), isEmpty);
    });

    test('rejects --target 0 with kExitUsage and mentions --target', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '0',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('--target'));
      expect(captured.stderr, contains('positive'));
      expect(await storage.listPlans(), isEmpty);
    });

    test('rejects --interval 0 in time mode with kExitUsage', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
          '--interval',
          '0',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('--interval'));
      expect(captured.stderr, contains('positive'));
    });

    test('rejects --distance 0 in distance mode with kExitUsage', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
          '--mode',
          'distance',
          '--distance',
          '0',
          '--interval-km',
          '10',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('--distance'));
      expect(captured.stderr, contains('positive'));
    });

    test('rejects --interval-km 0 in distance mode with kExitUsage', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
          '--mode',
          'distance',
          '--distance',
          '100',
          '--interval-km',
          '0',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('--interval-km'));
      expect(captured.stderr, contains('positive'));
    });

    test('rejects unknown --strategy with UsageException listing valid values',
        () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
          '--strategy',
          'zzz',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('--strategy must be one of'));
      expect(captured.stderr, contains('steady'));
      expect(captured.stderr, contains('front-load'));
      expect(captured.stderr, contains('back-load'));
    });

    test('rejects --strategy custom with CLI-unsupported UsageException',
        () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
          '--strategy',
          'custom',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('custom'));
      expect(captured.stderr, contains('steady'));
    });

    test('rejects unknown --mode with UsageException listing valid modes',
        () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
          '--mode',
          'zzz',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('--mode must be one of'));
      expect(captured.stderr, contains('time'));
      expect(captured.stderr, contains('distance'));
    });

    test('slug collision without --force rejects; with --force overwrites',
        () async {
      // First create succeeds.
      await captureOutput(() async {
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
        ]);
      });
      expect(await storage.listPlans(), contains('foo'));

      // Second create without --force must reject.
      late final int secondCode;
      final secondCapture = await captureOutput(() async {
        secondCode = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '4h',
          '--target',
          '80',
        ]);
      });

      expect(secondCode, kExitUsage);
      expect(secondCapture.stderr, contains('already exists'));
      expect(secondCapture.stderr, contains('--force'));

      final afterReject = await storage.loadPlan('foo');
      expect(afterReject!.duration, const Duration(hours: 3));
      expect(afterReject.targetCarbsGPerHr, 75.0);

      // Third create with --force overwrites.
      late final int thirdCode;
      final thirdCapture = await captureOutput(() async {
        thirdCode = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '4h',
          '--target',
          '80',
          '--force',
        ]);
      });

      expect(thirdCode, kExitSuccess);
      expect(thirdCapture.stderr, isEmpty);

      final afterForce = await storage.loadPlan('foo');
      expect(afterForce!.duration, const Duration(hours: 4));
      expect(afterForce.targetCarbsGPerHr, 80.0);
    });

    test('missing --name with no TTY exits kExitNoInput naming --name',
        () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'create',
          '--duration',
          '3h',
          '--target',
          '75',
        ]);
      });

      expect(code, kExitNoInput);
      expect(captured.stderr, contains('--name'));
      expect(await storage.listPlans(), isEmpty);
    });

    test(
        'with all required flags on a TTY takes the non-interactive path '
        'and does not prompt', () async {
      // readLine would return null immediately on read, so if the command
      // attempted to prompt we would see kExitNoInput. Success here proves
      // no prompt was issued.
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(
          buildRunner(isTty: true, readLine: () => null),
          [
            'plan',
            'create',
            '--name',
            'Foo',
            '--duration',
            '3h',
            '--target',
            '75',
          ],
        );
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
      expect(await storage.listPlans(), contains('foo'));
    });

    test(
        'missing --name on a TTY prompts and succeeds when a name is piped '
        'on stdin', () async {
      final responses = <String?>['Foo'];
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(
          buildRunner(
            isTty: true,
            readLine: () => responses.isEmpty ? null : responses.removeAt(0),
          ),
          [
            'plan',
            'create',
            '--duration',
            '3h',
            '--target',
            '75',
          ],
        );
      });

      expect(code, kExitSuccess);
      expect(captured.stdout, contains('Plan "foo" created.'));
      final loaded = await storage.loadPlan('foo');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Foo');
    });
  });

  group('plan list', () {
    test('prints saved plan names one per line on stdout', () async {
      await captureOutput(() async {
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Alpha',
          '--duration',
          '3h',
          '--target',
          '75',
        ]);
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Beta',
          '--duration',
          '4h',
          '--target',
          '70',
        ]);
      });

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), ['plan', 'list']);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
      expect(captured.stdout, contains('alpha'));
      expect(captured.stdout, contains('beta'));
    });

    test('with no saved plans prints "No saved plans" to stdout', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), ['plan', 'list']);
      });

      expect(code, kExitSuccess);
      expect(captured.stdout, contains('No saved plans'));
    });
  });

  group('plan show', () {
    test('prints all config fields for an existing plan', () async {
      await captureOutput(() async {
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h30m',
          '--target',
          '75',
        ]);
      });

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), ['plan', 'show', 'foo']);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
      expect(captured.stdout, contains('Foo'));
      expect(captured.stdout, contains('3h30m'));
      expect(captured.stdout, contains('75'));
      expect(captured.stdout, contains('steady'));
    });

    test('missing plan exits kExitUsage with "Plan not found"', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), ['plan', 'show', 'nonexistent']);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('Plan not found'));
    });
  });

  group('plan delete', () {
    test('without --yes and no TTY exits kExitNoInput', () async {
      await captureOutput(() async {
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
        ]);
      });

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), ['plan', 'delete', 'foo']);
      });

      expect(code, kExitNoInput);
      expect(captured.stderr, contains('TTY'));
      expect(await storage.listPlans(), contains('foo'));
    });

    test('with --yes deletes and prints confirmation', () async {
      await captureOutput(() async {
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
        ]);
      });

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'delete',
          'foo',
          '--yes',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
      expect(captured.stdout, contains('Deleted plan "foo".'));
      expect(await storage.listPlans(), isEmpty);
    });

    test('not-found exits kExitUsage', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'delete',
          'nonexistent',
          '--yes',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('Plan not found'));
    });
  });

  group('plan products add', () {
    test('missing plan exits kExitUsage with "Plan not found"', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'products',
          'add',
          'Maurten Gel 100',
          '--plan',
          'nonexistent',
          '--quantity',
          '5',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('Plan not found'));
    });

    test('ambiguous product query lists candidates and exits kExitUsage',
        () async {
      await captureOutput(() async {
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
        ]);
      });

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'products',
          'add',
          'Gel',
          '--plan',
          'foo',
          '--quantity',
          '5',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('Did you mean one of:'));
      expect(captured.stderr, contains('Maurten Gel 100'));
      expect(
        captured.stderr,
        contains('Re-run with the exact name in quotes.'),
      );
      expect(captured.stdout, isEmpty);
    });

    test('persists a ProductSelection with the built-in id and quantity',
        () async {
      await captureOutput(() async {
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
        ]);
      });

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'products',
          'add',
          'Maurten Gel 100',
          '--plan',
          'foo',
          '--quantity',
          '5',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
      expect(
        captured.stdout,
        contains('Added Maurten Gel 100 x5 to plan "foo".'),
      );

      final loaded = await storage.loadPlan('foo');
      expect(loaded!.selectedProducts, hasLength(1));
      expect(loaded.selectedProducts.first.productId, 'maurten-gel-100');
      expect(loaded.selectedProducts.first.quantity, 5);
    });
  });

  group('plan products list', () {
    test('on empty plan prints "No products in plan" to stdout', () async {
      await captureOutput(() async {
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
        ]);
      });

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'products',
          'list',
          '--plan',
          'foo',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
      expect(captured.stdout, contains('No products in plan'));
    });

    test('on populated plan prints each entry with name and quantity',
        () async {
      await captureOutput(() async {
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '3h',
          '--target',
          '75',
        ]);
        await runFuel(buildRunner(), [
          'plan',
          'products',
          'add',
          'Maurten Gel 100',
          '--plan',
          'foo',
          '--quantity',
          '5',
        ]);
      });

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'products',
          'list',
          '--plan',
          'foo',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stdout, contains('Maurten Gel 100'));
      expect(captured.stdout, contains('5'));
    });
  });

  group('plan generate', () {
    test('emits plan text to stdout with a seeded profile and products',
        () async {
      await seedProfile();
      await captureOutput(() async {
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '2h',
          '--target',
          '75',
          '--interval',
          '30',
        ]);
        await runFuel(buildRunner(), [
          'plan',
          'products',
          'add',
          'Maurten Gel 100',
          '--plan',
          'foo',
          '--quantity',
          '10',
        ]);
      });

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'generate',
          '--plan',
          'foo',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stdout, isNotEmpty);
      // Plan text should reference the product at some time point.
      expect(captured.stdout, contains('Maurten Gel 100'));
    });

    test(
        'emits caffeine advisory to stderr when bodyWeightKg is null and a '
        'selected product has caffeine', () async {
      await seedProfile(weightKg: null);
      await captureOutput(() async {
        await runFuel(buildRunner(), [
          'plan',
          'create',
          '--name',
          'Foo',
          '--duration',
          '2h',
          '--target',
          '75',
          '--interval',
          '30',
        ]);
        await runFuel(buildRunner(), [
          'plan',
          'products',
          'add',
          'Maurten Gel 100 CAF 100',
          '--plan',
          'foo',
          '--quantity',
          '5',
        ]);
      });

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'plan',
          'generate',
          '--plan',
          'foo',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, contains('caffeine'));
      expect(captured.stderr, contains('bodyWeightKg'));
      // Plan still generates to stdout.
      expect(captured.stdout, isNotEmpty);
    });
  });
}
