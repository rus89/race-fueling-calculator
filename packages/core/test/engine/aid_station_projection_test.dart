// ABOUTME: Tests for linear km->min projection on distance-defined aid stations.
// ABOUTME: Verifies precedence rules and missing-total-distance handling.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/models/race_config.dart';
import 'package:race_fueling_core/src/engine/aid_station_projection.dart';

void main() {
  group('projectAidStationMin', () {
    test('returns timeMinutes verbatim when set', () {
      const s = AidStation(timeMinutes: 95, distanceKm: 30);
      expect(projectAidStationMin(s, totalKm: 90, durationMin: 270), 95);
    });

    test('projects distance linearly when timeMinutes null', () {
      const s = AidStation(distanceKm: 30);
      expect(projectAidStationMin(s, totalKm: 90, durationMin: 270), 90);
    });

    test('projects half-distance to half-duration', () {
      const s = AidStation(distanceKm: 50);
      expect(projectAidStationMin(s, totalKm: 100, durationMin: 240), 120);
    });

    test('returns null when distance set but totalKm null', () {
      const s = AidStation(distanceKm: 30);
      expect(projectAidStationMin(s, totalKm: null, durationMin: 270), isNull);
    });

    test('returns null when distance set but totalKm zero', () {
      const s = AidStation(distanceKm: 30);
      expect(projectAidStationMin(s, totalKm: 0, durationMin: 270), isNull);
    });

    test('returns null when distance set but totalKm negative', () {
      const s = AidStation(distanceKm: 30);
      expect(projectAidStationMin(s, totalKm: -10, durationMin: 270), isNull);
    });

    test('returns null when both fields null', () {
      const s = AidStation();
      expect(projectAidStationMin(s, totalKm: 90, durationMin: 270), isNull);
    });

    test('rounds to nearest integer minute', () {
      const s = AidStation(distanceKm: 33.33);
      expect(projectAidStationMin(s, totalKm: 100, durationMin: 240), 80);
    });

    test(
      'timeMinutes precedence holds even when distance fields are inconsistent',
      () {
        // Sanity: explicit timeMinutes always wins, regardless of distance projection
        const s = AidStation(timeMinutes: 60, distanceKm: 50);
        expect(projectAidStationMin(s, totalKm: 100, durationMin: 240), 60);
      },
    );

    test(
      'station at the start line (distanceKm == 0) projects to minute 0',
      () {
        const s = AidStation(distanceKm: 0);
        expect(projectAidStationMin(s, totalKm: 100, durationMin: 240), 0);
      },
    );

    test(
      'station at the finish line (distanceKm == totalKm) projects to durationMin',
      () {
        const s = AidStation(distanceKm: 100);
        expect(projectAidStationMin(s, totalKm: 100, durationMin: 240), 240);
      },
    );

    test(
      'station beyond the finish (distanceKm > totalKm) projects past durationMin',
      () {
        // Pinning current pass-through behavior. The validator (A9) catches this
        // case; the projection helper itself is permissive.
        const s = AidStation(distanceKm: 110);
        expect(projectAidStationMin(s, totalKm: 100, durationMin: 240), 264);
      },
    );
  });
}
