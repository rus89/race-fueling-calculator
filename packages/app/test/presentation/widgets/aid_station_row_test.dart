// ABOUTME: Widget tests for AidStationRow — toggle, refill chips, remove.
// ABOUTME: Verifies time/distance switch emits correctly and onRemove fires.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/domain/domain.dart';
import 'package:race_fueling_app/presentation/widgets/aid_station_row.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders min unit when station is time-based', (tester) async {
    await tester.pumpWidget(
      wrap(
        AidStationRow(
          station: const AidStation(timeMinutes: 90),
          library: const [],
          onChanged: (_) {},
          onRemove: () {},
        ),
      ),
    );
    expect(find.text('min'), findsOneWidget);
  });

  testWidgets('renders km unit when station is distance-based', (tester) async {
    await tester.pumpWidget(
      wrap(
        AidStationRow(
          station: const AidStation(distanceKm: 25.0),
          library: const [],
          onChanged: (_) {},
          onRemove: () {},
        ),
      ),
    );
    expect(find.text('km'), findsOneWidget);
  });

  testWidgets('switching to distance emits a station with null timeMinutes', (
    tester,
  ) async {
    AidStation? captured;
    await tester.pumpWidget(
      wrap(
        AidStationRow(
          station: const AidStation(timeMinutes: 90),
          library: const [],
          onChanged: (s) => captured = s,
          onRemove: () {},
        ),
      ),
    );
    await tester.tap(find.text('Distance'));
    await tester.pump();
    expect(captured?.timeMinutes, isNull);
    expect(captured?.distanceKm, isNotNull);
  });

  testWidgets('toggle to distance clears the prior time value (Q2=C)', (
    tester,
  ) async {
    AidStation? captured;
    await tester.pumpWidget(
      wrap(
        AidStationRow(
          station: const AidStation(timeMinutes: 90),
          library: const [],
          onChanged: (s) => captured = s,
          onRemove: () {},
        ),
      ),
    );
    await tester.tap(find.text('Distance'));
    await tester.pump();
    // The active unit's value is reset to the 0 sentinel — user re-types.
    expect(captured?.distanceKm, 0.0);
  });

  testWidgets('toggle to time clears the prior distance value (Q2=C)', (
    tester,
  ) async {
    AidStation? captured;
    await tester.pumpWidget(
      wrap(
        AidStationRow(
          station: const AidStation(distanceKm: 25.0),
          library: const [],
          onChanged: (s) => captured = s,
          onRemove: () {},
        ),
      ),
    );
    await tester.tap(find.text('Time'));
    await tester.pump();
    expect(captured?.distanceKm, isNull);
    expect(captured?.timeMinutes, 0);
  });

  testWidgets('tapping the remove icon fires onRemove', (tester) async {
    var removed = false;
    await tester.pumpWidget(
      wrap(
        AidStationRow(
          station: const AidStation(timeMinutes: 90),
          library: const [],
          onChanged: (_) {},
          onRemove: () => removed = true,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Remove aid station'));
    await tester.pump();
    expect(removed, isTrue);
  });

  testWidgets('typing a new time emits an updated station', (tester) async {
    AidStation? captured;
    await tester.pumpWidget(
      wrap(
        AidStationRow(
          station: const AidStation(timeMinutes: 90),
          library: const [],
          onChanged: (s) => captured = s,
          onRemove: () {},
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '120');
    await tester.pump();
    expect(captured?.timeMinutes, 120);
  });

  testWidgets('refill chip remove emits station without that id', (
    tester,
  ) async {
    AidStation? captured;
    final lib = [
      Product(
        id: 'gel-a',
        brand: 'Maurten',
        name: 'Gel 100',
        type: ProductType.gel,
        carbsPerServing: 25,
      ),
    ];
    await tester.pumpWidget(
      wrap(
        AidStationRow(
          station: const AidStation(timeMinutes: 90, refill: ['gel-a']),
          library: lib,
          onChanged: (s) => captured = s,
          onRemove: () {},
        ),
      ),
    );
    // Find the chip's close IconButton via its tooltip.
    await tester.tap(find.byTooltip('Remove Maurten Gel 100 from refills'));
    await tester.pump();
    expect(captured?.refill, isEmpty);
    expect(captured?.timeMinutes, 90, reason: 'time field preserved');
  });

  testWidgets('+ refill button opens picker and emits selected product', (
    tester,
  ) async {
    AidStation? captured;
    final lib = [
      Product(
        id: 'gel-a',
        brand: 'Maurten',
        name: 'Gel 100',
        type: ProductType.gel,
        carbsPerServing: 25,
      ),
    ];
    await tester.pumpWidget(
      wrap(
        AidStationRow(
          station: const AidStation(timeMinutes: 90),
          library: lib,
          onChanged: (s) => captured = s,
          onRemove: () {},
        ),
      ),
    );
    await tester.tap(find.text('+ refill'));
    await tester.pumpAndSettle();
    // The popup should show the available product.
    expect(find.text('Maurten Gel 100'), findsOneWidget);
    await tester.tap(find.text('Maurten Gel 100'));
    await tester.pumpAndSettle();
    expect(captured?.refill, ['gel-a']);
  });

  testWidgets(
    'shows disabled "All products added" chip when nothing is available',
    (tester) async {
      final lib = [
        Product(
          id: 'gel-a',
          brand: 'Maurten',
          name: 'Gel 100',
          type: ProductType.gel,
          carbsPerServing: 25,
        ),
      ];
      await tester.pumpWidget(
        wrap(
          AidStationRow(
            station: const AidStation(timeMinutes: 90, refill: ['gel-a']),
            library: lib,
            onChanged: (_) {},
            onRemove: () {},
          ),
        ),
      );
      expect(find.text('All products added'), findsOneWidget);
      expect(find.text('+ refill'), findsNothing);
    },
  );
}
