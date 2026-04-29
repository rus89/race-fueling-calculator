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

    test('1000m below threshold: no boost, no advisory', () {
      final adj = calculateAdjustments(altitudeM: 1000);
      expect(adj.carbMultiplier, 1.0);
      expect(adj.advisories, isEmpty);
    });

    test('1500m at band start: no boost yet, no advisory', () {
      final adj = calculateAdjustments(altitudeM: 1500);
      expect(adj.carbMultiplier, closeTo(1.0, 1e-9));
      expect(adj.advisories, isEmpty);
    });

    test('2000m midpoint of moderate band: +2.5% carbs', () {
      final adj = calculateAdjustments(altitudeM: 2000);
      expect(adj.carbMultiplier, closeTo(1.025, 1e-9));
      expect(
        adj.advisories.any((a) => a.contains('Moderate altitude')),
        true,
      );
    });

    test('2500m at high-altitude band start: +5% carbs', () {
      final adj = calculateAdjustments(altitudeM: 2500);
      expect(adj.carbMultiplier, closeTo(1.05, 1e-9));
      expect(
        adj.advisories.any((a) => a.contains('High altitude')),
        true,
      );
    });

    test('3000m midpoint of high band: +7.5% carbs', () {
      final adj = calculateAdjustments(altitudeM: 3000);
      expect(adj.carbMultiplier, closeTo(1.075, 1e-9));
      expect(
        adj.advisories.any((a) => a.contains('High altitude')),
        true,
      );
    });

    test('4000m midpoint of very-high band: +12.5% carbs', () {
      final adj = calculateAdjustments(altitudeM: 4000);
      expect(adj.carbMultiplier, closeTo(1.125, 1e-9));
      expect(
        adj.advisories.any((a) => a.contains('Very high altitude')),
        true,
      );
    });

    test('5000m midpoint of extreme band: +17.5% carbs', () {
      final adj = calculateAdjustments(altitudeM: 5000);
      expect(adj.carbMultiplier, closeTo(1.175, 1e-9));
      expect(
        adj.advisories.any((a) => a.contains('Extreme altitude')),
        true,
      );
    });

    test('6000m above cap: +20% carbs with physiologist advisory', () {
      final adj = calculateAdjustments(altitudeM: 6000);
      expect(adj.carbMultiplier, closeTo(1.20, 1e-9));
      final cappedAdvisory = adj.advisories.firstWhere(
        (a) => a.contains('Extreme altitude'),
        orElse: () => '',
      );
      expect(cappedAdvisory, isNotEmpty);
      expect(cappedAdvisory, contains('consult a physiologist'));
    });

    test('moderate conditions have mild adjustments', () {
      final adj = calculateAdjustments(temperature: 22, humidity: 50);
      expect(adj.additionalWaterMlPerSlot, 0.0);
      expect(adj.carbMultiplier, 1.0);
    });

    test('25°C/50% RH stays below the simple-HI 80°F threshold', () {
      // simpleHI = 0.5*(77 + 61 + (77-68)*1.2 + 50*0.094) = 76.75°F (<80)
      // → use simple, ≈ 24.86°C, < 27°C threshold → no advisory.
      final adj = calculateAdjustments(temperature: 25, humidity: 50);
      expect(adj.additionalWaterMlPerSlot, 0.0);
      expect(adj.advisories, isEmpty);
    });

    test('25°C/30% RH stays on the simple-HI path with no advisory', () {
      // simpleHI = 0.5*(77 + 61 + 10.8 + 30*0.094) ≈ 75.81°F (<80)
      final adj = calculateAdjustments(temperature: 25, humidity: 30);
      expect(adj.additionalWaterMlPerSlot, 0.0);
      expect(adj.advisories, isEmpty);
    });

    test('20°C/40% RH stays on the simple-HI path with no advisory', () {
      // simpleHI = 0.5*(68 + 61 + 0 + 40*0.094) ≈ 66.38°F (<80)
      final adj = calculateAdjustments(temperature: 20, humidity: 40);
      expect(adj.additionalWaterMlPerSlot, 0.0);
      expect(adj.advisories, isEmpty);
    });

    test('Caution band (27°C/45% RH) ramps water from band start (~0)', () {
      // simpleHI(80.6°F, 45%) = 80.79°F → Rothfusz path. HI lands at the
      // very start of the Caution band (≥27°C), so water should be
      // greater than 0 but well below the 50 ml/slot ramp endpoint.
      final adj = calculateAdjustments(temperature: 27, humidity: 45);
      expect(adj.additionalWaterMlPerSlot, greaterThanOrEqualTo(0));
      expect(adj.additionalWaterMlPerSlot, lessThan(50));
      expect(
        adj.advisories.any((a) => a.contains('Caution')),
        true,
      );
    });

    test('Extreme Caution band advisory exclusive (no Caution prefix)', () {
      // 32°C / 50% RH → HI ≈ 34°C — Extreme Caution band.
      final adj = calculateAdjustments(temperature: 32, humidity: 50);
      expect(
        adj.advisories.any((a) => a.startsWith('Extreme Caution:')),
        true,
      );
      // Lower-band advisory (begins with 'Caution:') must NOT appear.
      // Use startsWith to avoid the 'Extreme Caution:' substring overlap.
      expect(
        adj.advisories.any((a) => a.startsWith('Caution:')),
        false,
      );
    });

    test('Danger band (33°C/85%) sits between 100 and 150 ml/slot', () {
      // HI(91.4°F, 85%) ≈ 117°F ≈ 47°C — squarely in Danger (41–54°C).
      // Linear ramp in band: 100 + (47-41)/(54-41) * 50 ≈ 123 ml.
      final adj = calculateAdjustments(temperature: 33, humidity: 85);
      expect(adj.additionalWaterMlPerSlot, greaterThan(100));
      expect(adj.additionalWaterMlPerSlot, lessThan(150));
      expect(
        adj.advisories.any((a) => a.contains('Danger:')),
        true,
      );
      expect(
        adj.advisories.any((a) => a.contains('Caution')),
        false,
      );
    });

    test('Extreme Danger zone caps water at 150 ml/slot', () {
      // 40°C (104°F), 85% RH → Rothfusz HI well above 54°C cutoff.
      final adj = calculateAdjustments(temperature: 40, humidity: 85);
      expect(adj.additionalWaterMlPerSlot, 150.0);
      expect(
        adj.advisories.any((a) => a.contains('EXTREME DANGER')),
        true,
      );
      // Lower-band advisory phrases must NOT appear at Extreme Danger.
      expect(
        adj.advisories.any((a) => a.contains('Caution:')),
        false,
      );
      expect(
        adj.advisories.any((a) => a.contains('Extreme Caution')),
        false,
      );
      expect(
        adj.advisories.any((a) => a.contains('Danger:')),
        false,
      );
    });

    test('extreme heat gives strongest advisory', () {
      // 40°C (104°F), 85% RH — well into Extreme Danger.
      final adj = calculateAdjustments(temperature: 40, humidity: 85);
      expect(adj.additionalWaterMlPerSlot, greaterThan(100));
      expect(adj.advisories.any((a) => a.contains('EXTREME DANGER')), true);
    });

    test('35°C/80% RH yields water at 150ml cap (Extreme Danger)', () {
      // HI(95°F, 80%) ≈ 134°F ≈ 56.7°C — Extreme Danger.
      final adj = calculateAdjustments(temperature: 35, humidity: 80);
      expect(adj.additionalWaterMlPerSlot, 150.0);
      expect(adj.advisories, isNotEmpty);
    });

    test('40°C/90% RH triggers Extreme Danger and caps water', () {
      final adj = calculateAdjustments(temperature: 40, humidity: 90);
      expect(adj.additionalWaterMlPerSlot, 150.0);
      expect(
        adj.advisories.any((a) => a.contains('EXTREME DANGER')),
        true,
      );
    });

    test('dry heat produces less water than humid heat at same temperature',
        () {
      // 38°C/20% vs 38°C/80% — humid should add at least as much water.
      final dryAdj = calculateAdjustments(temperature: 38, humidity: 20);
      final humidAdj = calculateAdjustments(temperature: 38, humidity: 80);
      expect(dryAdj.additionalWaterMlPerSlot,
          lessThanOrEqualTo(humidAdj.additionalWaterMlPerSlot));
    });

    test('low humidity Adjustment A still subtracts from HI', () {
      // 32.2°C (90°F), 10% RH → NWS Adjustment A applies (RH<13%, 80–112°F).
      // The adjustment lowers HI vs the bare polynomial output.
      final adj = calculateAdjustments(temperature: 32.2, humidity: 10);
      expect(adj.advisories, isNotEmpty);
      expect(
        adj.advisories.any((a) => a.contains('Heat index')),
        true,
      );
    });

    test('heat does not change carb multiplier (heat is hydration-only)', () {
      // Strong heat with no altitude — carbMultiplier must stay 1.0.
      final adj = calculateAdjustments(temperature: 38, humidity: 75);
      expect(adj.carbMultiplier, 1.0);
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
      // NOAA reference: at 90°F (~32.2°C) / 50% RH, HI ≈ 94°F ≈ 34.4°C.
      // Test point 32°C (89.6°F) / 50% RH lands in the Extreme Caution band
      // (32 ≤ HI < 41°C). The 50→100 ml ramp at HI≈34.4 yields ≈63 ml.
      final adj = calculateAdjustments(temperature: 32, humidity: 50);

      // Extreme Caution band: water in [50, 100) per the linear ramp.
      expect(adj.additionalWaterMlPerSlot, greaterThanOrEqualTo(50));
      expect(adj.additionalWaterMlPerSlot, lessThan(100));

      // Parse the °C value from the 'Heat index: ...°C (...°F)' summary
      // and check Rothfusz matches the NOAA reference within ±0.2°C.
      final summary = adj.advisories.firstWhere(
        (a) => a.contains('Heat index'),
        orElse: () => '',
      );
      expect(summary, isNotEmpty,
          reason: 'expected a "Heat index: …°C (…°F)" summary advisory');
      final match = RegExp(r'Heat index:\s*([\d.]+)°C').firstMatch(summary);
      expect(match, isNotNull,
          reason: 'could not parse °C from advisory: $summary');
      final hiCelsius = double.parse(match!.group(1)!);
      expect(hiCelsius, closeTo(34.4, 0.2));
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
