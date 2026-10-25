import 'package:flutter/material.dart';

abstract final class ReferenceColors {
  static const surface = Color(0xFFFFFDFE);
  static const ink = Color(0xFF4D4B4E);
  static const muted = Color(0xFF807E80);
  static const border = Color(0xFFE7E5E7);
  static const disabled = Color(0xFFB0AEB0);
  static const green = Color(0xFF5BCD05);
  static const greenEdge = Color(0xFF58A700);
  static const blue = Color(0xFF20A2CF);
  static const blueBorder = Color(0xFF89DBF6);
  static const blueFill = Color(0xFFE1F4FF);
  static const purple = Color(0xFF9861FF);
}

@immutable
class ReferencePalette extends ThemeExtension<ReferencePalette> {
  const ReferencePalette({
    required this.surface,
    required this.raisedSurface,
    required this.ink,
    required this.muted,
    required this.border,
    required this.disabled,
    required this.blueFill,
  });

  static const light = ReferencePalette(
    surface: ReferenceColors.surface,
    raisedSurface: Color(0xFFF7F7F7),
    ink: ReferenceColors.ink,
    muted: ReferenceColors.muted,
    border: ReferenceColors.border,
    disabled: ReferenceColors.disabled,
    blueFill: ReferenceColors.blueFill,
  );

  // Sampled from the archived Android dark-mode cohort. The source's dominant
  // app surface is #172021; cards and dividers are #233034 and #3A464E.
  // Foregrounds are samples from dark-mode-08 at (68,473), (164,476), and
  // (68,472); selected fill is dark-mode-15's navigation tile at (313,707).
  static const dark = ReferencePalette(
    surface: Color(0xFF172021),
    raisedSurface: Color(0xFF233034),
    ink: Color(0xFFF4FDFE),
    muted: Color(0xFFB2BABC),
    border: Color(0xFF3A464E),
    disabled: Color(0xFF7C8586),
    blueFill: Color(0xFF1C3749),
  );

  final Color surface;
  final Color raisedSurface;
  final Color ink;
  final Color muted;
  final Color border;
  final Color disabled;
  final Color blueFill;

  @override
  ReferencePalette copyWith({
    Color? surface,
    Color? raisedSurface,
    Color? ink,
    Color? muted,
    Color? border,
    Color? disabled,
    Color? blueFill,
  }) => ReferencePalette(
    surface: surface ?? this.surface,
    raisedSurface: raisedSurface ?? this.raisedSurface,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    border: border ?? this.border,
    disabled: disabled ?? this.disabled,
    blueFill: blueFill ?? this.blueFill,
  );

  @override
  ReferencePalette lerp(covariant ReferencePalette? other, double t) {
    if (other == null) return this;
    return ReferencePalette(
      surface: Color.lerp(surface, other.surface, t)!,
      raisedSurface: Color.lerp(raisedSurface, other.raisedSurface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      blueFill: Color.lerp(blueFill, other.blueFill, t)!,
    );
  }
}

extension ReferencePaletteContext on BuildContext {
  ReferencePalette get referencePalette =>
      Theme.of(this).extension<ReferencePalette>() ?? ReferencePalette.light;
}

ThemeData referenceTheme({Brightness brightness = Brightness.light}) {
  if (brightness == Brightness.light) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DuolingoSans',
      scaffoldBackgroundColor: ReferenceColors.surface,
      extensions: const [ReferencePalette.light],
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ReferenceColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: ReferenceColors.green,
        surface: ReferenceColors.surface,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          fontSize: 20,
          color: ReferenceColors.ink,
          height: 1.35,
        ),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
  const palette = ReferencePalette.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: ReferenceColors.green,
        brightness: Brightness.dark,
        surface: palette.surface,
      ).copyWith(
        onSurface: palette.ink,
        outline: palette.border,
        outlineVariant: palette.border,
      );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'DuolingoSans',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: palette.surface,
    extensions: [palette],
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
    ),
    colorScheme: scheme,
    dividerColor: palette.border,
    cardColor: palette.raisedSurface,
    dialogTheme: DialogThemeData(
      backgroundColor: palette.raisedSurface,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontSize: 20, color: palette.ink, height: 1.35),
    ),
    iconTheme: IconThemeData(color: palette.disabled),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.raisedSurface,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
