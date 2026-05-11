// ABOUTME: Widget tests for BonkTopbar — save-status dot + liveRegion announces,
// ABOUTME: brand-mark Semantics exclusion, AsyncError plan fallback, textScaler.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/providers/plan_provider.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/providers/save_status_provider.dart';
import 'package:race_fueling_app/presentation/theme/tokens.dart';
import 'package:race_fueling_app/presentation/widgets/topbar.dart';
import 'package:race_fueling_core/core.dart';

import '../../test_helpers/fake_plan_storage.dart';
import '../../test_helpers/google_fonts_setup.dart';

Future<ProviderContainer> _pumpTopbarWithStorage(
  WidgetTester tester,
  FakePlanStorage fake,
) async {
  final container = ProviderContainer(
    overrides: [planStorageProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: BonkTopbar())),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Color? _dotColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byKey(const Key('topbar.saveDot')),
  );
  final decoration = container.decoration as BoxDecoration?;
  return decoration?.color;
}

void main() {
  setUpAll(setUpGoogleFontsForTests);

  testWidgets('idle state: dot = accent + "auto-saved" text', (tester) async {
    await _pumpTopbarWithStorage(tester, FakePlanStorage());
    expect(_dotColor(tester), BonkTokens.accent);
    expect(find.text('· auto-saved'), findsOneWidget);
  });

  testWidgets('inFlight state: dot = ink3 + "saving…" + liveRegion', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final container = await _pumpTopbarWithStorage(tester, FakePlanStorage());
    container.read(saveStatusProvider.notifier).beginSave();
    await tester.pumpAndSettle();

    expect(_dotColor(tester), BonkTokens.ink3);
    expect(find.text('· saving…'), findsOneWidget);

    final data = tester.getSemantics(find.text('· saving…')).getSemanticsData();
    expect(
      data.flagsCollection.isLiveRegion,
      isTrue,
      reason: 'inFlight should be announced by AT',
    );
    handle.dispose();
  });

  testWidgets('failed state: dot = bad + "save failed" + liveRegion', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final container = await _pumpTopbarWithStorage(tester, FakePlanStorage());
    container.read(saveStatusProvider.notifier).beginSave();
    container.read(saveStatusProvider.notifier).endSaveFailure();
    await tester.pumpAndSettle();

    expect(_dotColor(tester), BonkTokens.bad);
    expect(find.text('· save failed'), findsOneWidget);

    final data = tester
        .getSemantics(find.text('· save failed'))
        .getSemanticsData();
    expect(
      data.flagsCollection.isLiveRegion,
      isTrue,
      reason: 'failed should be announced by AT',
    );
    handle.dispose();
  });

  testWidgets(
    'AsyncError on planProvider: plan summary hidden, save dot still renders',
    (tester) async {
      final fake = FakePlanStorage();
      final container = ProviderContainer(
        overrides: [
          planStorageProvider.overrideWithValue(fake),
          planProvider.overrideWith(
            (ref) => AsyncValue<FuelingPlan>.error(
              StateError('boom'),
              StackTrace.current,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: BonkTopbar())),
        ),
      );
      await tester.pumpAndSettle();
      // Plan summary uses the "Plan" eyebrow + 'g · ' interpolation. Both gone.
      expect(find.text('Plan'), findsNothing);
      expect(find.textContaining('g · '), findsNothing);
      // Save dot still renders because asyncState (notifier) has value.
      expect(find.byKey(const Key('topbar.saveDot')), findsOneWidget);
    },
  );

  testWidgets('brand mark is excluded from Semantics (Bonk text is AT name)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpTopbarWithStorage(tester, FakePlanStorage());

    // 'Bonk' text should have a SemanticsNode with label.
    final bonkData = tester.getSemantics(find.text('Bonk')).getSemanticsData();
    expect(bonkData.label, contains('Bonk'));

    // Traverse the full Semantics tree under BonkTopbar; assert no node
    // carries a brand-mark descriptor. The brand circle is decorative.
    final SemanticsNode root = tester.getSemantics(find.byType(BonkTopbar));
    final labels = <String>[];
    void visit(SemanticsNode node) {
      labels.add(node.label);
      node.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(root);
    for (final l in labels) {
      expect(
        l.toLowerCase().contains('mark') ||
            l.toLowerCase() == 'lime' ||
            l.toLowerCase() == 'circle',
        isFalse,
        reason: 'brand mark must be decorative — no AT label',
      );
    }
    handle.dispose();
  });

  testWidgets('survives 200% textScaler without vertical clipping', (
    tester,
  ) async {
    // Wide surface avoids horizontal RenderFlex overflow — out of scope.
    // The regression we're locking is the `height: 44` cap that clipped
    // text vertically at large scales. With minHeight: 44, the bar grows
    // when text intrinsic height exceeds 44.
    await tester.binding.setSurfaceSize(const Size(2400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = FakePlanStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(fake)],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(body: BonkTopbar()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bar grows past 44px at very large text scales (minHeight)', (
    tester,
  ) async {
    // Scaler 4.0 forces 13-pt brand text to ~52px line height — well
    // past the 44px floor. minHeight (not height) lets the bar expand.
    // Wide surface avoids horizontal RenderFlex overflow — orthogonal.
    await tester.binding.setSurfaceSize(const Size(4000, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = FakePlanStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [planStorageProvider.overrideWithValue(fake)],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(4.0)),
            child: Scaffold(
              body: Align(alignment: Alignment.topLeft, child: BonkTopbar()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(BonkTopbar));
    expect(
      size.height,
      greaterThan(44),
      reason: 'minHeight should let the bar grow past 44px',
    );
  });
}
