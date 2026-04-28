// ABOUTME: Calculates fueling adjustments for heat, humidity, and altitude.
// ABOUTME: Returns carb multipliers, additional hydration needs, and advisory notes.

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

/// Computes the NOAA Rothfusz heat index regression in °F.
///
/// Input: temperature in °F, relative humidity in % (0–100).
/// Returns heat index in °F.
///
/// The Rothfusz regression is valid when T >= 80°F (≈26.7°C) and
/// produces the standard NWS heat index. Below 80°F we fall back to a
/// linear hand-off where HI ≈ T (with a small humidity nudge) so the
/// transition is continuous.
///
/// Reference: https://www.weather.gov/ffc/heatindex
double _rothfuszHeatIndexF(double tempF, double humidity) {
  // Base regression (valid for T >= 80°F, RH >= 0%)
  final hi = -42.379 +
      2.04901523 * tempF +
      10.14333127 * humidity -
      0.22475541 * tempF * humidity -
      0.00683783 * tempF * tempF -
      0.05481717 * humidity * humidity +
      0.00122874 * tempF * tempF * humidity +
      0.00085282 * tempF * humidity * humidity -
      0.00000199 * tempF * tempF * humidity * humidity;

  // Adjustment A: If RH < 13% and tempF between 80–112°F, subtract
  if (humidity < 13 && tempF >= 80 && tempF <= 112) {
    final adj = ((13 - humidity) / 4) * sqrt((17 - (tempF - 95).abs()) / 17);
    return hi - adj;
  }

  // Adjustment B: If RH > 85% and tempF between 80–87°F, add
  if (humidity > 85 && tempF >= 80 && tempF <= 87) {
    final adj = ((humidity - 85) / 10) * ((87 - tempF) / 5);
    return hi + adj;
  }

  return hi;
}

/// Categorises heat index (in °C) and returns water addition + advisories.
///
/// Thresholds based on NWS Heat Index risk categories:
///   Caution:        27–32 °C (80–90 °F)  — fatigue possible
///   Extreme Caution: 32–39 °C (90–103 °F) — heat cramps/heat exhaustion
///   Danger:         39–52 °C (103–125 °F) — heat exhaustion likely
///   Extreme Danger:  52+ °C (125+ °F)     — heat stroke imminent
///
/// Water accumulates across zones (Caution +50, Extreme Caution +50,
/// Danger +50, capped at [_maxHeatWaterMlPerSlot]). Advisories are
/// exclusive: only the highest active zone's message is returned to
/// avoid contradictory guidance.
(double waterMl, List<String> advisories) _applyHeatThresholds(
    double hiCelsius) {
  // Hi < 27°C: no heat adjustment needed
  if (hiCelsius < 27) return (0.0, []);

  if (hiCelsius >= 52) {
    // Extreme Danger — water cap already reached at the Danger step.
    return (
      _maxHeatWaterMlPerSlot,
      [
        'EXTREME DANGER: Consider rescheduling or modifying race plans. '
            'Heat stroke risk. If racing: only liquid nutrition, maximum hydration.',
      ],
    );
  } else if (hiCelsius >= 39) {
    // Danger (39–52 °C) — heat exhaustion risk
    return (
      _maxHeatWaterMlPerSlot,
      [
        'Dangerous heat: minimize gel consumption, prioritize electrolyte '
            'drink mix. Watch for heat exhaustion symptoms.',
      ],
    );
  } else if (hiCelsius >= 32) {
    // Extreme Caution (32–39 °C)
    return (
      100.0,
      [
        'High heat stress: favor drink mix over gels to combine hydration and fueling',
      ],
    );
  } else {
    // Caution (27–32 °C)
    return (
      50.0,
      ['Warm conditions: extra water recommended when consuming gels'],
    );
  }
}

EnvironmentalAdjustments calculateAdjustments({
  double? temperature,
  double? humidity,
  double? altitudeM,
}) {
  var carbMultiplier = 1.0;
  var additionalWater = 0.0;
  final advisories = <String>[];

  // Altitude adjustments
  if (altitudeM != null && altitudeM > 1500) {
    // Linear scale: 1500m = 0%, 3000m = 10%
    final factor = ((altitudeM - 1500) / 1500).clamp(0.0, 1.0);
    carbMultiplier += 0.1 * factor;
    advisories.add('Target adjusted for altitude (${altitudeM.round()}m): '
        '+${(factor * 10).toStringAsFixed(0)}% carbs');
  }

  // Heat stress adjustments — NOAA Rothfusz Heat Index
  if (temperature != null) {
    final hum = humidity ?? 50.0;
    final tempF = _celsiusToFahrenheit(temperature);

    // Compute heat index
    // For temps below 26.7°C (80°F) the Rothfusz regression isn't defined,
    // so we fall back to a linear approximation that smoothly approaches
    // the actual temperature at cooler conditions.
    double hiF;
    if (temperature >= 26.7) {
      hiF = _rothfuszHeatIndexF(tempF, hum);
    } else {
      // Below the Rothfusz threshold, heat index ≈ actual temperature
      // with a slight humidity bump. This gives a smooth hand-off. The
      // raw bump is (hum-50)*0.1, but the clamp below suppresses the
      // negative half, so the effective range is [0, +5°F].
      final humEffect = (hum - 50) * 0.1;
      hiF = tempF + humEffect;
    }

    // Clamp: HI should never be lower than actual temperature
    if (hiF < tempF) hiF = tempF;

    final hiCelsius = _fahrenheitToCelsius(hiF);

    final (water, heatAdvisories) = _applyHeatThresholds(hiCelsius);
    additionalWater += water;
    advisories.addAll(heatAdvisories);

    // If heat advisories were generated, add a summary note
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
