// ABOUTME: Responsive breakpoints — five tiers matching the prototype's CSS.
// ABOUTME: Use BonkBreakpoint.forWidth(MediaQuery.sizeOf(context).width) at the page root.
enum BonkBreakpoint {
  wide, // ≥1520: 320 / flex / 380
  medium, // 1380-1520: 280 / flex / 360; hide stat cols 5-6
  noDiagnostics, // 1080-1380: 280 / flex (no diagnostics rail)
  narrow, // 880-1080: 280 / flex; stats drop to 3 cols
  mobile; // <880: single column; rails via slide-overs

  static BonkBreakpoint forWidth(double w) {
    if (w >= 1520) return BonkBreakpoint.wide;
    if (w >= 1380) return BonkBreakpoint.medium;
    if (w >= 1080) return BonkBreakpoint.noDiagnostics;
    if (w >= 880) return BonkBreakpoint.narrow;
    return BonkBreakpoint.mobile;
  }

  bool get showsDiagnosticsRail =>
      this == BonkBreakpoint.wide || this == BonkBreakpoint.medium;
  bool get showsSetupRail => this != BonkBreakpoint.mobile;
  double get setupRailWidth => this == BonkBreakpoint.wide
      ? 320
      : (this == BonkBreakpoint.mobile ? 0 : 280);
  // DiagnosticsRail documents an F1-RAIL-MIN-WIDTH floor of 360 px outer; the
  // wide tier upgrades to 380 px to absorb high-density displays without
  // squeezing the canvas. Anything below `medium` hides the inline rail and
  // routes it through the endDrawer instead.
  double get diagnosticsRailWidth => this == BonkBreakpoint.wide
      ? 380
      : (this == BonkBreakpoint.medium ? 360 : 0);
}
