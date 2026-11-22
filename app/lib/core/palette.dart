import 'package:material_ui/material_ui.dart';

/// Palette for the app.
///
/// The tones come from forest floors and moss: muted sage, moss green,
/// lichen, bark brown and clay. Nothing here is a saturated "AI blue".
class Palette {
  const Palette._();

  // Canvas
  static const canvas = Color(0xFFF4F3EE);
  static const canvasDeep = Color(0xFFEDEBE3);
  static const surface = Color(0xFFFBFAF6);
  static const surfaceAlt = Color(0xFFF7F6F0);

  // Ink
  static const ink = Color(0xFF23291F);
  static const inkSoft = Color(0xFF5B6355);
  static const inkFaint = Color(0xFF8D958A);
  static const inkInverse = Color(0xFFF7F7F2);

  // Accents drawn from nature
  static const moss = Color(0xFF5E7F4E);
  static const mossDeep = Color(0xFF3F5C34);
  static const mossLight = Color(0xFF8FA97C);
  static const sage = Color(0xFF9AAE8E);
  static const lichen = Color(0xFFC4CEB4);
  static const clay = Color(0xFFB5744F);
  static const bark = Color(0xFF7A6248);
  static const amber = Color(0xFFD2A24C);
  static const rust = Color(0xFFA85A3C);
  static const water = Color(0xFF5B8293);
  static const stone = Color(0xFF8C8A80);

  // Lines
  static const hairline = Color(0x1A23291F);
  static const hairlineStrong = Color(0x2E23291F);

  // Semantic
  static const healthy = Color(0xFF5E7F4E);
  static const warning = Color(0xFFD2A24C);
  static const danger = Color(0xFFA85A3C);
  static const idle = Color(0xFF8D958A);

  static const darkCanvas = Color(0xFF1B2018);
  static const darkSurface = Color(0xFF23291F);
  static const darkSurfaceAlt = Color(0xFF2B3226);
  static const darkHairline = Color(0x24F7F7F2);
}

/// Shared spacing and radius scale.
class Space {
  const Space._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double rSm = 8;
  static const double rMd = 12;
  static const double rLg = 16;
  static const double rXl = 22;

  static const double sidebarWidth = 232;
  static const double titleBarHeight = 38;
}
