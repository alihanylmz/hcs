import 'package:flutter/material.dart';

class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.activeColor,
    required this.iconColor,
    required this.textColor,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color:
                isActive
                    ? activeColor
                    : Colors.white.withValues(alpha: isDark ? 0.02 : 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  isActive
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: isDark ? 0.06 : 0.08),
            ),
            boxShadow:
                isActive
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                    : null,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.white.withValues(
                                alpha: isDark ? 0.06 : 0.08,
                              ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isActive ? Colors.white : iconColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w800 : FontWeight.w700,
                        color: isActive ? Colors.white : textColor,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: isActive ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarDivider extends StatelessWidget {
  const SidebarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Divider(
      color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.12),
      thickness: 1,
      height: 1,
    );
  }
}

