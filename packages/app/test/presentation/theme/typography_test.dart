// ABOUTME: Smoke tests pinning typography role contracts.
// ABOUTME: Ensures size/weight/color invariants survive refactors.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/theme/tokens.dart';
import 'package:race_fueling_app/presentation/theme/typography.dart';

import '../../test_helpers/google_fonts_setup.dart';

void main() {
  setUpAll(setUpGoogleFontsForTests);

  // testWidgets is used (instead of plain test) so that GoogleFonts'
  // background asset-load failure is captured by the tester binding and
  // does not poison the synchronous TextStyle property assertions.

  group('BonkType.sans defaults', () {
    testWidgets('size 14, w400, height 1.45, color ink', (tester) async {
      final s = BonkType.sans();
      expect(s.fontSize, 14);
      expect(s.fontWeight, FontWeight.w400);
      expect(s.height, 1.45);
      expect(s.color, BonkTokens.ink);
    });

    testWidgets('overrides apply', (tester) async {
      final s = BonkType.sans(size: 22, w: FontWeight.w600);
      expect(s.fontSize, 22);
      expect(s.fontWeight, FontWeight.w600);
    });
  });

  group('BonkType.mono defaults', () {
    testWidgets('size 12, height 1.4, letterSpacing -0.1, tabular figures', (
      tester,
    ) async {
      final m = BonkType.mono();
      expect(m.fontSize, 12);
      expect(m.height, 1.4);
      expect(m.letterSpacing, -0.1);
      expect(m.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('mono overrides apply', (tester) async {
      final m = BonkType.mono(size: 18, w: FontWeight.w700);
      expect(m.fontSize, 18);
      expect(m.fontWeight, FontWeight.w700);
    });
  });

  group('named roles', () {
    testWidgets('railEyebrow uses ink3 and letterSpacing 0.4', (tester) async {
      final s = BonkType.railEyebrow;
      expect(s.color, BonkTokens.ink3);
      expect(s.letterSpacing, 0.4);
    });

    testWidgets('railTitle is sans 22 w600 with letterSpacing -0.4', (
      tester,
    ) async {
      final s = BonkType.railTitle;
      expect(s.fontSize, 22);
      expect(s.fontWeight, FontWeight.w600);
      expect(s.letterSpacing, -0.4);
    });

    testWidgets('statHero is mono 36 w600 with accentInk color', (
      tester,
    ) async {
      final s = BonkType.statHero;
      expect(s.fontSize, 36);
      expect(s.fontWeight, FontWeight.w600);
      expect(s.color, BonkTokens.accentInk);
    });

    testWidgets('statValue is mono 20 w500', (tester) async {
      final s = BonkType.statValue;
      expect(s.fontSize, 20);
      expect(s.fontWeight, FontWeight.w500);
    });

    testWidgets('sectionLabel uses ink3 and letterSpacing 0.6', (tester) async {
      final s = BonkType.sectionLabel;
      expect(s.color, BonkTokens.ink3);
      expect(s.letterSpacing, 0.6);
    });

    testWidgets('fieldLabel uses ink2 and size 11.5', (tester) async {
      final s = BonkType.fieldLabel;
      expect(s.color, BonkTokens.ink2);
      expect(s.fontSize, 11.5);
    });

    testWidgets('railSub uses ink3 and size 12.5', (tester) async {
      final s = BonkType.railSub;
      expect(s.color, BonkTokens.ink3);
      expect(s.fontSize, 12.5);
    });

    testWidgets(
      'railEyebrow derives from mono (tabular figures present, size 11)',
      (tester) async {
        expect(BonkType.railEyebrow.fontSize, 11);
        expect(
          BonkType.railEyebrow.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      },
    );

    testWidgets(
      'sectionLabel derives from mono (tabular figures present, size 10.5)',
      (tester) async {
        expect(BonkType.sectionLabel.fontSize, 10.5);
        expect(
          BonkType.sectionLabel.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      },
    );

    testWidgets('statHero inherits mono height 1.4', (tester) async {
      expect(BonkType.statHero.height, 1.4);
    });
  });
}
