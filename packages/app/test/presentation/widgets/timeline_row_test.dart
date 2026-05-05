// ABOUTME: Widget tests for TimelineRow — bar geometry, items list, aid markers.
// ABOUTME: Covers cumulative readout, sip-bottle line, and aid station marker.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/widgets/timeline_row.dart';
import 'package:race_fueling_core/core.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders cumulative carbs readout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineRow(
            entry: PlanEntry(
              timeMark: Duration(minutes: 30),
              products: [],
              carbsGlucose: 7,
              carbsFructose: 6,
              carbsTotal: 13,
              cumulativeCarbs: 26,
              cumulativeCaffeine: 0,
              waterMl: 125,
              effectiveDrinkCarbs: 13,
            ),
            targetG: 20,
            peakG: 25,
            productsById: {},
          ),
        ),
      ),
    );
    expect(find.textContaining('26', findRichText: true), findsWidgets);
  });

  testWidgets('shows aid station marker when entry has aidStation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineRow(
            entry: PlanEntry(
              timeMark: Duration(minutes: 90),
              products: [],
              carbsGlucose: 0,
              carbsFructose: 0,
              carbsTotal: 0,
              cumulativeCarbs: 50,
              cumulativeCaffeine: 0,
              waterMl: 0,
              aidStation: AidStation(timeMinutes: 90, refill: ['x']),
            ),
            targetG: 20,
            peakG: 25,
            productsById: {},
          ),
        ),
      ),
    );
    expect(find.textContaining('AID STATION'), findsOneWidget);
  });

  testWidgets('shows sip-bottle line when only effectiveDrinkCarbs > 0', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineRow(
            entry: PlanEntry(
              timeMark: Duration(minutes: 30),
              products: [],
              carbsGlucose: 7,
              carbsFructose: 6,
              carbsTotal: 13,
              cumulativeCarbs: 26,
              cumulativeCaffeine: 0,
              waterMl: 125,
              effectiveDrinkCarbs: 13,
            ),
            targetG: 20,
            peakG: 25,
            productsById: {},
          ),
        ),
      ),
    );
    expect(find.textContaining('sipping bottle'), findsOneWidget);
  });
}
