import 'package:flutter/material.dart';

/// Soft, rounded visual language used across the app.
class AppColors {
  static const income = Color(0xFF1FA874);
  static const expense = Color(0xFFF2557A);
  static const primary = Color(0xFF6A5AE8);
  static const gradient = [Color(0xFF7463F0), Color(0xFF4F8EF0)];

  /// Categorical chart palette (validated for colour-blind separation),
  /// assigned to categories in a fixed order. Dark mode uses its own steps.
  static const chartLight = [
    Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100),
    Color(0xFFE87BA4), Color(0xFF008300), Color(0xFF6250D6), Color(0xFFE34948),
  ];
  static const chartDark = [
    Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500),
    Color(0xFFD55181), Color(0xFF0CA30C), Color(0xFF9085E9), Color(0xFFE66767),
  ];
  static const chartOtherLight = Color(0xFFA3A29D);
  static const chartOtherDark = Color(0xFF6F6E69);

  static const lightBg = Color(0xFFF4F3FB);
  static const darkBg = Color(0xFF14141C);
  static const darkCard = Color(0xFF1F1F2B);
}

const kRadius = 26.0;

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFFA79FFF) : AppColors.primary,
    surface: dark ? AppColors.darkBg : AppColors.lightBg,
  );

  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
  final baseText = ThemeData(brightness: brightness).textTheme;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: baseText.titleLarge!
          .copyWith(
            color: scheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        textStyle: baseText.labelLarge!
            .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: const StadiumBorder()),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.darkCard : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
    popupMenuTheme: PopupMenuThemeData(shape: rounded),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: rounded,
    ),
    datePickerTheme: DatePickerThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
  );
}

/// White rounded card with a very soft shadow (flat tinted card in dark mode).
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.only(top: 14),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(kRadius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? (dark ? AppColors.darkCard : Colors.white),
        borderRadius: radius,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Round soft icon button.
class SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  const SoftIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final btn = Material(
      color: dark ? AppColors.darkCard : Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
