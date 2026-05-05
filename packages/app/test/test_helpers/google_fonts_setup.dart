// ABOUTME: Test helper that installs the GoogleFonts asset stubs needed by
// ABOUTME: any widget/contract test that touches BonkType. Call from setUpAll.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Installs the bindings and stubs needed for tests that touch `BonkType`.
///
/// Call once from `setUpAll`. Disables `GoogleFonts` runtime fetching (so the
/// suite never reaches `fonts.gstatic.com`) and stubs `flutter/assets` with an
/// empty manifest so the GoogleFonts package's asset lookups don't throw a
/// `FormatException` from a missing manifest. Property-only assertions on the
/// returned `TextStyle` (size/weight/color/letterSpacing/fontFeatures) are
/// unaffected — they're set synchronously at the call site.
void setUpGoogleFontsForTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final emptyManifest = const StandardMessageCodec().encodeMessage(
    <String, Object>{},
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        return emptyManifest;
      });
}
