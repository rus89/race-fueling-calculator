// ABOUTME: Renders the plan summary block and grouped warnings section below the plan table.
// ABOUTME: Engine stores ratio as fructose/glucose, so '1:${ratio}' reads as glucose:fructose.
import 'package:race_fueling_core/core.dart';
import 'color.dart';

String formatSummaryBlock(FuelingPlan plan, {required bool useColor}) {
  final buf = StringBuffer();
  final s = plan.summary;

  buf.writeln('');
  buf.writeln(
      useColor ? bold('═══ SUMMARY ═══', enabled: true) : '=== SUMMARY ===');
  buf.writeln('Total carbs:      ${s.totalCarbs.toStringAsFixed(0)}g');
  buf.writeln('Average:          ${s.averageGPerHr.toStringAsFixed(1)}g/hr');
  buf.writeln('Total caffeine:   ${s.totalCaffeineMg.toStringAsFixed(0)}mg');
  buf.writeln(
      'G:F ratio:        1:${s.glucoseFructoseRatio.toStringAsFixed(2)}');
  buf.writeln('Total water:      ${s.totalWaterMl.toStringAsFixed(0)}ml');

  if (s.environmentalNotes.isNotEmpty) {
    buf.writeln('');
    for (final note in s.environmentalNotes) {
      buf.writeln(dim('  $note', enabled: useColor));
    }
  }

  final criticals =
      plan.warnings.where((w) => w.severity == Severity.critical).toList();
  final advisories =
      plan.warnings.where((w) => w.severity == Severity.advisory).toList();

  if (criticals.isNotEmpty || advisories.isNotEmpty) {
    buf.writeln('');
    buf.writeln(useColor
        ? bold('═══ WARNINGS ═══', enabled: true)
        : '=== WARNINGS ===');

    if (criticals.isNotEmpty) {
      buf.writeln(red('CRITICAL:', enabled: useColor));
      for (final w in criticals) {
        buf.writeln(red('  • ${w.message}', enabled: useColor));
      }
    }

    if (advisories.isNotEmpty) {
      buf.writeln(yellow('ADVISORY:', enabled: useColor));
      for (final w in advisories) {
        buf.writeln(yellow('  • ${w.message}', enabled: useColor));
      }
    }
  }

  return buf.toString();
}
