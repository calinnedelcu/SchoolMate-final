import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/core/session.dart';
import 'package:firster/l10n/app_localizations.dart';
import 'package:firster/student/cereri.dart';
import 'package:firster/student/inbox.dart';
import 'package:firster/student/widgets/qr_bottom_sheet.dart';
import 'package:firster/student/widgets/schedule_bottom_sheet.dart';
import 'package:flutter/material.dart';

class _DampedScrollPhysics extends ScrollPhysics {
  const _DampedScrollPhysics({super.parent});
  @override
  _DampedScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _DampedScrollPhysics(parent: buildParent(ancestor));
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, offset) * 0.55;
}

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _surfaceLowest = Color(0xFFFFFFFF);
const _onSurface = Color(0xFF1A2050);
const _labelColor = Color(0xFF7A7E9A);
const _pencilYellow = Color(0xFFF5C518);

class MeniuScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final void Function(String docId)? onNavigateToActiveLeave;

  const MeniuScreen({
    super.key,
    this.onNavigateTab,
    this.onNavigateToActiveLeave,
  });

  @override
  State<MeniuScreen> createState() => _MeniuScreenState();
}

class _MeniuScreenState extends State<MeniuScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _leaveActiveStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _classDocStream;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots();

    _leaveActiveStream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', isEqualTo: currentUser.uid)
        .where('status', whereIn: ['approved', 'active', 'pending'])
        .snapshots();

    final classId = AppSession.classId;
    if (classId != null && classId.isNotEmpty) {
      _classDocStream = FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .snapshots();
    }
  }

  ({int startMin, int endMin, String startText, String endText})?
  _todaySchedule(Map<String, dynamic> classData) {
    final now = DateTime.now();
    final weekday = now.weekday;
    if (weekday > 5) return null;

    final schedule = (classData['schedule'] as Map?) ?? {};
    final daySchedule = schedule[weekday.toString()] as Map?;
    if (daySchedule == null) return null;

    int parseMinutes(String value) {
      final parts = value.split(':');
      if (parts.length != 2) return -1;
      final hour = int.tryParse(parts[0]) ?? -1;
      final minute = int.tryParse(parts[1]) ?? -1;
      if (hour < 0 || minute < 0) return -1;
      return hour * 60 + minute;
    }

    final startText = (daySchedule['start'] ?? '').toString();
    final endText = (daySchedule['end'] ?? '').toString();
    final startMin = parseMinutes(startText);
    final endMin = parseMinutes(endText);
    if (startMin < 0 || endMin < 0) return null;
    return (
      startMin: startMin,
      endMin: endMin,
      startText: startText,
      endText: endText,
    );
  }

  void _openCereri() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(2);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CereriScreen()));
  }

  Future<void> _openInbox() async {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(3);
      return;
    }

    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'inboxLastOpenedAt': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      }, SetOptions(merge: true));
    }

    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const InboxScreen()));
  }

  void _openSchedule() {
    showScheduleSheet(context);
  }

  Future<void> _showQrSheet(BuildContext context) async {
    await showQrSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final fallbackName = (AppSession.username?.trim().isNotEmpty ?? false)
        ? AppSession.username!.trim()
        : 'Student';

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userDocStream,
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final fullName = (data['fullName'] ?? '').toString().trim();
            final resolvedName = fullName.isNotEmpty ? fullName : fallbackName;
            final classId = (data['classId'] ?? AppSession.classId ?? '')
                .toString()
                .trim();
            final inboxLastOpenedAt = (data['inboxLastOpenedAt'] as Timestamp?)
                ?.toDate();
            final classStream = classId.isNotEmpty
                ? FirebaseFirestore.instance
                      .collection('classes')
                      .doc(classId)
                      .snapshots()
                : _classDocStream;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: classStream,
              builder: (context, classSnapshot) {
                final classData =
                    classSnapshot.data?.data() ?? const <String, dynamic>{};
                final todaySchedule = _todaySchedule(classData);

                return Column(
                  children: [
                    _TopHeroHeader(displayName: resolvedName),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const _DampedScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        child: Column(
                          children: [
                            _AziHeroCard(schedule: todaySchedule),
                            const SizedBox(height: 16),
                            _CerereInvoireCard(
                              leaveStream: _leaveActiveStream,
                              onCreateNew: _openCereri,
                              onShowQr: () => _showQrSheet(context),
                              onPendingTap: widget.onNavigateToActiveLeave,
                            ),
                            const SizedBox(height: 16),
                            _InboxPreviewCard(
                              studentUid:
                                  FirebaseAuth.instance.currentUser?.uid ?? '',
                              inboxLastOpenedAt: inboxLastOpenedAt,
                              onTap: _openInbox,
                            ),
                            const SizedBox(height: 24),
                            _QuickActionsRow(
                              onQr: () => _showQrSheet(context),
                              onSchedule: _openSchedule,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HEADER
// ────────────────────────────────────────────────────────────────────────────
class _TopHeroHeader extends StatelessWidget {
  final String displayName;

  const _TopHeroHeader({required this.displayName});

  static const _months = [
    '', 'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
    'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
  ];

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final dateStr = '${now.day} ${_months[now.month]} ${now.year}';

    return SizedBox(
      width: double.infinity,
      height: topPadding + 170,
      child: CustomPaint(
        painter: _HeaderWavePainter(),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(26, topPadding + 16, 70, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.homeGreeting(displayName),
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
                      color: _pencilYellow,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateStr,
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
          ],
        ),
      ),
    );
  }
}

void _drawSymbol(
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

class _HeaderWavePainter extends CustomPainter {
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

    // Large soft blob top-right
    final blobPaint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(Offset(size.width - 30, 40), 85, blobPaint);

    // Outlined ring top-right
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset(size.width - 30, 40), 85, ringPaint);

    // Soft blob bottom-left behind wave
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height - 70),
      55,
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );

    // Math symbols scattered as school-themed sparkles
    final c1 = Colors.white.withValues(alpha: 0.3);
    final c2 = Colors.white.withValues(alpha: 0.22);
    final cy = const Color(0xFFF5C518).withValues(alpha: 0.35);
    _drawSymbol(canvas, 'π', Offset(size.width * 0.54, 26), 15, cy);
    _drawSymbol(canvas, '+', Offset(size.width * 0.62, 52), 13, c1);
    _drawSymbol(canvas, '×', Offset(size.width * 0.48, 72), 11, c2);
    _drawSymbol(canvas, '√', Offset(size.width * 0.72, 38), 13, c2);
    _drawSymbol(canvas, '∞', Offset(size.width * 0.82, 65), 14, cy);
    _drawSymbol(canvas, '÷', Offset(size.width * 0.90, 42), 12, c2);
    _drawSymbol(canvas, '=', Offset(size.width * 0.22, size.height - 88), 11, c2);
    _drawSymbol(canvas, '∆', Offset(size.width * 0.38, size.height - 100), 12, cy);
    _drawSymbol(canvas, '²', Offset(size.width * 0.46, size.height - 75), 11, c2);

    canvas.restore();

    // Wave highlight line
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

    // Second wave accent (filled)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────────────────────
// AZI HERO CARD (gradient, white text, vertical layout)
// ────────────────────────────────────────────────────────────────────────────
class _AziHeroCard extends StatelessWidget {
  final ({int startMin, int endMin, String startText, String endText})?
      schedule;

  const _AziHeroCard({required this.schedule});

  static const _dayNames = {
    1: 'Luni', 2: 'Marți', 3: 'Miercuri', 4: 'Joi',
    5: 'Vineri', 6: 'Sâmbătă', 7: 'Duminică',
  };
  static const _dayNamesEn = {
    1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday',
    5: 'Friday', 6: 'Saturday', 7: 'Sunday',
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).languageCode;
    final dayName = locale == 'ro'
        ? (_dayNames[now.weekday] ?? '')
        : (_dayNamesEn[now.weekday] ?? '');
    final intervalText = schedule != null
        ? '${schedule!.startText} - ${schedule!.endText}'
        : '—';

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2848B0), Color(0xFF3460CC), Color(0xFF4070E0)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x282848B0),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _AziCardDecorPainter()),
          ),
          Positioned(
            right: -18,
            bottom: -22,
            child: Transform.rotate(
              angle: -0.18,
              child: Icon(
                Icons.menu_book_rounded,
                size: 140,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.access_time_rounded,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.homeTodayCardTitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _pencilYellow,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${now.day}/${now.month}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  l.homeTodayDayLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 32,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: _pencilYellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 18),
                Text(
                  l.homeTodayIntervalLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  intervalText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AziCardDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Notebook grid pattern (math squared paper)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    const gridSize = 26.0;
    for (double x = gridSize; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = gridSize; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Large soft circle top-right
    canvas.drawCircle(
      Offset(size.width + 10, -10),
      90,
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );

    // Outlined ring top-right
    canvas.drawCircle(
      Offset(size.width + 10, -10),
      90,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Medium soft circle bottom-right
    canvas.drawCircle(
      Offset(size.width - 30, size.height + 10),
      70,
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );

    // Math symbols as school-themed sparkles
    final c1 = Colors.white.withValues(alpha: 0.3);
    final c2 = Colors.white.withValues(alpha: 0.22);
    final cy = const Color(0xFFF5C518).withValues(alpha: 0.35);
    _drawSymbol(canvas, '∑', Offset(size.width - 28, size.height * 0.42), 14, cy);
    _drawSymbol(canvas, '=', Offset(size.width * 0.88, size.height - 38), 12, c1);
    _drawSymbol(canvas, '∫', Offset(size.width * 0.82, size.height * 0.28), 15, c2);
    _drawSymbol(canvas, 'π', Offset(size.width * 0.93, size.height * 0.55), 13, c2);
    _drawSymbol(canvas, '+', Offset(size.width * 0.72, size.height * 0.58), 11, cy);
    _drawSymbol(canvas, '√', Offset(size.width * 0.78, size.height - 28), 12, c2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────────────────────────────────
// CERERE DE ÎNVOIRE CARD
// ────────────────────────────────────────────────────────────────────────────
class _CerereInvoireCard extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? leaveStream;
  final VoidCallback onCreateNew;
  final VoidCallback onShowQr;
  final void Function(String docId)? onPendingTap;

  const _CerereInvoireCard({
    required this.leaveStream,
    required this.onCreateNew,
    required this.onShowQr,
    required this.onPendingTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: leaveStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);

        bool isExpired(Map<String, dynamic> data) {
          final forDate = (data['requestedForDate'] as Timestamp?)?.toDate();
          if (forDate == null) return false;
          return forDate.isBefore(todayMidnight);
        }

        QueryDocumentSnapshot<Map<String, dynamic>>? activeDoc;
        for (final d in docs) {
          final data = d.data();
          if (isExpired(data)) continue;
          final status = data['status'];
          if (status == 'approved' || status == 'active') {
            activeDoc ??= d;
          }
        }

        final onTap = activeDoc != null ? onShowQr : onCreateNew;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _surfaceLowest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _WhiteCardDecorPainter()),
                ),
                Positioned(
                  right: -12,
                  bottom: -18,
                  child: Transform.rotate(
                    angle: -0.12,
                    child: Icon(
                      Icons.assignment_rounded,
                      size: 90,
                      color: _primary.withValues(alpha: 0.055),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _primary.withValues(alpha: 0.12),
                                  _primary.withValues(alpha: 0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.description_rounded,
                              color: _primary,
                              size: 24,
                            ),
                          ),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _pencilYellow,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.homeRequestCardTitle,
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.homeRequestNoneSubtitle,
                              style: const TextStyle(
                                color: _labelColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: _labelColor,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// INBOX PREVIEW CARD
// ────────────────────────────────────────────────────────────────────────────
class _InboxPreviewCard extends StatelessWidget {
  final String studentUid;
  final DateTime? inboxLastOpenedAt;
  final VoidCallback onTap;

  const _InboxPreviewCard({
    required this.studentUid,
    required this.inboxLastOpenedAt,
    required this.onTap,
  });

  DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isVisibleLeaveMessage(Map<String, dynamic> data) {
    final source = (data['source'] ?? '').toString().trim();
    return source != 'secretariat';
  }

  DateTime? _leaveMessageTime(Map<String, dynamic> data) {
    return _readDateTime(data['reviewedAt']) ??
        _readDateTime(data['requestedAt']);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: studentUid.isEmpty
            ? null
            : FirebaseFirestore.instance
                  .collection('leaveRequests')
                  .where('studentUid', isEqualTo: studentUid)
                  .orderBy('requestedAt', descending: true)
                  .limit(20)
                  .snapshots(),
        builder: (context, leaveSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: studentUid.isEmpty
                ? null
                : FirebaseFirestore.instance
                      .collection('secretariatMessages')
                      .where('recipientUid', isEqualTo: studentUid)
                      .where('recipientRole', isEqualTo: 'student')
                      .limit(20)
                      .snapshots(),
            builder: (context, secretariatSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: studentUid.isEmpty
                    ? null
                    : FirebaseFirestore.instance
                          .collection('secretariatMessages')
                          .where('recipientUid', isEqualTo: '')
                          .where('recipientRole', isEqualTo: 'student')
                          .limit(20)
                          .snapshots(),
                builder: (context, globalSnapshot) {
                  final leaveDocs = leaveSnapshot.data?.docs ?? const [];
                  final secretariatDocs =
                      secretariatSnapshot.data?.docs ?? const [];
                  final globalDocs = globalSnapshot.data?.docs ?? const [];

                  final entries = <_PreviewEntry>[];
                  for (final doc in leaveDocs) {
                    final data = doc.data();
                    if (!_isVisibleLeaveMessage(data)) continue;
                    final when = _leaveMessageTime(data);
                    if (when == null) continue;
                    entries.add(_PreviewEntry(when: when));
                  }
                  for (final doc in [...secretariatDocs, ...globalDocs]) {
                    final data = doc.data();
                    final when = _readDateTime(data['createdAt']);
                    if (when == null) continue;
                    entries.add(_PreviewEntry(when: when));
                  }

                  entries.sort((a, b) => b.when.compareTo(a.when));

                  int unread;
                  if (inboxLastOpenedAt == null) {
                    unread = entries.length;
                  } else {
                    unread = entries
                        .where((e) => e.when.isAfter(inboxLastOpenedAt!))
                        .length;
                  }

                  final hasNew = unread > 0;

                  return Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _surfaceLowest,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _WhiteCardDecorPainter(variant: 4),
                          ),
                        ),
                        Positioned(
                          right: -10,
                          bottom: -16,
                          child: Transform.rotate(
                            angle: 0.14,
                            child: Icon(
                              Icons.mail_rounded,
                              size: 85,
                              color: _primary.withValues(alpha: 0.055),
                            ),
                          ),
                        ),
                        Container(
                      padding: const EdgeInsets.fromLTRB(0, 0, 14, 0),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: _primary, width: 4),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 18, 0, 18),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        _primary.withValues(alpha: 0.12),
                                        _primary.withValues(alpha: 0.06),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: _primary.withValues(alpha: 0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_rounded,
                                    color: _primary,
                                    size: 22,
                                  ),
                                ),
                                if (hasNew)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _pencilYellow,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        l.homeInboxPreviewTitle,
                                        style: const TextStyle(
                                          color: _onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (hasNew) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _pencilYellow,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'NEW',
                                            style: TextStyle(
                                              color: _onSurface,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    hasNew
                                        ? l.homeInboxUnreadCount(unread)
                                        : l.homeInboxNoMessages,
                                    style: TextStyle(
                                      color: hasNew ? _primary : _labelColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: _labelColor,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PreviewEntry {
  final DateTime when;
  const _PreviewEntry({required this.when});
}

class _WhiteCardDecorPainter extends CustomPainter {
  final int variant;
  const _WhiteCardDecorPainter({this.variant = 0});

  @override
  void paint(Canvas canvas, Size size) {
    // Soft primary-tinted blob bottom-right
    canvas.drawCircle(
      Offset(size.width - 20, size.height + 10),
      40,
      Paint()..color = _primary.withValues(alpha: 0.035),
    );

    // Math symbols scattered — yellow symbol varies per card
    final c1 = _primary.withValues(alpha: 0.1);
    final c2 = _primary.withValues(alpha: 0.07);
    final cy = const Color(0xFFF5C518).withValues(alpha: 0.4);

    final entries = [
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
      _drawSymbol(canvas, text, pos, fs, color);
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteCardDecorPainter oldDelegate) =>
      oldDelegate.variant != variant;
}

// ────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS ROW (2 tiles)
// ────────────────────────────────────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onQr;
  final VoidCallback onSchedule;

  const _QuickActionsRow({
    required this.onQr,
    required this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            icon: Icons.qr_code_2_rounded,
            label: 'QR Gate',
            gradientColors: const [Color(0xFF2848B0), Color(0xFF4070E0)],
            onTap: onQr,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.calendar_today_rounded,
            label: 'Schedule',
            gradientColors: const [Color(0xFF3460CC), Color(0xFF4878E8)],
            onTap: onSchedule,
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _QuickTileDecorPainter()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 16,
                    height: 2,
                    decoration: BoxDecoration(
                      color: _pencilYellow,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTileDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Notebook grid pattern
    final gridPaint = Paint()
      ..color = _primary.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    const gridSize = 22.0;
    for (double x = gridSize; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = gridSize; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Soft corner blob bottom-right
    canvas.drawCircle(
      Offset(size.width + 5, size.height + 5),
      28,
      Paint()..color = _primary.withValues(alpha: 0.05),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
