// ABOUTME: Calculates fueling adjustments for heat, humidity, and altitude.
// ABOUTME: Returns carb multipliers, additional hydration needs, and advisory notes.

// Rothfusz heat index per NWS Technical Attachment SR/SSD 90-23 (1990).

import 'dart:math' show sqrt;

/// Project design cap for heat-driven extra water per slot (ml).
const _maxHeatWaterMlPerSlot = 150.0;

class EnvironmentalAdjustments {
  final double carbMultiplier;
  final double additionalWaterMlPerSlot;
  final List<String> advisories;

  const EnvironmentalAdjustments({
    this.carbMultiplier = 1.0,
    this.additionalWaterMlPerSlot = 0.0,
    this.advisories = const [],
  });
}

/// Converts Celsius to Fahrenheit.
double _celsiusToFahrenheit(double celsius) => celsius * 9.0 / 5.0 + 32.0;

/// Converts Fahrenheit to Celsius.
double _fahrenheitToCelsius(double fahrenheit) =>
    (fahrenheit - 32.0) * 5.0 / 9.0;

/// Steadman's simple heat index regression in °F (T °F, RH %).
///
/// Used by NWS as the entry point: if this returns < 80°F the polynomial
/// regression is not applied. Source: Steadman (1979) via NWS guidance.
double _simpleHeatIndexF(double tempF, double humidity) =>
    0.5 * (tempF + 61.0 + (tempF - 68.0) * 1.2 + humidity * 0.094);

/// Rothfusz polynomial regression of the Steadman heat index in °F.
///
/// Defined for tempF in 80–112°F and RH in 0–100%. Includes the two
/// NWS adjustments for low-humidity (RH<13%) and high-humidity (RH>85%)
/// regimes that bring the regression in line with Steadman's table.
double _rothfuszHeatIndexF(double tempF, double humidity) {
  final hi = -42.379 +
      2.04901523 * tempF +
      10.14333127 * humidity -
      0.22475541 * tempF * humidity -
      0.00683783 * tempF * tempF -
      0.05481717 * humidity * humidity +
      0.00122874 * tempF * tempF * humidity +
      0.00085282 * tempF * humidity * humidity -
      0.00000199 * tempF * tempF * humidity * humidity;

  // Adjustment A: dry, hot regime.
  if (humidity < 13 && tempF >= 80 && tempF <= 112) {
    final adj = ((13 - humidity) / 4) * sqrt((17 - (tempF - 95).abs()) / 17);
    return hi - adj;
  }

  // Adjustment B: humid, warm regime.
  if (humidity > 85 && tempF >= 80 && tempF <= 87) {
    final adj = ((humidity - 85) / 10) * ((87 - tempF) / 5);
    return hi + adj;
  }

  return hi;
}

/// Computes heat index in °F given temperature in °C and RH percent.
///
/// Uses the simple Steadman regression first; if its result is < 80°F the
/// Rothfusz polynomial is undefined and the simple value is returned. At
/// or above 80°F the Rothfusz regression (with NWS adjustments) is used.
double _heatIndexF(double tempC, double humidity) {
  final tempF = _celsiusToFahrenheit(tempC);
  final simpleF = _simpleHeatIndexF(tempF, humidity);
  if (simpleF < 80.0) return simpleF;
  return _rothfuszHeatIndexF(tempF, humidity);
}

/// Categorises heat index (in °C) into NWS risk bands and returns the
/// per-slot extra-water target plus a single (highest-band) advisory.
///
/// NWS thresholds:
///   Caution         27 ≤ HI < 32 °C  fatigue with prolonged exposure
///   Extreme Caution 32 ≤ HI < 41 °C  heat exhaustion possible
///   Danger          41 ≤ HI < 54 °C  heat exhaustion likely
///   Extreme Danger  HI ≥ 54 °C       heat stroke imminent
///
/// Water scales linearly across each band:
///   Caution         0 → 50  ml/slot
///   Extreme Caution 50 → 100 ml/slot
///   Danger          100 → 150 ml/slot
///   Extreme Danger  capped at [_maxHeatWaterMlPerSlot] (150 ml/slot)
///
/// Advisories are exclusive: only the highest active band returns text,
/// to avoid contradictory guidance.
(double waterMl, List<String> advisories) _applyHeatThresholds(
    double hiCelsius) {
  if (hiCelsius < 27) return (0.0, []);

  if (hiCelsius >= 54) {
    return (
      _maxHeatWaterMlPerSlot,
      [
        'EXTREME DANGER: Heat stroke imminent. Consider rescheduling or '
            'modifying race plans. If racing: liquid nutrition only, maximum '
            'hydration.',
      ],
    );
  }

  if (hiCelsius >= 41) {
    final t = (hiCelsius - 41) / (54 - 41);
    return (
      100.0 + 50.0 * t,
      [
        'Danger: heat exhaustion likely. Reduce intensity, favor electrolyte '
            'drink mix over gels, watch for heat exhaustion symptoms.',
      ],
    );
  }

  if (hiCelsius >= 32) {
    final t = (hiCelsius - 32) / (41 - 32);
    return (
      50.0 + 50.0 * t,
      [
        'Extreme Caution: heat exhaustion possible. Favor drink mix over '
            'gels to combine hydration and fueling.',
      ],
    );
  }

  // 27 ≤ HI < 32 — Caution
  final t = (hiCelsius - 27) / (32 - 27);
  return (
    50.0 * t,
    [
      'Caution: possible fatigue with prolonged exposure. Extra water '
          'recommended when consuming gels.'
    ],
  );
}

/// Maps an altitude (m) to a piecewise-linear carb boost (fraction of 1.0)
/// and a human-readable band label. Boost ramps:
///   1500–2500m → 0.00 → 0.05 (Moderate altitude)
///   2500–3500m → 0.05 → 0.10 (High altitude)
///   3500–4500m → 0.10 → 0.15 (Very high altitude)
///   4500–5500m → 0.15 → 0.20 (Extreme altitude)
///   ≥ 5500m    → 0.20 capped (Extreme altitude)
(double boost, String label) _altitudeBoost(double altitudeM) {
  if (altitudeM < 1500) return (0.0, '');
  if (altitudeM < 2500) {
    final t = (altitudeM - 1500) / 1000.0;
    return (0.05 * t, 'Moderate altitude');
  }
  if (altitudeM < 3500) {
    final t = (altitudeM - 2500) / 1000.0;
    return (0.05 + 0.05 * t, 'High altitude');
  }
  if (altitudeM < 4500) {
    final t = (altitudeM - 3500) / 1000.0;
    return (0.10 + 0.05 * t, 'Very high altitude');
  }
  if (altitudeM < 5500) {
    final t = (altitudeM - 4500) / 1000.0;
    return (0.15 + 0.05 * t, 'Extreme altitude');
  }
  return (0.20, 'Extreme altitude');
}

EnvironmentalAdjustments calculateAdjustments({
  double? temperature,
  double? humidity,
  double? altitudeM,
}) {
  var carbMultiplier = 1.0;
  var additionalWater = 0.0;
  final advisories = <String>[];

  // Altitude carb-need curve: piecewise linear, 0–5500m, +0% to +20%,
  // derived from ACSM Position Stand on altitude (2008) and athlete
  // fueling guidelines.
  if (altitudeM != null && altitudeM > 1500) {
    final (boost, label) = _altitudeBoost(altitudeM);
    carbMultiplier += boost;
    final pct = (boost * 100).toStringAsFixed(1);
    final m = altitudeM.round();
    if (altitudeM >= 5500) {
      advisories.add('$label (${m}m), capped at +20%: '
          'consult a physiologist for race-specific guidance');
    } else {
      advisories.add('$label (${m}m): +$pct% carb target');
    }
  }

  // Heat stress adjustments — NWS Rothfusz Heat Index.
  if (temperature != null) {
    final hum = humidity ?? 50.0;
    var hiF = _heatIndexF(temperature, hum);

    // Heat index should never read below the dry-bulb temperature.
    final tempF = _celsiusToFahrenheit(temperature);
    if (hiF < tempF) hiF = tempF;

    final hiCelsius = _fahrenheitToCelsius(hiF);

    final (water, heatAdvisories) = _applyHeatThresholds(hiCelsius);
    additionalWater += water;
    advisories.addAll(heatAdvisories);

    if (heatAdvisories.isNotEmpty) {
      advisories.add(
          'Heat index: ${hiCelsius.toStringAsFixed(1)}°C (${hiF.toStringAsFixed(0)}°F)');
    }
  }

  return EnvironmentalAdjustments(
    carbMultiplier: carbMultiplier,
    additionalWaterMlPerSlot: additionalWater,
    advisories: advisories,
  );
}
