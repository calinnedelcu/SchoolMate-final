import 'dart:ui' as ui;

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

/// Shared header for bottom-nav screens (Home, Schedule, Profile).
/// Wave-shaped bottom edge, gradient background, math sparkles.
class WaveHeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const WaveHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SizedBox(
      width: double.infinity,
      height: topPadding + 190,
      child: CustomPaint(
        painter: const WaveHeaderPainter(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(26, topPadding + 16, 70, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 46,
                height: 3,
                decoration: BoxDecoration(
                  color: kPencilYellow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WaveHeaderPainter extends CustomPainter {
  const WaveHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        const [Color(0xFF2040A0), Color(0xFF3058C8)],
      );

    final path = Path()
      ..lineTo(0, size.height - 40)
      ..quadraticBezierTo(
        size.width * 0.25, size.height,
        size.width * 0.5, size.height - 20,
      )
      ..quadraticBezierTo(
        size.width * 0.75, size.height - 42,
        size.width, size.height - 14,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
    canvas.save();
    canvas.clipPath(path);

    final blobPaint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(Offset(size.width - 30, 40), 85, blobPaint);

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset(size.width - 30, 40), 85, ringPaint);

    canvas.drawCircle(
      Offset(size.width * 0.12, size.height - 70),
      55,
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );

    final c1 = Colors.white.withValues(alpha: 0.3);
    final c2 = Colors.white.withValues(alpha: 0.22);
    final cy = kPencilYellow.withValues(alpha: 0.35);
    drawMathSymbol(canvas, 'π', Offset(size.width * 0.54, 26), 15, cy);
    drawMathSymbol(canvas, '+', Offset(size.width * 0.62, 52), 13, c1);
    drawMathSymbol(canvas, '×', Offset(size.width * 0.48, 72), 11, c2);
    drawMathSymbol(canvas, '√', Offset(size.width * 0.72, 38), 13, c2);
    drawMathSymbol(canvas, '∞', Offset(size.width * 0.82, 65), 14, cy);
    drawMathSymbol(canvas, '÷', Offset(size.width * 0.90, 42), 12, c2);
    drawMathSymbol(canvas, '=', Offset(size.width * 0.22, size.height - 88), 11, c2);
    drawMathSymbol(canvas, '∆', Offset(size.width * 0.38, size.height - 100), 12, cy);
    drawMathSymbol(canvas, '²', Offset(size.width * 0.46, size.height - 75), 11, c2);

    canvas.restore();

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final linePath = Path()
      ..moveTo(0, size.height - 52)
      ..quadraticBezierTo(
        size.width * 0.3, size.height - 12,
        size.width * 0.55, size.height - 34,
      )
      ..quadraticBezierTo(
        size.width * 0.78, size.height - 54,
        size.width, size.height - 22,
      );
    canvas.drawPath(linePath, linePaint);

    final accentPaint = Paint()..color = const Color(0x14FFFFFF);
    final accentPath = Path()
      ..moveTo(0, size.height - 58)
      ..quadraticBezierTo(
        size.width * 0.35, size.height - 16,
        size.width * 0.6, size.height - 42,
      )
      ..quadraticBezierTo(
        size.width * 0.8, size.height - 60,
        size.width, size.height - 28,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(accentPath, accentPaint);
  }

  @override
  bool shouldRepaint(covariant WaveHeaderPainter oldDelegate) => false;
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
