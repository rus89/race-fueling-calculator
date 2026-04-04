// ABOUTME: Tests for carb distribution across timeline slots for all strategy modes.
// ABOUTME: Verifies steady, front-load, back-load, and custom curve distributions.
import 'package:test/test.dart';
import 'package:race_fueling_core/src/engine/carb_distributor.dart';
import 'package:race_fueling_core/src/engine/timeline_builder.dart';
import 'package:race_fueling_core/src/models/race_config.dart';

void main() {
  group('distributeCarbs — steady', () {
    test('60g/hr with 20-min intervals gives 20g per slot', () {
      final slots = [
        TimeSlot(timeMark: Duration(minutes: 20)),
        TimeSlot(timeMark: Duration(minutes: 40)),
        TimeSlot(timeMark: Duration(minutes: 60)),
      ];
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 1),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );

      final targets = distributeCarbs(slots, config);

      expect(targets.length, 3);
      expect(targets[0], closeTo(20.0, 0.1));
      expect(targets[1], closeTo(20.0, 0.1));
      expect(targets[2], closeTo(20.0, 0.1));
    });

    test('handles uneven intervals correctly', () {
      // Slots at 20, 40, 45 (aid station), 60 — gaps are 20, 20, 5, 15 minutes
      final slots = [
        TimeSlot(timeMark: Duration(minutes: 20)),
        TimeSlot(timeMark: Duration(minutes: 40)),
        TimeSlot(timeMark: Duration(minutes: 45), isAidStation: true),
        TimeSlot(timeMark: Duration(minutes: 60)),
      ];
      final config = RaceConfig(
        name: 'Test',
        duration: Duration(hours: 1),
        timelineMode: TimelineMode.timeBased,
        intervalMinutes: 20,
        targetCarbsGPerHr: 60.0,
        strategy: Strategy.steady,
        selectedProducts: [],
      );

      final targets = distributeCarbs(slots, config);

      // Each slot's target is proportional to its time gap
      expect(targets[0], closeTo(20.0, 0.1)); // 20min gap
      expect(targets[1], closeTo(20.0, 0.1)); // 20min gap
      expect(targets[2], closeTo(5.0, 0.1)); // 5min gap
      expect(targets[3], closeTo(15.0, 0.1)); // 15min gap
    });
  });
}
