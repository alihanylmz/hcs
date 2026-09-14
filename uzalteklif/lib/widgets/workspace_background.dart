import 'package:flutter/material.dart';

import '../app/nav_shell_colors.dart';

/// Sayfa arka planlari.
///
/// Eskiden burada sicak kum rengi/brass-mint gradyan + ince izgara dokusu
/// vardi. Yeni navigasyon kabugu (Sidebar + ust cubuk) acik lavanta-gri
/// bir zemin (`NavShellColors.pageBackground`) kullanmaya gecince, bu eski
/// gradyan sayfa icerigi ile kabugun arasinda "iki farkli tema" gibi
/// gorunen bir uyumsuzluk yaratti - kullanicinin fark ettigi buydu. Artik
/// bu widget de ayni duz zemin rengini kullaniyor.
class WorkspaceBackground extends StatelessWidget {
  const WorkspaceBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: NavShellColors.of(context).pageBackground,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
