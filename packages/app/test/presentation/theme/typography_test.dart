// ABOUTME: Smoke tests pinning typography role contracts.
// ABOUTME: Ensures size/weight/color invariants survive refactors.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:race_fueling_app/presentation/theme/tokens.dart';
import 'package:race_fueling_app/presentation/theme/typography.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Disable runtime HTTP fetching so tests don't try the network.
    GoogleFonts.config.allowRuntimeFetching = false;
    // Stub the asset manifest with an empty Map so GoogleFonts asset
    // lookups resolve without a FormatException. The TextStyle props we
    // assert on are populated synchronously regardless of font load.
    final emptyManifest = const StandardMessageCodec().encodeMessage(
      <String, Object>{},
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          return emptyManifest;
        });
  });

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
  });

  group('named roles', () {
    testWidgets('railEyebrow uses ink3 and letterSpacing 0.4', (tester) async {
      final s = BonkType.railEyebrow();
      expect(s.color, BonkTokens.ink3);
      expect(s.letterSpacing, 0.4);
    });

    testWidgets('railTitle is sans 22 w600 with letterSpacing -0.4', (
      tester,
    ) async {
      final s = BonkType.railTitle();
      expect(s.fontSize, 22);
      expect(s.fontWeight, FontWeight.w600);
      expect(s.letterSpacing, -0.4);
    });

    testWidgets('statHero is mono 36 w600 with accentInk color', (
      tester,
    ) async {
      final s = BonkType.statHero();
      expect(s.fontSize, 36);
      expect(s.fontWeight, FontWeight.w600);
      expect(s.color, BonkTokens.accentInk);
    });

    testWidgets('statValue is mono 20 w500', (tester) async {
      final s = BonkType.statValue();
      expect(s.fontSize, 20);
      expect(s.fontWeight, FontWeight.w500);
    });

    testWidgets('sectionLabel uses ink3 and letterSpacing 0.6', (tester) async {
      final s = BonkType.sectionLabel();
      expect(s.color, BonkTokens.ink3);
      expect(s.letterSpacing, 0.6);
    });

    testWidgets('fieldLabel uses ink2 and size 11.5', (tester) async {
      final s = BonkType.fieldLabel();
      expect(s.color, BonkTokens.ink2);
      expect(s.fontSize, 11.5);
    });

    testWidgets('railSub uses ink3 and size 12.5', (tester) async {
      final s = BonkType.railSub();
      expect(s.color, BonkTokens.ink3);
      expect(s.fontSize, 12.5);
    });
  });
}
