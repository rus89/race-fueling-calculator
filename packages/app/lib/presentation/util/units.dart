// ABOUTME: Pure unit-conversion helpers for the metric ↔ imperial UI boundary.
// ABOUTME: Storage stays canonical SI; conversion happens at input/display only.

/// Conversion factor: 1 kg = 2.20462 lb (NIST published factor).
const double _kKgPerLb = 2.20462;

/// Conversion factor: 1 km = 0.621371 mi (NIST published factor).
const double _kMiPerKm = 0.621371;

double kgToLb(double kg) => kg * _kKgPerLb;

double lbToKg(double lb) => lb / _kKgPerLb;

double kmToMi(double km) => km * _kMiPerKm;

double miToKm(double mi) => mi / _kMiPerKm;
