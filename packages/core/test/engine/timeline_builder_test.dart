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
}
