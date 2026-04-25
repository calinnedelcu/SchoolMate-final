import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../core/session.dart';
import '../student/logout_dialog.dart';
import 'orardir.dart';
import 'cereriasteptare.dart';
import 'statuselevi.dart';
import 'mesajedir.dart';
import 'voluntariat_manage_page.dart';
import 'widgets/schedule_bottom_sheet_teacher.dart';
import '../admin/admin_post_composer_page.dart';

class _DampedScrollPhysics extends ScrollPhysics {
  const _DampedScrollPhysics({super.parent});
  @override
  _DampedScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _DampedScrollPhysics(parent: buildParent(ancestor));
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, offset) * 0.55;
}

const _kGreen = Color(0xFF2848B0);
const _pencilYellow = Color(0xFFF5C518);
const _kBg = Color(0xFFEFF5FA);

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

// Painter copied/adapted from student header to match exact visuals
class _HeaderWavePainterTeacher extends CustomPainter {
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
    final blobPaint = Paint()..color = Colors.white.withOpacity(0.06);
    canvas.drawCircle(Offset(size.width - 30, 40), 85, blobPaint);

    // Outlined ring top-right
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset(size.width - 30, 40), 85, ringPaint);

    // Soft blob bottom-left behind wave
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height - 70),
      55,
      Paint()..color = Colors.white.withOpacity(0.04),
    );

    // Math symbols scattered as school-themed sparkles
    final c1 = Colors.white.withOpacity(0.3);
    final c2 = Colors.white.withOpacity(0.22);
    final cy = _pencilYellow.withOpacity(0.35);
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
      ..color = Colors.white.withOpacity(0.22)
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

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _teacherStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _pendingStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _studentsStream;
  String _classId = '';
  bool _profilePressed = false;

  @override
  void initState() {
    super.initState();
    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      _teacherStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();

      // Listen once to get classId and initialize pending stream
      _teacherStream!.listen((doc) {
        if (!mounted) return;
        final data = doc.data() ?? {};
        final classId = (data['classId'] ?? '').toString().trim();
        if (classId.isNotEmpty && classId != _classId) {
          setState(() {
            _classId = classId;
            _pendingStream = FirebaseFirestore.instance
                .collection('leaveRequests')
                .where('classId', isEqualTo: classId)
                .where('status', isEqualTo: 'pending')
                .snapshots();
            _studentsStream = FirebaseFirestore.instance
                .collection('users')
                .where('classId', isEqualTo: classId)
                .where('role', isEqualTo: 'student')
                .snapshots();
          });
        }
      });
    }
  }

  // ignore: unused_element
  Future<void> _logout() async {
    final shouldLogout = await showStudentLogoutDialog(
      context,
      accentColor: _kGreen,
      surfaceColor: Colors.white,
      softSurfaceColor: const Color(0xFFE8EEF4),
      titleColor: const Color(0xFF1F8BE7),
      messageColor: const Color(0xFF6488A8),
    );

    if (!shouldLogout) return;
    try {
      await FirebaseAuth.instance.signOut();
      AppSession.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu am putut face logout. Încearcă din nou.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('No session')));
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _teacherStream,
              builder: (context, snap) {
                final data = snap.data?.data() ?? const <String, dynamic>{};
                final fullName = (data['fullName'] ?? '').toString().trim();
                final displayName = fullName.isNotEmpty
                    ? fullName
                    : (AppSession.username ?? 'Diriginte');

                final scrollStart = 190.0;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: _kBg),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildHeader(displayName),
                    ),
                    Positioned(
                      top: scrollStart,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SingleChildScrollView(
                        physics: const _DampedScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          children: [
                            _buildActivityCard(),
                            const SizedBox(height: 16),
                            _buildGrid(context),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: topPadding + 5,
            right: 14,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _profilePressed = true),
              onTapUp: (_) {
                setState(() => _profilePressed = false);
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const OrarDirPage(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
              onTapCancel: () => setState(() => _profilePressed = false),
              child: AnimatedScale(
                scale: _profilePressed ? 0.78 : 1.0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0x3389BEEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0x6DC5E0F6),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Blue hero header (copied from student design) ─────────────────────────
  Widget _buildHeader(String displayName) {
    final topPadding = MediaQuery.of(context).padding.top;
    final now = DateTime.now();
    final dateStr = '${now.day} aprilie ${now.year}';

    return SizedBox(
      width: double.infinity,
      height: topPadding + 170,
      child: CustomPaint(
        painter: _HeaderWavePainterTeacher(),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(26, topPadding + 16, 70, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $displayName',
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
                      color: Colors.white.withOpacity(0.85),
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

 

  Widget _headerCircle(double size, double opacity) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ─── Card "Activitate Recentă" ──────────────────────────────────────────────
  Widget _buildActivityCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _pendingStream,
      builder: (context, snap) {
        final pendingDocs = snap.data?.docs ?? [];

        final items = <_ActivityData>[];

        // Cereri în așteptare reale (max 1 pentru a lăsa loc celorlalte)
        for (final doc in pendingDocs.take(1)) {
          final d = doc.data() as Map<String, dynamic>;
          final classId = (d['classId'] ?? '').toString();
          items.add(
            _ActivityData(
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFF9D1F5F),
              title: 'Pending request - $classId',
              time: 'NOW',
            ),
          );
        }

        items.add(
          const _ActivityData(
            icon: Icons.campaign_rounded,
            iconColor: _kGreen,
            title: 'New school announcement',
            time: 'TODAY',
          ),
        );

        if (pendingDocs.length > 1) {
          final d = pendingDocs[1].data() as Map<String, dynamic>;
          final studentName = (d['studentName'] ?? '').toString();
          items.add(
            _ActivityData(
              icon: Icons.cancel_rounded,
              iconColor: _kGreen,
              title: 'Request rejected - $studentName',
              time: 'TODAY',
            ),
          );
        }

        return Container(
          width: double.infinity,
          height: 390,
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
              Positioned.fill(child: CustomPaint(painter: _AziCardDecorPainter())),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: items
                              .map((item) => _ActivityItemWidget(data: item))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: _studentsStream,
                      builder: (context, stuSnap) {
                        final students = stuSnap.data?.docs ?? [];
                        final inSchool = students
                            .where(
                              (d) =>
                                  (d.data() as Map<String, dynamic>)['inSchool'] ==
                                  true,
                            )
                            .length;
                        final absent = students.length - inSchool;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatBox(
                                  label: 'PRESENT',
                                  value: students.isEmpty ? '--' : '$inSchool',
                                  valueColor: _kGreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatBox(
                                  label: 'ABSENT',
                                  value: students.isEmpty ? '--' : '$absent',
                                  valueColor: absent > 0
                                      ? const Color(0xFF8E3557)
                                      : const Color(0xFF717B6E),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Grid 2×2 ───────────────────────────────────────────────────────────────
  Widget _buildGrid(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _pendingStream,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        final requestsSubtitle = count > 0
            ? '$count ${count == 1 ? 'new request' : 'new requests'}'
            : 'No new requests';

        return Column(
          children: [
            // Top full-width white long button: Leave Requests
            _GridCard(
              icon: Icons.article_rounded,
              title: 'Leave requests',
              subtitle: requestsSubtitle,
              isDark: false,
              wide: true,
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const CereriAsteptarePage(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Top full-width white long button: Messages
            _GridCard(
              icon: Icons.chat_bubble_rounded,
              title: 'Messages',
              subtitle: 'No new messages',
              isDark: false,
              wide: true,
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const MesajeDirPage(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Row with two student-style quick tiles: My Class (left) and Schedule (right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _QuickActionTileTeacher(
                    icon: Icons.group_rounded,
                    label: 'My Class',
                    gradientColors: const [Color(0xFF2848B0), Color(0xFF4070E0)],
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const StatusEleviPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionTileTeacher(
                    icon: Icons.event_rounded,
                    label: 'Schedule',
                    gradientColors: const [Color(0xFF3460CC), Color(0xFF4878E8)],
                    onTap: () => showTeacherScheduleSheet(context, _classId),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Volunteering long button at bottom
            _GridCard(
              icon: Icons.volunteer_activism_rounded,
              title: 'Volunteering',
              subtitle: 'Manage activities',
              isDark: false,
              wide: true,
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const VoluntariatManagePage(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Post Announcement (kept wide)
            _GridCard(
              icon: Icons.campaign_rounded,
              title: 'Post Announcement',
              subtitle: 'Create new announcement',
              isDark: false,
              wide: true,
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const AdminPostComposerPage(
                    mode: PostComposerMode.teacher,
                  ),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Model date activitate ────────────────────────────────────────────────────

class _ActivityData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String time;

  const _ActivityData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.time,
  });
}

// ─── Widget rând activitate ───────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatBox({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF717B6E),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItemWidget extends StatelessWidget {
  final _ActivityData data;

  const _ActivityItemWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8FC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: data.iconColor.withOpacity(1.0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: Color(0xFF4B83B2),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.time,
                      style: const TextStyle(
                        color: Color(0xFF85A0B7),
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card grid 2×2 ───────────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final bool wide;
  final VoidCallback? onTap;

  const _GridCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.wide = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : _kGreen.withValues(alpha: 0.10);
    final iconColor = isDark ? Colors.white : _kGreen;
    final titleColor = isDark ? Colors.white : const Color(0xFF4B83B2);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.74)
        : const Color(0xFF8AA2B6);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: wide ? null : 184,
        padding: wide
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
            : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isDark && !wide
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1F8BE7), Color(0xFF328FDF)],
                )
              : null,
          color: wide
              ? const Color(0xFFFFFFFF)
              : isDark
              ? null
              : const Color(0xFFDEE8F0),
          borderRadius: BorderRadius.circular(22),
          border: (!isDark && !wide)
              ? Border.all(
                  color: const Color(0xFFBACCD9).withValues(alpha: 0.36),
                  width: 1.1,
                )
              : null,
          boxShadow: isDark && !wide
              ? const [
                  BoxShadow(
                    color: Color(0x351F8BE7),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ]
              : wide
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: wide
            ? Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F0F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: _kGreen, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _kGreen,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF717B6E),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF717B6E),
                    size: 24,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 22,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Student-style quick action tile (copied/adapted from student meniu.dart)
class _QuickActionTileTeacher extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _QuickActionTileTeacher({
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
        height: 184,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
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
            Positioned.fill(child: CustomPaint(painter: _QuickTileDecorPainterTeacher())),
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
                      color: _kGreen,
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

class _QuickTileDecorPainterTeacher extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = _kGreen.withOpacity(0.04)
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
      Paint()..color = _kGreen.withOpacity(0.05),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Reuse the student's Azi card decor painter (not the whole card) to match the
// notebook grid + symbols background used by Today's Schedule.
class _AziCardDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Notebook grid pattern (math squared paper)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
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
      Paint()..color = Colors.white.withOpacity(0.06),
    );

    // Outlined ring top-right
    canvas.drawCircle(
      Offset(size.width + 10, -10),
      90,
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Medium soft circle bottom-right
    canvas.drawCircle(
      Offset(size.width - 30, size.height + 10),
      70,
      Paint()..color = Colors.white.withOpacity(0.05),
    );

    // Math symbols as school-themed sparkles
    final c1 = Colors.white.withOpacity(0.3);
    final c2 = Colors.white.withOpacity(0.22);
    final cy = _pencilYellow.withOpacity(0.35);
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
