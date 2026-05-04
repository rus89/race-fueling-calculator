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
          entry(
            products: [
              ProductServing(
                productId: 'gel-1',
                productName: 'Test Gel',
                servings: 1,
              ),
            ],
          ),
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
          entry(
            distanceMark: 10.0,
            products: [
              ProductServing(
                productId: 'gel-1',
                productName: 'Test Gel',
                servings: 1,
              ),
            ],
          ),
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
          entry(
            products: [
              ProductServing(
                productId: 'gel-1',
                productName: 'Test Gel',
                servings: 1,
              ),
            ],
          ),
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
          entry(
            products: [
              ProductServing(
                productId: 'p1',
                productName: longName,
                servings: 1,
              ),
            ],
          ),
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
          entry(
            products: [
              ProductServing(
                productId: 'gel-1',
                productName: 'Test Gel',
                servings: 1,
              ),
            ],
          ),
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
          entry(
            products: [
              ProductServing(
                productId: 'gel-1',
                productName: 'Test Gel',
                servings: 1,
              ),
            ],
          ),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: true);

      expect(
        output.contains('\x1B[1m'),
        isTrue,
        reason: 'header should be bolded under useColor: true',
      );
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
      expect(lines[1].startsWith('-'), isTrue);
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
                productId: 'gel-1',
                productName: 'Test Gel',
                servings: 1,
              ),
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
                productId: 'gel-1',
                productName: 'Test Gel',
                servings: 1,
              ),
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
          entry(
            products: [
              ProductServing(
                productId: 'gel-1',
                productName: 'Test Gel',
                servings: 2,
              ),
            ],
          ),
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
          entry(
            products: [
              ProductServing(productId: 'p1', productName: 'A', servings: 1),
              ProductServing(productId: 'p2', productName: 'B', servings: 1),
            ],
          ),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains('A, B'));
    });
  });

  group('formatPlanTable — mixed time/distance entries', () {
    test('shows Dist column when any entry has distanceMark, '
        'leaves null entries blank, and preserves alignment', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(
            timeMark: const Duration(minutes: 20),
            distanceMark: 10.0,
            products: [
              ProductServing(
                productId: 'p1',
                productName: 'Gel A',
                servings: 1,
              ),
            ],
          ),
          entry(
            timeMark: const Duration(minutes: 40),
            // distanceMark intentionally null
            products: [
              ProductServing(
                productId: 'p2',
                productName: 'Gel B',
                servings: 1,
              ),
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
      final dividerIdx = lines.indexWhere((l) => l.startsWith('-'));
      expect(dividerIdx, greaterThan(0));
      final dividerWidth = visibleWidth(lines[dividerIdx]);
      expect(visibleWidth(lines[dividerIdx - 1]), dividerWidth);
      expect(visibleWidth(lines[dividerIdx + 1]), dividerWidth);
      expect(visibleWidth(lines[dividerIdx + 2]), dividerWidth);
    });
  });

  group('formatPlanTable — ASCII fallback under useColor: false', () {
    FuelingPlan multiRowPlan() => FuelingPlan(
      raceConfig: testConfig,
      entries: [
        entry(
          timeMark: const Duration(minutes: 20),
          products: [
            ProductServing(productId: 'p1', productName: 'Gel A', servings: 1),
          ],
        ),
        entry(
          timeMark: const Duration(minutes: 40),
          products: [
            ProductServing(productId: 'p2', productName: 'Gel B', servings: 2),
          ],
          cumulativeCaffeine: 50.0,
        ),
      ],
      summary: summary(),
    );

    test('uses ASCII pipe " | " separator and not Unicode " │ "', () {
      final output = formatPlanTable(multiRowPlan(), useColor: false);

      expect(output, contains(' | '));
      expect(output, isNot(contains(' │ ')));
    });

    test('divider line is built from ASCII "-" characters', () {
      final output = formatPlanTable(multiRowPlan(), useColor: false);

      expect(output, contains('-' * 10));
    });

    test('output contains zero box-drawing characters', () {
      final output = formatPlanTable(multiRowPlan(), useColor: false);

      expect(output, isNot(matches(RegExp(r'[│─]'))));
    });

    test('divider and every content row share identical visible width', () {
      final output = formatPlanTable(multiRowPlan(), useColor: false);
      final lines = output.split('\n').where((l) => l.isNotEmpty).toList();
      final dividerIdx = lines.indexWhere((l) => l.startsWith('-'));

      expect(dividerIdx, greaterThan(0));
      final dividerWidth = visibleWidth(lines[dividerIdx]);
      // Header above the divider must match.
      expect(visibleWidth(lines[dividerIdx - 1]), dividerWidth);
      // Every content row below the divider must match.
      for (var i = dividerIdx + 1; i < lines.length; i++) {
        expect(
          visibleWidth(lines[i]),
          dividerWidth,
          reason: 'row $i width mismatch',
        );
      }
    });
  });

  group('formatPlanTable — Unicode glyphs under useColor: true', () {
    test('divider line is built from Unicode "─" characters', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(
            products: [
              ProductServing(
                productId: 'gel-1',
                productName: 'Test Gel',
                servings: 1,
              ),
            ],
          ),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: true);

      expect(output, contains('─' * 10));
      expect(output, contains(' │ '));
    });
  });

  group('formatPlanTable — sip-bottle continuation', () {
    test(
      'renders sip placeholder when products empty and effectiveDrinkCarbs > 0',
      () {
        final plan = FuelingPlan(
          raceConfig: testConfig,
          entries: [
            PlanEntry(
              timeMark: const Duration(minutes: 30),
              products: const [],
              carbsGlucose: 7,
              carbsFructose: 6,
              carbsTotal: 13,
              cumulativeCarbs: 13,
              cumulativeCaffeine: 0,
              waterMl: 125,
              effectiveDrinkCarbs: 13,
            ),
          ],
          summary: summary(),
        );

        final output = formatPlanTable(plan, useColor: false);

        expect(output, contains('sip'));
        expect(output, contains('13g'));
      },
    );

    test('does not render sip placeholder when effectiveDrinkCarbs is 0', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          PlanEntry(
            timeMark: const Duration(minutes: 30),
            products: const [],
            carbsGlucose: 0,
            carbsFructose: 0,
            carbsTotal: 0,
            cumulativeCarbs: 0,
            cumulativeCaffeine: 0,
            waterMl: 0,
          ),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output.toLowerCase(), isNot(contains('sip')));
    });
  });

  group('formatPlanTable — aid-station marker', () {
    test('renders AID marker with refill list above the entry row', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          PlanEntry(
            timeMark: const Duration(minutes: 90),
            products: const [],
            carbsGlucose: 0,
            carbsFructose: 0,
            carbsTotal: 0,
            cumulativeCarbs: 50,
            cumulativeCaffeine: 0,
            waterMl: 0,
            aidStation: const AidStation(
              timeMinutes: 90,
              refill: ['sis-beta-fuel-drink', 'maurten-160'],
            ),
          ),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output.toUpperCase(), contains('AID'));
      expect(output, contains('90'));
      expect(output, contains('sis-beta-fuel-drink'));
      expect(output, contains('maurten-160'));
    });

    test('renders AID marker with no-refill placeholder when refill empty', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          PlanEntry(
            timeMark: const Duration(minutes: 60),
            products: const [],
            carbsGlucose: 0,
            carbsFructose: 0,
            carbsTotal: 0,
            cumulativeCarbs: 30,
            cumulativeCaffeine: 0,
            waterMl: 0,
            aidStation: const AidStation(timeMinutes: 60),
          ),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output.toUpperCase(), contains('AID'));
      expect(output.toLowerCase(), contains('no refill'));
    });

    test('does not render AID marker for entries without aidStation', () {
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(
            products: [
              ProductServing(
                productId: 'gel-1',
                productName: 'Test Gel',
                servings: 1,
              ),
            ],
          ),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output.toUpperCase(), isNot(contains('AID')));
    });
  });

  group('formatPlanTable — truncation boundary', () {
    test('keeps product cell of exactly 25 visible chars without ellipsis', () {
      final exact25 = 'A' * 25;
      final plan = FuelingPlan(
        raceConfig: testConfig,
        entries: [
          entry(
            products: [
              ProductServing(
                productId: 'p1',
                productName: exact25,
                servings: 1,
              ),
            ],
          ),
        ],
        summary: summary(),
      );

      final output = formatPlanTable(plan, useColor: false);

      expect(output, contains(exact25));
      expect(output, isNot(contains('…')));
    });

    test(
      'truncates product cell of 26 visible chars to 24 chars + ellipsis',
      () {
        final overflow26 = 'A' * 26;
        final plan = FuelingPlan(
          raceConfig: testConfig,
          entries: [
            entry(
              products: [
                ProductServing(
                  productId: 'p1',
                  productName: overflow26,
                  servings: 1,
                ),
              ],
            ),
          ],
          summary: summary(),
        );

        final output = formatPlanTable(plan, useColor: false);

        expect(output, contains('${'A' * 24}…'));
        expect(output, isNot(contains('A' * 25)));
      },
    );
  });
}
