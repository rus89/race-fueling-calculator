// ABOUTME: Validates a generated fueling plan and aid-station definitions
// ABOUTME: against the race config; produces critical and advisory warnings.
import '../models/fueling_plan.dart';
import '../models/athlete_profile.dart';
import '../models/race_config.dart';
import '../models/warning.dart';

List<Warning> validatePlan(
  List<PlanEntry> entries,
  AthleteProfile profile,
  Duration raceDuration,
) {
  final warnings = <Warning>[];

  warnings.addAll(_checkGutTolerance(entries, profile, raceDuration));
  warnings.addAll(_checkSingleSource(entries, raceDuration));
  warnings.addAll(_checkCaffeine(entries, profile));
  warnings.addAll(_checkGaps(entries));
  warnings.addAll(_checkRatio(entries, raceDuration));
  warnings.addAll(_checkCarbDrop(entries, raceDuration));

  return warnings;
}

/// Validates aid station definitions against the race configuration.
///
/// Emits:
/// - **critical** when a station has neither `timeMinutes` nor `distanceKm`
///   (cannot be placed on the timeline).
/// - **critical** when `timeMinutes` is negative or beyond `config.duration`.
/// - **critical** when `distanceKm` is negative or beyond `config.distanceKm`.
/// - **advisory** when a station uses `distanceKm` but the race has no
///   `distanceKm` set (the projection would return null, dropping the
///   station silently).
List<Warning> validateAidStationDefinitions(RaceConfig config) {
  final out = <Warning>[];
  final raceMinutes = config.duration.inMinutes;
  final raceKm = config.distanceKm;
  for (var i = 0; i < config.aidStations.length; i++) {
    final s = config.aidStations[i];
    final n = i + 1;
    if (s.timeMinutes == null && s.distanceKm == null) {
      out.add(
        Warning(
          severity: Severity.critical,
          message: 'Aid station #$n has no time or distance defined',
        ),
      );
      continue;
    }
    final t = s.timeMinutes;
    if (t != null) {
      if (t < 0) {
        out.add(
          Warning(
            severity: Severity.critical,
            message: 'Aid station #$n has negative timeMinutes ($t)',
          ),
        );
      } else if (t > raceMinutes) {
        out.add(
          Warning(
            severity: Severity.critical,
            message:
                'Aid station #$n at minute $t is beyond race duration '
                '($raceMinutes min)',
          ),
        );
      }
    }
    final km = s.distanceKm;
    if (km != null) {
      if (km < 0) {
        out.add(
          Warning(
            severity: Severity.critical,
            message:
                'Aid station #$n has negative distanceKm '
                '(${km.toStringAsFixed(0)})',
          ),
        );
      } else if (raceKm != null && km > raceKm) {
        out.add(
          Warning(
            severity: Severity.critical,
            message:
                'Aid station #$n at km ${km.toStringAsFixed(0)} is '
                'beyond total race distance (${raceKm.toStringAsFixed(0)} km)',
          ),
        );
      } else if (t == null && raceKm == null) {
        out.add(
          Warning(
            severity: Severity.advisory,
            message:
                'Aid station #$n at km ${km.toStringAsFixed(0)} '
                'needs total race distance set',
          ),
        );
      }
    }
  }
  return out;
}

List<Warning> _checkGutTolerance(
  List<PlanEntry> entries,
  AthleteProfile profile,
  Duration raceDuration,
) {
  final warnings = <Warning>[];
  final totalMin = raceDuration.inMinutes;
  final tolerance = profile.gutToleranceGPerHr;

  // Check each 60-min rolling window
  for (var startMin = 0; startMin < totalMin; startMin += 20) {
    final endMin = startMin + 60;
    final hourCarbs = entries
        .where(
          (e) =>
              e.timeMark.inMinutes > startMin && e.timeMark.inMinutes <= endMin,
        )
        .fold(0.0, (sum, e) => sum + e.carbsTotal);

    if (hourCarbs > tolerance * 1.15) {
      warnings.add(
        Warning(
          severity: Severity.critical,
          message:
              'Exceeding gut tolerance: ${hourCarbs.toStringAsFixed(0)}g/hr '
              'at $startMin-${endMin}min (trained: ${tolerance.toStringAsFixed(0)}g/hr)',
        ),
      );
      break; // One warning is enough
    }
  }

  return warnings;
}

List<Warning> _checkSingleSource(
  List<PlanEntry> entries,
  Duration raceDuration,
) {
  final warnings = <Warning>[];
  final totalMin = raceDuration.inMinutes;

  for (var startMin = 0; startMin < totalMin; startMin += 20) {
    final endMin = startMin + 60;
    final hourEntries = entries.where(
      (e) => e.timeMark.inMinutes > startMin && e.timeMark.inMinutes <= endMin,
    );

    final hourGlucose = hourEntries.fold(0.0, (sum, e) => sum + e.carbsGlucose);
    final hourFructose = hourEntries.fold(
      0.0,
      (sum, e) => sum + e.carbsFructose,
    );

    if (hourGlucose > 60 && hourFructose == 0) {
      warnings.add(
        Warning(
          severity: Severity.critical,
          message:
              'Over 60g/hr from single-source carbs at $startMin-${endMin}min. '
              'Dual-source (glucose + fructose) needed for absorption above 60g/hr.',
        ),
      );
      break;
    }
  }

  return warnings;
}

// TODO(v1.1): caffeine thresholds are one-size-fits-all — 400 mg absolute cap
// and 6 mg/kg with no athlete-level sensitivity override. To fix, add a
// `caffeineSensitivity` field to AthleteProfile (low / normal / high),
// regenerate .g.dart, write a storage migration for existing profiles, and
// gate these thresholds on the field. Tracked in JOURNAL.md KI-9.
List<Warning> _checkCaffeine(List<PlanEntry> entries, AthleteProfile profile) {
  final warnings = <Warning>[];
  final totalCaffeine = entries.isEmpty ? 0.0 : entries.last.cumulativeCaffeine;

  if (totalCaffeine > 400) {
    warnings.add(
      Warning(
        severity: Severity.critical,
        message:
            'Total caffeine ${totalCaffeine.toStringAsFixed(0)}mg exceeds '
            'safe threshold (400mg).',
      ),
    );
  } else {
    final kg = profile.bodyWeightKg;
    if (kg != null) {
      final mgPerKg = totalCaffeine / kg;
      if (mgPerKg > 6.0) {
        warnings.add(
          Warning(
            severity: Severity.critical,
            message:
                'Total caffeine ${totalCaffeine.toStringAsFixed(0)}mg exceeds '
                '${mgPerKg.toStringAsFixed(1)}mg/kg (threshold: 6mg/kg).',
          ),
        );
      }
    }
  }

  return warnings;
}

List<Warning> _checkGaps(List<PlanEntry> entries) {
  final warnings = <Warning>[];
  var prevMin = 0;

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final gap = entry.timeMark.inMinutes - prevMin;

    if (gap > 30 && entry.carbsTotal > 0) {
      warnings.add(
        Warning(
          severity: Severity.advisory,
          message:
              '$gap-minute gap before intake at ${entry.timeMark.inMinutes}min. '
              'Consider more frequent fueling.',
          entryIndex: i,
        ),
      );
    }

    if (entry.carbsTotal > 0) {
      prevMin = entry.timeMark.inMinutes;
    }
  }

  return warnings;
}

List<Warning> _checkRatio(List<PlanEntry> entries, Duration raceDuration) {
  final warnings = <Warning>[];
  final totalMin = raceDuration.inMinutes;

  for (var startMin = 0; startMin < totalMin; startMin += 20) {
    final endMin = startMin + 60;
    final hourEntries = entries.where(
      (e) => e.timeMark.inMinutes > startMin && e.timeMark.inMinutes <= endMin,
    );

    final hourGlucose = hourEntries.fold(0.0, (sum, e) => sum + e.carbsGlucose);
    final hourFructose = hourEntries.fold(
      0.0,
      (sum, e) => sum + e.carbsFructose,
    );
    final hourCarbs = hourGlucose + hourFructose;

    // Only check ratio if above 50g/hr where dual-source matters
    if (hourCarbs > 50 && hourFructose > 0 && hourGlucose > 0) {
      final ratio = hourFructose / hourGlucose;
      // Acceptable G:F ratio range: [0.5, 1.0] (fructose/glucose).
      // Reference: Jeukendrup AE (2014) "A step towards personalized sports
      // nutrition: carbohydrate intake during exercise" Sports Med
      // 44(Suppl 1):S25-S33. For >60 g/hr targets, multi-transporter
      // co-ingestion (glucose + fructose) at 1:0.8–1:1 is recommended.
      if (ratio < 0.5 || ratio > 1.0) {
        warnings.add(
          Warning(
            severity: Severity.advisory,
            message:
                'Glucose:fructose ratio is 1:${ratio.toStringAsFixed(1)} '
                'at $startMin-${endMin}min '
                '(optimal range: 1:0.5 to 1:1.0 for high absorption).',
          ),
        );
        break; // One warning is enough
      }
    }
  }

  return warnings;
}

// Warns when the second half of the race averages significantly fewer
// carbs than the first half and the strategy is not back-load.
// A >20% drop suggests the plan front-loads by accident, not design.
List<Warning> _checkCarbDrop(List<PlanEntry> entries, Duration raceDuration) {
  final warnings = <Warning>[];
  if (entries.isEmpty) return warnings;

  final halfMin = raceDuration.inMinutes / 2;
  final firstHalf = entries
      .where((e) => e.timeMark.inMinutes <= halfMin)
      .fold(0.0, (sum, e) => sum + e.carbsTotal);
  final secondHalf = entries
      .where((e) => e.timeMark.inMinutes > halfMin)
      .fold(0.0, (sum, e) => sum + e.carbsTotal);

  if (firstHalf > 0 && secondHalf < firstHalf * 0.8) {
    warnings.add(
      Warning(
        severity: Severity.advisory,
        message:
            'Carb intake drops significantly in the second half '
            '(${secondHalf.toStringAsFixed(0)}g vs ${firstHalf.toStringAsFixed(0)}g). '
            'Consider back-load strategy if this is intentional.',
      ),
    );
  }

  return warnings;
}
