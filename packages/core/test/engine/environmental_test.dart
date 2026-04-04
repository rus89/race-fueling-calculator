// ABOUTME: Tests for environmental adjustment calculations (heat, humidity, altitude).
// ABOUTME: Verifies carb multipliers, water additions, and advisory note generation.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/engine/environmental.dart';

void main() {
  group('calculateAdjustments', () {
    test('no conditions returns neutral adjustments', () {
      final adj = calculateAdjustments();
      expect(adj.carbMultiplier, 1.0);
      expect(adj.additionalWaterMlPerSlot, 0.0);
      expect(adj.advisories, isEmpty);
    });

    test('altitude >1500m increases carb target', () {
      final adj = calculateAdjustments(altitudeM: 2000);
      expect(adj.carbMultiplier, greaterThan(1.0));
      expect(adj.carbMultiplier, lessThanOrEqualTo(1.1));
      expect(adj.advisories, contains(contains('altitude')));
    });

    test('high temperature increases water recommendation', () {
      final adj = calculateAdjustments(temperature: 35, humidity: 70);
      expect(adj.additionalWaterMlPerSlot, greaterThan(0));
      expect(adj.advisories, isNotEmpty);
    });

    test('moderate conditions have mild adjustments', () {
      final adj = calculateAdjustments(temperature: 22, humidity: 50);
      expect(adj.additionalWaterMlPerSlot, 0.0);
      expect(adj.carbMultiplier, 1.0);
    });

    test('extreme heat gives strongest advisory', () {
      final adj = calculateAdjustments(temperature: 40, humidity: 85);
      expect(adj.additionalWaterMlPerSlot, greaterThan(50));
      expect(adj.advisories.any((a) => a.contains('drink mix')), true);
    });
  });
}
