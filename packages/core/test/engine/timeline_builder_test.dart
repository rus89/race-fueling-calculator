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

    test(
      '90-min race with 20-min intervals produces 4 slots (last at 80min)',
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
      },
    );

    test('aligned aid station marks the existing 60-min slot', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 30,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
        aidStations: [AidStation(timeMinutes: 60)],
      );

      final slots = buildTimeline(config);

      expect(slots.length, 4); // 30, 60, 90, 120
      expect(slots.where((s) => s.isAidStation).length, 1);
      final marked = slots.firstWhere((s) => s.isAidStation);
      expect(marked.timeMark, Duration(minutes: 60));
    });

    test('non-aligned timeMinutes does not insert a new slot', () {
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
      expect(slots.length, 4); // 30, 60, 90, 120 — no extra at 45
      expect(
        slots.every((s) => !s.isAidStation),
        isTrue,
        reason: 'non-aligned aid station should not mark any slot',
      );
      expect(slots.map((s) => s.timeMark.inMinutes), [30, 60, 90, 120]);
    });

    test(
      'multiple aid stations: aligned ones are marked, non-aligned are skipped (time-based)',
      () {
        final config = RaceConfig(
          name: 'Test',
          duration: Duration(hours: 2),
          timelineMode: TimelineMode.timeBased,
          intervalMinutes: 30,
          targetCarbsGPerHr: 60.0,
          strategy: Strategy.steady,
          selectedProducts: [],
          aidStations: [
            AidStation(timeMinutes: 60), // aligned
            AidStation(timeMinutes: 75), // non-aligned — should be skipped
            AidStation(timeMinutes: 90), // aligned
          ],
        );
        final slots = buildTimeline(config);
        expect(slots.length, 4); // 30, 60, 90, 120 — unchanged
        expect(slots.where((s) => s.isAidStation).length, 2);
        final marked = slots
            .where((s) => s.isAidStation)
            .map((s) => s.timeMark.inMinutes)
            .toList();
        expect(marked, containsAll([60, 90]));
      },
    );
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

    test('aligned aid station at 50km marks the existing 50km slot', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 5),
        distanceKm: 100.0,
        timelineMode: TimelineMode.distanceBased,
        intervalKm: 10.0,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
        aidStations: [AidStation(distanceKm: 50.0)],
      );

      final slots = buildTimeline(config);

      expect(slots.length, 10); // aligned position uses an existing slot
      final aidSlots = slots.where((s) => s.isAidStation).toList();
      expect(aidSlots.length, 1);
      expect(aidSlots[0].distanceMark, 50.0);
    });

    test('non-aligned distanceKm does not insert a new slot', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 5),
        distanceKm: 100,
        timelineMode: TimelineMode.distanceBased,
        intervalKm: 10,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
        aidStations: [AidStation(distanceKm: 45)],
      );
      final slots = buildTimeline(config);
      expect(slots.length, 10); // 10, 20, ..., 100 — no extra at 45
      expect(
        slots.every((s) => !s.isAidStation),
        isTrue,
        reason: 'non-aligned aid station should not mark any slot',
      );
    });

    test(
      'multiple aid stations: aligned ones are marked, non-aligned are skipped (distance-based)',
      () {
        final config = RaceConfig(
          name: 'Test',
          duration: Duration(hours: 5),
          distanceKm: 100,
          timelineMode: TimelineMode.distanceBased,
          intervalKm: 10,
          targetCarbsGPerHr: 60.0,
          strategy: Strategy.steady,
          selectedProducts: [],
          aidStations: [
            AidStation(distanceKm: 30), // aligned
            AidStation(distanceKm: 45), // non-aligned — should be skipped
            AidStation(distanceKm: 70), // aligned
          ],
        );
        final slots = buildTimeline(config);
        expect(slots.length, 10); // 10, 20, ..., 100 — unchanged
        expect(slots.where((s) => s.isAidStation).length, 2);
      },
    );
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

    test('distanceKm == 0 in distanceBased mode throws ArgumentError', () {
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
      expect(() => buildTimeline(config), throwsArgumentError);
    });

    test('negative distanceKm in distanceBased mode throws ArgumentError', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 5),
        distanceKm: -10.0,
        timelineMode: TimelineMode.distanceBased,
        intervalKm: 10.0,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );
      expect(() => buildTimeline(config), throwsArgumentError);
    });

    test('tiny positive distanceKm produces a sane timeline', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(minutes: 1),
        distanceKm: 0.1,
        timelineMode: TimelineMode.distanceBased,
        intervalKm: 0.1,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );
      final slots = buildTimeline(config);
      expect(slots.length, 1);
      expect(slots[0].distanceMark, 0.1);
    });

    test('null distanceKm in timeBased mode does not throw', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 2),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );
      expect(() => buildTimeline(config), returnsNormally);
    });

    test('distanceKm == 0 in timeBased mode does not throw', () {
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 2),
        distanceKm: 0.0,
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );
      expect(() => buildTimeline(config), returnsNormally);
    });
  });
}
