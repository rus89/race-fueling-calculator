// ABOUTME: Renders the fueling plan as a formatted terminal table with explicit color contract.
// ABOUTME: Inserts a Dist column for distance-based plans; truncates long product names.
import 'package:race_fueling_core/core.dart';
import 'color.dart';

const _separator = ' │ '; // 3 visible chars between columns

String formatPlanTable(FuelingPlan plan, {required bool useColor}) {
  final buf = StringBuffer();
  final hasDistance = plan.entries.any((e) => e.distanceMark != null);

  final headers = <String>[
    'Time',
    if (hasDistance) 'Dist',
    'Product',
    'Carbs (G+F)',
    'Cumul.',
    'Caffeine',
    'Water',
  ];
  final widths = <int>[
    8,
    if (hasDistance) 7,
    25,
    14,
    8,
    10,
    8,
  ];

  final totalWidth =
      widths.reduce((a, b) => a + b) + (widths.length - 1) * _separator.length;

  buf.writeln(_row(headers, widths, useColor: useColor, bolded: true));
  buf.writeln('─' * totalWidth);

  for (final entry in plan.entries) {
    final cells = <String>[
      _formatDuration(entry.timeMark),
      if (hasDistance)
        entry.distanceMark != null
            ? '${entry.distanceMark!.toStringAsFixed(0)}km'
            : '',
      _productCell(entry, useColor: useColor),
      '${entry.carbsTotal.toStringAsFixed(0)}g (${entry.carbsGlucose.toStringAsFixed(0)}+${entry.carbsFructose.toStringAsFixed(0)})',
      '${entry.cumulativeCarbs.toStringAsFixed(0)}g',
      entry.cumulativeCaffeine > 0
          ? '${entry.cumulativeCaffeine.toStringAsFixed(0)}mg'
          : '—',
      entry.waterMl > 0 ? '${entry.waterMl.toStringAsFixed(0)}ml' : '—',
    ];

    buf.writeln(_row(cells, widths, useColor: useColor));
  }

  return buf.toString();
}

String _productCell(PlanEntry entry, {required bool useColor}) {
  if (entry.products.isEmpty) {
    return dim('—', enabled: useColor);
  }
  final raw = entry.products
      .map((p) => '${p.productName}${p.servings > 1 ? " x${p.servings}" : ""}')
      .join(', ');
  // Truncate to 24 visible chars + ellipsis when overflowing the 25-wide cell.
  if (visibleWidth(raw) > 25) {
    return '${raw.substring(0, 24)}…';
  }
  return raw;
}

String _row(
  List<String> cells,
  List<int> widths, {
  required bool useColor,
  bool bolded = false,
}) {
  final parts = <String>[
    for (var i = 0; i < cells.length; i++) padVisibleRight(cells[i], widths[i]),
  ];
  final line = parts.join(_separator);
  return bolded ? bold(line, enabled: useColor) : line;
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return '$h:${m.toString().padLeft(2, '0')}';
}
