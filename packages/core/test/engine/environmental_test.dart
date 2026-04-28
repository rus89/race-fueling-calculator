// ABOUTME: Tests for environmental adjustment calculations (heat, humidity, altitude).
// ABOUTME: Verifies carb multipliers, water additions, and advisory note generation.
import 'package:race_fueling_core/src/engine/environmental.dart';
import 'package:test/test.dart';

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

    test('altitude at sea level has no carb adjustment', () {
      final adj = calculateAdjustments(altitudeM: 500);
      expect(adj.carbMultiplier, 1.0);
    });

    test('altitude above 3000m caps at 10% carb increase', () {
      final adj = calculateAdjustments(altitudeM: 4000);
      expect(adj.carbMultiplier, closeTo(1.1, 0.001));
    });

    test('moderate conditions have mild adjustments', () {
      final adj = calculateAdjustments(temperature: 22, humidity: 50);
      expect(adj.additionalWaterMlPerSlot, 0.0);
      expect(adj.carbMultiplier, 1.0);
    });

    test('marginal heat (27 °C) barely enters caution zone', () {
      // 27°C = 80.6°F / 50% → HI ≈ actual temp (barely above 80°F threshold)
      final adj = calculateAdjustments(temperature: 27, humidity: 50);
      // Should be just at the Caution boundary with at least 50ml water
      expect(adj.additionalWaterMlPerSlot, greaterThanOrEqualTo(50));
      expect(
        adj.advisories.any((a) => a.contains('Warm conditions')),
        true,
      );
    });

    test('Danger zone returns only the Danger advisory (exclusive)', () {
      // 35°C (95°F), 70% RH → Rothfusz HI ≈ 122.6°F (50.3°C)
      // This is in the Danger zone (39–52°C)
      final adj = calculateAdjustments(temperature: 35, humidity: 70);
      // Water still accumulates: Caution (50) + Extreme Caution (50) + Danger
      // (50) = 150ml
      expect(adj.additionalWaterMlPerSlot, 150.0);
      expect(
        adj.advisories.any((a) => a.contains('Dangerous heat')),
        true,
      );
      // Lower-zone advisories must NOT appear at Danger
      expect(
        adj.advisories.any((a) => a.contains('Warm conditions')),
        false,
      );
      expect(
        adj.advisories.any((a) => a.contains('High heat stress')),
        false,
      );
    });

    test('Extreme Danger zone returns only the Extreme Danger advisory', () {
      // 40°C (104°F), 85% RH → Rothfusz HI well above 52°C
      final adj = calculateAdjustments(temperature: 40, humidity: 85);
      expect(adj.additionalWaterMlPerSlot, 150.0);
      expect(
        adj.advisories.any((a) => a.contains('EXTREME DANGER')),
        true,
      );
      expect(
        adj.advisories.any((a) => a.contains('Warm conditions')),
        false,
      );
      expect(
        adj.advisories.any((a) => a.contains('High heat stress')),
        false,
      );
      expect(
        adj.advisories.any((a) => a.contains('Dangerous heat')),
        false,
      );
    });

    test('extreme heat gives strongest advisory', () {
      // 40°C (104°F), 85% RH → Rothfusz HI will be very high, likely Danger+
      final adj = calculateAdjustments(temperature: 40, humidity: 85);
      expect(adj.additionalWaterMlPerSlot, greaterThan(100));
      expect(adj.advisories.any((a) => a.contains('EXTREME DANGER')), true);
    });

    test('dry heat produces milder advisories than humid heat', () {
      // 38°C (100°F), 20% RH → Rothfusz with Adjustment A (RH < 13%) doesn't
      // apply since RH=20 > 13. But HI should be relatively moderate.
      final dryAdj = calculateAdjustments(temperature: 38, humidity: 20);
      final humidAdj = calculateAdjustments(temperature: 38, humidity: 80);
      // Lower humidity should have lower water addition
      expect(dryAdj.additionalWaterMlPerSlot,
          lessThanOrEqualTo(humidAdj.additionalWaterMlPerSlot));
    });

    test('low humidity adjustment subtracts from HI when applicable', () {
      // 32.2°C (90°F), 10% RH → Adjustment A applies (RH < 13%, temp 80-112)
      // The adj = ((13-10)/4) * sqrt((17-|90-95|)/17) = 0.75 * sqrt(12/17)
      // = 0.75 * 0.840 = 0.630
      final adj = calculateAdjustments(temperature: 32.2, humidity: 10);
      // Adjustment A reduces HI but we still enter Extreme Caution → 100ml
      expect(adj.additionalWaterMlPerSlot, greaterThanOrEqualTo(50));
      expect(adj.advisories, isNotEmpty);
      // Should include the heat index summary line
      expect(
        adj.advisories.any((a) => a.contains('Heat index')),
        true,
      );
    });

    test('humidity defaults to 50% when not provided', () {
      // 35°C with no humidity should use 50% default
      final adj = calculateAdjustments(temperature: 35);
      expect(adj.advisories, isNotEmpty);
      expect(adj.additionalWaterMlPerSlot, greaterThan(0));
    });

    test('advisory includes heat index value', () {
      final adj = calculateAdjustments(temperature: 35, humidity: 60);
      final hasIndex = adj.advisories
          .any((a) => a.contains('Heat index') && a.contains('°C'));
      expect(hasIndex, true);
    });

    test('combined altitude and heat produce both adjustments', () {
      final adj = calculateAdjustments(
        temperature: 35,
        humidity: 60,
        altitudeM: 2500,
      );
      expect(adj.carbMultiplier, greaterThan(1.0));
      expect(adj.additionalWaterMlPerSlot, greaterThan(0));
      expect(
        adj.advisories.where((a) => a.contains('altitude')).length,
        1,
      );
      expect(
        adj.advisories.where((a) => a.contains('Heat index')).length,
        1,
      );
    });

    test('cool conditions produce no heat advisories', () {
      // 15°C, well below 26.7°C Rothfusz threshold
      final adj = calculateAdjustments(temperature: 15, humidity: 80);
      expect(adj.additionalWaterMlPerSlot, 0.0);
      expect(adj.carbMultiplier, 1.0);
    });

    test('Rothfusz regression gives known output at reference point', () {
      // At 32°C (89.6°F) / 50% RH, the Rothfusz regression produces
      // HI ≈ 33°C which falls in Extreme Caution zone → 100ml water.
      // The well-known NOAA reference: at 90°F/50%, HI is noticeably higher.
      final adj = calculateAdjustments(temperature: 32, humidity: 50);
      // Extreme Caution zone: Caution (50) + Extreme Caution (50) = 100ml
      expect(adj.additionalWaterMlPerSlot, greaterThanOrEqualTo(100));
      expect(
        adj.advisories.any((a) => a.contains('High heat stress')),
        true,
      );
    });

    test('high humidity triggers Adjustment B (Rothfusz)', () {
      // 28°C (82.4°F), 90% RH → falls in Adjustment B window (RH > 85%,
      // temp 80–87°F). Without Adjustment B the base Rothfusz HI ≈ 33.75°C;
      // with Adjustment B the contribution is +0.46°F (+0.26°C), giving
      // HI ≈ 34.00°C. Asserting closeTo(34.0, 0.1) would fail (reading
      // ~33.7°C) if Adjustment B were removed.
      final adj = calculateAdjustments(temperature: 28, humidity: 90);
      expect(adj.advisories, isNotEmpty);
      expect(adj.additionalWaterMlPerSlot, greaterThanOrEqualTo(50));

      final summary = adj.advisories.firstWhere(
        (a) => a.contains('Heat index'),
        orElse: () => '',
      );
      expect(summary, isNotEmpty,
          reason: 'expected a "Heat index: …°C (…°F)" summary advisory');

      // Parse the °C value from a string like 'Heat index: 34.0°C (93°F)'.
      final match = RegExp(r'Heat index:\s*([\d.]+)°C').firstMatch(summary);
      expect(match, isNotNull,
          reason: 'could not parse °C from advisory: $summary');
      final hiCelsius = double.parse(match!.group(1)!);
      expect(hiCelsius, closeTo(34.0, 0.1));
    });
  });
}
