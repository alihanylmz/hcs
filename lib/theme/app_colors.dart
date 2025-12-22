import 'package:flutter/material.dart';

class AppColors {
  // Kurumsal Renkler (Sarı / Kırmızı / Siyah)
  // Not: Projede "corporateNavy" birçok yerde kullanıldığı için ismi koruyup rengi siyaha çekiyoruz.
  static const Color corporateNavy = Color(0xFF0B0B0B); // Kurumsal Siyah
  static const Color corporateYellow = Color(0xFFFFC107); // Sarı (Amber)
  static const Color corporateRed = Color(0xFFD32F2F); // Kırmızı

  static const Color backgroundGrey = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF64748B);
  
  // Status Colors
  static const Color statusOpen = Colors.blue;
  static const Color statusStock = Colors.purple;
  static const Color statusSent = Colors.indigo;
  static const Color statusProgress = Colors.orange;
  static const Color statusDone = Colors.green;
  static const Color statusArchived = Colors.grey;

  // Modern palet (kurumsal renklere uyarlanmış)
  static const Color primary = corporateNavy; // Siyah
  static const Color background = Color(0xFFF8FAFC); // Kırık Beyaz (Slate-50)
  static const Color surface = Colors.white;
  // textDark ve textLight yukarıda zaten var
  static const Color accent = corporateYellow; // Sarı vurgu
}
