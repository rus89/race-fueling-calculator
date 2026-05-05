// ABOUTME: Tests for FuelingPlan, PlanEntry, and PlanSummary model construction and serialization.
// ABOUTME: Verifies raceConfig round-trip, warnings attachment, and cumulative stats fields.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/models/fueling_plan.dart';
import 'package:race_fueling_core/src/models/race_config.dart';
import 'package:race_fueling_core/src/models/warning.dart';

void main() {
  group('ProductServing', () {
    test('creates correctly', () {
      final serving = ProductServing(
        productId: 'gel-1',
        productName: 'Test Gel',
        servings: 1,
      );
      expect(serving.productId, 'gel-1');
      expect(serving.servings, 1);
    });

    test('isDrinkStart defaults to false', () {
      const s = ProductServing(productId: 'x', productName: 'X', servings: 1);
      expect(s.isDrinkStart, isFalse);
    });

    test('copyWith flips the isDrinkStart flag', () {
      const s = ProductServing(productId: 'x', productName: 'X', servings: 1);
      expect(s.copyWith(isDrinkStart: true).isDrinkStart, isTrue);
    });

    test('toJson/fromJson roundtrip preserves isDrinkStart', () {
      const s = ProductServing(
        productId: 'x',
        productName: 'X',
        servings: 1,
        isDrinkStart: true,
      );
      final json = s.toJson();
      final round = ProductServing.fromJson(json);
      expect(round.isDrinkStart, isTrue);
    });

    test('fromJson defaults isDrinkStart false when key absent', () {
      const json = <String, dynamic>{
        'productId': 'x',
        'productName': 'X',
        'servings': 1,
      };
      final s = ProductServing.fromJson(json);
      expect(s.isDrinkStart, isFalse);
    });
  });

  group('PlanEntry', () {
    PlanEntry baseEntry({
      Duration timeMark = const Duration(minutes: 30),
      double? distanceMark,
      List<ProductServing> products = const [],
      double carbsGlucose = 10.0,
      double carbsFructose = 6.0,
      double carbsTotal = 16.0,
      double cumulativeCarbs = 16.0,
      double cumulativeCaffeine = 0.0,
      double waterMl = 100.0,
      List<Warning> warnings = const [],
      double effectiveDrinkCarbs = 0.0,
      AidStation? aidStation,
    }) => PlanEntry(
      timeMark: timeMark,
      distanceMark: distanceMark,
      products: products,
      carbsGlucose: carbsGlucose,
      carbsFructose: carbsFructose,
      carbsTotal: carbsTotal,
      cumulativeCarbs: cumulativeCarbs,
      cumulativeCaffeine: cumulativeCaffeine,
      waterMl: waterMl,
      warnings: warnings,
      effectiveDrinkCarbs: effectiveDrinkCarbs,
      aidStation: aidStation,
    );

    test('creates with all fields', () {
      final entry = PlanEntry(
        timeMark: Duration(minutes: 20),
        products: [
          ProductServing(productId: 'gel-1', productName: 'Gel', servings: 1),
        ],
        carbsGlucose: 20.0,
        carbsFructose: 5.0,
        carbsTotal: 25.0,
        cumulativeCarbs: 25.0,
        cumulativeCaffeine: 40.0,
        waterMl: 150.0,
      );
      expect(entry.carbsTotal, 25.0);
      expect(entry.distanceMark, isNull);
      expect(entry.warnings, isEmpty);
    });

    test('effectiveDrinkCarbs defaults to 0', () {
      final e = PlanEntry(
        timeMark: const Duration(minutes: 15),
        products: const [],
        carbsGlucose: 10,
        carbsFructose: 6,
        carbsTotal: 16,
        cumulativeCarbs: 16,
        cumulativeCaffeine: 0,
        waterMl: 100,
      );
      expect(e.effectiveDrinkCarbs, 0);
      expect(e.aidStation, isNull);
    });

    test('effectiveDrinkCarbs and aidStation round-trip through JSON', () {
      final e = PlanEntry(
        timeMark: const Duration(minutes: 90),
        products: const [],
        carbsGlucose: 8,
        carbsFructose: 5,
        carbsTotal: 13,
        cumulativeCarbs: 13,
        cumulativeCaffeine: 0,
        waterMl: 125,
        effectiveDrinkCarbs: 13,
        aidStation: const AidStation(
          timeMinutes: 90,
          refill: ['sis-beta-fuel'],
        ),
      );
      final back = PlanEntry.fromJson(e.toJson());
      expect(back.effectiveDrinkCarbs, 13);
      expect(back.aidStation?.timeMinutes, 90);
      expect(back.aidStation?.refill, ['sis-beta-fuel']);
    });

    test('copyWith preserves effectiveDrinkCarbs, aidStation, warnings', () {
      final original = PlanEntry(
        timeMark: const Duration(minutes: 90),
        products: const [],
        carbsGlucose: 8,
        carbsFructose: 5,
        carbsTotal: 13,
        cumulativeCarbs: 13,
        cumulativeCaffeine: 0,
        waterMl: 100,
        effectiveDrinkCarbs: 13,
        aidStation: const AidStation(timeMinutes: 90, refill: ['x']),
        warnings: const [Warning(severity: Severity.advisory, message: 'm')],
      );
      final updated = original.copyWith(waterMl: 250);
      expect(updated.waterMl, 250);
      expect(updated.effectiveDrinkCarbs, 13);
      expect(updated.aidStation?.timeMinutes, 90);
      expect(updated.warnings, hasLength(1));
    });

    test('copyWith with no args returns an equal instance', () {
      final e = baseEntry(
        distanceMark: 12.5,
        aidStation: const AidStation(timeMinutes: 30),
      );
      expect(e.copyWith(), equals(e));
    });

    test('copyWith updates timeMark', () {
      final e = baseEntry();
      expect(
        e.copyWith(timeMark: const Duration(minutes: 60)).timeMark,
        const Duration(minutes: 60),
      );
    });

    test('copyWith updates distanceMark', () {
      final e = baseEntry(distanceMark: 5.0);
      expect(e.copyWith(distanceMark: 10.0).distanceMark, 10.0);
    });

    test('copyWith updates products', () {
      final e = baseEntry();
      final next = e.copyWith(
        products: const [
          ProductServing(productId: 'g', productName: 'Gel', servings: 1),
        ],
      );
      expect(next.products, hasLength(1));
    });

    test('copyWith updates carbsGlucose', () {
      final e = baseEntry();
      expect(e.copyWith(carbsGlucose: 20.0).carbsGlucose, 20.0);
    });

    test('copyWith updates carbsFructose', () {
      final e = baseEntry();
      expect(e.copyWith(carbsFructose: 8.0).carbsFructose, 8.0);
    });

    test('copyWith updates carbsTotal', () {
      final e = baseEntry();
      expect(e.copyWith(carbsTotal: 30.0).carbsTotal, 30.0);
    });

    test('copyWith updates cumulativeCarbs', () {
      final e = baseEntry();
      expect(e.copyWith(cumulativeCarbs: 80.0).cumulativeCarbs, 80.0);
    });

    test('copyWith updates cumulativeCaffeine', () {
      final e = baseEntry();
      expect(e.copyWith(cumulativeCaffeine: 50.0).cumulativeCaffeine, 50.0);
    });

    test('copyWith updates waterMl', () {
      final e = baseEntry();
      expect(e.copyWith(waterMl: 250.0).waterMl, 250.0);
    });

    test('copyWith updates warnings', () {
      final e = baseEntry();
      final next = e.copyWith(
        warnings: const [Warning(severity: Severity.advisory, message: 'm')],
      );
      expect(next.warnings, hasLength(1));
    });

    test('copyWith updates effectiveDrinkCarbs', () {
      final e = baseEntry();
      expect(e.copyWith(effectiveDrinkCarbs: 13.0).effectiveDrinkCarbs, 13.0);
    });

    test('copyWith updates aidStation', () {
      final e = baseEntry();
      const station = AidStation(timeMinutes: 90, refill: ['x']);
      expect(e.copyWith(aidStation: station).aidStation?.timeMinutes, 90);
    });

    test('copyWith preserves distanceMark when null is passed explicitly', () {
      final e = baseEntry(distanceMark: 12.5);
      expect(e.copyWith(distanceMark: null).distanceMark, 12.5);
    });

    test('copyWith preserves aidStation when null is passed explicitly', () {
      const station = AidStation(timeMinutes: 60);
      final e = baseEntry(aidStation: station);
      expect(e.copyWith(aidStation: null).aidStation, station);
    });

    test('toJson omits aidStation when null (no schema noise)', () {
      final e = PlanEntry(
        timeMark: const Duration(minutes: 15),
        products: const [],
        carbsGlucose: 10,
        carbsFructose: 6,
        carbsTotal: 16,
        cumulativeCarbs: 16,
        cumulativeCaffeine: 0,
        waterMl: 100,
      );
      expect(e.toJson().containsKey('aidStation'), isFalse);
    });
  });

  group('PlanSummary', () {
    test('creates correctly', () {
      final summary = PlanSummary(
        totalCarbs: 200.0,
        averageGPerHr: 66.7,
        totalCaffeineMg: 120.0,
        glucoseFructoseRatio: 0.8,
        totalWaterMl: 1500.0,
        environmentalNotes: ['Altitude adjustment: +5%'],
      );
      expect(summary.averageGPerHr, 66.7);
    });

    test('glucoseToFructoseRatio returns 0 when fructose is 0', () {
      final summary = PlanSummary(
        totalCarbs: 100.0,
        averageGPerHr: 50.0,
        totalCaffeineMg: 0.0,
        glucoseFructoseRatio: 0.0,
        totalGlucose: 100.0,
        totalFructose: 0.0,
        totalWaterMl: 0.0,
      );
      expect(summary.glucoseToFructoseRatio, 0.0);
    });

    test(
      'glucoseToFructoseRatio returns glucose / fructose for valid case',
      () {
        final summary = PlanSummary(
          totalCarbs: 100.0,
          averageGPerHr: 50.0,
          totalCaffeineMg: 0.0,
          glucoseFructoseRatio: 0.5,
          totalGlucose: 60.0,
          totalFructose: 40.0,
          totalWaterMl: 0.0,
        );
        expect(summary.glucoseToFructoseRatio, closeTo(1.5, 1e-9));
      },
    );

    test('glucoseToFructoseRatio is the inverse of glucoseFructoseRatio', () {
      final summary = PlanSummary(
        totalCarbs: 100.0,
        averageGPerHr: 50.0,
        totalCaffeineMg: 0.0,
        glucoseFructoseRatio: 40.0 / 60.0,
        totalGlucose: 60.0,
        totalFructose: 40.0,
        totalWaterMl: 0.0,
      );
      expect(
        summary.glucoseToFructoseRatio * summary.glucoseFructoseRatio,
        closeTo(1.0, 1e-9),
      );
    });
  });

  final testConfig = RaceConfig(
    name: 'Test Race',
    duration: Duration(hours: 1),
    timelineMode: TimelineMode.timeBased,
    intervalMinutes: 20,
    targetCarbsGPerHr: 60.0,
    strategy: Strategy.steady,
    selectedProducts: [],
  );

  group('FuelingPlan', () {
    test('JSON round-trip', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          PlanEntry(
            timeMark: Duration(minutes: 20),
            products: [
              ProductServing(productId: 'g1', productName: 'Gel', servings: 1),
            ],
            carbsGlucose: 20.0,
            carbsFructose: 5.0,
            carbsTotal: 25.0,
            cumulativeCarbs: 25.0,
            cumulativeCaffeine: 0.0,
            waterMl: 100.0,
          ),
        ],
        summary: PlanSummary(
          totalCarbs: 25.0,
          averageGPerHr: 75.0,
          totalCaffeineMg: 0.0,
          glucoseFructoseRatio: 0.8,
          totalWaterMl: 100.0,
        ),
        warnings: [Warning(severity: Severity.advisory, message: 'Test')],
      );
      final json = plan.toJson();
      final restored = FuelingPlan.fromJson(json);
      expect(restored.raceConfig.name, 'Test Race');
      expect(restored.entries.length, 1);
      expect(restored.warnings.length, 1);
    });
  });
}
