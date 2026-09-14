import 'package:flutter/material.dart';

/// Ust navigasyon kabugunun (Sidebar + AppLayout'un masaustu ust cubugu)
/// renk tokenlari. Referans admin temasindan (beyaz sidebar/ust cubuk,
/// canli mavi aksan, acik lavanta-gri sayfa zemini) birebir alindi.
///
/// Bilincli olarak `AppColors`'tan ayri tutuluyor: `AppColors` onlarca
/// icerik ekraninda (buton, rozet, durum renkleri) kullaniliyor, o global
/// paleti degistirmek bu isin kapsamini asar. Bu dosya sadece navigasyon
/// kabugu icin.
class NavShellColors {
  const NavShellColors._();

  static NavShellPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
  }

  static const NavShellPalette light = NavShellPalette(
    surface: Color(0xFFFFFFFF),
    pageBackground: Color(0xFFF5F6FA),
    textPrimary: Color(0xFF1E2A3A),
    textSecondary: Color(0xFF8A94A6),
    border: Color(0xFFEEF0F5),
    accent: Color(0xFF3E7BFA),
    accentOn: Color(0xFFFFFFFF),
    accentSoft: Color(0x163E7BFA), // ~%9 opak
    avatarBackground: Color(0xFFEEF1FE),
    dangerSoft: Color(0xFFFDECEC),
    danger: Color(0xFFE0475A),
  );

  static const NavShellPalette dark = NavShellPalette(
    surface: Color(0xFF171D2E),
    pageBackground: Color(0xFF0F1424),
    textPrimary: Color(0xFFEDEFF5),
    textSecondary: Color(0xFF9AA4B8),
    border: Color(0xFF2A3149),
    accent: Color(0xFF5B8DFF),
    accentOn: Color(0xFFFFFFFF),
    accentSoft: Color(0x295B8DFF), // ~%16 opak
    avatarBackground: Color(0xFF232A40),
    dangerSoft: Color(0x33E0475A),
    danger: Color(0xFFEF7A88),
  );
}

class NavShellPalette {
  const NavShellPalette({
    required this.surface,
    required this.pageBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.accent,
    required this.accentOn,
    required this.accentSoft,
    required this.avatarBackground,
    required this.dangerSoft,
    required this.danger,
  });

  final Color surface;
  final Color pageBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color accent;
  final Color accentOn;
  final Color accentSoft;
  final Color avatarBackground;
  final Color dangerSoft;
  final Color danger;
}
