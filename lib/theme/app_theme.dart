import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- CATPPUCCIN LATTE (LIGHT) PALETTE ---
  static const Color _latteBase = Color(0xFFEFF1F5);
  static const Color _latteMantle = Color(0xFFE6E9EF); // Alternatif Yüzey
  static const Color _latteText = Color(0xFF4C4F69);
  static const Color _latteSubtext1 = Color(0xFF5C5F77);
  static const Color _latteSubtext0 = Color(0xFF6C6F85);
  static const Color _latteOverlay0 = Color(0xFF9CA0B0); // Borderlar için
  static const Color _latteBlue = Color(0xFF1E66F5); // Primary
  static const Color _latteLavender = Color(0xFF7287FD); // Secondary/Accent
  static const Color _latteRed = Color(0xFFD20F39); // Error
  static const Color _latteSurface0 = Color(0xFFCCD0DA);

  // --- CATPPUCCIN MOCHA (DARK) PALETTE ---
  static const Color _mochaBase = Color(0xFF1E1E2E);
  static const Color _mochaMantle = Color(0xFF181825);
  static const Color _mochaSurface0 = Color(0xFF313244); // Kart Arka Planı
  static const Color _mochaText = Color(0xFFCDD6F4);
  static const Color _mochaSubtext1 = Color(0xFFBAC2DE);
  static const Color _mochaSubtext0 = Color(0xFFA6ADC8);
  static const Color _mochaOverlay0 = Color(0xFF6C7086); // Borderlar için
  static const Color _mochaBlue = Color(0xFF89B4FA); // Primary
  static const Color _mochaMauve = Color(0xFFCBA6F7); // Secondary/Accent
  static const Color _mochaRed = Color(0xFFF38BA8); // Error

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _latteBase,
      primaryColor: _latteBlue,
      
      colorScheme: const ColorScheme.light(
        primary: _latteBlue,
        secondary: _latteLavender,
        surface: Colors.white, // Kartlar için beyaz daha temiz durur
        error: _latteRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _latteText,
        surfaceContainerHighest: _latteMantle, // Input fill color vb. için
      ),

      textTheme: GoogleFonts.interTextTheme().copyWith(
        headlineLarge: const TextStyle(color: _latteText, fontWeight: FontWeight.bold),
        headlineMedium: const TextStyle(color: _latteText, fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(color: _latteText, fontWeight: FontWeight.bold),
        titleMedium: const TextStyle(color: _latteText, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(color: _latteText),
        bodyMedium: const TextStyle(color: _latteSubtext1),
        bodySmall: const TextStyle(color: _latteSubtext0),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: _latteBase, // Scaffold ile aynı
        foregroundColor: _latteText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: _latteText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: _latteText),
      ),

      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0, // Düz tasarım
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFDCE0E8), width: 1), // Crust rengine yakın border
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _latteOverlay0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _latteOverlay0.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _latteBlue, width: 2),
        ),
        labelStyle: const TextStyle(color: _latteSubtext0),
        hintStyle: TextStyle(color: _latteSubtext0.withOpacity(0.7)),
        prefixIconColor: _latteSubtext0,
        suffixIconColor: _latteSubtext0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _latteBlue,
          foregroundColor: Colors.white,
          elevation: 0, // Flat
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _latteBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _latteBlue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      dividerTheme: const DividerThemeData(
        color: _latteSurface0,
        thickness: 1,
      ),
      
      iconTheme: const IconThemeData(color: _latteText),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _mochaBase,
      primaryColor: _mochaBlue,
      
      colorScheme: const ColorScheme.dark(
        primary: _mochaBlue,
        secondary: _mochaMauve,
        surface: _mochaSurface0,
        error: _mochaRed,
        onPrimary: _mochaBase,
        onSecondary: _mochaBase,
        onSurface: _mochaText,
        surfaceContainerHighest: _mochaMantle,
      ),

      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: const TextStyle(color: _mochaText, fontWeight: FontWeight.bold),
        headlineMedium: const TextStyle(color: _mochaText, fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(color: _mochaText, fontWeight: FontWeight.bold),
        titleMedium: const TextStyle(color: _mochaText, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(color: _mochaText),
        bodyMedium: const TextStyle(color: _mochaSubtext1),
        bodySmall: const TextStyle(color: _mochaSubtext0),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: _mochaBase,
        foregroundColor: _mochaText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: _mochaText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: _mochaText),
      ),

      cardTheme: CardTheme(
        color: _mochaSurface0,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _mochaOverlay0.withOpacity(0.2)), // Hafif border
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _mochaMantle, // Biraz daha koyu input alanı
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _mochaOverlay0.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _mochaOverlay0.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _mochaBlue, width: 2),
        ),
        labelStyle: const TextStyle(color: _mochaSubtext0),
        hintStyle: TextStyle(color: _mochaSubtext0.withOpacity(0.5)),
        prefixIconColor: _mochaSubtext0,
        suffixIconColor: _mochaSubtext0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _mochaBlue,
          foregroundColor: _mochaBase, // Koyu tema üzerinde açık renk metin yerine base rengi daha iyi
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _mochaBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _mochaBlue,
        foregroundColor: _mochaBase,
        elevation: 4,
      ),

      dividerTheme: DividerThemeData(
        color: _mochaOverlay0.withOpacity(0.2),
        thickness: 1,
      ),

      iconTheme: const IconThemeData(color: _mochaText),
    );
  }
}
