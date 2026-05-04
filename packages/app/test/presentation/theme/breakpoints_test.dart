// ABOUTME: Tests for the BonkBreakpoint enum mapper.
import 'package:flutter_test/flutter_test.dart';
import 'package:race_fueling_app/presentation/theme/breakpoints.dart';

void main() {
  test('1500 → wide', () {
    expect(BonkBreakpoint.forWidth(1500), BonkBreakpoint.wide);
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
}
