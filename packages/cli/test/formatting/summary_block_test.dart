// ABOUTME: Tests for summary block and warnings section with explicit useColor contract.
// ABOUTME: Covers full output, empty notes/warnings, severity-only variants, and ANSI stripping.
import 'package:test/test.dart';
import 'package:race_fueling_cli/src/formatting/summary_block.dart';
import 'package:race_fueling_core/core.dart';

void main() {
  final testConfig = RaceConfig(
    name: 'Test Race',
    duration: Duration(hours: 3),
    timelineMode: TimelineMode.timeBased,
    intervalMinutes: 20,
    targetCarbsGPerHr: 80.0,
    strategy: Strategy.steady,
    selectedProducts: [],
  );

  FuelingPlan buildPlan({
    List<String> environmentalNotes = const [],
    List<Warning> warnings = const [],
    double glucoseFructoseRatio = 0.80,
  }) {
    return FuelingPlan(
      raceConfig: testConfig,
      entries: const [],
      summary: PlanSummary(
        totalCarbs: 240.0,
        averageGPerHr: 80.0,
        totalCaffeineMg: 200.0,
        glucoseFructoseRatio: glucoseFructoseRatio,
        totalWaterMl: 1200.0,
        environmentalNotes: environmentalNotes,
      ),
      warnings: warnings,
    );
  }

  group('formatSummaryBlock — full populated', () {
    test('includes all summary fields and warning sections', () {
      final plan = buildPlan(
        environmentalNotes: ['Altitude adjustment: +7%'],
        warnings: [
          Warning(
              severity: Severity.critical, message: 'Gut tolerance exceeded'),
          Warning(severity: Severity.advisory, message: 'Consider more water'),
        ],
      );

      final output = formatSummaryBlock(plan, useColor: false);

      expect(output, contains('=== SUMMARY ==='));
      expect(output, contains('240'));
      expect(output, contains('80'));
      expect(output, contains('200'));
      expect(output, contains('1200'));
      expect(output, contains('Altitude'));
      expect(output, contains('=== WARNINGS ==='));
      expect(output, contains('CRITICAL'));
      expect(output, contains('Gut tolerance'));
      expect(output, contains('ADVISORY'));
    });
  });

  group('formatSummaryBlock — G:F ratio label format', () {
    test('renders "G:F ratio:        1:0.80" with two-decimal formatting', () {
      final plan = buildPlan(glucoseFructoseRatio: 0.80);
      final output = formatSummaryBlock(plan, useColor: false);
      expect(output, contains('G:F ratio:        1:0.80'));
    });
  });

  group('formatSummaryBlock — empty environmentalNotes', () {
    test('does not emit a blank line before the (absent) notes section', () {
      final plan = buildPlan(); // empty notes, no warnings
      final output = formatSummaryBlock(plan, useColor: false);

      expect(output, isNot(contains('Altitude')));
      // Header → totals → no extra trailing blank line before EOF.
      final lines = output.split('\n');
      // Remove the final empty string from the trailing newline.
      final trimmed =
          lines.last.isEmpty ? lines.sublist(0, lines.length - 1) : lines;
      expect(trimmed.last.trim(), isNotEmpty);
    });
  });

  group('formatSummaryBlock — empty warnings', () {
    test('does not emit WARNINGS header when both lists are empty', () {
      final plan = buildPlan();
      final output = formatSummaryBlock(plan, useColor: false);
      expect(output, isNot(contains('WARNINGS')));
      expect(output, isNot(contains('CRITICAL')));
      expect(output, isNot(contains('ADVISORY')));
    });
  });

  group('formatSummaryBlock — severity-only variants', () {
    test('only critical: emits CRITICAL block, no ADVISORY block', () {
      final plan = buildPlan(warnings: [
        Warning(severity: Severity.critical, message: 'Boom'),
      ]);
      final output = formatSummaryBlock(plan, useColor: false);
      expect(output, contains('CRITICAL'));
      expect(output, isNot(contains('ADVISORY')));
    });

    test('only advisory: emits ADVISORY block, no CRITICAL block', () {
      final plan = buildPlan(warnings: [
        Warning(severity: Severity.advisory, message: 'Heads up'),
      ]);
      final output = formatSummaryBlock(plan, useColor: false);
      expect(output, contains('ADVISORY'));
      expect(output, isNot(contains('CRITICAL')));
    });
  });

  group('formatSummaryBlock — color contract', () {
    test('useColor: false output contains zero ANSI escapes', () {
      final plan = buildPlan(
        environmentalNotes: ['Heat advisory'],
        warnings: [
          Warning(severity: Severity.critical, message: 'Test'),
        ],
      );
      final output = formatSummaryBlock(plan, useColor: false);
      expect(output.contains('\x1B'), isFalse);
    });

    test('useColor: true emits red for critical and yellow for advisory', () {
      final plan = buildPlan(warnings: [
        Warning(severity: Severity.critical, message: 'Critical thing'),
        Warning(severity: Severity.advisory, message: 'Advisory thing'),
      ]);
      final output = formatSummaryBlock(plan, useColor: true);
      expect(output, contains('\x1B[31m'), reason: 'red for critical');
      expect(output, contains('\x1B[33m'), reason: 'yellow for advisory');
    });
  });
}
