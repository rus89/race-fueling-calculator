// ABOUTME: Tests for RaceConfig and supporting types (Strategy, TimelineMode, AidStation, etc.).
// ABOUTME: Covers construction, serialization, and required vs. optional field validation.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/models/race_config.dart';

void main() {
  group('RaceConfig', () {
    test('creates time-based config with steady strategy', () {
      final config = RaceConfig(
        name: 'Test Race',
        duration: Duration(hours: 3),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 80.0,
        strategy: Strategy.steady,
        selectedProducts: [
          ProductSelection(productId: 'gel-1', quantity: 6),
        ],
      );
      expect(config.name, 'Test Race');
      expect(config.intervalMinutes, 20);
      expect(config.distanceKm, isNull);
      expect(config.aidStations, isEmpty);
    });

    test('creates distance-based config with aid stations', () {
      final config = RaceConfig(
        name: 'XCM Race',
        duration: Duration(hours: 5),
        distanceKm: 100.0,
        timelineMode: TimelineMode.distanceBased,
        intervalKm: 10.0,
        targetCarbsGPerHr: 75.0,
        strategy: Strategy.frontLoad,
        selectedProducts: [],
        aidStations: [
          AidStation(distanceKm: 40.0, timeMinutes: null),
          AidStation(distanceKm: 70.0, timeMinutes: null),
        ],
      );
      expect(config.aidStations.length, 2);
    });

    test('custom strategy requires customCurve', () {
      final config = RaceConfig(
        name: 'Custom',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.custom,
        selectedProducts: [],
        customCurve: [
          CurveSegment(durationMinutes: 60, targetGPerHr: 80.0),
          CurveSegment(durationMinutes: 60, targetGPerHr: 50.0),
        ],
      );
      expect(config.customCurve!.length, 2);
    });

    test('ProductSelection supports aid-station flag', () {
      final ps = ProductSelection(
        productId: 'bottle-1',
        quantity: 2,
        isAidStationOnly: true,
      );
      expect(ps.isAidStationOnly, true);
    });

    test('JSON round-trip', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 2, minutes: 30),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 15,
        targetCarbsGPerHr: 70.0,
        strategy: Strategy.steady,
        selectedProducts: [
          ProductSelection(productId: 'gel-1', quantity: 8),
        ],
        temperature: 28.0,
        humidity: 65.0,
        altitudeM: 2000.0,
      );
      final json = config.toJson();
      expect(json['schema_version'], 1);
      final restored = RaceConfig.fromJson(json);
      expect(restored, equals(config));
    });

    test('copyWith with no args returns an equal instance', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 80.0,
        strategy: Strategy.steady,
        selectedProducts: [
          ProductSelection(productId: 'gel-1', quantity: 6),
        ],
      );
      expect(config.copyWith(), equals(config));
    });

    test('copyWith appends a ProductSelection', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 80.0,
        strategy: Strategy.steady,
        selectedProducts: [
          ProductSelection(productId: 'gel-1', quantity: 6),
        ],
      );
      final updated = config.copyWith(
        selectedProducts: [
          ...config.selectedProducts,
          ProductSelection(productId: 'gel-2', quantity: 3),
        ],
      );
      expect(updated.selectedProducts.length, 2);
      expect(updated.selectedProducts.last.productId, 'gel-2');
      expect(updated.name, 'Test');
    });

    test('copyWith preserves aidStations and nullable fields when omitted', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 5),
        distanceKm: 100.0,
        timelineMode: TimelineMode.distanceBased,
        intervalKm: 10.0,
        targetCarbsGPerHr: 75.0,
        strategy: Strategy.steady,
        selectedProducts: [],
        aidStations: [AidStation(distanceKm: 40.0)],
        altitudeM: 2000.0,
      );
      final updated = config.copyWith(targetCarbsGPerHr: 90.0);
      expect(updated.aidStations.length, 1);
      expect(updated.altitudeM, 2000.0);
      expect(updated.distanceKm, 100.0);
      expect(updated.targetCarbsGPerHr, 90.0);
    });
  });
}
