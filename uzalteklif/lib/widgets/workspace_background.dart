import 'dart:ui';

import 'package:flutter/material.dart';

class WorkspaceBackground extends StatelessWidget {
  const WorkspaceBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF6F0E6),
                  Color(0xFFE8EDF4),
                  Color(0xFFFDF8F0),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          top: -120,
          right: -80,
          child: _BlurOrb(
            color: Color(0x66C98E4B),
            size: 260,
          ),
        ),
        const Positioned(
          left: -90,
          bottom: -90,
          child: _BlurOrb(
            color: Color(0x664E907A),
            size: 240,
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        child,
      ],
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x12FFFFFF)
      ..strokeWidth = 1;

    const spacing = 48.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
