import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Brand
  static const Color corporateNavy = Color(0xFF111827);
  static const Color corporateBlue = Color(0xFF0F6BFF);
  static const Color corporateYellow = Color(0xFFEAB308);
  static const Color corporateRed = Color(0xFFB91C1C);
  static const Color industrialCyan = Color(0xFF0891B2);
  static const Color industrialSteel = Color(0xFF475569);

  // Light surfaces
  static const Color backgroundGrey = Color(0xFFF1F3F6);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF7F8FA);
  static const Color surfaceMuted = Color(0xFFE2E8F0);
  static const Color surfaceAccent = Color(0xFFEAF2FF);
  static const Color borderSubtle = Color(0xFFD8DEE7);
  static const Color borderStrong = Color(0xFF64748B);

  // Dark surfaces
  static const Color backgroundDark = Color(0xFF0A0F16);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color surfaceDarkRaised = Color(0xFF182230);
  static const Color surfaceDarkMuted = Color(0xFF202C3B);
  static const Color borderDark = Color(0xFF334155);

  // Text
  static const Color textDark = Color(0xFF0F172A);
  static const Color textLight = Color(0xFF64748B);
  static const Color textOnDark = Color(0xFFF8FAFC);
  static const Color textOnDarkMuted = Color(0xFF94A3B8);

  // Status
  static const Color statusOpen = corporateBlue;
  static const Color statusStock = Color(0xFFB7791F);
  static const Color statusSent = Color(0xFF64748B);
  static const Color statusProgress = Color(0xFFD97706);
  static const Color statusDone = Color(0xFF15803D);
  static const Color statusArchived = Color(0xFF94A3B8);

  // Navigation
  static const Color sidebarBackgroundLight = Color(0xFF111827);
  static const Color sidebarBackgroundDark = Color(0xFF0A0F16);
  static const Color sidebarActiveLight = Color(0xFF0F6BFF);
  static const Color sidebarActiveDark = Color(0xFF0B5DE8);
  static const Color sidebarText = Color(0xFFF8FAFC);
  static const Color sidebarTextMuted = Color(0xFF94A3B8);

  // Aliases used across the app
  static const Color primary = corporateBlue;
  static const Color background = backgroundGrey;
  static const Color surface = surfaceWhite;
  static const Color accent = corporateYellow;
  static const Color sidebarBackground = sidebarBackgroundLight;
  static const Color sidebarActive = sidebarActiveLight;
}
