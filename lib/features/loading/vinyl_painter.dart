import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1A1A1A));

    final groovePaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double r = radius * 0.38; r < radius * 0.96; r += 5.5) {
      canvas.drawCircle(center, r, groovePaint);
    }

    final sheenPaint = Paint()
      ..color = AppColors.purple.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.3;
    canvas.drawCircle(center, radius * 0.65, sheenPaint);

    canvas.drawCircle(
      center,
      radius * 0.30,
      Paint()..color = const Color(0xFF0D0D0D),
    );

    canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF333333));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
