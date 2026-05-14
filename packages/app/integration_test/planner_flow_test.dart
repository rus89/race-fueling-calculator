// ABOUTME: End-to-end smoke flow — load defaults, raise target above gut
// ABOUTME: tolerance via the notifier, confirm validator warning renders.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:race_fueling_app/app.dart';
import 'package:race_fueling_app/presentation/providers/planner_notifier.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'default plan loads and target above gut tolerance triggers warning',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: BonkApp()));
      await tester.pumpAndSettle();

      // Seed plan should be visible.
      expect(find.text('Andalucía Bike Race — Stage 3'), findsOneWidget);
      expect(find.textContaining('Target intake — 80 g/hr'), findsOneWidget);

      // Push the target above gut tolerance via the notifier. Tester.drag on
      // a Slider is non-deterministic across surface sizes — driving the
      // notifier directly keeps the test stable while still exercising the
      // recompute + warning path end-to-end. The seed gutToleranceGPerHr is
      // 75 g/hr; 110 sits comfortably above the 1.15× threshold.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BonkApp)),
      );
      container
          .read(plannerNotifierProvider.notifier)
          .updateRaceConfig((c) => c.copyWith(targetCarbsGPerHr: 110));
      await tester.pumpAndSettle();

      // Validator emits 'Exceeding gut tolerance: 110g/hr ...' (see
      // plan_validator.dart). Match the engine's actual copy.
      expect(find.textContaining('Exceeding gut tolerance'), findsOneWidget);
    },
  );
}
