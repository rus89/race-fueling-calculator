// ABOUTME: Tests for timeline slot generation in time-based and distance-based modes.
// ABOUTME: Verifies interval spacing, aid station insertion, and slot count correctness.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/engine/timeline_builder.dart';
import 'package:race_fueling_core/src/models/race_config.dart';

void main() {
  group('buildTimeline — time-based', () {
    test('2-hour race with 20-min intervals produces 6 slots', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );

      final slots = buildTimeline(config);

      expect(slots.length, 6);
      expect(slots[0].timeMark, Duration(minutes: 20));
      expect(slots[1].timeMark, Duration(minutes: 40));
      expect(slots[5].timeMark, Duration(minutes: 120));
      expect(slots.every((s) => !s.isAidStation), true);
    });

    test('90-min race with 20-min intervals produces 4 slots (last at 80min)',
        () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(minutes: 90),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );

      final slots = buildTimeline(config);

      expect(slots.length, 4);
      expect(slots.last.timeMark, Duration(minutes: 80));
    });

    test('aid stations add slots at correct positions', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 30,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
        aidStations: [AidStation(timeMinutes: 45)],
      );

      final slots = buildTimeline(config);

      final aidSlots = slots.where((s) => s.isAidStation).toList();
      expect(aidSlots.length, 1);
      expect(aidSlots[0].timeMark, Duration(minutes: 45));
    });
  });

  group('buildTimeline — distance-based', () {
    test('100km race with 10km intervals produces 10 slots', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 5),
        distanceKm: 100.0,
        timelineMode: TimelineMode.distanceBased,
        intervalKm: 10.0,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );

      final slots = buildTimeline(config);

      expect(slots.length, 10);
      expect(slots[0].distanceMark, 10.0);
      expect(slots[0].timeMark, Duration(minutes: 30)); // 5h/100km = 3min/km
      expect(slots[9].distanceMark, 100.0);
    });

    test('aid station at 45km inserts between 40km and 50km', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 5),
        distanceKm: 100.0,
        timelineMode: TimelineMode.distanceBased,
        intervalKm: 10.0,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
        aidStations: [AidStation(distanceKm: 45.0)],
      );

      final slots = buildTimeline(config);

      expect(slots.length, 11); // 10 regular + 1 aid station
      final aidSlots = slots.where((s) => s.isAidStation).toList();
      expect(aidSlots.length, 1);
      expect(aidSlots[0].distanceMark, 45.0);
    });
  });

  group('buildTimeline — boundary cases', () {
    test('intervalMinutes == 0 throws ArgumentError', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 0,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );
      expect(() => buildTimeline(config), throwsArgumentError);
    });

    test('negative intervalMinutes throws ArgumentError', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: -5,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );
      expect(() => buildTimeline(config), throwsArgumentError);
    });

    test('intervalMinutes == 1 produces a sane timeline', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(minutes: 3),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 1,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );
      final slots = buildTimeline(config);
      expect(slots.length, 3);
      expect(slots[0].timeMark, Duration(minutes: 1));
      expect(slots[2].timeMark, Duration(minutes: 3));
    });

    test('null intervalMinutes falls back to default 20', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );
      final slots = buildTimeline(config);
      expect(slots.length, 6);
      expect(slots[0].timeMark, Duration(minutes: 20));
    });

    test(
      'distanceKm == 0 should not produce a timeline of time-zero slots',
      () {
        final config = RaceConfig(
          name: 'Test',
          duration: Duration(hours: 5),
          distanceKm: 0.0,
          timelineMode: TimelineMode.distanceBased,
          intervalKm: 10.0,
          targetCarbsGPerHr: 60.0,
          strategy: Strategy.steady,
          selectedProducts: [],
          aidStations: [AidStation(distanceKm: 50.0)],
        );
        // Desired: either throws ArgumentError, returns [], or places the aid
        // station at a sensible timeMark derived from a defaulted pace.
        // Actual: paceMinPerKm falls back to 0, so the aid station collapses
        // to timeMark 0 — that's the bug this test will catch when unskipped.
        final slots = buildTimeline(config);
        final aidSlots = slots.where((s) => s.isAidStation).toList();
        expect(aidSlots, isEmpty);
      },
      skip: 'KI-5: zero distance yields nonsensical timeline; fix in Phase 8',
    );
  });
}
