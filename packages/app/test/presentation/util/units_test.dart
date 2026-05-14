// ABOUTME: Tests for unit-conversion helpers at the metric/imperial UI boundary.
// ABOUTME: Pins round-trip tolerance and spot-check accuracy versus published factors.
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/util/units.dart';

void main() {
  group('Mass conversion', () {
    test('kgToLb spot check: 72 kg ≈ 158.733 lb', () {
      expect(kgToLb(72), closeTo(158.7326, 0.01));
    });

    test('lbToKg spot check: 158.7 lb ≈ 71.985 kg', () {
      expect(lbToKg(158.7), closeTo(71.985, 0.01));
    });

    test('lbToKg(kgToLb(x)) round-trips within 1e-9', () {
      expect(lbToKg(kgToLb(72)), closeTo(72, 1e-9));
      expect(lbToKg(kgToLb(55.5)), closeTo(55.5, 1e-9));
      expect(lbToKg(kgToLb(0.1)), closeTo(0.1, 1e-9));
    });
  });

  group('Distance conversion', () {
    test('kmToMi spot check: 100 km ≈ 62.1371 mi', () {
      expect(kmToMi(100), closeTo(62.1371, 0.01));
    });

    test('miToKm spot check: 62.14 mi ≈ 100.005 km', () {
      expect(miToKm(62.14), closeTo(100.005, 0.01));
    });

    test('miToKm(kmToMi(x)) round-trips within 1e-9', () {
      expect(miToKm(kmToMi(100)), closeTo(100, 1e-9));
      expect(miToKm(kmToMi(42.2)), closeTo(42.2, 1e-9));
      expect(miToKm(kmToMi(0.5)), closeTo(0.5, 1e-9));
    });
  });
}
