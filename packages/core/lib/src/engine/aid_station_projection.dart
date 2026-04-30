// ABOUTME: Projects aid stations defined by distanceKm to a minute mark.
// ABOUTME: Uses a linear km->min mapping; explicit timeMinutes always wins.
import '../models/race_config.dart';

/// Returns the effective minute mark for an aid station.
///
/// Precedence: `timeMinutes` (explicit) > linear projection from
/// `distanceKm`. Returns `null` when distance is set but `totalKm` is
/// missing/non-positive, or when the station has neither field set.
int? projectAidStationMin(
  AidStation station, {
  required double? totalKm,
  required int durationMin,
}) {
  if (station.timeMinutes != null) return station.timeMinutes;
  final km = station.distanceKm;
  if (km == null) return null;
  if (totalKm == null || totalKm <= 0) return null;
  return ((km / totalKm) * durationMin).round();
}
