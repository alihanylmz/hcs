import 'package:flutter/material.dart';

import 'nav_shell_colors.dart';

/// Onaylanan tasarima gore menu ogesi: aktifken dolu bir pil degil, sol
/// tarafta ince renkli bir cizgi + aksanin hafif tonunda arka plan.
/// [expanded] false iken (ray daraltilmisken) sadece ikon gosterilir.
class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.expanded = true,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final palette = NavShellColors.of(context);
    final color = isActive ? palette.accent : palette.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        children: [
          if (isActive)
            Positioned(
              left: 0,
              top: 6,
              bottom: 6,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(3),
                  ),
                ),
              ),
            ),
          Material(
            color: isActive ? palette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 13 : 0,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment:
                      expanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: color),
                    if (expanded) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w600,
                            color:
                                isActive ? palette.accent : palette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SidebarDivider extends StatelessWidget {
  const SidebarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = NavShellColors.of(context);
    return Divider(color: palette.border, thickness: 1, height: 1);
  }
}
