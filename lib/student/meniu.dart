import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_mate/core/session.dart';
import 'package:school_mate/student/cereri.dart';
import 'package:school_mate/student/inbox.dart';
import 'package:school_mate/student/widgets/no_anim_route.dart';
import 'package:school_mate/student/widgets/qr_bottom_sheet.dart';
import 'package:school_mate/student/widgets/school_decor.dart';
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
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _classDocStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _timetableDocStream;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots();

    final classId = AppSession.classId;
    if (classId != null && classId.isNotEmpty) {
      _classDocStream = FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .snapshots();
      _timetableDocStream = FirebaseFirestore.instance
          .collection('timetables')
          .doc(classId)
          .snapshots();
    }
  }

  static int _parseHHMM(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return -1;
    final hour = int.tryParse(parts[0]) ?? -1;
    final minute = int.tryParse(parts[1]) ?? -1;
    if (hour < 0 || minute < 0) return -1;
    return hour * 60 + minute;
  }

  static String _formatHHMM(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  ({int startMin, int endMin, String startText, String endText})?
  _todayScheduleFromTimetable(Map<String, dynamic> timetableData) {
    final now = DateTime.now();
    final weekday = now.weekday;
    if (weekday > 5) return null;

    final days = (timetableData['days'] as Map?)?.cast<String, dynamic>();
    final dayMap = days?[weekday.toString()] as Map?;
    if (dayMap == null || dayMap.isEmpty) return null;

    final startTime = (timetableData['startTime'] as String?) ?? '08:00';
    final baseMin = _parseHHMM(startTime);
    if (baseMin < 0) return null;

    final rawSlots = (timetableData['slots'] as List?) ?? const [];
    final lessonStarts = <int>[];
    final lessonEnds = <int>[];
    int cur = baseMin;
    for (final raw in rawSlots) {
      if (raw is! Map) continue;
      final m = raw.cast<String, dynamic>();
      final type = (m['type'] as String?) ?? 'lesson';
      final duration = (m['duration'] as num?)?.toInt() ?? 50;
      final end = cur + duration;
      if (type == 'lesson') {
        lessonStarts.add(cur);
        lessonEnds.add(end);
      }
      cur = end;
    }

    int firstIdx = -1;
    int lastIdx = -1;
    for (var i = 0; i < lessonStarts.length; i++) {
      final entry = dayMap['$i'];
      if (entry is Map && entry.isNotEmpty) {
        if (firstIdx < 0) firstIdx = i;
        lastIdx = i;
      }
    }
    if (firstIdx < 0) return null;

    final s = lessonStarts[firstIdx];
    final e = lessonEnds[lastIdx];
    return (
      startMin: s,
      endMin: e,
      startText: _formatHHMM(s),
      endText: _formatHHMM(e),
    );
  }

  ({int startMin, int endMin, String startText, String endText})?
  _todaySchedule(Map<String, dynamic> classData) {
    final now = DateTime.now();
    final weekday = now.weekday;
    if (weekday > 5) return null;

    final schedule = (classData['schedule'] as Map?) ?? {};
    final daySchedule = schedule[weekday.toString()] as Map?;
    if (daySchedule == null) return null;

    final startText = (daySchedule['start'] ?? '').toString();
    final endText = (daySchedule['end'] ?? '').toString();
    final startMin = _parseHHMM(startText);
    final endMin = _parseHHMM(endText);
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
    Navigator.of(context).push(noAnimRoute((_) => const CereriScreen()));
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
    Navigator.of(context).push(noAnimRoute((_) => const InboxScreen()));
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
            final timetableStream = classId.isNotEmpty
                ? FirebaseFirestore.instance
                      .collection('timetables')
                      .doc(classId)
                      .snapshots()
                : _timetableDocStream;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: classStream,
              builder: (context, classSnapshot) {
                final classData =
                    classSnapshot.data?.data() ?? const <String, dynamic>{};

                final now = DateTime.now();
                final dateStr =
                    '${now.day} ${_homeMonths[now.month]} ${now.year}';
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: timetableStream,
                  builder: (context, ttSnapshot) {
                    final timetableData =
                        ttSnapshot.data?.data() ?? const <String, dynamic>{};
                    final todaySchedule =
                        _todayScheduleFromTimetable(timetableData) ??
                            _todaySchedule(classData);

                    return Column(
                      children: [
                        WaveHeroHeader(
                          title: 'Welcome,\n$resolvedName',
                          subtitle: dateStr,
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const _DampedScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                            child: Column(
                              children: [
                                _AziHeroCard(schedule: todaySchedule),
                                const SizedBox(height: 16),
                                _QuickActionsRow(
                                  onQr: () => _showQrSheet(context),
                                  onLeaveRequests: _openCereri,
                                ),
                                const SizedBox(height: 16),
                                _InboxPreviewCard(
                                  studentUid:
                                      FirebaseAuth.instance.currentUser?.uid ??
                                          '',
                                  inboxLastOpenedAt: inboxLastOpenedAt,
                                  onTap: _openInbox,
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
            );
          },
        ),
      ),
    );
  }
}

const _homeMonths = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// AZI HERO CARD (gradient, white text, vertical layout)
class _AziHeroCard extends StatelessWidget {
  final ({int startMin, int endMin, String startText, String endText})?
      schedule;

  const _AziHeroCard({required this.schedule});

  static const _dayNamesEn = {
    1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday',
    5: 'Friday', 6: 'Saturday', 7: 'Sunday',
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayName = _dayNamesEn[now.weekday] ?? '';
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
                        "TODAY'S SCHEDULE",
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
                  'Current day',
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
                  'Class interval',
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
    drawMathSymbol(canvas, '∑', Offset(size.width - 28, size.height * 0.42), 14, cy);
    drawMathSymbol(canvas, '=', Offset(size.width * 0.88, size.height - 38), 12, c1);
    drawMathSymbol(canvas, '∫', Offset(size.width * 0.82, size.height * 0.28), 15, c2);
    drawMathSymbol(canvas, 'π', Offset(size.width * 0.93, size.height * 0.55), 13, c2);
    drawMathSymbol(canvas, '+', Offset(size.width * 0.72, size.height * 0.58), 11, cy);
    drawMathSymbol(canvas, '√', Offset(size.width * 0.78, size.height - 28), 12, c2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// INBOX PREVIEW CARD
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
                                      const Text(
                                        'Announcements',
                                        style: TextStyle(
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
                                        ? (unread == 1
                                              ? '1 new announcement'
                                              : '$unread new announcements')
                                        : 'No new announcements',
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
      drawMathSymbol(canvas, text, pos, fs, color);
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteCardDecorPainter oldDelegate) =>
      oldDelegate.variant != variant;
}

// QUICK ACTIONS ROW (2 tiles)
class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onQr;
  final VoidCallback onLeaveRequests;

  const _QuickActionsRow({
    required this.onQr,
    required this.onLeaveRequests,
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
            icon: Icons.description_rounded,
            label: 'Leave requests',
            gradientColors: const [Color(0xFF3460CC), Color(0xFF4878E8)],
            onTap: onLeaveRequests,
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
