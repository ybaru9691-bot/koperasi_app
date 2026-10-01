import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Widget khusus untuk merender teks melengkung (curved text)
/// melingkari bagian bawah logo seperti bentuk setengah lingkaran.
class CurvedText extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final double radius;

  const CurvedText({
    super.key,
    required this.text,
    required this.textStyle,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(radius * 2 + 40, radius + 40),
      painter: _CurvedTextPainter(
        text: text,
        textStyle: textStyle,
        radius: radius,
      ),
    );
  }
}

class _CurvedTextPainter extends CustomPainter {
  final String text;
  final TextStyle textStyle;
  final double radius;

  _CurvedTextPainter({
    required this.text,
    required this.textStyle,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, 0);

    final List<TextPainter> painters = [];
    double totalWidth = 0;

    for (int i = 0; i < text.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: text[i], style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      painters.add(tp);
      totalWidth += tp.width;
    }

    const double letterSpacing = 2.0;
    totalWidth += (text.length - 1) * letterSpacing;

    final double totalAngle = totalWidth / radius;
    double currentAngle = (math.pi / 2) + (totalAngle / 2);

    for (int i = 0; i < text.length; i++) {
      final tp = painters[i];
      final double charAngle = tp.width / radius;
      final double halfCharAngle = charAngle / 2;

      final double angle = currentAngle - halfCharAngle;
      final double x = center.dx + radius * math.cos(angle);
      final double y = center.dy + radius * math.sin(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle - (math.pi / 2));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();

      currentAngle -= (charAngle + (letterSpacing / radius));
    }
  }

  @override
  bool shouldRepaint(covariant _CurvedTextPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.radius != radius;
  }
}
