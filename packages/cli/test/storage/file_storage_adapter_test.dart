// ABOUTME: Tests for FileStorageAdapter reading and writing JSON to a temp directory.
// ABOUTME: Covers profile, product list, and plan persistence with real file I/O.
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:race_fueling_cli/src/storage/file_storage_adapter.dart';
import 'package:race_fueling_core/core.dart';

void main() {
  late Directory tempDir;
  late FileStorageAdapter adapter;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('race_fueling_test_');
    adapter = FileStorageAdapter(baseDir: tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FileStorageAdapter', () {
    test('loadProfile returns null when no file exists', () async {
      final profile = await adapter.loadProfile();
      expect(profile, isNull);
    });

    test('saveProfile then loadProfile round-trips', () async {
      final profile = AthleteProfile(
        gutToleranceGPerHr: 75.0,
        unitSystem: UnitSystem.metric,
        bodyWeightKg: 70.0,
      );
      await adapter.saveProfile(profile);
      final loaded = await adapter.loadProfile();
      expect(loaded, isNotNull);
      expect(loaded!.gutToleranceGPerHr, 75.0);
      expect(loaded.unitSystem, UnitSystem.metric);
    });

    test('saveUserProducts then loadUserProducts round-trips', () async {
      final products = [
        Product(
          id: 'custom-1',
          name: 'My Gel',
          type: ProductType.gel,
          carbsPerServing: 30,
        ),
      ];
      await adapter.saveUserProducts(products);
      final loaded = await adapter.loadUserProducts();
      expect(loaded.length, 1);
      expect(loaded[0].name, 'My Gel');
    });

    test('loadUserProducts returns empty list when no file', () async {
      final products = await adapter.loadUserProducts();
      expect(products, isEmpty);
    });

    test('loadUserProducts throws on future schema version', () async {
      final file = File(p.join(tempDir.path, 'products.json'));
      await file.writeAsString('{"schema_version": 999, "products": []}');
      await expectLater(
        adapter.loadUserProducts(),
        throwsA(isA<SchemaVersionException>()),
      );
    });

    test('savePlan then loadPlan round-trips', () async {
      final config = RaceConfig(
        name: 'Test Race',
        duration: Duration(hours: 3),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 70.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );
      await adapter.savePlan('test-race', config);
      final loaded = await adapter.loadPlan('test-race');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Test Race');
    });

    test('loadPlan returns null for missing plan', () async {
      final loaded = await adapter.loadPlan('does-not-exist');
      expect(loaded, isNull);
    });

    test('listPlans returns saved plan names', () async {
      final config = RaceConfig(
        name: 'Race 1',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );
      await adapter.savePlan('race-1', config);
      await adapter.savePlan('race-2', config);
      final names = await adapter.listPlans();
      expect(names, containsAll(['race-1', 'race-2']));
    });

    test('deletePlan removes the plan', () async {
      final config = RaceConfig(
        name: 'Delete Me',
        duration: Duration(hours: 1),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );
      await adapter.savePlan('delete-me', config);
      await adapter.deletePlan('delete-me');
      final loaded = await adapter.loadPlan('delete-me');
      expect(loaded, isNull);
    });
  });
}
