// ABOUTME: Tests for the ProfileCommand — setup, show, and set subcommands
// ABOUTME: with flag paths, invariant errors, no-TTY gating, and persistence.
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:race_fueling_cli/src/cli/exit_codes.dart';
import 'package:race_fueling_cli/src/cli/runner.dart';
import 'package:race_fueling_cli/src/commands/profile_command.dart';
import 'package:race_fueling_cli/src/storage/file_storage_adapter.dart';
import 'package:race_fueling_core/core.dart';
import 'package:test/test.dart';

import '../support/capture.dart';

void main() {
  late Directory tempDir;
  late FileStorageAdapter storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('race_fueling_profile_test_');
    storage = FileStorageAdapter(baseDir: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  CommandRunner<void> buildRunner({bool isTty = false}) {
    return CommandRunner<void>('fuel', 'test')
      ..addCommand(ProfileCommand(storage, isTty: () => isTty));
  }

  group('profile setup', () {
    test('persists profile when all flags are provided', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'profile',
          'setup',
          '--tolerance',
          '75',
          '--units',
          'metric',
          '--weight',
          '70',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);

      final loaded = await storage.loadProfile();
      expect(loaded, isNotNull);
      expect(loaded!.gutToleranceGPerHr, 75.0);
      expect(loaded.unitSystem, UnitSystem.metric);
      expect(loaded.bodyWeightKg, 70.0);
    });

    test('exits kExitNoInput when a required flag is missing and no TTY',
        () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'profile',
          'setup',
          '--tolerance',
          '75',
          '--units',
          'metric',
          // no --weight; stdin in the test harness has no terminal
        ]);
      });

      expect(code, kExitNoInput);
      expect(captured.stderr, contains('TTY'));
      expect(await storage.loadProfile(), isNull);
    });

    test('rejects non-numeric --tolerance with kExitUsage', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'profile',
          'setup',
          '--tolerance',
          'abc',
          '--units',
          'metric',
          '--weight',
          '70',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('Expected a number'));
      expect(captured.stderr, contains('abc'));
      expect(await storage.loadProfile(), isNull);
    });

    test('rejects unknown --units value with kExitUsage', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'profile',
          'setup',
          '--tolerance',
          '75',
          '--units',
          'bogus',
          '--weight',
          '70',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('--units must be one of'));
      expect(await storage.loadProfile(), isNull);
    });

    test('rejects out-of-range tolerance (>200) with kExitData', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'profile',
          'setup',
          '--tolerance',
          '250',
          '--units',
          'metric',
          '--weight',
          '70',
        ]);
      });

      expect(code, kExitData);
      expect(captured.stderr, contains('gutToleranceGPerHr'));
      expect(await storage.loadProfile(), isNull);
    });

    test('persists without --weight when weight is not required', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'profile',
          'setup',
          '--tolerance',
          '75',
          '--units',
          'metric',
          '--no-weight',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);

      final loaded = await storage.loadProfile();
      expect(loaded, isNotNull);
      expect(loaded!.bodyWeightKg, isNull);
    });
  });

  group('profile show', () {
    test('reports missing profile and exits kExitData', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), ['profile', 'show']);
      });

      expect(code, kExitData);
      expect(captured.stderr, contains('No profile found'));
      expect(captured.stderr, contains('profile setup'));
    });

    test('prints all fields and config path after setup', () async {
      await storage.saveProfile(const AthleteProfile(
        gutToleranceGPerHr: 80.0,
        unitSystem: UnitSystem.imperial,
        bodyWeightKg: 68.0,
      ));

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), ['profile', 'show']);
      });

      expect(code, kExitSuccess);
      expect(captured.stdout, contains('80'));
      expect(captured.stdout, contains('imperial'));
      expect(captured.stdout, contains('68'));
      expect(captured.stdout, contains('Config file:'));
      expect(captured.stdout, contains('profile.json'));
    });
  });

  group('profile set', () {
    test('updates tolerance and preserves other fields', () async {
      await storage.saveProfile(const AthleteProfile(
        gutToleranceGPerHr: 60.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      ));

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'profile',
          'set',
          '--tolerance',
          '90',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);

      final loaded = await storage.loadProfile();
      expect(loaded!.gutToleranceGPerHr, 90.0);
      expect(loaded.unitSystem, UnitSystem.metric);
      expect(loaded.bodyWeightKg, 70.0);
    });

    test('reports missing profile and exits kExitData', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'profile',
          'set',
          '--tolerance',
          '90',
        ]);
      });

      expect(code, kExitData);
      expect(captured.stderr, contains('No profile found'));
    });
  });
}
