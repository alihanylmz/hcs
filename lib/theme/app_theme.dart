import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // Ana Renkler (Profile Page ile uyumlu)
  static const Color _lightBg = Color(0xFFF8FAFC); // Slate-50
  static const Color _darkBg = Color(0xFF0B1220); // Koyu kömür (industrial)
  
  static const Color _inputFillLight = Colors.white;
  static const Color _inputFillDark = Color(0xFF111827);

  // --- LIGHT THEME ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBg,
      primaryColor: AppColors.corporateNavy,
      
      colorScheme: const ColorScheme.light(
        primary: AppColors.corporateNavy,
        secondary: AppColors.corporateYellow,
        surface: Colors.white,
        error: AppColors.corporateRed,
        onPrimary: Colors.white,
        onSurface: AppColors.textDark,
      ),

      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.corporateNavy,
      ),

      // AppBar Varsayılan Ayarı
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.corporateNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),

      // Kart Tasarımı (Hafif gölgeli, oval)
      // cardTheme: CardTheme(
      //   color: Colors.white,
      //   elevation: 4,
      //   shadowColor: Colors.black.withOpacity(0.05),
      //   margin: const EdgeInsets.only(bottom: 16),
      //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // ),

      // Input (Yazı Alanı) Tasarımı - Profil Sayfası Tarzı
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _inputFillLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.corporateYellow, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),

      // Buton Tasarımı - Geniş ve Şık
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.corporateNavy,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.corporateNavy.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.corporateNavy,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  // --- DARK THEME ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      primaryColor: AppColors.corporateNavy,
      
      colorScheme: const ColorScheme.dark(
        primary: AppColors.corporateNavy,
        secondary: AppColors.corporateYellow,
        surface: _inputFillDark,
        error: AppColors.corporateRed,
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),

      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.corporateNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),

      // cardTheme: CardTheme(
      //   color: _inputFillDark,
      //   elevation: 0,
      //   margin: const EdgeInsets.only(bottom: 16),
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(16),
      //     side: const BorderSide(color: Colors.white10),
      //   ),
      // ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _inputFillDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.corporateYellow, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.grey),
        hintStyle: TextStyle(color: Colors.grey.shade700),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.corporateNavy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.corporateNavy,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }
}
