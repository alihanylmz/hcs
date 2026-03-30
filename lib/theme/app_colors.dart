import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Brand
  static const Color corporateNavy = Color(0xFF24313C);
  static const Color corporateBlue = Color(0xFF2F7C78);
  static const Color corporateYellow = Color(0xFFC7964F);
  static const Color corporateRed = Color(0xFFC76659);

  // Light surfaces
  static const Color backgroundGrey = Color(0xFFF4F1EA);
  static const Color surfaceWhite = Color(0xFFFFFCF7);
  static const Color surfaceSoft = Color(0xFFF9F5EE);
  static const Color surfaceMuted = Color(0xFFEEE7DC);
  static const Color surfaceAccent = Color(0xFFE4F1EF);
  static const Color borderSubtle = Color(0xFFD8D0C3);
  static const Color borderStrong = Color(0xFFC7BCA9);

  // Dark surfaces
  static const Color backgroundDark = Color(0xFF0F161B);
  static const Color surfaceDark = Color(0xFF162127);
  static const Color surfaceDarkRaised = Color(0xFF1B2931);
  static const Color surfaceDarkMuted = Color(0xFF243540);
  static const Color borderDark = Color(0xFF334A57);

  // Text
  static const Color textDark = Color(0xFF1F2A33);
  static const Color textLight = Color(0xFF6E7A75);
  static const Color textOnDark = Color(0xFFF2F5F6);
  static const Color textOnDarkMuted = Color(0xFFB7C0C5);

  // Status
  static const Color statusOpen = corporateBlue;
  static const Color statusStock = Color(0xFFBE914E);
  static const Color statusSent = Color(0xFF71838D);
  static const Color statusProgress = Color(0xFFD28C43);
  static const Color statusDone = Color(0xFF3E8A78);
  static const Color statusArchived = Color(0xFF919FA7);

  // Navigation
  static const Color sidebarBackgroundLight = Color(0xFF21313D);
  static const Color sidebarBackgroundDark = Color(0xFF111B22);
  static const Color sidebarActiveLight = Color(0xFF30515A);
  static const Color sidebarActiveDark = Color(0xFF213942);
  static const Color sidebarText = Color(0xFFF2F5F6);
  static const Color sidebarTextMuted = Color(0xFFB8C5CC);

  // Aliases used across the app
  static const Color primary = corporateBlue;
  static const Color background = backgroundGrey;
  static const Color surface = surfaceWhite;
  static const Color accent = corporateYellow;
  static const Color sidebarBackground = sidebarBackgroundLight;
  static const Color sidebarActive = sidebarActiveLight;
}
