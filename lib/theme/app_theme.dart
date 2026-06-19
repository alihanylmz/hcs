import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

    final baseTextTheme = GoogleFonts.manropeTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).copyWith(
      displayLarge: GoogleFonts.manrope(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
        color: onSurfaceColor,
      ),
      displayMedium: GoogleFonts.manrope(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: onSurfaceColor,
      ),
      headlineLarge: GoogleFonts.manrope(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: onSurfaceColor,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: onSurfaceColor,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: onSurfaceColor,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: onSurfaceColor,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: onSurfaceColor,
        height: 1.45,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: onSurfaceColor,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: mutedTextColor,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
        color: onSurfaceColor,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
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
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
      splashFactory: InkRipple.splashFactory,
      cardColor: cardColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: onSurfaceColor,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: onSurfaceColor),
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
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
        contentTextStyle: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        modalBackgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: borderColor),
        backgroundColor: surfaceAltColor,
        selectedColor: primaryColor.withValues(alpha: isDark ? 0.22 : 0.10),
        labelStyle: baseTextTheme.labelMedium?.copyWith(color: onSurfaceColor),
        secondaryLabelStyle: baseTextTheme.labelMedium?.copyWith(
          color: onSurfaceColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAltColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(color: mutedTextColor),
        labelStyle: baseTextTheme.bodyMedium?.copyWith(color: mutedTextColor),
        prefixIconColor: mutedTextColor,
        suffixIconColor: mutedTextColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
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
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w800,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primaryColor),
      listTileTheme: ListTileThemeData(
        iconColor: mutedTextColor,
        textColor: onSurfaceColor,
        selectedTileColor: surfaceAltColor,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceAccent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? primaryColor.withValues(alpha: 0.22) : borderColor,
          ),
        ),
        labelColor: onSurfaceColor,
        unselectedLabelColor: mutedTextColor,
        labelStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDarkMuted : AppColors.corporateNavy,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
