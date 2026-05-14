// ABOUTME: Tests for the BonkBreakpoint enum mapper.
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/theme/breakpoints.dart';

void main() {
  test('1600 → wide', () {
    expect(BonkBreakpoint.forWidth(1600), BonkBreakpoint.wide);
  });
  test('1400 → medium', () {
    expect(BonkBreakpoint.forWidth(1400), BonkBreakpoint.medium);
  });
  test('1200 → noDiagnostics', () {
    expect(BonkBreakpoint.forWidth(1200), BonkBreakpoint.noDiagnostics);
  });
  test('1000 → narrow', () {
    expect(BonkBreakpoint.forWidth(1000), BonkBreakpoint.narrow);
  });
  test('800 → mobile', () {
    expect(BonkBreakpoint.forWidth(800), BonkBreakpoint.mobile);
  });

  group('boundary equality', () {
    test('1520 → wide, 1519.999 → medium', () {
      expect(BonkBreakpoint.forWidth(1520), BonkBreakpoint.wide);
      expect(BonkBreakpoint.forWidth(1519.999), BonkBreakpoint.medium);
    });
    test('1380 → medium, 1379.999 → noDiagnostics', () {
      expect(BonkBreakpoint.forWidth(1380), BonkBreakpoint.medium);
      expect(BonkBreakpoint.forWidth(1379.999), BonkBreakpoint.noDiagnostics);
    });
    test('1080 → noDiagnostics, 1079.999 → narrow', () {
      expect(BonkBreakpoint.forWidth(1080), BonkBreakpoint.noDiagnostics);
      expect(BonkBreakpoint.forWidth(1079.999), BonkBreakpoint.narrow);
    });
    test('880 → narrow, 879.999 → mobile', () {
      expect(BonkBreakpoint.forWidth(880), BonkBreakpoint.narrow);
      expect(BonkBreakpoint.forWidth(879.999), BonkBreakpoint.mobile);
    });
    test('zero width → mobile', () {
      expect(BonkBreakpoint.forWidth(0), BonkBreakpoint.mobile);
    });
  });

  group('convenience getters', () {
    // Table: tier → (showsDiagnostics, showsSetup, setupWidth, diagnosticsWidth)
    final cases = <BonkBreakpoint, (bool, bool, double, double)>{
      BonkBreakpoint.wide: (true, true, 320, 380),
      BonkBreakpoint.medium: (true, true, 280, 360),
      BonkBreakpoint.noDiagnostics: (false, true, 280, 0),
      BonkBreakpoint.narrow: (false, true, 280, 0),
      BonkBreakpoint.mobile: (false, false, 0, 0),
    };

    for (final entry in cases.entries) {
      final tier = entry.key;
      final (showsDiag, showsSetup, setupW, diagW) = entry.value;
      test('${tier.name} getters', () {
        expect(
          tier.showsDiagnosticsRail,
          showsDiag,
          reason: 'showsDiagnosticsRail',
        );
        expect(tier.showsSetupRail, showsSetup, reason: 'showsSetupRail');
        expect(tier.setupRailWidth, setupW, reason: 'setupRailWidth');
        expect(
          tier.diagnosticsRailWidth,
          diagW,
          reason: 'diagnosticsRailWidth',
        );
      });
    }
  });

  group('usesEndDrawerForDiagnostics', () {
    // Pinned table: only the two intermediate tiers (noDiagnostics, narrow)
    // route the diagnostics surface through an endDrawer. wide/medium have
    // the inline rail; mobile uses tabs.
    final cases = <BonkBreakpoint, bool>{
      BonkBreakpoint.wide: false,
      BonkBreakpoint.medium: false,
      BonkBreakpoint.noDiagnostics: true,
      BonkBreakpoint.narrow: true,
      BonkBreakpoint.mobile: false,
    };
    for (final entry in cases.entries) {
      test('${entry.key.name} → ${entry.value}', () {
        expect(entry.key.usesEndDrawerForDiagnostics, entry.value);
      });
    }
  });
}
