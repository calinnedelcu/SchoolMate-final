import 'package:flutter/material.dart';

const kPencilYellow = Color(0xFFF5C518);

void drawMathSymbol(
  Canvas canvas,
  String text,
  Offset pos,
  double fontSize,
  Color color,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  painter.layout();
  painter.paint(canvas, pos - Offset(painter.width / 2, painter.height / 2));
}

class HeaderSparklesPainter extends CustomPainter {
  final int variant;
  const HeaderSparklesPainter({this.variant = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final c1 = Colors.white.withValues(alpha: 0.3);
    final c2 = Colors.white.withValues(alpha: 0.22);
    final cy = kPencilYellow.withValues(alpha: 0.35);

    final w = size.width;
    final h = size.height;

    final entries = <(String, Offset, double)>[
      ('π', Offset(w * 0.55, h * 0.25), 14),
      ('+', Offset(w * 0.68, h * 0.55), 12),
      ('×', Offset(w * 0.78, h * 0.3), 11),
      ('√', Offset(w * 0.86, h * 0.7), 13),
      ('∞', Offset(w * 0.92, h * 0.4), 14),
      ('÷', Offset(w * 0.48, h * 0.7), 11),
      ('=', Offset(w * 0.6, h * 0.85), 11),
      ('∑', Offset(w * 0.82, h * 0.15), 12),
    ];

    final yellowIdx = variant % entries.length;
    for (int i = 0; i < entries.length; i++) {
      final (text, pos, fs) = entries[i];
      final color = i == yellowIdx ? cy : (i.isEven ? c1 : c2);
      drawMathSymbol(canvas, text, pos, fs, color);
    }

    // Large soft blob top-right (same as home header)
    canvas.drawCircle(
      Offset(w - 20, -10),
      70,
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );
    canvas.drawCircle(
      Offset(w - 20, -10),
      70,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant HeaderSparklesPainter oldDelegate) =>
      oldDelegate.variant != variant;
}

class WhiteCardSparklesPainter extends CustomPainter {
  final Color primary;
  final int variant;
  const WhiteCardSparklesPainter({required this.primary, this.variant = 0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width - 20, size.height + 10),
      40,
      Paint()..color = primary.withValues(alpha: 0.035),
    );

    final c1 = primary.withValues(alpha: 0.1);
    final c2 = primary.withValues(alpha: 0.07);
    final cy = kPencilYellow.withValues(alpha: 0.4);

    final entries = <(String, Offset, double)>[
      ('π', Offset(size.width - 58, 16), 11.0),
      ('+', Offset(size.width - 42, 24), 10.0),
      ('×', Offset(size.width - 72, 28), 10.0),
      ('=', Offset(size.width - 50, size.height - 14), 10.0),
      ('√', Offset(size.width - 78, size.height - 20), 11.0),
    ];
    final yellowIdx = variant % entries.length;
    for (int i = 0; i < entries.length; i++) {
      final (text, pos, fs) = entries[i];
      final color = i == yellowIdx ? cy : (i.isEven ? c1 : c2);
      drawMathSymbol(canvas, text, pos, fs, color);
    }
  }

  @override
  bool shouldRepaint(covariant WhiteCardSparklesPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.primary != primary;
}
