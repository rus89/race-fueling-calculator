// ABOUTME: CLI integration test covering storage round-trip, engine output, and formatters.
// ABOUTME: Uses a temp dir; complements the subprocess e2e test in test/e2e/.
import 'dart:io';
import 'package:test/test.dart';
import 'package:race_fueling_core/core.dart';
import 'package:race_fueling_cli/src/storage/file_storage_adapter.dart';
import 'package:race_fueling_cli/src/formatting/plan_table.dart';
import 'package:race_fueling_cli/src/formatting/summary_block.dart';

void main() {
  late Directory tempDir;
  late FileStorageAdapter storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fuel_integration_');
    storage = FileStorageAdapter(baseDir: tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('full workflow: profile → plan → products → generate', () async {
    // 1. Setup profile
    final profile = AthleteProfile(
      gutToleranceGPerHr: 80.0,
      unitSystem: UnitSystem.metric,
      bodyWeightKg: 72.0,
    );
    await storage.saveProfile(profile);

    // 2. Create plan
    final config = RaceConfig(
      name: 'XCM Test Race',
      duration: Duration(hours: 4),
      distanceKm: 80.0,
      timelineMode: TimelineMode.timeBased,
      intervalMinutes: 20,
      targetCarbsGPerHr: 75.0,
      strategy: Strategy.steady,
      selectedProducts: [
        ProductSelection(productId: 'maurten-gel-100', quantity: 8),
        ProductSelection(productId: 'maurten-320', quantity: 2),
      ],
      temperature: 28.0,
      altitudeM: 1800.0,
    );
    await storage.savePlan('xcm-test', config);

    // 3. Load and generate
    final loaded = await storage.loadPlan('xcm-test');
    expect(loaded, isNotNull);

    final loadedProfile = await storage.loadProfile();
    expect(loadedProfile, isNotNull);

    final allProducts = mergeProducts(builtInProducts, []);
    final plan = generatePlan(loaded!, loadedProfile!, allProducts);

    // 4. Verify plan
    expect(plan.entries, isNotEmpty);
    expect(plan.entries.length, 12); // 240min / 20min
    expect(plan.summary.totalCarbs, greaterThan(0));
    expect(plan.summary.averageGPerHr, greaterThan(0));
    expect(plan.summary.environmentalNotes, isNotEmpty); // altitude

    // 5. Verify formatting doesn't crash
    final table = formatPlanTable(plan, useColor: false);
    expect(table, isNotEmpty);
    expect(table, contains('Maurten'));

    final summary = formatSummaryBlock(plan, useColor: false);
    expect(summary, isNotEmpty);
    expect(summary, contains('SUMMARY'));
  });
}
