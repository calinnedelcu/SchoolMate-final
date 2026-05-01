import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import '../student/widgets/no_anim_route.dart';
import '../student/widgets/school_decor.dart' show WaveHeroHeader;
import 'cereriasteptare.dart';
import 'mesajedir.dart';
import 'widgets/schedule_bottom_sheet_teacher.dart';

const _homeMonths = [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

// Same palette as parent dashboard
const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _surfaceContainerLow = Color(0xFFE8EAF2);
const _surfaceLowest = Color(0xFFFFFFFF);
const _onSurface = Color(0xFF1A2050);
const _labelColor = Color(0xFF7A7E9A);
const _pencilYellow = Color(0xFFF5C518);

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

class _WhiteCardDecorPainter extends CustomPainter {
  final int variant;
  const _WhiteCardDecorPainter({this.variant = 0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width - 20, size.height + 10),
      40,
      Paint()..color = _primary.withValues(alpha: 0.035),
    );

    final c1 = _primary.withValues(alpha: 0.10);
    final c2 = _primary.withValues(alpha: 0.07);
    final cy = _pencilYellow.withValues(alpha: 0.40);

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

class _DampedScrollPhysics extends ScrollPhysics {
  const _DampedScrollPhysics({super.parent});

  @override
  _DampedScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _DampedScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, offset) * 0.55;
}

// MAIN WIDGET
class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _teacherStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _pendingStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _studentsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _classMessagesStream;
  String _classId = '';
  DateTime? _localInboxLastOpened;

  @override
  void initState() {
    super.initState();
    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      _teacherStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();

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
            _classMessagesStream = FirebaseFirestore.instance
                .collection('leaveRequests')
                .where('classId', isEqualTo: classId)
                .snapshots();
          });
        }
      });
    }
  }

  DateTime? _effectiveLastOpened(DateTime? server, DateTime? local) {
    if (server == null) return local;
    if (local == null) return server;
    return local.isAfter(server) ? local : server;
  }

  Future<void> _openMessages() async {
    final uid = AppSession.uid;
    final openedAt = DateTime.now();
    if (mounted) setState(() => _localInboxLastOpened = openedAt);
    if (uid != null && uid.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
            'inboxLastOpenedAt': Timestamp.fromDate(openedAt),
          }, SetOptions(merge: true))
          .catchError((_) {});
    }
    await Navigator.push(
      context,
      noAnimRoute((_) => const MesajeDirPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('No session')));
    }

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _teacherStream,
              builder: (context, snap) {
                final data = snap.data?.data() ?? const <String, dynamic>{};
                final fullName = (data['fullName'] ?? '').toString().trim();
                final displayName = fullName.isNotEmpty
                    ? fullName
                    : (AppSession.username ?? 'Teacher');
                final serverInboxLastOpened =
                    (data['inboxLastOpenedAt'] as Timestamp?)?.toDate();
                final inboxLastOpened = _effectiveLastOpened(
                  serverInboxLastOpened,
                  _localInboxLastOpened,
                );

                final now = DateTime.now();
                final dateStr =
                    '${now.day} ${_homeMonths[now.month]} ${now.year}';

                return Column(
                  children: [
                    WaveHeroHeader(
                      title: 'Welcome,\n$displayName',
                      subtitle: dateStr,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const _DampedScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        child: Column(
                          children: [
                            _QuickStatsCard(
                              studentsStream: _studentsStream,
                              pendingStream: _pendingStream,
                              messagesStream: _classMessagesStream,
                              inboxLastOpened: inboxLastOpened,
                            ),
                            const SizedBox(height: 16),
                            _ShortcutsRow(
                              pendingStream: _pendingStream,
                              onRequestsTap: () => Navigator.push(
                                context,
                                noAnimRoute(
                                  (_) => const CereriAsteptarePage(),
                                ),
                              ),
                              onScheduleTap: () =>
                                  showTeacherScheduleSheet(context, _classId),
                            ),
                            const SizedBox(height: 16),
                            _AnnouncementsCard(
                              onTap: _openMessages,
                              messagesStream: _classMessagesStream,
                              inboxLastOpened: inboxLastOpened,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }
}

// QUICK STATS CARD (STUDENTS / PENDING / MESSAGES)
class _QuickStatsCard extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? studentsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? pendingStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? messagesStream;
  final DateTime? inboxLastOpened;

  const _QuickStatsCard({
    required this.studentsStream,
    required this.pendingStream,
    required this.messagesStream,
    required this.inboxLastOpened,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: const _WhiteCardDecorPainter(variant: 2),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _primary.withValues(alpha: 0.12),
                          _primary.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.10),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.dashboard_rounded,
                      color: _primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'At a glance',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 32,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: _pencilYellow,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: studentsStream,
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? const [];
                  return Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.group_rounded,
                          iconColor: _primary,
                          iconBg: _primary.withValues(alpha: 0.12),
                          value: '${docs.length}',
                          label: 'STUDENTS',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PendingStatTile(stream: pendingStream),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MessagesStatTile(
                          stream: messagesStream,
                          inboxLastOpened: inboxLastOpened,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 15, 10, 15),
      decoration: BoxDecoration(
        color: _surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: _onSurface,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: _labelColor,
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingStatTile extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? stream;
  const _PendingStatTile({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return _StatTile(
          icon: Icons.hourglass_top_rounded,
          iconColor: const Color(0xFFC58A00),
          iconBg: const Color(0xFFFFF1C4),
          value: '$count',
          label: 'PENDING',
        );
      },
    );
  }
}

class _MessagesStatTile extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? stream;
  final DateTime? inboxLastOpened;

  const _MessagesStatTile({
    required this.stream,
    required this.inboxLastOpened,
  });

  DateTime? _readWhen(Map<String, dynamic> d) {
    final reviewed = (d['reviewedAt'] as Timestamp?)?.toDate();
    final requested = (d['requestedAt'] as Timestamp?)?.toDate();
    return reviewed ?? requested;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        int unread;
        if (inboxLastOpened == null) {
          unread = docs.length;
        } else {
          unread = docs.where((d) {
            final when = _readWhen(d.data());
            return when != null && when.isAfter(inboxLastOpened!);
          }).length;
        }
        return _StatTile(
          icon: Icons.mark_email_unread_rounded,
          iconColor: _primary,
          iconBg: const Color(0xFFE2E7FA),
          value: '$unread',
          label: 'MESSAGES',
        );
      },
    );
  }
}

// SHORTCUT TILES
class _ShortcutsRow extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? pendingStream;
  final VoidCallback onRequestsTap;
  final VoidCallback onScheduleTap;

  const _ShortcutsRow({
    required this.pendingStream,
    required this.onRequestsTap,
    required this.onScheduleTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: pendingStream,
      builder: (context, snap) {
        final pending = snap.data?.docs.length ?? 0;
        return Row(
          children: [
            Expanded(
              child: _ShortcutTile(
                icon: Icons.description_rounded,
                title: 'Leave requests',
                subtitle: pending == 0
                    ? 'No new requests'
                    : (pending == 1 ? '1 pending' : '$pending pending'),
                badgeCount: pending,
                onTap: onRequestsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ShortcutTile(
                icon: Icons.event_note_rounded,
                title: 'Schedule',
                subtitle: 'Today\'s lessons',
                badgeCount: 0,
                onTap: onScheduleTap,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int badgeCount;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount > 0;
    return Container(
      height: 138,
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
        border: hasBadge
            ? const Border(left: BorderSide(color: _primary, width: 4))
            : null,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _WhiteCardDecorPainter(variant: hasBadge ? 1 : 3),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hasBadge ? 13 : 15, 14, 13, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _primary.withValues(alpha: 0.12),
                                  _primary.withValues(alpha: 0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.10),
                                width: 1,
                              ),
                            ),
                            child: Icon(icon, color: _primary, size: 23),
                          ),
                    if (hasBadge)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _pencilYellow,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            badgeCount > 9 ? '9+' : '$badgeCount',
                            style: const TextStyle(
                              color: _onSurface,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasBadge ? _primary : _labelColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ANNOUNCEMENTS CARD (light, mirrors parent's announcements card)
class _AnnouncementsCard extends StatelessWidget {
  final VoidCallback onTap;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? messagesStream;
  final DateTime? inboxLastOpened;

  const _AnnouncementsCard({
    required this.onTap,
    required this.messagesStream,
    required this.inboxLastOpened,
  });

  DateTime? _readWhen(Map<String, dynamic> d) {
    final reviewed = (d['reviewedAt'] as Timestamp?)?.toDate();
    final requested = (d['requestedAt'] as Timestamp?)?.toDate();
    return reviewed ?? requested;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: messagesStream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        int unread;
        if (inboxLastOpened == null) {
          unread = docs.length;
        } else {
          unread = docs.where((d) {
            final when = _readWhen(d.data());
            return when != null && when.isAfter(inboxLastOpened!);
          }).length;
        }
        final hasNew = unread > 0;

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
                  child: CustomPaint(
                    painter: const _WhiteCardDecorPainter(variant: 4),
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
                  decoration: BoxDecoration(
                    border: hasNew
                        ? const Border(
                            left: BorderSide(color: _primary, width: 4),
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hasNew ? 14 : 18, 18, 0, 18),
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
                                        borderRadius: BorderRadius.circular(6),
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
          ),
        );
      },
    );
  }
}

