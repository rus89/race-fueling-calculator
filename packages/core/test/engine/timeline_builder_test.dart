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
    test(
      'intervalMinutes == 0 should not infinite-loop',
      () {
        final config = RaceConfig(
          name: 'Test',
          duration: Duration(hours: 2),
          timelineMode: TimelineMode.timeBased,
          intervalMinutes: 0,
          targetCarbsGPerHr: 60.0,
          strategy: Strategy.steady,
          selectedProducts: [],
        );
        // Desired: either throws ArgumentError or falls back to a sane default.
        // Actual: for-loop `min += 0` never terminates.
        expect(() => buildTimeline(config), throwsA(anything));
      },
      skip: 'KI-2: zero interval causes infinite loop; fix in Phase 8',
    );

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
        );
        // Desired: either throws ArgumentError or returns [].
        // Actual: paceMinPerKm falls back to 0, loop exits with 0 slots (OK here),
        // but aid stations at any distance collapse to timeMark 0.
        final slots = buildTimeline(config);
        expect(slots, isEmpty);
      },
      skip: 'KI-5: zero distance yields nonsensical timeline; fix in Phase 8',
    );
  });
}
