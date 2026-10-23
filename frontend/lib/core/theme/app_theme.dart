import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta visual do LEGIS: azul-marinho com acentos verde-petróleo.
class AppColors {
  AppColors._();

  // Azul noturno / marinho profundo.
  static const navy = Color(0xFF0B192C);
  static const navyLight = Color(0xFF0F2038);
  static const navyElevated = Color(0xFF162A47);

  // Verde-petróleo / turquesa: acento contemporâneo que harmoniza com o azul-marinho.

  static const teal = Color(0xFF287F80);
  static const tealLight = Color(0xFF48A6A4);
  /// Tom claro para textos pequenos e ícones sobre fundos escuros.
  static const tealTint = Color(0xFFB5E7E3);

  // Textos sobre fundos escuros.
  static const offWhite = Color(0xFFF8F9FA);
  static const slate = Color(0xFFE2E8F0);
}

/// Paleta semântica. Toda tela deve ler as cores daqui (context.palette) em vez
/// de usar cores fixas; assim claro/escuro e mobile/desktop ficam sempre coerentes.
@immutable
class LegisPalette extends ThemeExtension<LegisPalette> {
  const LegisPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.inputFill,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.action,
    required this.onAction,
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.hero,
    required this.onHero,
    required this.onHeroMuted,
    required this.navBar,
    required this.onNavBar,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
  });

  final Color background;     // Fundo do Scaffold.
  final Color surface;        // Cards, diálogos, bottom sheets.
  final Color surfaceAlt;     // Superfícies secundárias.
  final Color inputFill;      // Campos de texto.
  final Color border;
  final Color text;           // Texto principal.
  final Color textSecondary;  // Texto de apoio.
  final Color action;         // Botão primário.
  final Color onAction;
  final Color accent;         // Bronze: ícones ativos, bordas, selos.
  final Color accentText;     // Bronze legível para textos pequenos.
  final Color accentSoft;     // Fundo suave em teal.
  final Color onAccentSoft;
  final Color hero;           // Cards de destaque (azul noturno).
  final Color onHero;
  final Color onHeroMuted;
  final Color navBar;         // AppBar e menu lateral.
  final Color onNavBar;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;

  static const light = LegisPalette(
    background: Color(0xFFF8F9FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFF2F6),
    inputFill: Color(0xFFFFFFFF),
    border: Color(0xFFE1E6ED),
    text: AppColors.navy,
    textSecondary: Color(0xFF4A5A70),
    action: AppColors.navy,
    onAction: AppColors.offWhite,
    accent: AppColors.teal,
    accentText: AppColors.teal,
    accentSoft: Color(0xFFE4F4F2),
    onAccentSoft: Color(0xFF155B5B),
    hero: AppColors.navy,
    onHero: AppColors.offWhite,
    onHeroMuted: AppColors.slate,
    navBar: AppColors.navy,
    onNavBar: AppColors.offWhite,
    success: Color(0xFF126F4B),
    successSoft: Color(0xFFE5F5EE),
    warning: Color(0xFF8D5B10),
    warningSoft: Color(0xFFFFF3DA),
    danger: Color(0xFFB64A4A),
  );

  static const dark = LegisPalette(
    background: AppColors.navy,
    surface: AppColors.navyLight,
    surfaceAlt: AppColors.navyElevated,
    inputFill: AppColors.navyElevated,
    border: Color(0xFF25395A),
    text: AppColors.offWhite,
    textSecondary: AppColors.slate,
    action: AppColors.teal,
    onAction: AppColors.offWhite,
    accent: AppColors.tealLight,
    accentText: AppColors.tealTint,
    accentSoft: Color(0xFF173B46),
    onAccentSoft: AppColors.tealTint,
    hero: AppColors.navyLight,
    onHero: AppColors.offWhite,
    onHeroMuted: AppColors.slate,
    navBar: AppColors.navyLight,
    onNavBar: AppColors.offWhite,
    success: Color(0xFF6FD8A8),
    successSoft: Color(0xFF123A2E),
    warning: Color(0xFFF2C879),
    warningSoft: Color(0xFF3A2F14),
    danger: Color(0xFFF29A9A),
  );

  // A paleta é imutável e só existe nas duas variantes acima.
  @override
  LegisPalette copyWith() => this;

  @override
  LegisPalette lerp(ThemeExtension<LegisPalette>? other, double t) =>
      other is LegisPalette && t >= 0.5 ? other : this;
}

extension LegisThemeContext on BuildContext {
  LegisPalette get palette => Theme.of(this).extension<LegisPalette>() ?? LegisPalette.light;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light, LegisPalette.light);
  static ThemeData get dark => _build(Brightness.dark, LegisPalette.dark);

  static ThemeData _build(Brightness brightness, LegisPalette p) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.action,
      onPrimary: p.onAction,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: p.onAccentSoft,
      secondary: p.accent,
      onSecondary: AppColors.offWhite,
      secondaryContainer: p.accentSoft,
      onSecondaryContainer: p.onAccentSoft,
      error: p.danger,
      onError: isDark ? AppColors.navy : AppColors.offWhite,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textSecondary,
      outline: p.border,
      outlineVariant: p.border,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceAlt,
      surfaceContainerHighest: p.surfaceAlt,
    );

    final base = ThemeData(brightness: brightness, useMaterial3: true)
        .textTheme
        .apply(bodyColor: p.text, displayColor: p.text);

    final textTheme = base.copyWith(
      headlineLarge: TextStyle(color: p.text, fontSize: 25, fontWeight: FontWeight.w700, height: 1.2),
      headlineMedium: TextStyle(color: p.text, fontSize: 21, fontWeight: FontWeight.w700, height: 1.25),
      titleLarge: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: p.text, fontSize: 14, height: 1.45),
      bodyMedium: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.4),
      bodySmall: TextStyle(color: p.textSecondary, fontSize: 12, height: 1.35),
      labelLarge: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    Color selectedOr(Set<WidgetState> states, Color selected, Color other) =>
        states.contains(WidgetState.selected) ? selected : other;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[p],
      scaffoldBackgroundColor: p.background,
      canvasColor: p.surface,
      cardColor: p.surface,
      dividerColor: p.border,
      iconTheme: IconThemeData(color: p.text),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: p.navBar,
        foregroundColor: p.onNavBar,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: p.onNavBar),
        actionsIconTheme: IconThemeData(color: p.onNavBar),
        titleTextStyle: TextStyle(color: p.onNavBar, fontSize: 16, fontWeight: FontWeight.w700),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: BorderSide(color: p.border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.accent,
        textColor: p.text,
        subtitleTextStyle: TextStyle(color: p.textSecondary, fontSize: 12.5, height: 1.35),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.inputFill,
        hintStyle: TextStyle(color: p.textSecondary.withValues(alpha: .8), fontSize: 13),
        labelStyle: TextStyle(color: p.textSecondary),
        floatingLabelStyle: TextStyle(color: p.accentText),
        helperStyle: TextStyle(color: p.textSecondary, fontSize: 11.5),
        errorStyle: TextStyle(color: p.danger, fontSize: 11.5),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder(p.border),
        enabledBorder: inputBorder(p.border),
        focusedBorder: inputBorder(p.accent, 1.5),
        errorBorder: inputBorder(p.danger),
        focusedErrorBorder: inputBorder(p.danger, 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.action,
          foregroundColor: p.onAction,
          disabledBackgroundColor: p.action.withValues(alpha: .6),
          disabledForegroundColor: p.onAction.withValues(alpha: .8),
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.accent, width: 1.2),
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentText,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accentSoft,
        elevation: 3,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: selectedOr(states, p.accentText, p.textSecondary),
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: selectedOr(states, p.text, p.textSecondary),
            )),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(color: p.textSecondary, fontSize: 14, height: 1.45),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: p.text, fontSize: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.accentSoft,
        selectedColor: p.action,
        side: BorderSide.none,
        labelStyle: TextStyle(color: p.onAccentSoft, fontSize: 11, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => selectedOr(states, AppColors.offWhite, p.textSecondary)),
        trackColor: WidgetStateProperty.resolveWith(
            (states) => selectedOr(states, p.accent, p.surfaceAlt)),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (states) => selectedOr(states, Colors.transparent, p.border)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (states) => selectedOr(states, p.accent, Colors.transparent)),
        checkColor: const WidgetStatePropertyAll(AppColors.offWhite),
        side: BorderSide(color: p.textSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (states) => selectedOr(states, p.accent, p.textSecondary)),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: p.accent,
        collapsedIconColor: p.textSecondary,
        textColor: p.text,
        collapsedTextColor: p.text,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: .35),
        selectionHandleColor: p.accent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.navyElevated : AppColors.navy,
        contentTextStyle: const TextStyle(color: AppColors.offWhite, fontSize: 13.5),
        actionTextColor: AppColors.tealTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
