// ABOUTME: Design tokens (color, spacing, radius, shadow) for the Bonk theme.
// ABOUTME: Mirrored from the prototype's CSS custom properties.
//
// Color-usage doctrine
// --------------------
// Severity TEXT (warning headlines, "CRITICAL" / "ADVISORY" labels) is always
// rendered in `ink` or `ink2`. Color carries severity through the LEFT BAR,
// dot, or icon only — never through text foreground. This keeps every
// severity label at WCAG AA contrast on cream surfaces.
//
// Decorative-only hues (`accent`, `glu`, `fru`) are surface/fill colors and
// FAIL contrast as text (≤2.2:1 on bg). For accent text use `accentInk`.
//
// TODO(dark-mode): v1.1 ships light-only per design spec §13. When dark mode
// lands, `BonkTokens` becomes a `ThemeExtension` with light/dark variants and
// consumers read via `Theme.of(context).extension<BonkTokens>()`. Adding the
// indirection later means touching every consumer once they exist; if more
// than ~5 widget files reference these tokens before dark mode lands, do the
// extraction proactively.
import 'package:flutter/material.dart';

class BonkTokens {
  BonkTokens._();

  // Surfaces
  static const bg = Color(0xFFF5F3EE);
  static const bg2 = Color(0xFFECEBE4);
  static const paper = Color(0xFFFBFAF6);

  // Text / ink
  static const ink = Color(0xFF0E0E0C);
  static const ink2 = Color(0xFF2A2A26);
  static const ink3 = Color(0xFF5B5B54);

  // Rules
  static const rule = Color(0xFFD8D5CB);
  static const rule2 = Color(0xFFE6E3D9);

  // Accent + semantic
  // OKLCH(0.88 0.18 120) — committed as sRGB hex.
  // Decorative fill / chip / dot only — fails contrast as text. Use accentInk for text.
  static const accent = Color(0xFFC8E85B);
  static const accentInk = Color(0xFF3F4D14);
  static const warn = Color(0xFFC28A4A);
  static const bad = Color(0xFFCD5340);
  static const ok = Color(0xFF6FA169);
  static const hydro = Color(0xFF7FA3C4);
  static const caf = Color(0xFF9D614A);
  // Chart/legend hues — fills only, never text foreground (fail AA).
  static const glu = Color(0xFFA8D24F);
  static const fru = Color(0xFFD4A04A);

  // Radii
  static const rSm = 4.0;
  static const r = 8.0;
  static const rLg = 14.0;

  // Spacing scale (px)
  static const space2 = 2.0;
  static const space4 = 4.0;
  static const space6 = 6.0;
  static const space8 = 8.0;
  static const space10 = 10.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space18 = 18.0;
  static const space22 = 22.0;
  static const space44 = 44.0; // topbar height

  // Semantic aliases
  static const topbarHeight = space44;
}
