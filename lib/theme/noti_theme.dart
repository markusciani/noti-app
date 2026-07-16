import 'package:flutter/material.dart';

enum NotiThemePreset {
  main('main', 'Main Theme'),
  red('red', 'Red'),
  orange('orange', 'Orange'),
  blue('blue', 'Blue');

  const NotiThemePreset(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static NotiThemePreset fromStorage(String? value) {
    return NotiThemePreset.values.firstWhere(
      (preset) => preset.storageValue == value,
      orElse: () => NotiThemePreset.main,
    );
  }
}

enum NotiAppearance {
  light('light', 'Light'),
  dark('dark', 'Dark');

  const NotiAppearance(this.storageValue, this.label);

  final String storageValue;
  final String label;

  Brightness get brightness {
    return this == NotiAppearance.dark ? Brightness.dark : Brightness.light;
  }

  static NotiAppearance fromStorage(String? value) {
    return NotiAppearance.values.firstWhere(
      (appearance) => appearance.storageValue == value,
      orElse: () => NotiAppearance.light,
    );
  }
}

class NotiPalette {
  const NotiPalette({
    required this.brightness,
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.surface,
    required this.surfaceContainer,
    required this.background,
    required this.onPrimary,
    required this.onPrimaryContainer,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
  });

  final Brightness brightness;
  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color surface;
  final Color surfaceContainer;
  final Color background;
  final Color onPrimary;
  final Color onPrimaryContainer;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;

  factory NotiPalette.forPreset(
    NotiThemePreset preset, {
    NotiAppearance appearance = NotiAppearance.light,
  }) {
    if (appearance == NotiAppearance.dark) {
      switch (preset) {
        case NotiThemePreset.red:
          return const NotiPalette(
            brightness: Brightness.dark,
            primary: Color(0xFFFFB2B7),
            primaryContainer: Color(0xFF8C2835),
            secondary: Color(0xFFE8BDC1),
            secondaryContainer: Color(0xFF604048),
            surface: Color(0xFF20191A),
            surfaceContainer: Color(0xFF302426),
            background: Color(0xFF20191A),
            onPrimary: Color(0xFF61121D),
            onPrimaryContainer: Color(0xFFFFDADC),
            onSurface: Color(0xFFF1DFE0),
            onSurfaceVariant: Color(0xFFD8C1C3),
            outline: Color(0xFFA38C8E),
          );
        case NotiThemePreset.orange:
          return const NotiPalette(
            brightness: Brightness.dark,
            primary: Color(0xFFFFB77D),
            primaryContainer: Color(0xFF713800),
            secondary: Color(0xFFEAC0A0),
            secondaryContainer: Color(0xFF5B4636),
            surface: Color(0xFF211A14),
            surfaceContainer: Color(0xFF30261D),
            background: Color(0xFF211A14),
            onPrimary: Color(0xFF492200),
            onPrimaryContainer: Color(0xFFFFDCBF),
            onSurface: Color(0xFFF1E0D4),
            onSurfaceVariant: Color(0xFFDBC2AF),
            outline: Color(0xFFA58C79),
          );
        case NotiThemePreset.blue:
          return const NotiPalette(
            brightness: Brightness.dark,
            primary: Color(0xFFB5C4FF),
            primaryContainer: Color(0xFF174EAD),
            secondary: Color(0xFFC3C9E9),
            secondaryContainer: Color(0xFF3C496E),
            surface: Color(0xFF171B28),
            surfaceContainer: Color(0xFF252B3B),
            background: Color(0xFF171B28),
            onPrimary: Color(0xFF103067),
            onPrimaryContainer: Color(0xFFDCE7FF),
            onSurface: Color(0xFFE0E2F1),
            onSurfaceVariant: Color(0xFFC4C7D8),
            outline: Color(0xFF8E91A2),
          );
        case NotiThemePreset.main:
          return const NotiPalette(
            brightness: Brightness.dark,
            primary: Color(0xFFC4C1FF),
            primaryContainer: Color(0xFF413A9C),
            secondary: Color(0xFFC9C2EA),
            secondaryContainer: Color(0xFF49436A),
            surface: Color(0xFF14131B),
            surfaceContainer: Color(0xFF24222D),
            background: Color(0xFF14131B),
            onPrimary: Color(0xFF29236E),
            onPrimaryContainer: Color(0xFFE4E1FF),
            onSurface: Color(0xFFE6E1EA),
            onSurfaceVariant: Color(0xFFC8C4D5),
            outline: Color(0xFF928E9E),
          );
      }
    }

    switch (preset) {
      case NotiThemePreset.red:
        return const NotiPalette(
          brightness: Brightness.light,
          primary: Color(0xFFD44F57),
          primaryContainer: Color(0xFFFFDADC),
          secondary: Color(0xFF80535A),
          secondaryContainer: Color(0xFFFFD9DD),
          surface: Color(0xFFFFF8F7),
          surfaceContainer: Color(0xFFF9E7E7),
          background: Color(0xFFFFF8F7),
          onPrimary: Color(0xFFFFF8F8),
          onPrimaryContainer: Color(0xFF5B111B),
          onSurface: Color(0xFF25191A),
          onSurfaceVariant: Color(0xFF5D3F42),
          outline: Color(0xFF89686B),
        );
      case NotiThemePreset.orange:
        return const NotiPalette(
          brightness: Brightness.light,
          primary: Color(0xFFC96E1A),
          primaryContainer: Color(0xFFFFDCBF),
          secondary: Color(0xFF765846),
          secondaryContainer: Color(0xFFFFDCC6),
          surface: Color(0xFFFFF8F4),
          surfaceContainer: Color(0xFFF9E8DC),
          background: Color(0xFFFFF8F4),
          onPrimary: Color(0xFFFFF9F5),
          onPrimaryContainer: Color(0xFF472000),
          onSurface: Color(0xFF271A12),
          onSurfaceVariant: Color(0xFF5E4635),
          outline: Color(0xFF8A6C58),
        );
      case NotiThemePreset.blue:
        return const NotiPalette(
          brightness: Brightness.light,
          primary: Color(0xFF3D73E6),
          primaryContainer: Color(0xFFDCE7FF),
          secondary: Color(0xFF4F628E),
          secondaryContainer: Color(0xFFDCE6FF),
          surface: Color(0xFFF8F9FF),
          surfaceContainer: Color(0xFFE8EEFC),
          background: Color(0xFFF8F9FF),
          onPrimary: Color(0xFFF9FAFF),
          onPrimaryContainer: Color(0xFF102D65),
          onSurface: Color(0xFF171C29),
          onSurfaceVariant: Color(0xFF424B62),
          outline: Color(0xFF737B91),
        );
      case NotiThemePreset.main:
        return const NotiPalette(
          brightness: Brightness.light,
          primary: Color(0xFF5B56E8),
          primaryContainer: Color(0xFFE4E1FF),
          secondary: Color(0xFF625B84),
          secondaryContainer: Color(0xFFE5DFFF),
          surface: Color(0xFFFFFBFF),
          surfaceContainer: Color(0xFFEEEAF6),
          background: Color(0xFFFFFBFF),
          onPrimary: Color(0xFFFBF9FF),
          onPrimaryContainer: Color(0xFF262064),
          onSurface: Color(0xFF1C1B20),
          onSurfaceVariant: Color(0xFF474459),
          outline: Color(0xFF787486),
        );
    }
  }

  ColorScheme get colorScheme {
    return ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: brightness == Brightness.dark ? background : onPrimary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSurface,
      surface: surface,
      surfaceContainerHighest: surfaceContainer,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.42),
      inversePrimary: primaryContainer,
    );
  }
}

class NotiTheme {
  const NotiTheme._();

  static ThemeData build(
    NotiThemePreset preset, {
    NotiAppearance appearance = NotiAppearance.light,
  }) {
    final palette = NotiPalette.forPreset(preset, appearance: appearance);
    final scheme = palette.colorScheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.background,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          foregroundColor: scheme.primary,
          disabledForegroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          disabledForegroundColor: scheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          hoverColor: scheme.primaryContainer,
          highlightColor: scheme.primaryContainer,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondaryContainer,
        labelStyle: TextStyle(color: scheme.onSecondaryContainer),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest;
        }),
      ),
    );
  }
}
