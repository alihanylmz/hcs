import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Teklif Theme Palette (UzalTeklif Premium Palette)
  static const Color ink = Color(0xFF15304A);       // Primary Navy/Ink
  static const Color brass = Color(0xFFC98E4B);     // Warm Brass / Amber Accent
  static const Color sand = Color(0xFFF4EFE7);      // Warm Sand Background
  static const Color paper = Color(0xFFFFFCF7);     // Paper White Surface
  static const Color mist = Color(0xFFE4E8ED);      // Soft Mist Border
  static const Color mint = Color(0xFF4E907A);      // Sage Mint Success

  // Legacy Aliases mapped to Teklif Palette
  static const Color corporateNavy = ink;
  static const Color corporateBlue = ink;
  static const Color corporateYellow = brass;
  static const Color corporateRed = Color(0xFFB91C1C);
  static const Color industrialCyan = mint;
  static const Color industrialSteel = Color(0xFF475569);

  // Light surfaces
  static const Color backgroundGrey = sand;
  static const Color surfaceWhite = paper;
  static const Color surfaceSoft = Color(0xFFF0EAE1);
  static const Color surfaceMuted = Color(0xFFE4E8ED);
  static const Color surfaceAccent = Color(0xFFE8EEF5);
  static const Color borderSubtle = mist;
  static const Color borderStrong = Color(0xFFB0BAC5);

  // Dark surfaces
  static const Color backgroundDark = Color(0xFF0D1724);
  static const Color surfaceDark = Color(0xFF142233);
  static const Color surfaceDarkRaised = Color(0xFF1B2B3E);
  static const Color surfaceDarkMuted = Color(0xFF24364D);
  static const Color borderDark = Color(0xFF2C4059);

  // Text
  static const Color textDark = ink;
  static const Color textLight = Color(0xFF5A6E82);
  static const Color textOnDark = Color(0xFFEAF0F6);
  static const Color textOnDarkMuted = Color(0xFF94A3B8);

  // Status
  static const Color statusOpen = ink;
  static const Color statusStock = brass;
  static const Color statusSent = Color(0xFF5A6E82);
  static const Color statusProgress = brass;
  static const Color statusDone = mint;
  static const Color statusArchived = Color(0xFF94A3B8);

  // Navigation
  static const Color sidebarBackgroundLight = ink;
  static const Color sidebarBackgroundDark = Color(0xFF0D1724);
  static const Color sidebarActiveLight = brass;
  static const Color sidebarActiveDark = brass;
  static const Color sidebarText = Color(0xFFEAF0F6);
  static const Color sidebarTextMuted = Color(0xFF94A3B8);

  // Aliases used across the app
  static const Color primary = ink;
  static const Color background = sand;
  static const Color surface = paper;
  static const Color accent = brass;
  static const Color sidebarBackground = sidebarBackgroundLight;
  static const Color sidebarActive = sidebarActiveLight;
}
