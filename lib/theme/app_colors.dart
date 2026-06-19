import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Brand
  static const Color corporateNavy = Color(0xFF0F172A);
  static const Color corporateBlue = Color(0xFF2563EB);
  static const Color corporateYellow = Color(0xFFF59E0B);
  static const Color corporateRed = Color(0xFFDC2626);

  // Light surfaces
  static const Color backgroundGrey = Color(0xFFF1F5F9);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color surfaceMuted = Color(0xFFE2E8F0);
  static const Color surfaceAccent = Color(0xFFE8F0FF);
  static const Color borderSubtle = Color(0xFFD8E1EE);
  static const Color borderStrong = Color(0xFF94A3B8);

  // Dark surfaces
  static const Color backgroundDark = Color(0xFF020817);
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color surfaceDarkRaised = Color(0xFF111C32);
  static const Color surfaceDarkMuted = Color(0xFF16233D);
  static const Color borderDark = Color(0xFF2B3C5F);

  // Text
  static const Color textDark = Color(0xFF0F172A);
  static const Color textLight = Color(0xFF64748B);
  static const Color textOnDark = Color(0xFFF8FAFC);
  static const Color textOnDarkMuted = Color(0xFF94A3B8);

  // Status
  static const Color statusOpen = corporateBlue;
  static const Color statusStock = Color(0xFFD97706);
  static const Color statusSent = Color(0xFF64748B);
  static const Color statusProgress = Color(0xFFEA580C);
  static const Color statusDone = Color(0xFF059669);
  static const Color statusArchived = Color(0xFF94A3B8);

  // Navigation
  static const Color sidebarBackgroundLight = Color(0xFF0B1220);
  static const Color sidebarBackgroundDark = Color(0xFF020617);
  static const Color sidebarActiveLight = Color(0xFF16233D);
  static const Color sidebarActiveDark = Color(0xFF17284A);
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
