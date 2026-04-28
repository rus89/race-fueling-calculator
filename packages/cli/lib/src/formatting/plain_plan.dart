// ABOUTME: Minimal plain-text formatter for a FuelingPlan — one entry per line
// ABOUTME: with clock time, product, carbs, and a summary tail. No colors.
import 'package:race_fueling_core/core.dart';

/// Formats [plan] as plain text suitable for stdout. The output is one line
/// per timeline entry followed by a summary block. Phase 7 replaces this with
/// a richer formatter.
String formatPlanText(FuelingPlan plan) {
  final buffer = StringBuffer();

  if (plan.entries.isEmpty) {
    buffer.writeln('(no timeline entries)');
  } else {
    for (final entry in plan.entries) {
      buffer.writeln(_formatEntry(entry));
    }
  }

  buffer.writeln('');
  buffer.writeln('Summary:');
  buffer.writeln('  Total carbs:    ${_g(plan.summary.totalCarbs)}g');
  buffer.writeln(
    '  Average rate:   ${_g(plan.summary.averageGPerHr)}g/hr',
  );
  buffer.writeln(
    '  Total caffeine: ${_g(plan.summary.totalCaffeineMg)}mg',
  );
  buffer.writeln(
    '  Total water:    ${_g(plan.summary.totalWaterMl)}ml',
  );
  buffer.writeln('  Warnings:       ${plan.warnings.length}');

  if (plan.warnings.isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('Warnings:');
    for (final warning in plan.warnings) {
      buffer.writeln('  [${warning.severity.name}] ${warning.message}');
    }
  }

  return buffer.toString();
}

String _formatEntry(PlanEntry entry) {
  final time = _clock(entry.timeMark);
  final products = entry.products.isEmpty
      ? '(rest)'
      : entry.products.map((s) => '${s.productName} x${s.servings}').join(', ');
  return '$time  $products  '
      '(${_g(entry.carbsTotal)}g this slot, '
      '${_g(entry.cumulativeCarbs)}g total)';
}

/// Formats a [Duration] as `h:mm` clock time (e.g. `0:20`, `2:45`).
String _clock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '$h:$m';
}

String _g(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}
