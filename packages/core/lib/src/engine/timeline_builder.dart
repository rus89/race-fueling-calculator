// ABOUTME: Builds the sequence of time or distance slots for a race fueling timeline.
// ABOUTME: Inserts aid station slots at specified positions alongside regular intervals.
import '../models/race_config.dart';

class TimeSlot {
  final Duration timeMark;
  final double? distanceMark;
  final bool isAidStation;

  const TimeSlot({
    required this.timeMark,
    this.distanceMark,
    this.isAidStation = false,
  });
}

List<TimeSlot> buildTimeline(RaceConfig config) {
  if (config.timelineMode == TimelineMode.timeBased) {
    return _buildTimeBased(config);
  }
  return _buildDistanceBased(config);
}

List<TimeSlot> _buildTimeBased(RaceConfig config) {
  final intervalMin = config.intervalMinutes ?? 20;
  final totalMin = config.duration.inMinutes;
  final slots = <TimeSlot>[];

  // Generate regular interval slots
  for (var min = intervalMin; min <= totalMin; min += intervalMin) {
    slots.add(TimeSlot(timeMark: Duration(minutes: min)));
  }

  // Insert aid station slots
  for (final station in config.aidStations) {
    final stationMin = station.timeMinutes;
    if (stationMin == null) continue;
    final exists = slots.any((s) => s.timeMark.inMinutes == stationMin);
    if (exists) {
      // Mark existing slot as aid station
      final idx = slots.indexWhere((s) => s.timeMark.inMinutes == stationMin);
      slots[idx] = TimeSlot(
        timeMark: Duration(minutes: stationMin),
        isAidStation: true,
      );
    } else {
      slots.add(TimeSlot(
        timeMark: Duration(minutes: stationMin),
        isAidStation: true,
      ));
    }
  }

  slots.sort((a, b) => a.timeMark.compareTo(b.timeMark));
  return slots;
}

List<TimeSlot> _buildDistanceBased(RaceConfig config) {
  final intervalKm = config.intervalKm ?? 10.0;
  final totalKm = config.distanceKm ?? 0.0;
  final totalMin = config.duration.inMinutes;
  final paceMinPerKm = totalKm > 0 ? totalMin / totalKm : 0.0;
  final slots = <TimeSlot>[];

  for (var km = intervalKm; km <= totalKm; km += intervalKm) {
    slots.add(TimeSlot(
      timeMark: Duration(minutes: (km * paceMinPerKm).round()),
      distanceMark: km,
    ));
  }

  for (final station in config.aidStations) {
    final stationKm = station.distanceKm;
    if (stationKm == null) continue;
    final exists = slots.any((s) => s.distanceMark == stationKm);
    if (exists) {
      final idx = slots.indexWhere((s) => s.distanceMark == stationKm);
      slots[idx] = TimeSlot(
        timeMark: Duration(minutes: (stationKm * paceMinPerKm).round()),
        distanceMark: stationKm,
        isAidStation: true,
      );
    } else {
      slots.add(TimeSlot(
        timeMark: Duration(minutes: (stationKm * paceMinPerKm).round()),
        distanceMark: stationKm,
        isAidStation: true,
      ));
    }
  }

  slots.sort((a, b) => a.timeMark.compareTo(b.timeMark));
  return slots;
}
