// ABOUTME: Calculates target carb grams per timeline slot based on race strategy.
// ABOUTME: Supports steady, front-load, back-load, and custom curve distributions.
import '../models/race_config.dart';
import 'timeline_builder.dart';

List<double> distributeCarbs(
    List<TimeSlot> slots, RaceConfig config, double targetCarbsGPerHr) {
  switch (config.strategy) {
    case Strategy.steady:
      return _distributeSteady(slots, targetCarbsGPerHr);
    case Strategy.frontLoad:
      return _distributeFrontLoad(slots, config, targetCarbsGPerHr);
    case Strategy.backLoad:
      return _distributeBackLoad(slots, config, targetCarbsGPerHr);
    case Strategy.custom:
      return _distributeCustom(slots, config, targetCarbsGPerHr);
  }
}

List<double> _distributeSteady(List<TimeSlot> slots, double targetCarbsGPerHr) {
  final gPerMin = targetCarbsGPerHr / 60.0;
  return _distributeByGapMinutes(slots, List.filled(slots.length, gPerMin));
}

List<double> _distributeFrontLoad(
    List<TimeSlot> slots, RaceConfig config, double targetCarbsGPerHr) {
  final totalMin = config.duration.inMinutes;
  final gPerMin = targetCarbsGPerHr / 60.0;

  return _distributeByGapMinutes(
      slots,
      slots.map((slot) {
        final progress = slot.timeMark.inMinutes / totalMin;
        final multiplier =
            progress < 0.33 ? 1.1 : (progress < 0.67 ? 1.0 : 0.9);
        return gPerMin * multiplier;
      }).toList());
}

List<double> _distributeBackLoad(
    List<TimeSlot> slots, RaceConfig config, double targetCarbsGPerHr) {
  final totalMin = config.duration.inMinutes;
  final gPerMin = targetCarbsGPerHr / 60.0;

  return _distributeByGapMinutes(
      slots,
      slots.map((slot) {
        final progress = slot.timeMark.inMinutes / totalMin;
        final multiplier =
            progress < 0.33 ? 0.9 : (progress < 0.67 ? 1.0 : 1.1);
        return gPerMin * multiplier;
      }).toList());
}

List<double> _distributeCustom(
    List<TimeSlot> slots, RaceConfig config, double targetCarbsGPerHr) {
  final curve = config.customCurve ?? [];
  final gPerMinRates = <double>[];

  for (final slot in slots) {
    final slotMin = slot.timeMark.inMinutes;
    var cumulativeMin = 0;
    var rate = targetCarbsGPerHr / 60.0; // fallback

    for (final segment in curve) {
      cumulativeMin += segment.durationMinutes;
      if (slotMin <= cumulativeMin) {
        rate = segment.targetGPerHr / 60.0;
        break;
      }
    }

    gPerMinRates.add(rate);
  }

  return _distributeByGapMinutes(slots, gPerMinRates);
}

List<double> _distributeByGapMinutes(
    List<TimeSlot> slots, List<double> gPerMinRates) {
  assert(slots.length == gPerMinRates.length,
      '_distributeByGapMinutes: slots and gPerMinRates must have equal length');
  final targets = <double>[];
  var prevMin = 0;

  for (var i = 0; i < slots.length; i++) {
    final gapMin = slots[i].timeMark.inMinutes - prevMin;
    targets.add(gPerMinRates[i] * gapMin);
    prevMin = slots[i].timeMark.inMinutes;
  }

  return targets;
}
