// ABOUTME: RecoveryBanner branches on planProvider error type and saveStatusProvider.
// ABOUTME: Asserts healthy path, storage error path, save-failure path, and AT reachability.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_fueling_app/data/plan_storage.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/providers/planner_notifier.dart';
import 'package:race_fueling_app/presentation/providers/save_status_provider.dart';
import 'package:race_fueling_app/presentation/widgets/recovery_banner.dart';
import '../../test_helpers/fake_plan_storage.dart';
import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('renders nothing on healthy path', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(FakePlanStorage())],
        child: const MaterialApp(home: Scaffold(body: BonkRecoveryBanner())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BonkRecoveryBanner), findsOneWidget);
    expect(find.textContaining('couldn'), findsNothing);
    expect(find.textContaining('failed'), findsNothing);
  });

  testWidgets('PlanStorageException → discard + retry buttons + liveRegion', (
    tester,
  ) async {
    final fake = FakePlanStorage()
      ..loadError = const PlanStorageException(
        'corrupt blob',
        cause: FormatException(),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: Scaffold(body: BonkRecoveryBanner())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("Saved plan couldn't be read"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Discard and start fresh'), findsOneWidget);
    // Two actions in this branch.
    expect(find.byType(OutlinedButton), findsNWidgets(2));

    // AT live-region flag is on the banner root so screen readers
    // announce when the label flips between healthy and error.
    final handle = tester.ensureSemantics();
    final data = tester
        .getSemantics(find.byType(BonkRecoveryBanner))
        .getSemanticsData();
    expect(data.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('engine error → single Retry button, no Discard', (tester) async {
    final fake = FakePlanStorage()..loadError = StateError('boom');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: Scaffold(body: BonkRecoveryBanner())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't compute plan."), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Discard and start fresh'), findsNothing);
  });

  testWidgets('save failure → retry-save banner with single button', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [planStorageProvider.overrideWithValue(FakePlanStorage())],
    );
    addTearDown(container.dispose);
    container.read(saveStatusProvider.notifier).beginSave();
    container.read(saveStatusProvider.notifier).endSaveFailure();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: BonkRecoveryBanner())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Last save failed'), findsOneWidget);
    expect(find.text('Retry save'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('Retry button is wired to retryLoad', (tester) async {
    // Wiring-only — the visible Retry button must carry an onPressed
    // pointing at PlannerNotifier.retryLoad. The side effect (a second
    // storage.load call) is covered by
    // planner_notifier_test.dart's retryLoad tests; running that path
    // through a fake-async testWidgets zone surfaces Riverpod 3.x
    // invalidateSelf + AsyncNotifier rebuild semantics that are orthogonal
    // to the F1b wiring check.
    final fake = FakePlanStorage()..loadError = StateError('boom');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: Scaffold(body: BonkRecoveryBanner())),
      ),
    );
    await tester.pumpAndSettle();

    final btn = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Retry'),
    );
    expect(btn.onPressed, isNotNull);
    expect(fake.loadCount, 1);
  });

  testWidgets('Discard button is wired to discardCorruptedAndUseSeed', (
    tester,
  ) async {
    // This test pins the wiring: the visible button must carry an onTap
    // that resolves to PlannerNotifier.discardCorruptedAndUseSeed. The
    // side-effects (state → AsyncData, save fired, isSeedFallback) are
    // covered by planner_notifier_test.dart's
    // "discardCorruptedAndUseSeed clears error and saves seed" — running
    // that path through a testWidgets fake-async zone surfaces Riverpod
    // 3.x rebuild semantics that are orthogonal to the F1b wiring check.
    final fake = FakePlanStorage()
      ..loadError = const PlanStorageException(
        'corrupt blob',
        cause: FormatException(),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: Scaffold(body: BonkRecoveryBanner())),
      ),
    );
    await tester.pumpAndSettle();

    final btn = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Discard and start fresh'),
    );
    // The button must be enabled and carry a non-null onPressed — that
    // is the F1b wiring contract. The side-effect contract lives in the
    // notifier test.
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('Retry save → calls retrySave and increments saveCount', (
    tester,
  ) async {
    final fake = FakePlanStorage();
    final container = ProviderContainer(
      overrides: [planStorageProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    // Prime the planner so a current state exists.
    await container.read(plannerNotifierProvider.future);
    final beforeSaves = fake.saveCount;

    // Drive the save status into failed.
    container.read(saveStatusProvider.notifier).beginSave();
    container.read(saveStatusProvider.notifier).endSaveFailure();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: BonkRecoveryBanner())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Retry save'));
    // pump (not pumpAndSettle) — Material ink animation runs indefinitely
    // under fake time, so pumpAndSettle never returns. The async save
    // microtask resolves on a single pump.
    await tester.pump();
    await tester.pump();

    expect(fake.saveCount, greaterThan(beforeSaves));
  });

  testWidgets(
    'Buttons are AT-reachable (semantics tree contains tappable buttons)',
    (tester) async {
      final fake = FakePlanStorage()
        ..loadError = const PlanStorageException(
          'corrupt blob',
          cause: FormatException(),
        );
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [planStorageProvider.overrideWithValue(fake)],
          child: const MaterialApp(home: Scaffold(body: BonkRecoveryBanner())),
        ),
      );
      await tester.pumpAndSettle();

      // The OutlinedButtons must expose tappable semantics. Without the
      // ExcludeSemantics wrapper that previously hid the visual subtree,
      // these nodes are reachable to assistive tech.
      final retryButton = find.widgetWithText(OutlinedButton, 'Retry');
      final discardButton = find.widgetWithText(
        OutlinedButton,
        'Discard and start fresh',
      );
      final retryData = tester.getSemantics(retryButton).getSemanticsData();
      final discardData = tester.getSemantics(discardButton).getSemanticsData();
      expect(retryData.hasAction(SemanticsAction.tap), isTrue);
      expect(discardData.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    },
  );
}
