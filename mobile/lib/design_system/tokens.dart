/// Spacing and radius scales. Defined once, reused everywhere — never invent
/// per-screen values (DESIGN_INTENT §5).
class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii, mapped to the export's Tailwind usage so screens match it:
///  - xs (8)  → toggle segments (rounded-lg)
///  - sm (12) → in-card buttons, toggle container (rounded-xl)
///  - md (16) → cards, inputs (rounded-2xl)
///  - lg (20) → large surfaces (`--radius`)
///  - xl (24) → sheets / paywall / modals (rounded-3xl)
class Radii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999; // pill buttons / filter chips / tags
}
