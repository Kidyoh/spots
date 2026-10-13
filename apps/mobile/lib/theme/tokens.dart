import 'package:flutter/material.dart';

/// Design tokens mirrored from `apps/web/src/styles.css` (`:root`), so the app
/// and the site read as one brand: warm cream surfaces, deep green, and a
/// terracotta/amber accent used sparingly. No pure black or white anywhere.
abstract final class Palette {
  static const bg = Color(0xFFFBF9F4);
  static const card = Color(0xFFFFFEFB);
  static const ink = Color(0xFF2B3A2E);
  static const inkSoft = Color(0xFF586256);
  static const muted = Color(0xFF6F6857);
  static const line = Color(0xFFE2D7C2);
  static const lineSoft = Color(0xFFECE3D1);
  static const divider = Color(0xFFD6D2C8);
  static const green = Color(0xFF3E5C44);
  static const greenDeep = Color(0xFF2C4232);
  static const sage = Color(0xFF7E9579);
  static const terracotta = Color(0xFFE37B33);
  static const amber = Color(0xFFE6A94F);
  static const gold = Color(0xFFEFC877);

  /// AA-safe orange for accent *text*; the bright terracotta stays for fills.
  static const accentText = Color(0xFFA85E1D);
  static const starFill = Color(0xFFC99A3F);
  static const starEmpty = Color(0xFFE0D6C2);

  static const accentWash = Color(0x1AE37B33);
  static const press = Color(0x143E5C44);

  /// Shadow tint: the deep green, never grey/black.
  static const shadow = Color(0xFF2C4232);
}

abstract final class Radii {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}

/// Soft, green-tinted elevation. Floating chrome (the tab bar, the dice) uses
/// [floating]; cards resting on the page use [card].
abstract final class Shadows {
  static List<BoxShadow> card = [
    BoxShadow(color: Palette.shadow.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 10)),
    BoxShadow(color: Palette.shadow.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(color: Palette.shadow.withValues(alpha: 0.18), blurRadius: 34, offset: const Offset(0, 14)),
    BoxShadow(color: Palette.shadow.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
  ];
}

/// The six deterministic cover gradients from `lib/format.ts` — a spot or
/// flyer with no image (or one still loading) wears one of these, keyed on
/// its id so it never reshuffles between renders.
const _coverGradients = <List<Color>>[
  [Color(0xFF9FB68F), Color(0xFF7E9579)],
  [Color(0xFFECC079), Color(0xFFE6A94F)],
  [Color(0xFFEA9560), Color(0xFFE37B33)],
  [Color(0xFFA7BE9C), Color(0xFF82996F)],
  [Color(0xFFE9B97E), Color(0xFFD9924B)],
  [Color(0xFFB9AC90), Color(0xFF968870)],
];

/// Java-style string hash, identical to the web's so a spot gets the same
/// gradient on both.
int _hash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c).toSigned(32);
  }
  return h.abs();
}

LinearGradient coverGradient(String key) {
  final colors = _coverGradients[_hash(key) % _coverGradients.length];
  // 160deg in CSS ≈ top-left-ish to bottom-right-ish.
  return LinearGradient(begin: const Alignment(-0.35, -1), end: const Alignment(0.35, 1), colors: colors);
}
