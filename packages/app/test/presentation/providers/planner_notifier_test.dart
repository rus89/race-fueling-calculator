// ABOUTME: Unit tests for PlannerNotifier — load + mutate + debounced save.
// ABOUTME: Uses an in-memory FakePlanStorage to assert save side effects.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/domain/planner_state.dart';
import 'package:race_fueling_app/presentation/providers/plan_storage_provider.dart';
import 'package:race_fueling_app/presentation/providers/planner_notifier.dart';
import 'package:race_fueling_app/presentation/providers/save_status_provider.dart';

import '../../test_helpers/fake_plan_storage.dart';

ProviderContainer _makeContainer(FakePlanStorage fake) {
  final c = ProviderContainer(
    overrides: [planStorageProvider.overrideWithValue(fake)],
  );
  return c;
}

// Past the 500 ms debounce window plus a small cushion for microtask drain.
const _pastDebounceWindow = Duration(milliseconds: 600);

void main() {
  test('falls back to seed when storage empty', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    final state = await c.read(plannerNotifierProvider.future);
    expect(state.raceConfig.name, contains('Andalucía'));
    // Empty drive ⇒ first-run seed; the flag flips so the UI can offer a
    // quickstart banner without misreading "Andalucía" as a saved blob.
    expect(state.isSeedFallback, isTrue);
  });

  test('updateRaceConfig persists new state after debounce window', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);

    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 100));

    // State flip is synchronous.
    expect(
      c.read(plannerNotifierProvider).requireValue.raceConfig.targetCarbsGPerHr,
      100,
    );
    // But disk write is deferred — saveStatus already flipped to inFlight on
    // the first dirty tick so the Topbar can show "saving…" while the user
    // is still typing.
    expect(fake.saveCount, 0);
    expect(c.read(saveStatusProvider), SaveStatus.inFlight);

    await Future<void>.delayed(_pastDebounceWindow);

    expect(fake.saveCount, 1);
    expect(fake.lastSaved!.raceConfig.targetCarbsGPerHr, 100);
    expect(c.read(saveStatusProvider), SaveStatus.idle);
  });

  test('loaded state takes precedence over seed', () async {
    // Custom blob — explicitly NOT a seed (user has saved a customised plan).
    final custom = PlannerState.seed().copyWith(
      raceConfig: PlannerState.seed().raceConfig.copyWith(
        name: 'My Custom Race',
      ),
      isSeedFallback: false,
    );
    final fake = FakePlanStorage()..loaded = custom;
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    final state = await c.read(plannerNotifierProvider.future);
    expect(state.raceConfig.name, 'My Custom Race');
    // The persisted flag is authoritative — load doesn't clobber it.
    expect(state.isSeedFallback, isFalse);
  });

  test(
    'loaded blob with isSeedFallback: true survives until first edit',
    () async {
      // Reload after a "Start fresh" recovery: the seed was saved with the
      // flag set, and the UI must keep showing the quickstart banner until
      // the user actually edits something.
      final fake = FakePlanStorage()..loaded = PlannerState.seed();
      final c = _makeContainer(fake);
      addTearDown(c.dispose);
      final state = await c.read(plannerNotifierProvider.future);
      expect(state.isSeedFallback, isTrue);
    },
  );

  test('first user edit flips isSeedFallback to false', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    final initial = await c.read(plannerNotifierProvider.future);
    expect(initial.isSeedFallback, isTrue);

    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 100));
    await Future<void>.delayed(_pastDebounceWindow);

    expect(
      c.read(plannerNotifierProvider).requireValue.isSeedFallback,
      isFalse,
    );
    // The save must reflect the flipped flag — the persisted blob is no
    // longer marked as a fallback once the user has edited it.
    expect(fake.lastSaved!.isSeedFallback, isFalse);
  });

  test('subsequent edits leave isSeedFallback false', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);

    final notifier = c.read(plannerNotifierProvider.notifier);
    notifier.updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 90));
    await Future<void>.delayed(_pastDebounceWindow);
    notifier.updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 100));
    await Future<void>.delayed(_pastDebounceWindow);

    expect(
      c.read(plannerNotifierProvider).requireValue.isSeedFallback,
      isFalse,
    );
  });

  test('updateRaceConfig before build completes is a no-op', () async {
    final fake = FakePlanStorage()..loadGate = Completer<void>();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);

    // Read the notifier without awaiting .future — state is AsyncLoading
    // because the gated load() has not resolved yet.
    final notifier = c.read(plannerNotifierProvider.notifier);
    expect(c.read(plannerNotifierProvider).isLoading, isTrue);

    // Mutator must not throw.
    expect(
      () => notifier.updateRaceConfig(
        (cfg) => cfg.copyWith(targetCarbsGPerHr: 999),
      ),
      returnsNormally,
    );
    // saveCount stays 0 because the early-return short-circuited.
    expect(fake.saveCount, 0);

    // Let the load complete and confirm state then resolves to the seed.
    fake.loadGate!.complete();
    final loaded = await c.read(plannerNotifierProvider.future);
    expect(loaded.raceConfig.targetCarbsGPerHr, isNot(999));
  });

  test('two mutations separated by a debounce gap save in order', () async {
    // With the 500 ms debounce window, mutations spaced far apart fire
    // two distinct saves on the serialized chain.
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);

    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 90));
    await Future<void>.delayed(_pastDebounceWindow);
    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 100));
    await Future<void>.delayed(_pastDebounceWindow);

    expect(fake.saveCount, 2);
    expect(fake.lastSaved!.raceConfig.targetCarbsGPerHr, 100);
  });

  test('rapid edits coalesce into one write with the final payload', () async {
    // 10 successive edits inside the 500 ms debounce window must collapse
    // to a single disk write carrying the final value.
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);

    final n = c.read(plannerNotifierProvider.notifier);
    for (var i = 0; i < 10; i++) {
      n.updateRaceConfig(
        (cfg) => cfg.copyWith(targetCarbsGPerHr: 80 + i.toDouble()),
      );
    }
    expect(fake.saveCount, 0);
    expect(c.read(saveStatusProvider), SaveStatus.inFlight);

    await Future<void>.delayed(_pastDebounceWindow);

    expect(fake.saveCount, 1);
    expect(fake.lastSaved!.raceConfig.targetCarbsGPerHr, 89);
    expect(c.read(saveStatusProvider), SaveStatus.idle);
  });

  test(
    'updateAthleteProfile persists new state after debounce window',
    () async {
      final fake = FakePlanStorage();
      final c = _makeContainer(fake);
      addTearDown(c.dispose);
      await c.read(plannerNotifierProvider.future);
      c
          .read(plannerNotifierProvider.notifier)
          .updateAthleteProfile((p) => p.copyWith(gutToleranceGPerHr: 100));
      expect(
        c
            .read(plannerNotifierProvider)
            .requireValue
            .athleteProfile
            .gutToleranceGPerHr,
        100,
      );
      // Disk write still deferred.
      expect(fake.saveCount, 0);

      await Future<void>.delayed(_pastDebounceWindow);
      expect(fake.saveCount, 1);
      expect(fake.lastSaved!.athleteProfile.gutToleranceGPerHr, 100);
      // raceConfig must NOT have changed.
      expect(
        c
            .read(plannerNotifierProvider)
            .requireValue
            .raceConfig
            .targetCarbsGPerHr,
        PlannerState.seed().raceConfig.targetCarbsGPerHr,
      );
    },
  );

  test(
    'save failure flips saveStatus to failed after debounce window',
    () async {
      final fake = FakePlanStorage()..saveError = StateError('disk full');
      final c = _makeContainer(fake);
      addTearDown(c.dispose);
      await c.read(plannerNotifierProvider.future);

      c
          .read(plannerNotifierProvider.notifier)
          .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 100));
      await Future<void>.delayed(_pastDebounceWindow);

      expect(c.read(saveStatusProvider), SaveStatus.failed);
    },
  );

  test('emits AsyncError when storage load throws', () async {
    final fake = FakePlanStorage()..loadError = StateError('boom');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);

    // Prime the notifier; expect the future to complete with an error.
    final caught = await c
        .read(plannerNotifierProvider.future)
        .then<Object?>((s) => null, onError: (Object e) => e);
    expect(caught, isA<StateError>());
    // The provider's current state should be AsyncError.
    expect(c.read(plannerNotifierProvider).hasError, isTrue);
  });

  test('mutator does not save while state is AsyncError', () async {
    final fake = FakePlanStorage()..loadError = StateError('boom');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);

    await c
        .read(plannerNotifierProvider.future)
        .then<Object?>((s) => null, onError: (Object e) => e);
    expect(c.read(plannerNotifierProvider).hasError, isTrue);

    // A mutation issued while in error state must NOT overwrite the
    // recoverable corrupted blob via a stealth save.
    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 999));
    await Future<void>.delayed(_pastDebounceWindow);

    expect(fake.saveCount, 0);
    expect(c.read(plannerNotifierProvider).hasError, isTrue);
  });

  test('two sequential mutations during AsyncError both no-op', () async {
    final fake = FakePlanStorage()..loadError = StateError('boom');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);

    await c
        .read(plannerNotifierProvider.future)
        .then<Object?>((s) => null, onError: (Object e) => e);

    final notifier = c.read(plannerNotifierProvider.notifier);
    notifier.updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 99));
    notifier.updateAthleteProfile((p) => p.copyWith(gutToleranceGPerHr: 88));
    await Future<void>.delayed(_pastDebounceWindow);

    // Cumulative saves: zero. Both mutations short-circuit on the
    // AsyncError guard so the corrupted blob remains recoverable.
    expect(fake.saveCount, 0);
    expect(c.read(plannerNotifierProvider).hasError, isTrue);
  });

  test('discardCorruptedAndUseSeed clears error and saves seed', () async {
    final fake = FakePlanStorage()..loadError = StateError('boom');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);

    await c
        .read(plannerNotifierProvider.future)
        .then<Object?>((s) => null, onError: (Object e) => e);
    expect(c.read(plannerNotifierProvider).hasError, isTrue);

    c.read(plannerNotifierProvider.notifier).discardCorruptedAndUseSeed();
    // Drain microtasks — destructive recovery flushes the debouncer
    // synchronously so the corrupted blob is overwritten immediately.
    await Future<void>.value();
    await Future<void>.value();

    final after = c.read(plannerNotifierProvider);
    expect(after.hasValue, isTrue);
    expect(after.requireValue.isSeedFallback, isTrue);
    expect(fake.saveCount, 1);
    expect(fake.lastSaved!.isSeedFallback, isTrue);
  });

  test(
    'discardCorruptedAndUseSeed flushes the save immediately (no 500ms wait)',
    () async {
      // Pin the flushNow: true invariant on discardCorruptedAndUseSeed. The
      // destructive recovery must overwrite the corrupted blob on disk
      // before the user can reload — a 500 ms gap leaves the bad payload
      // accessible to a confused reload.
      final fake = FakePlanStorage()..loadError = StateError('corrupted');
      final c = _makeContainer(fake);
      addTearDown(c.dispose);
      // Drain the load future without letting the test framework treat the
      // load error as a test failure. Mirrors the pattern used by every
      // other AsyncError-path test in this file.
      await c
          .read(plannerNotifierProvider.future)
          .then<Object?>((s) => null, onError: (Object e) => e);
      expect(c.read(plannerNotifierProvider).hasError, isTrue);

      c.read(plannerNotifierProvider.notifier).discardCorruptedAndUseSeed();
      // Microtask cycle only — no Future.delayed past the debounce window.
      await Future<void>.value();
      await Future<void>.value();

      expect(fake.saveCount, 1);
      expect(fake.lastSaved!.isSeedFallback, isTrue);
    },
  );

  test(
    'discardCorruptedAndUseSeed is a no-op when state is AsyncData',
    () async {
      final fake = FakePlanStorage();
      final c = _makeContainer(fake);
      addTearDown(c.dispose);
      await c.read(plannerNotifierProvider.future);

      c.read(plannerNotifierProvider.notifier).discardCorruptedAndUseSeed();
      await Future<void>.delayed(_pastDebounceWindow);

      // No extraneous save; the user wasn't in an error state.
      expect(fake.saveCount, 0);
    },
  );

  test(
    'discardCorruptedAndUseSeed is a no-op while load is still in flight',
    () async {
      // Hold the load gate so state stays AsyncLoading. The recovery
      // helper must NOT race-condition itself into firing before the
      // load resolves — that would clobber a soon-to-be-good blob.
      final fake = FakePlanStorage()..loadGate = Completer<void>();
      final c = _makeContainer(fake);
      addTearDown(c.dispose);

      // Materialise the notifier so build() begins running.
      final notifier = c.read(plannerNotifierProvider.notifier);
      expect(c.read(plannerNotifierProvider).isLoading, isTrue);

      notifier.discardCorruptedAndUseSeed();
      await Future<void>.delayed(_pastDebounceWindow);

      expect(fake.saveCount, 0);
      expect(c.read(plannerNotifierProvider).isLoading, isTrue);

      // Let the load complete — state must resolve to the seed normally.
      fake.loadGate!.complete();
      final resolved = await c.read(plannerNotifierProvider.future);
      expect(resolved.raceConfig.name, contains('Andalucía'));
    },
  );

  test(
    'retryLoad transitions AsyncError to AsyncData once storage recovers',
    () async {
      final fake = FakePlanStorage()..loadError = StateError('boom');
      final c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c
          .read(plannerNotifierProvider.future)
          .then<Object?>((s) => null, onError: (Object e) => e);
      expect(c.read(plannerNotifierProvider).hasError, isTrue);

      // Storage recovers (e.g., user fixed permissions, switched browsers, etc.)
      fake.loadError = null;
      await c.read(plannerNotifierProvider.notifier).retryLoad();

      expect(c.read(plannerNotifierProvider).hasValue, isTrue);
      expect(c.read(plannerNotifierProvider).hasError, isFalse);
    },
  );

  test('retryLoad is a no-op when state is AsyncData', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    final beforeSaves = fake.saveCount;

    await c.read(plannerNotifierProvider.notifier).retryLoad();

    expect(fake.saveCount, beforeSaves);
    expect(c.read(plannerNotifierProvider).hasValue, isTrue);
  });

  test('retryLoad stays in AsyncError when storage still fails', () async {
    final fake = FakePlanStorage()..loadError = StateError('boom');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);

    // Prime AsyncError.
    await c
        .read(plannerNotifierProvider.future)
        .then<Object?>((s) => null, onError: (Object e) => e);
    expect(c.read(plannerNotifierProvider).hasError, isTrue);

    // First retry — storage still throws. State must remain AsyncError;
    // no stealth save can land while we're still unrecovered.
    final notifier = c.read(plannerNotifierProvider.notifier);
    await notifier.retryLoad().then<Object?>(
      (_) => null,
      onError: (Object e) => e,
    );
    expect(c.read(plannerNotifierProvider).hasError, isTrue);
    expect(fake.saveCount, 0);

    // Second retry — also throws. No deadlock, no extraneous save.
    await notifier.retryLoad().then<Object?>(
      (_) => null,
      onError: (Object e) => e,
    );
    expect(c.read(plannerNotifierProvider).hasError, isTrue);
    expect(fake.saveCount, 0);
  });

  test('retrySave re-emits current state and triggers a save', () async {
    final fake = FakePlanStorage();
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    final before = fake.saveCount;

    c.read(plannerNotifierProvider.notifier).retrySave();
    // retrySave passes flushNow: true so the save fires on the next
    // microtask cycle — no debounce-window wait.
    await Future<void>.value();
    await Future<void>.value();

    expect(fake.saveCount, before + 1);
  });

  test('retrySave flushes the save immediately (no 500ms wait)', () async {
    // Pin the flushNow: true invariant on retrySave. The user clicked
    // "Retry save" because a previous save failed; they expect an
    // immediate retry, not a debounce-window stall.
    final fake = FakePlanStorage()..saveError = StateError('disk full');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);

    // Drive a save failure by editing the plan and waiting past the window.
    c
        .read(plannerNotifierProvider.notifier)
        .updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 100));
    await Future<void>.delayed(_pastDebounceWindow);
    expect(c.read(saveStatusProvider), SaveStatus.failed);
    final failedCount = fake.saveCount;

    // Recovery: storage works again, user clicks Retry.
    fake.saveError = null;
    c.read(plannerNotifierProvider.notifier).retrySave();
    // Microtask cycle only — no Future.delayed.
    await Future<void>.value();
    await Future<void>.value();

    expect(fake.saveCount, failedCount + 1);
  });

  test('retrySave is a no-op when state has no current value', () async {
    // AsyncError on first build: no prior AsyncData exists. retrySave
    // must not crash and must not flush a save.
    final fake = FakePlanStorage()..loadError = StateError('boom');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);

    await c
        .read(plannerNotifierProvider.future)
        .then<Object?>((s) => null, onError: (Object e) => e);
    expect(c.read(plannerNotifierProvider).hasError, isTrue);

    c.read(plannerNotifierProvider.notifier).retrySave();
    await Future<void>.delayed(_pastDebounceWindow);

    expect(fake.saveCount, 0);
    expect(c.read(plannerNotifierProvider).hasError, isTrue);
  });

  test(
    'resetToSeed restores the seed plan and persists the seed flag',
    () async {
      final fake = FakePlanStorage();
      // Loaded blob is a customised plan, not a seed fallback.
      final custom = PlannerState.seed().copyWith(
        raceConfig: PlannerState.seed().raceConfig.copyWith(name: 'My Race'),
        isSeedFallback: false,
      );
      fake.loaded = custom;
      final c = _makeContainer(fake);
      addTearDown(c.dispose);
      await c.read(plannerNotifierProvider.future);
      expect(
        c.read(plannerNotifierProvider).requireValue.raceConfig.name,
        'My Race',
      );

      // Capture saveCount before the call so the delta assertion is
      // robust to chained saves landing during load/seed boot. LOW#12.
      final beforeCount = fake.saveCount;

      c.read(plannerNotifierProvider.notifier).resetToSeed();
      // resetToSeed passes flushNow: true for symmetry with the other
      // explicit user-intent paths (discardCorruptedAndUseSeed): a
      // "Reset" click is a user-facing immediacy signal — the seed
      // should land on disk on the next microtask, not 500 ms later.
      // Microtask cycle only — no Future.delayed past the debounce window.
      await Future<void>.value();
      await Future<void>.value();

      final after = c.read(plannerNotifierProvider).requireValue;
      expect(after.raceConfig.name, contains('Andalucía'));
      // The seed flag must survive — the explicit "Reset" intent restores
      // the quickstart treatment instead of silently advancing past it.
      expect(after.isSeedFallback, isTrue);
      expect(fake.lastSaved!.isSeedFallback, isTrue);
      // Exactly one save from the resetToSeed call itself.
      expect(fake.saveCount, beforeCount + 1);
    },
  );

  test('resetToSeed flushes the save immediately (no 500ms wait)', () async {
    // MEDIUM #6: resetToSeed is a user-explicit reset action. It should
    // land on disk on the next microtask cycle, matching the symmetry
    // with discardCorruptedAndUseSeed.
    final fake = FakePlanStorage();
    final custom = PlannerState.seed().copyWith(
      raceConfig: PlannerState.seed().raceConfig.copyWith(name: 'My Race'),
      isSeedFallback: false,
    );
    fake.loaded = custom;
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);
    final beforeCount = fake.saveCount;

    c.read(plannerNotifierProvider.notifier).resetToSeed();
    // Microtask cycle only — no Future.delayed.
    await Future<void>.value();
    await Future<void>.value();

    expect(fake.saveCount, beforeCount + 1);
  });

  test('resetToSeed is a no-op while state is AsyncError', () async {
    final fake = FakePlanStorage()..loadError = StateError('boom');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c
        .read(plannerNotifierProvider.future)
        .then<Object?>((s) => null, onError: (Object e) => e);
    expect(c.read(plannerNotifierProvider).hasError, isTrue);

    // Users on a corrupted-blob state must explicitly opt into the
    // destructive recovery path (discardCorruptedAndUseSeed). The healthy
    // resetToSeed must not bypass the AsyncError guard.
    c.read(plannerNotifierProvider.notifier).resetToSeed();
    await Future<void>.delayed(_pastDebounceWindow);

    expect(c.read(plannerNotifierProvider).hasError, isTrue);
    expect(fake.saveCount, 0);
  });

  test(
    'retrySave shows saving… feedback (inFlight) even when a debounce window is pending',
    () async {
      // HIGH #4: pre-fix, `_emitForce` skipped `beginSave()` if the debouncer
      // already had a pending tick — meaning a retry chained behind a fresh
      // edit produced no "saving…" feedback. The retry must always increment
      // pendingCount and (HIGH #5 wiring) clobber the sticky-failed signal
      // back to inFlight so the user sees their click was received.
      final fake = FakePlanStorage()..saveError = StateError('disk full');
      final c = _makeContainer(fake);
      addTearDown(c.dispose);
      await c.read(plannerNotifierProvider.future);

      final notifier = c.read(plannerNotifierProvider.notifier);
      final statusCtrl = c.read(saveStatusProvider.notifier);

      // Drive to failed state.
      notifier.updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 90));
      await Future<void>.delayed(_pastDebounceWindow);
      expect(c.read(saveStatusProvider), SaveStatus.failed);

      // Storage recovers. Start a fresh edit mid-window, then immediately
      // press Retry. The retry must still register saving… feedback.
      fake.saveError = null;
      notifier.updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 95));
      // The fresh edit alone is sticky-failed-preserving — status still failed.
      expect(c.read(saveStatusProvider), SaveStatus.failed);
      expect(statusCtrl.pendingCount, 1);

      // Now the retry — synchronous observation, no awaits.
      notifier.retrySave();
      // Retry clobbers sticky-failed AND increments pendingCount so the
      // user-visible signal flips to "saving…" right away.
      expect(c.read(saveStatusProvider), SaveStatus.inFlight);
      expect(statusCtrl.pendingCount, greaterThanOrEqualTo(1));
    },
  );

  test(
    'rapid edits increment pendingCount only once (hasPending gates beginSave)',
    () async {
      // MEDIUM #8: while a debounce window is open, hasPending == true so
      // subsequent edits inside the window must NOT increment pendingCount
      // a second time — otherwise endSaveSuccess on the single coalesced
      // save would still leave _pending > 0 and the status stuck at
      // inFlight forever.
      final fake = FakePlanStorage();
      final c = _makeContainer(fake);
      addTearDown(c.dispose);
      await c.read(plannerNotifierProvider.future);

      final notifier = c.read(plannerNotifierProvider.notifier);
      final statusCtrl = c.read(saveStatusProvider.notifier);
      for (var i = 0; i < 10; i++) {
        notifier.updateRaceConfig(
          (cfg) => cfg.copyWith(targetCarbsGPerHr: 80 + i.toDouble()),
        );
      }
      // Exactly one open lifecycle, regardless of how many edits fired.
      expect(statusCtrl.pendingCount, 1);
      expect(c.read(saveStatusProvider), SaveStatus.inFlight);

      await Future<void>.delayed(_pastDebounceWindow);
      expect(statusCtrl.pendingCount, 0);
      expect(c.read(saveStatusProvider), SaveStatus.idle);
    },
  );

  test('mutation during failed status preserves the failure signal', () async {
    // HIGH #5: edits during a failed-save window must not silently flip
    // status back to inFlight (which would mask the failure). The user
    // needs to keep seeing "save failed" until a save actually succeeds.
    final fake = FakePlanStorage()..saveError = StateError('disk full');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);
    await c.read(plannerNotifierProvider.future);

    final notifier = c.read(plannerNotifierProvider.notifier);
    notifier.updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 90));
    await Future<void>.delayed(_pastDebounceWindow);
    expect(c.read(saveStatusProvider), SaveStatus.failed);

    // Mutate again while still in failed state. Status MUST stay failed
    // until a save actually succeeds.
    notifier.updateRaceConfig((cfg) => cfg.copyWith(targetCarbsGPerHr: 95));
    expect(c.read(saveStatusProvider), SaveStatus.failed);

    // Even after the second save window settles (still failing), the
    // sticky-failed signal persists.
    await Future<void>.delayed(_pastDebounceWindow);
    expect(c.read(saveStatusProvider), SaveStatus.failed);
  });

  test('debugEmit goes through _emit and respects the AsyncError guard', () async {
    final fake = FakePlanStorage()..loadError = StateError('boom');
    final c = _makeContainer(fake);
    addTearDown(c.dispose);

    // Prime the notifier into AsyncError.
    await c
        .read(plannerNotifierProvider.future)
        .then<Object?>((s) => null, onError: (Object e) => e);
    expect(c.read(plannerNotifierProvider).hasError, isTrue);

    // debugEmit calls _emit. With state in AsyncError, the guard short-circuits
    // and the save chain is NOT pushed. This pins the AsyncError guard
    // independently of the _currentOrNull short-circuit on the public mutators.
    final notifier = c.read(plannerNotifierProvider.notifier);
    notifier.debugEmit(PlannerState.seed());
    await Future<void>.delayed(_pastDebounceWindow);

    expect(c.read(plannerNotifierProvider).hasError, isTrue);
    expect(fake.saveCount, 0);
  });
}
