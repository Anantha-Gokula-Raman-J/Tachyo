import 'package:flutter/material.dart';

// Design tokens ported from the Astryx design system (MIT, Meta Platforms):
// packages/themes/neutral/src/neutralTheme.ts and neutralPalettes.generated.ts.
// Astryx ships React/CSS; this file maps its portable roles (--color-*,
// --radius-*, --spacing-*) onto a Flutter ThemeExtension so widgets read
// roles, never raw hex values. See specs/ui/design-system.md.

class AstryxTokens extends ThemeExtension<AstryxTokens> {
  const AstryxTokens({
    required this.backgroundBody,
    required this.backgroundSurface,
    required this.backgroundCard,
    required this.backgroundMuted,
    required this.accent,
    required this.accentMuted,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.borderEmphasized,
    required this.download,
    required this.downloadMuted,
    required this.upload,
    required this.uploadMuted,
    required this.warning,
    required this.error,
  });

  final Color backgroundBody; // --color-background-body
  final Color backgroundSurface; // --color-background-surface
  final Color backgroundCard; // --color-background-card
  final Color backgroundMuted; // --color-background-muted
  final Color accent; // --color-accent
  final Color accentMuted; // --color-accent-muted
  final Color onAccent;
  final Color textPrimary; // --color-text-primary
  final Color textSecondary; // --color-text-secondary
  final Color textDisabled; // --color-text-disabled
  final Color border; // --color-border
  final Color borderEmphasized; // --color-border-emphasized
  final Color download; // --color-info
  final Color downloadMuted; // --color-info-muted
  final Color upload; // --color-success
  final Color uploadMuted; // --color-success-muted
  final Color warning; // --color-warning
  final Color error; // --color-error

  // --radius-*
  static const double radiusInner = 6; // 0.375rem
  static const double radiusElement = 10; // 0.625rem
  static const double radiusContainer = 12; // 0.75rem
  static const double radiusPage = 28; // 1.75rem

  // --spacing-* (4px rhythm)
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  static const light = AstryxTokens(
    backgroundBody: Color(0xFFF1F1F1), // neutral.light[95]
    backgroundSurface: Color(0xFFFFFFFF), // neutral.light[100]
    backgroundCard: Color(0xFFFFFFFF),
    backgroundMuted: Color(0xFFF1F1F1),
    accent: Color(0xFF1B1B1B), // neutral.light[10]
    accentMuted: Color(0xFFD4D4D4), // neutral.light[85]
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF000000), // neutral.light[0]
    textSecondary: Color(0xFF474747), // neutral.light[30]
    textDisabled: Color(0xFF919191), // neutral.light[60]
    border: Color(0x14000000), // neutral.light[0] @ 0x14
    borderEmphasized: Color(0xFFD4D4D4), // neutral.light[85]
    download: Color(0xFF0074E2), // --color-info light
    downloadMuted: Color(0xFFD3E2FF), // blue.light[85] (approx.)
    upload: Color(0xFF198100), // --color-success light
    uploadMuted: Color(0xFFCDEBC0), // green.dark[85] (approx.)
    warning: Color(0xFFFFCE2F),
    error: Color(0xFFC9303A),
  );

  static const dark = AstryxTokens(
    backgroundBody: Color(0xFF1B1B1B), // neutral.dark[10]
    backgroundSurface: Color(0xFF262626), // neutral.dark[15]
    backgroundCard: Color(0xFF262626), // neutral.dark[15], lifted off the body
    backgroundMuted: Color(0xFF1B1B1B),
    accent: Color(0xFFF1F1F1), // neutral.dark[95]
    accentMuted: Color(0xFF474747), // neutral.dark[30]
    onAccent: Color(0xFF000000),
    textPrimary: Color(0xFFFFFFFF), // neutral.dark[100]
    textSecondary: Color(0xFF9E9E9E), // neutral.dark[65]
    textDisabled: Color(0xFF525252), // neutral.dark[35]
    border: Color(0x1AFFFFFF), // neutral.dark[100] @ 0x1A
    borderEmphasized: Color(0xFF525252), // neutral.dark[35]
    download: Color(0xFF6D9CFE), // --color-info dark
    downloadMuted: Color(0x3D6D9CFE),
    upload: Color(0xFF64AF4C), // --color-success dark
    uploadMuted: Color(0x3D64AF4C),
    warning: Color(0xFFFFCE2F),
    error: Color(0xFFFF705D),
  );

  static AstryxTokens of(BuildContext context) =>
      Theme.of(context).extension<AstryxTokens>() ?? light;

  @override
  AstryxTokens copyWith() => this;

  @override
  AstryxTokens lerp(AstryxTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AstryxTokens(
      backgroundBody: c(backgroundBody, other.backgroundBody),
      backgroundSurface: c(backgroundSurface, other.backgroundSurface),
      backgroundCard: c(backgroundCard, other.backgroundCard),
      backgroundMuted: c(backgroundMuted, other.backgroundMuted),
      accent: c(accent, other.accent),
      accentMuted: c(accentMuted, other.accentMuted),
      onAccent: c(onAccent, other.onAccent),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textDisabled: c(textDisabled, other.textDisabled),
      border: c(border, other.border),
      borderEmphasized: c(borderEmphasized, other.borderEmphasized),
      download: c(download, other.download),
      downloadMuted: c(downloadMuted, other.downloadMuted),
      upload: c(upload, other.upload),
      uploadMuted: c(uploadMuted, other.uploadMuted),
      warning: c(warning, other.warning),
      error: c(error, other.error),
    );
  }
}

ThemeData buildTheme(Brightness brightness) {
  final t = brightness == Brightness.dark ? AstryxTokens.dark : AstryxTokens.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.accent,
    onPrimary: t.onAccent,
    secondary: t.download,
    onSecondary: t.onAccent,
    error: t.error,
    onError: Colors.white,
    surface: t.backgroundSurface,
    onSurface: t.textPrimary,
    onSurfaceVariant: t.textSecondary,
    outline: t.borderEmphasized,
    outlineVariant: t.border,
    secondaryContainer: t.accentMuted,
    onSecondaryContainer: t.textPrimary,
    surfaceContainerHighest: t.backgroundMuted,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AstryxTokens.radiusContainer),
    side: BorderSide(color: t.border),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.backgroundBody,
    extensions: [t],
    cardTheme: CardThemeData(
      color: t.backgroundCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.backgroundBody,
      foregroundColor: t.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.backgroundSurface,
      indicatorColor: t.accentMuted,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(color: t.border, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.onAccent : t.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.accent : t.backgroundMuted,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AstryxTokens.radiusElement)),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AstryxTokens.radiusElement)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.textPrimary,
        side: BorderSide(color: t.borderEmphasized),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AstryxTokens.radiusElement)),
      ),
    ),
  );
}
