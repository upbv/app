import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

/// Builds the light and dark themes from the shared palette.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final canvas = isDark ? Palette.darkCanvas : Palette.canvas;
    final surface = isDark ? Palette.darkSurface : Palette.surface;
    final ink = isDark ? Palette.inkInverse : Palette.ink;
    final inkSoft = isDark ? const Color(0xFFB4BCAE) : Palette.inkSoft;
    final inkFaint = isDark ? const Color(0xFF8A9384) : Palette.inkFaint;
    final hairline = isDark ? Palette.darkHairline : Palette.hairline;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Palette.moss,
        brightness: brightness,
      ).copyWith(
        primary: Palette.moss,
        secondary: Palette.clay,
        surface: surface,
        onSurface: ink,
        error: Palette.danger,
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, ink, inkSoft, inkFaint),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: inkSoft, size: 18),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        textStyle: TextStyle(fontSize: 12, color: ink),
        decoration: BoxDecoration(
          color: isDark ? Palette.darkSurfaceAlt : Palette.surface,
          borderRadius: BorderRadius.circular(Space.rSm),
          border: Border.all(color: hairline),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(inkFaint.withValues(alpha: 0.35)),
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(6),
      ),
    );
  }

  static TextTheme _textTheme(
    TextTheme base,
    Color ink,
    Color inkSoft,
    Color inkFaint,
  ) {
    TextStyle s(double size, FontWeight weight, Color color, {double? h, double? ls}) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: h,
        letterSpacing: ls,
      );
    }

    return base.copyWith(
      displaySmall: s(30, FontWeight.w600, ink, h: 1.15, ls: -0.4),
      headlineMedium: s(22, FontWeight.w600, ink, h: 1.2, ls: -0.2),
      headlineSmall: s(18, FontWeight.w600, ink, h: 1.25, ls: -0.1),
      titleMedium: s(15, FontWeight.w600, ink, h: 1.3),
      titleSmall: s(13.5, FontWeight.w600, ink, h: 1.3),
      bodyLarge: s(14, FontWeight.w400, ink, h: 1.45),
      bodyMedium: s(13, FontWeight.w400, inkSoft, h: 1.45),
      bodySmall: s(12, FontWeight.w400, inkFaint, h: 1.4),
      labelLarge: s(13, FontWeight.w500, inkSoft),
      labelMedium: s(11.5, FontWeight.w500, inkFaint, ls: 0.1),
      labelSmall: s(10.5, FontWeight.w500, inkFaint, ls: 0.4),
    );
  }
}

/// Overlays the system chrome colours so the app matches the window itself.
class SystemUi {
  const SystemUi._();

  static void apply(Brightness brightness) {
    final overlay = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Palette.darkCanvas,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Palette.canvas,
          );

    SystemChrome.setSystemUIOverlayStyle(overlay);
  }
}
