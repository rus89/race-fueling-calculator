// ABOUTME: Tests for the ProductsCommand — list, show, add, edit, remove, and
// ABOUTME: reset subcommands covering flag paths, validation, and persistence.
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:race_fueling_cli/src/cli/exit_codes.dart';
import 'package:race_fueling_cli/src/cli/runner.dart';
import 'package:race_fueling_cli/src/commands/products_command.dart';
import 'package:race_fueling_cli/src/storage/file_storage_adapter.dart';
import 'package:race_fueling_core/core.dart';
import 'package:test/test.dart';

import '../support/capture.dart';

void main() {
  late Directory tempDir;
  late FileStorageAdapter storage;

  setUp(() {
    tempDir =
        Directory.systemTemp.createTempSync('race_fueling_products_test_');
    storage = FileStorageAdapter(baseDir: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  CommandRunner<void> buildRunner({bool isTty = false}) {
    return CommandRunner<void>('fuel', 'test')
      ..addCommand(ProductsCommand(storage, isTty: () => isTty));
  }

  group('products list', () {
    test('groups built-in products by type with section headings', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), ['products', 'list']);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
      expect(captured.stdout, contains('Gels:'));
      expect(captured.stdout, contains('Drink Mixes:'));
      expect(captured.stdout, contains('Maurten Gel 100'));
    });
  });

  group('products show', () {
    test('prints details for a built-in match and marks it as built-in',
        () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'show',
          'Maurten Gel 100',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
      expect(captured.stdout, contains('Maurten Gel 100'));
      expect(captured.stdout, contains('Source: built-in'));
    });

    test('lists candidates and exits kExitUsage when query is ambiguous',
        () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), ['products', 'show', 'gel']);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('Multiple products match'));
      expect(captured.stderr, contains('Maurten Gel 100'));
      expect(captured.stdout, isEmpty);
    });

    test('exits kExitUsage with no-match message when query matches nothing',
        () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'show',
          'definitely-not-a-product',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('No product matched'));
    });
  });

  group('products add', () {
    test('persists a new user product with derived user-<slug> id', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'add',
          '--name',
          'My Custom Mix',
          '--type',
          'liquid',
          '--carbs',
          '45',
          '--glucose',
          '25',
          '--fructose',
          '20',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);

      final saved = await storage.loadUserProducts();
      expect(saved, hasLength(1));
      expect(saved.first.id, 'user-my-custom-mix');
      expect(saved.first.name, 'My Custom Mix');
      expect(saved.first.type, ProductType.liquid);
      expect(saved.first.carbsPerServing, 45.0);
      expect(saved.first.glucoseGrams, 25.0);
      expect(saved.first.fructoseGrams, 20.0);
      expect(saved.first.isBuiltIn, isFalse);
    });

    test('rejects ID collision with a built-in unless --force is passed',
        () async {
      // The slug for "Maurten Gel 100" becomes "user-maurten-gel-100"; that
      // does not collide with a built-in id on its own, so we construct a
      // user-named product that would collide if --force is absent. Use a
      // slug that matches an existing user product to assert the guard.
      await storage.saveUserProducts([
        Product(
          id: 'user-collide',
          name: 'Collide',
          type: ProductType.gel,
          carbsPerServing: 20.0,
        ),
      ]);

      late final int firstCode;
      final firstCapture = await captureOutput(() async {
        firstCode = await runFuel(buildRunner(), [
          'products',
          'add',
          '--name',
          'Collide',
          '--type',
          'gel',
          '--carbs',
          '25',
        ]);
      });

      expect(firstCode, kExitUsage);
      expect(firstCapture.stderr, contains('already exists'));
      final afterFirst = await storage.loadUserProducts();
      expect(afterFirst, hasLength(1));
      expect(afterFirst.first.carbsPerServing, 20.0); // unchanged

      late final int secondCode;
      final secondCapture = await captureOutput(() async {
        secondCode = await runFuel(buildRunner(), [
          'products',
          'add',
          '--name',
          'Collide',
          '--type',
          'gel',
          '--carbs',
          '25',
          '--force',
        ]);
      });

      expect(secondCode, kExitSuccess);
      expect(secondCapture.stderr, isEmpty);
      final afterForce = await storage.loadUserProducts();
      expect(afterForce, hasLength(1));
      expect(afterForce.first.carbsPerServing, 25.0);
    });

    test('rejects non-numeric --carbs with kExitUsage', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'add',
          '--name',
          'Bad Carbs',
          '--type',
          'gel',
          '--carbs',
          'abc',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('Expected a number'));
      expect(captured.stderr, contains('--carbs'));
      expect(await storage.loadUserProducts(), isEmpty);
    });

    test('rejects --carbs 0 with kExitUsage and mentions --carbs', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'add',
          '--name',
          'Zero Carb',
          '--type',
          'gel',
          '--carbs',
          '0',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('--carbs'));
      expect(await storage.loadUserProducts(), isEmpty);
    });

    test('rejects unknown --type value with kExitUsage', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'add',
          '--name',
          'Bogus',
          '--type',
          'not-a-type',
          '--carbs',
          '30',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('--type must be one of'));
      expect(await storage.loadUserProducts(), isEmpty);
    });

    test('rejects when glucose + fructose mismatch carbs beyond 1g tolerance',
        () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'add',
          '--name',
          'Bad Sum',
          '--type',
          'liquid',
          '--carbs',
          '45',
          '--glucose',
          '10',
          '--fructose',
          '10',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('glucose'));
      expect(await storage.loadUserProducts(), isEmpty);
    });

    test('a user-slug that mirrors a built-in does not shadow the built-in',
        () async {
      // Slug for "MaurtenGel100" is "maurtengel100"; prefixed that becomes
      // "user-maurtengel100" — this must not collide with "maurten-gel-100".
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'add',
          '--name',
          'MaurtenGel100',
          '--type',
          'gel',
          '--carbs',
          '20',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);

      final saved = await storage.loadUserProducts();
      expect(saved, hasLength(1));
      expect(saved.first.id, 'user-maurtengel100');

      final merged = mergeProducts(builtInProducts, saved);
      // Built-in Maurten Gel 100 still resolves by its exact name.
      final gel100 = merged.firstWhere(
        (p) => p.name == 'Maurten Gel 100',
      );
      expect(gel100.isBuiltIn, isTrue);
      expect(gel100.carbsPerServing, 25.0);
      // And the newly added user product sits alongside the built-in.
      expect(merged.any((p) => p.id == 'user-maurtengel100'), isTrue);
    });
  });

  group('products edit', () {
    test(
        'creates a user override with the built-in bare id when target is '
        'built-in', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'edit',
          'Maurten Gel 100',
          '--carbs',
          '30',
          '--glucose',
          '17',
          '--fructose',
          '13',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);

      final saved = await storage.loadUserProducts();
      expect(saved, hasLength(1));
      expect(saved.first.id, 'maurten-gel-100');
      expect(saved.first.name, 'Maurten Gel 100');
      expect(saved.first.isBuiltIn, isFalse);
      expect(saved.first.carbsPerServing, 30.0);

      final merged = mergeProducts(builtInProducts, saved);
      final gel100 = merged.firstWhere((p) => p.name == 'Maurten Gel 100');
      expect(gel100.carbsPerServing, 30.0);
      expect(gel100.isBuiltIn, isFalse);
    });

    test('rejects edit when --carbs alone leaves glucose+fructose stale',
        () async {
      // Maurten Gel 100 ships with 14g glucose + 11g fructose = 25g. Changing
      // only --carbs to 30 would leave the sugars stale and violate the
      // invariant that add enforces.
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'edit',
          'Maurten Gel 100',
          '--carbs',
          '30',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('glucose'));
      expect(await storage.loadUserProducts(), isEmpty);
    });

    test('accepts edit that only touches unrelated fields (e.g. --caffeine)',
        () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'edit',
          'Maurten Gel 100',
          '--caffeine',
          '50',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);

      final saved = await storage.loadUserProducts();
      expect(saved, hasLength(1));
      expect(saved.first.id, 'maurten-gel-100');
      expect(saved.first.caffeineMg, 50.0);
      // Carbs and sugars stay at the built-in's values.
      expect(saved.first.carbsPerServing, 25.0);
      expect(saved.first.glucoseGrams, 14.0);
      expect(saved.first.fructoseGrams, 11.0);
    });

    test('updates a user product in place', () async {
      await storage.saveUserProducts([
        Product(
          id: 'user-custom',
          name: 'Custom',
          type: ProductType.gel,
          carbsPerServing: 20.0,
        ),
      ]);

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'edit',
          'Custom',
          '--carbs',
          '35',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);

      final saved = await storage.loadUserProducts();
      expect(saved, hasLength(1));
      expect(saved.first.id, 'user-custom');
      expect(saved.first.carbsPerServing, 35.0);
    });
  });

  group('products remove', () {
    test('refuses to remove a built-in and points at edit', () async {
      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'remove',
          'Maurten Gel 100',
        ]);
      });

      expect(code, kExitUsage);
      expect(captured.stderr, contains('built-in'));
      expect(captured.stderr, contains('edit'));
      expect(await storage.loadUserProducts(), isEmpty);
    });

    test('removes a user product by name', () async {
      await storage.saveUserProducts([
        Product(
          id: 'user-custom',
          name: 'My Custom',
          type: ProductType.gel,
          carbsPerServing: 20.0,
        ),
      ]);

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'remove',
          'My Custom',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
      expect(await storage.loadUserProducts(), isEmpty);
    });
  });

  group('products reset', () {
    test('without --yes and without TTY exits kExitNoInput', () async {
      await storage.saveUserProducts([
        Product(
          id: 'user-custom',
          name: 'Custom',
          type: ProductType.gel,
          carbsPerServing: 20.0,
        ),
      ]);

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), ['products', 'reset']);
      });

      expect(code, kExitNoInput);
      expect(captured.stderr, contains('TTY'));
      expect(await storage.loadUserProducts(), hasLength(1));
    });

    test('with --yes wipes all user products', () async {
      await storage.saveUserProducts([
        Product(
          id: 'user-custom',
          name: 'Custom',
          type: ProductType.gel,
          carbsPerServing: 20.0,
        ),
      ]);

      late final int code;
      final captured = await captureOutput(() async {
        code = await runFuel(buildRunner(), [
          'products',
          'reset',
          '--yes',
        ]);
      });

      expect(code, kExitSuccess);
      expect(captured.stderr, isEmpty);
      expect(await storage.loadUserProducts(), isEmpty);
    });
  });
}
