// ABOUTME: RecoveryBanner branches on planProvider error type and saveStatusProvider.
// ABOUTME: Asserts healthy path, storage error path, and save-failure path copy.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:race_fueling_app/data/plan_storage.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
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

  testWidgets('PlanStorageException → discard + retry buttons', (tester) async {
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
  });

  testWidgets('save failure → retry-save banner', (tester) async {
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
  });
}
