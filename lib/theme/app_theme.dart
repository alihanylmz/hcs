import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static final ThemeData lightTheme = _buildTheme(brightness: Brightness.light);
  static final ThemeData darkTheme = _buildTheme(brightness: Brightness.dark);

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final scaffoldColor =
        isDark ? AppColors.backgroundDark : AppColors.backgroundGrey;
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceWhite;
    final cardColor =
        isDark ? AppColors.surfaceDarkRaised : AppColors.surfaceWhite;
    final surfaceAltColor =
        isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceSoft;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderSubtle;
    final primaryColor = AppColors.corporateBlue;
    final secondaryColor = AppColors.corporateYellow;
    final onSurfaceColor = isDark ? AppColors.textOnDark : AppColors.textDark;
    final mutedTextColor =
        isDark ? AppColors.textOnDarkMuted : AppColors.textLight;
    const onPrimaryColor = Colors.white;

    final platformTextTheme =
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final baseTextTheme = platformTextTheme.copyWith(
      displayLarge: platformTextTheme.displayLarge?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurfaceColor,
      ),
      displayMedium: platformTextTheme.displayMedium?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurfaceColor,
      ),
      headlineLarge: platformTextTheme.headlineLarge?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurfaceColor,
      ),
      headlineMedium: platformTextTheme.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurfaceColor,
      ),
      titleLarge: platformTextTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: onSurfaceColor,
      ),
      titleMedium: platformTextTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurfaceColor,
      ),
      bodyLarge: platformTextTheme.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: onSurfaceColor,
        height: 1.45,
      ),
      bodyMedium: platformTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurfaceColor,
        height: 1.45,
      ),
      bodySmall: platformTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: mutedTextColor,
        height: 1.4,
      ),
      labelLarge: platformTextTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: onSurfaceColor,
      ),
      labelMedium: platformTextTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: mutedTextColor,
      ),
    );

    final colorScheme =
        isDark
            ? ColorScheme.dark(
              primary: primaryColor,
              secondary: secondaryColor,
              tertiary: AppColors.statusDone,
              surface: cardColor,
              error: AppColors.corporateRed,
              onPrimary: onPrimaryColor,
              onSecondary: AppColors.textDark,
              onSurface: onSurfaceColor,
              outline: borderColor,
            )
            : ColorScheme.light(
              primary: primaryColor,
              secondary: secondaryColor,
              tertiary: AppColors.statusDone,
              surface: cardColor,
              error: AppColors.corporateRed,
              onPrimary: onPrimaryColor,
              onSecondary: AppColors.textDark,
              onSurface: onSurfaceColor,
              outline: borderColor,
            );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldColor,
      canvasColor: scaffoldColor,
      colorScheme: colorScheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: _NoAnimationPageTransitionsBuilder(),
          TargetPlatform.linux: _NoAnimationPageTransitionsBuilder(),
          TargetPlatform.macOS: _NoAnimationPageTransitionsBuilder(),
        },
      ),
      textTheme: baseTextTheme,
      dividerColor: borderColor,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
      splashFactory: InkRipple.splashFactory,
      cardColor: cardColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: onSurfaceColor,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: onSurfaceColor),
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: onSurfaceColor,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? AppColors.surfaceDarkMuted : AppColors.corporateNavy,
        contentTextStyle: baseTextTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        modalBackgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: borderColor),
        backgroundColor: surfaceAltColor,
        selectedColor: primaryColor.withValues(alpha: isDark ? 0.22 : 0.10),
        labelStyle: baseTextTheme.labelMedium?.copyWith(color: onSurfaceColor),
        secondaryLabelStyle: baseTextTheme.labelMedium?.copyWith(
          color: onSurfaceColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAltColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(color: mutedTextColor),
        labelStyle: baseTextTheme.bodyMedium?.copyWith(color: mutedTextColor),
        prefixIconColor: mutedTextColor,
        suffixIconColor: mutedTextColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurfaceColor,
          backgroundColor:
              isDark
                  ? AppColors.surfaceDarkMuted.withValues(alpha: 0.74)
                  : AppColors.surfaceWhite,
          side: BorderSide(color: borderColor),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: onSurfaceColor,
          backgroundColor:
              isDark
                  ? AppColors.surfaceDarkMuted.withValues(alpha: 0.76)
                  : AppColors.surfaceSoft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primaryColor),
      listTileTheme: ListTileThemeData(
        iconColor: mutedTextColor,
        textColor: onSurfaceColor,
        selectedTileColor: surfaceAltColor,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceAccent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? primaryColor.withValues(alpha: 0.22) : borderColor,
          ),
        ),
        labelColor: onSurfaceColor,
        unselectedLabelColor: mutedTextColor,
        labelStyle: baseTextTheme.labelMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: baseTextTheme.labelMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDarkMuted : AppColors.corporateNavy,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: baseTextTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return isDark ? AppColors.surfaceDarkRaised : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.36);
          }
          return isDark ? AppColors.borderDark : AppColors.borderStrong;
        }),
      ),
    );
  }
}

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
