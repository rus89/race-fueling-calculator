// ABOUTME: Tests for plan table rendering with explicit useColor contract.
// ABOUTME: Covers shape, distance-mode column, ANSI stripping, truncation, and alignment.
import 'package:test/test.dart';
import 'package:race_fueling_cli/src/formatting/color.dart';
import 'package:race_fueling_cli/src/formatting/plan_table.dart';
import 'package:race_fueling_core/core.dart';

void main() {
  final testConfig = RaceConfig(
    name: 'Test Race',
    duration: Duration(hours: 2),
    timelineMode: TimelineMode.timeBased,
    intervalMinutes: 20,
    targetCarbsGPerHr: 75.0,
    strategy: Strategy.steady,
    selectedProducts: [],
  );

  PlanEntry entry({
    Duration timeMark = const Duration(minutes: 20),
    double? distanceMark,
    List<ProductServing> products = const [],
    double carbsTotal = 25.0,
    double cumulativeCarbs = 25.0,
    double cumulativeCaffeine = 0.0,
    double waterMl = 100.0,
  }) {
    return PlanEntry(
      timeMark: timeMark,
      distanceMark: distanceMark,
      products: products,
      carbsGlucose: 15.0,
      carbsFructose: 10.0,
      carbsTotal: carbsTotal,
      cumulativeCarbs: cumulativeCarbs,
      cumulativeCaffeine: cumulativeCaffeine,
      waterMl: waterMl,
    );
  }

  PlanSummary summary() => PlanSummary(
        totalCarbs: 50.0,
        averageGPerHr: 75.0,
        totalCaffeineMg: 0.0,
        glucoseFructoseRatio: 0.67,
        totalWaterMl: 200.0,
      );

  group('formatPlanTable — shape (time-based)', () {
    test('emits headers, divider, and one row per entry', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(
                productId: 'gel-1', productName: 'Test Gel', servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('Time'));
      expect(output, contains('Product'));
      expect(output, contains('Carbs'));
      expect(output, contains('Cumul.'));
      expect(output, contains('Caffeine'));
      expect(output, contains('Water'));
      expect(output, contains('0:20'));
      expect(output, contains('Test Gel'));
      expect(output, isNot(contains('Dist'))); // time-based plan: no Dist col
    });
  });

  group('formatPlanTable — distance mode', () {
    test('inserts Dist column when any entry has distanceMark != null', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(distanceMark: 10.0, products: [
            ProductServing(
                productId: 'gel-1', productName: 'Test Gel', servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('Dist'));
      expect(output, contains('10km'));
    });
  });

  group('formatPlanTable — color contract', () {
    test('useColor: false output contains zero ANSI escapes', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(
                productId: 'gel-1', productName: 'Test Gel', servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output.contains('\x1B'), isFalse);
    });
  });

  group('formatPlanTable — truncation', () {
    test('truncates Product cell to 24 visible chars + ellipsis', () {
      final longName = 'A' * 40;
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(productId: 'p1', productName: longName, servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('${'A' * 24}…'));
      expect(output, isNot(contains('A' * 25)));
    });
  });

  group('formatPlanTable — alignment with colored content', () {
    test('divider line and content row have matching visible width', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(
                productId: 'gel-1', productName: 'Test Gel', servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: true);
      final lines = output.split('\n').where((l) => l.isNotEmpty).toList();
      // Find the divider (made entirely of '─') and the first content row.
      final dividerIdx = lines.indexWhere((l) => l.startsWith('─'));
      expect(dividerIdx, greaterThan(0));
      final dividerWidth = visibleWidth(lines[dividerIdx]);
      final headerWidth = visibleWidth(lines[dividerIdx - 1]);
      final rowWidth = visibleWidth(lines[dividerIdx + 1]);
      expect(headerWidth, dividerWidth);
      expect(rowWidth, dividerWidth);
    });

    // Per-entry severity colors (red/yellow) are scoped to the summary block
    // (Task 7.3). The table layer only emits bold (header) and dim (empty
    // product cell). This assertion documents that color IS being applied
    // here, even though severity is not.
    test('emits ANSI bold escape on header when useColor: true', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(
                productId: 'gel-1', productName: 'Test Gel', servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: true);

      expect(output.contains('\x1B[1m'), isTrue,
          reason: 'header should be bolded under useColor: true');
    });
  });

  group('formatPlanTable — empty entries', () {
    test('renders header and divider only when entries list is empty', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);
      final lines = output.split('\n').where((l) => l.isNotEmpty).toList();

      expect(lines, hasLength(2));
      expect(lines[0], contains('Time'));
      expect(lines[0], contains('Product'));
      expect(lines[1].startsWith('─'), isTrue);
    });
  });

  group('formatPlanTable — empty product cell', () {
    test('renders plain "—" without ANSI when useColor: false', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [entry(products: const [])],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('—'));
      expect(output.contains('\x1B'), isFalse);
    });

    test('wraps "—" in dim ANSI escape when useColor: true', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [entry(products: const [])],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: true);

      expect(output, contains('\x1B[2m—\x1B[0m'));
    });
  });

  group('formatPlanTable — zero-value cells', () {
    test('renders "—" for cumulativeCaffeine of 0', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(
            products: [
              ProductServing(
                  productId: 'gel-1', productName: 'Test Gel', servings: 1),
            ],
            cumulativeCaffeine: 0.0,
            waterMl: 100.0,
          ),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      // Only the caffeine cell should hold an em-dash; products and water
      // are populated.
      expect(output, contains('—'));
      expect(output, isNot(contains('mg')));
    });

    test('renders "—" for waterMl of 0', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(
            products: [
              ProductServing(
                  productId: 'gel-1', productName: 'Test Gel', servings: 1),
            ],
            cumulativeCaffeine: 50.0,
            waterMl: 0.0,
          ),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('—'));
      expect(output, isNot(contains('ml')));
    });
  });

  group('formatPlanTable — product rendering', () {
    test('appends " x<n>" suffix when servings > 1', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(
                productId: 'gel-1', productName: 'Test Gel', servings: 2),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('Test Gel x2'));
    });

    test('joins multiple products on one entry with ", "', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(productId: 'p1', productName: 'A', servings: 1),
            ProductServing(productId: 'p2', productName: 'B', servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('A, B'));
    });
  });

  group('formatPlanTable — mixed time/distance entries', () {
    test(
        'shows Dist column when any entry has distanceMark, '
        'leaves null entries blank, and preserves alignment', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(
            timeMark: const Duration(minutes: 20),
            distanceMark: 10.0,
            products: [
              ProductServing(
                  productId: 'p1', productName: 'Gel A', servings: 1),
            ],
          ),
          entry(
            timeMark: const Duration(minutes: 40),
            // distanceMark intentionally null
            products: [
              ProductServing(
                  productId: 'p2', productName: 'Gel B', servings: 1),
            ],
          ),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);
      final lines = output.split('\n').where((l) => l.isNotEmpty).toList();

      // Header must include Dist column.
      expect(lines[0], contains('Dist'));
      expect(output, isNot(contains('null')));

      // Header, divider, and both content rows must have identical
      // visible width.
      final dividerIdx = lines.indexWhere((l) => l.startsWith('─'));
      expect(dividerIdx, greaterThan(0));
      final dividerWidth = visibleWidth(lines[dividerIdx]);
      expect(visibleWidth(lines[dividerIdx - 1]), dividerWidth);
      expect(visibleWidth(lines[dividerIdx + 1]), dividerWidth);
      expect(visibleWidth(lines[dividerIdx + 2]), dividerWidth);
    });
  });

  group('formatPlanTable — truncation boundary', () {
    test('keeps product cell of exactly 25 visible chars without ellipsis', () {
      final exact25 = 'A' * 25;
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(productId: 'p1', productName: exact25, servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains(exact25));
      expect(output, isNot(contains('…')));
    });

    test('truncates product cell of 26 visible chars to 24 chars + ellipsis',
        () {
      final overflow26 = 'A' * 26;
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(products: [
            ProductServing(
                productId: 'p1', productName: overflow26, servings: 1),
          ]),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('${'A' * 24}…'));
      expect(output, isNot(contains('A' * 25)));
    });
  });
}
