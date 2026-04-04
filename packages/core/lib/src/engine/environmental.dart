// ABOUTME: Calculates fueling adjustments for heat, humidity, and altitude.
// ABOUTME: Returns carb multipliers, additional hydration needs, and advisory notes.

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

  // Heat stress adjustments
  if (temperature != null) {
    final hum = humidity ?? 50.0;
    // Simple heat index approximation
    final heatStress = temperature + (hum / 100.0) * 10.0;

    if (heatStress > 40) {
      // Moderate heat
      additionalWater += 50.0;
      advisories.add('Warm conditions: extra water recommended with gels');
    }
    if (heatStress > 44) {
      // High heat
      additionalWater += 50.0;
      advisories.add('High heat stress: consider favoring drink mix over gels '
          'to combine hydration and fueling');
    }
    if (heatStress > 48) {
      // Extreme heat
      additionalWater += 50.0;
    }
  }

  return EnvironmentalAdjustments(
    carbMultiplier: carbMultiplier,
    additionalWaterMlPerSlot: additionalWater,
    advisories: advisories,
  );
}
