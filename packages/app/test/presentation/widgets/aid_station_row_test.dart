// ABOUTME: Widget tests for AidStationRow — toggle, refill chips, remove.
// ABOUTME: Verifies time/distance switch emits correctly and onRemove fires.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/domain/domain.dart';
import 'package:race_fueling_app/presentation/widgets/aid_station_row.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders min unit when station is time-based', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AidStationRow(
            station: const AidStation(timeMinutes: 90),
            library: const [],
            onChanged: (_) {},
            onRemove: () {},
          ),
        ),
      ),
    );
    expect(find.text('min'), findsOneWidget);
  });

  testWidgets('switching to distance emits a station with null timeMinutes', (
    tester,
  ) async {
    AidStation? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AidStationRow(
            station: const AidStation(timeMinutes: 90),
            library: const [],
            onChanged: (s) => captured = s,
            onRemove: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Distance'));
    await tester.pump();
    expect(captured?.timeMinutes, isNull);
    expect(captured?.distanceKm, isNotNull);
  });

  testWidgets('tapping the close icon fires onRemove', (tester) async {
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AidStationRow(
            station: const AidStation(timeMinutes: 90),
            library: const [],
            onChanged: (_) {},
            onRemove: () => removed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    expect(removed, isTrue);
  });
}
