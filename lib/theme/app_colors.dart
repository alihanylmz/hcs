import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Brand
  static const Color corporateNavy = Color(0xFF102A43);
  static const Color corporateBlue = Color(0xFF2F6FED);
  static const Color corporateYellow = Color(0xFFD09A3B);
  static const Color corporateRed = Color(0xFFC4524D);

  // Light surfaces
  static const Color backgroundGrey = Color(0xFFF4F7FB);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF6F9FC);
  static const Color surfaceMuted = Color(0xFFEAF0F7);
  static const Color surfaceAccent = Color(0xFFF3F7FF);
  static const Color borderSubtle = Color(0xFFD8E1EC);
  static const Color borderStrong = Color(0xFFC4D2E1);

  // Dark surfaces
  static const Color backgroundDark = Color(0xFF08131F);
  static const Color surfaceDark = Color(0xFF0F2032);
  static const Color surfaceDarkRaised = Color(0xFF16283B);
  static const Color surfaceDarkMuted = Color(0xFF1B3249);
  static const Color borderDark = Color(0xFF294055);

  // Text
  static const Color textDark = Color(0xFF132235);
  static const Color textLight = Color(0xFF647A90);
  static const Color textOnDark = Color(0xFFF4F7FB);
  static const Color textOnDarkMuted = Color(0xFF9CB1C5);

  // Status
  static const Color statusOpen = Color(0xFF2F6FED);
  static const Color statusStock = Color(0xFF8B7236);
  static const Color statusSent = Color(0xFF4D6985);
  static const Color statusProgress = Color(0xFFD57A1F);
  static const Color statusDone = Color(0xFF237A5A);
  static const Color statusArchived = Color(0xFF8997A6);

  // Navigation
  static const Color sidebarBackgroundLight = Color(0xFF0F1E30);
  static const Color sidebarBackgroundDark = Color(0xFF09121E);
  static const Color sidebarActiveLight = Color(0xFF183856);
  static const Color sidebarActiveDark = Color(0xFF122A42);
  static const Color sidebarText = Color(0xFFF4F7FB);
  static const Color sidebarTextMuted = Color(0xFF9FB0C3);

  // Aliases used across the app
  static const Color primary = corporateNavy;
  static const Color background = backgroundGrey;
  static const Color surface = surfaceWhite;
  static const Color accent = corporateYellow;
  static const Color sidebarBackground = sidebarBackgroundLight;
  static const Color sidebarActive = sidebarActiveLight;
}
