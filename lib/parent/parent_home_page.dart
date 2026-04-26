import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../Auth/login_page_firestore.dart';
import '../admin/services/admin_api.dart';
import '../core/session.dart';
import '../student/widgets/no_anim_route.dart';
import '../student/widgets/school_decor.dart' as decor;
import '../student/widgets/school_decor.dart' show WaveHeroHeader;
import 'parent_inbox_page.dart';
import 'parent_requests_page.dart';
import 'parent_schedule_page.dart';
import 'parent_students_page.dart';

const _homeMonths = [
  '',
  'ianuarie',
  'februarie',
  'martie',
  'aprilie',
  'mai',
  'iunie',
  'iulie',
  'august',
  'septembrie',
  'octombrie',
  'noiembrie',
  'decembrie',
];

// ── Colour tokens (same palette as student/admin) ────────────────────────────
const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _surfaceContainerLow = Color(0xFFE8EAF2);
const _surfaceLowest = Color(0xFFFFFFFF);
const _outline = Color(0xFF7A7E9A);
const _outlineVariant = Color(0xFFBFC3D9);
const _onSurface = Color(0xFF1A2050);
const _labelColor = Color(0xFF7A7E9A);
const _pencilYellow = Color(0xFFF5C518);
const _danger = Color(0xFFB03040);

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

// ─────────────────────────────────────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  DateTime? _localInboxLastOpened;

  // Cached user-doc stream — must not be recreated inside build().
  String? _cachedUserDocUid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getUserDocStream(String uid) {
    if (uid != _cachedUserDocUid || _userDocStream == null) {
      _cachedUserDocUid = uid;
      _userDocStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
    }
    return _userDocStream!;
  }

  // Cache the future so it is not recreated on every StreamBuilder rebuild.
  String? _cachedChildrenKey;
  Future<List<String>>? _cachedChildrenFuture;

  Future<List<String>> _getOrCreateChildrenFuture(
    String parentUid,
    List<String> directChildren,
  ) {
    final key = '$parentUid|${directChildren.join(",")}';
    if (key != _cachedChildrenKey || _cachedChildrenFuture == null) {
      _cachedChildrenKey = key;
      _cachedChildrenFuture = _loadLinkedChildren(parentUid, directChildren);
    }
    return _cachedChildrenFuture!;
  }

  Future<List<String>> _loadLinkedChildren(
    String parentUid,
    List<String> directChildren,
  ) async {
    final ids = <String>{
      ...directChildren
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
    };

    final users = FirebaseFirestore.instance.collection('users');

    try {
      final byParents = await users
          .where('parents', arrayContains: parentUid)
          .get();
      ids.addAll(byParents.docs.map((doc) => doc.id));
    } catch (_) {}

    try {
      final byParentUid = await users
          .where('parentUid', isEqualTo: parentUid)
          .get();
      ids.addAll(byParentUid.docs.map((doc) => doc.id));
    } catch (_) {}

    try {
      final byParentId = await users
          .where('parentId', isEqualTo: parentUid)
          .get();
      ids.addAll(byParentId.docs.map((doc) => doc.id));
    } catch (_) {}

    ids.remove(parentUid);
    final sorted = ids.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) return const SizedBox();

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _getUserDocStream(uid),
          builder: (context, snap) {
            final data = snap.data?.data() ?? <String, dynamic>{};
            final fullName = (data['fullName'] ?? '').toString().trim();
            final displayName = fullName.isNotEmpty
                ? fullName
                : (AppSession.username ?? 'Parinte');
            final rawChildren = data['children'];
            final directChildrenUids = rawChildren is List
                ? rawChildren
                      .map((e) {
                        if (e is String) return e.trim();
                        if (e is Map) {
                          return ((e['uid'] ?? e['studentUid'] ?? e['id']) ??
                                  '')
                              .toString()
                              .trim();
                        }
                        return '';
                      })
                      .where((s) => s.isNotEmpty)
                      .toList()
                : <String>[];
            final serverInboxLastOpened =
                (data['inboxLastOpenedAt'] as Timestamp?)?.toDate();
            final inboxLastOpened = _effectiveLastOpened(
              serverInboxLastOpened,
              _localInboxLastOpened,
            );

            return FutureBuilder<List<String>>(
              future: _getOrCreateChildrenFuture(uid, directChildrenUids),
              builder: (context, childrenSnapshot) {
                final childrenUids =
                    childrenSnapshot.data ?? directChildrenUids;
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
                              childrenUids: childrenUids,
                              inboxLastOpened: inboxLastOpened,
                            ),
                            const SizedBox(height: 16),
                            _ShortcutsRow(
                              childrenUids: childrenUids,
                              onRequestsTap: () {
                                _markOpened(uid, 'requestsLastOpenedAt');
                                Navigator.push(
                                  context,
                                  noAnimRoute(
                                    (_) => const ParentRequestsPage(),
                                  ),
                                );
                              },
                              onScheduleTap: () {
                                Navigator.push(
                                  context,
                                  noAnimRoute(
                                    (_) => const ParentSchedulePage(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _ParentAnnouncementsCard(
                              parentUid: uid,
                              childrenUids: childrenUids,
                              inboxLastOpened: inboxLastOpened,
                              onTap: () async {
                                await _openInbox(context, uid);
                              },
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

  DateTime? _effectiveLastOpened(DateTime? serverValue, DateTime? localValue) {
    if (serverValue == null) return localValue;
    if (localValue == null) return serverValue;
    return localValue.isAfter(serverValue) ? localValue : serverValue;
  }

  Future<void> _openInbox(BuildContext context, String uid) async {
    final openedAt = DateTime.now();
    if (mounted) {
      setState(() {
        _localInboxLastOpened = openedAt;
      });
    }

    _markOpened(uid, 'inboxLastOpenedAt', openedAt);

    await Navigator.push(
      context,
      noAnimRoute((_) => const ParentInboxPage()),
    );

    final returnedAt = DateTime.now();
    if (mounted) {
      setState(() {
        _localInboxLastOpened = returnedAt;
      });
    }
    _markOpened(uid, 'inboxLastOpenedAt', returnedAt);
  }

  static Future<void> _markOpened(String uid, String field, [DateTime? when]) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({
          field: Timestamp.fromDate(when ?? DateTime.now()),
        }, SetOptions(merge: true))
        .catchError((_) {});
  }
}

// QUICK STATS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _QuickStatsCard extends StatelessWidget {
  final List<String> childrenUids;
  final DateTime? inboxLastOpened;

  const _QuickStatsCard({
    required this.childrenUids,
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
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.group_rounded,
                      iconColor: _primary,
                      iconBg: _primary.withValues(alpha: 0.12),
                      value: '${childrenUids.length}',
                      label: 'CHILDREN',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PendingRequestsStat(childrenUids: childrenUids),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _UnreadInboxStat(
                      childrenUids: childrenUids,
                      inboxLastOpened: inboxLastOpened,
                    ),
                  ),
                ],
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

class _PendingRequestsStat extends StatelessWidget {
  final List<String> childrenUids;

  const _PendingRequestsStat({required this.childrenUids});

  @override
  Widget build(BuildContext context) {
    if (childrenUids.isEmpty) {
      return const _StatTile(
        icon: Icons.hourglass_top_rounded,
        iconColor: Color(0xFFC58A00),
        iconBg: Color(0xFFFFF1C4),
        value: '0',
        label: 'PENDING',
      );
    }
    final chunk = childrenUids.take(10).toList();
    final stream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', whereIn: chunk)
        .where('status', isEqualTo: 'pending')
        .snapshots();

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

class _UnreadInboxStat extends StatelessWidget {
  final List<String> childrenUids;
  final DateTime? inboxLastOpened;

  const _UnreadInboxStat({
    required this.childrenUids,
    required this.inboxLastOpened,
  });

  @override
  Widget build(BuildContext context) {
    if (childrenUids.isEmpty) {
      return const _StatTile(
        icon: Icons.mark_email_unread_rounded,
        iconColor: _primary,
        iconBg: Color(0xFFE2E7FA),
        value: '0',
        label: 'UNREAD',
      );
    }
    final chunk = childrenUids.take(10).toList();
    final stream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', whereIn: chunk)
        .orderBy('requestedAt', descending: true)
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        int unread;
        if (inboxLastOpened == null) {
          unread = docs.length;
        } else {
          unread = docs.where((d) {
            final ts =
                (d.data()['reviewedAt'] as Timestamp?) ??
                (d.data()['requestedAt'] as Timestamp?);
            return ts != null && ts.toDate().isAfter(inboxLastOpened!);
          }).length;
        }
        return _StatTile(
          icon: Icons.mark_email_unread_rounded,
          iconColor: _primary,
          iconBg: const Color(0xFFE2E7FA),
          value: '$unread',
          label: 'UNREAD',
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANNOUNCEMENTS CARD (mirrors student's inbox preview)
// ─────────────────────────────────────────────────────────────────────────────
class _ParentAnnouncementsCard extends StatelessWidget {
  final String parentUid;
  final List<String> childrenUids;
  final DateTime? inboxLastOpened;
  final VoidCallback onTap;

  const _ParentAnnouncementsCard({
    required this.parentUid,
    required this.childrenUids,
    required this.inboxLastOpened,
    required this.onTap,
  });

  DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildSecretariatStreams() {
    final base = FirebaseFirestore.instance.collection('secretariatMessages');
    return [
      // Parent-targeted: broadcasts + per-child messages
      base
          .where('recipientRole', isEqualTo: 'parent')
          .where('studentUid', isEqualTo: '')
          .limit(20)
          .snapshots(),
      ...childrenUids.map(
        (childUid) => base
            .where('recipientRole', isEqualTo: 'parent')
            .where('studentUid', isEqualTo: childUid)
            .limit(20)
            .snapshots(),
      ),
      // Student-targeted: school-wide broadcasts + messages to any child
      base
          .where('recipientRole', isEqualTo: 'student')
          .where('recipientUid', isEqualTo: '')
          .limit(20)
          .snapshots(),
      ...childrenUids.map(
        (childUid) => base
            .where('recipientRole', isEqualTo: 'student')
            .where('recipientUid', isEqualTo: childUid)
            .limit(20)
            .snapshots(),
      ),
    ];
  }

  Widget _withMergedDocs(
    List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams,
    Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs)
    onReady,
  ) {
    Widget step(
      int index,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> acc,
    ) {
      if (index >= streams.length) return onReady(acc);
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: streams[index],
        builder: (context, snap) {
          if (snap.hasError) return step(index + 1, acc);
          if (!snap.hasData) {
            return onReady(acc);
          }
          return step(index + 1, [...acc, ...snap.data!.docs]);
        },
      );
    }

    return step(0, const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
  }

  @override
  Widget build(BuildContext context) {
    final hasChildren = childrenUids.isNotEmpty;
    final leaveStream = hasChildren
        ? FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('studentUid', whereIn: childrenUids.take(10).toList())
              .where('status', whereIn: ['approved', 'rejected'])
              .snapshots()
        : null;
    final secretariatStreams = _buildSecretariatStreams();

    return GestureDetector(
      onTap: onTap,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: leaveStream,
        builder: (context, leaveSnap) {
          return _withMergedDocs(secretariatStreams, (secretariatDocs) {
            final times = <DateTime>[];
            for (final d in leaveSnap.data?.docs ?? const []) {
              final data = d.data();
              if ((data['source'] ?? '').toString() == 'secretariat') {
                continue;
              }
              final when =
                  _readDateTime(data['reviewedAt']) ??
                  _readDateTime(data['requestedAt']);
              if (when != null) times.add(when);
            }
            // Dedupe secretariat docs by id (broadcasts may overlap with
            // per-child queries).
            final byId =
                <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
            for (final d in secretariatDocs) {
              byId[d.id] = d;
            }
            for (final d in byId.values) {
              final when = _readDateTime(d.data()['createdAt']);
              if (when != null) times.add(when);
            }

            int unread;
            if (inboxLastOpened == null) {
              unread = times.length;
            } else {
              unread = times.where((t) => t.isAfter(inboxLastOpened!)).length;
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
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
          });
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHORTCUTS ROW (Requests + Schedule)
// ─────────────────────────────────────────────────────────────────────────────
class _ShortcutsRow extends StatefulWidget {
  final List<String> childrenUids;
  final VoidCallback onRequestsTap;
  final VoidCallback onScheduleTap;

  const _ShortcutsRow({
    required this.childrenUids,
    required this.onRequestsTap,
    required this.onScheduleTap,
  });

  @override
  State<_ShortcutsRow> createState() => _ShortcutsRowState();
}

class _ShortcutsRowState extends State<_ShortcutsRow> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _pendingStream;

  @override
  void initState() {
    super.initState();
    _buildStream(widget.childrenUids);
  }

  @override
  void didUpdateWidget(_ShortcutsRow old) {
    super.didUpdateWidget(old);
    if (old.childrenUids.join() != widget.childrenUids.join()) {
      _buildStream(widget.childrenUids);
    }
  }

  void _buildStream(List<String> uids) {
    _pendingStream = uids.isNotEmpty
        ? FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('studentUid', whereIn: uids)
              .where('status', isEqualTo: 'pending')
              .snapshots()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingStream,
      builder: (context, snap) {
        final pending = snap.data?.docs.length ?? 0;
        return Row(
          children: [
            Expanded(
              child: _ShortcutTile(
                icon: Icons.description_rounded,
                title: 'Requests',
                subtitle: pending == 0
                    ? 'No new requests'
                    : (pending == 1 ? '1 pending' : '$pending pending'),
                badgeCount: pending,
                onTap: widget.onRequestsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ShortcutTile(
                icon: Icons.event_note_rounded,
                title: 'Schedule',
                subtitle: 'Weekly timetable',
                badgeCount: 0,
                onTap: widget.onScheduleTap,
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
    return Material(
      color: _surfaceLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 138,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
            border: hasBadge
                ? Border(
                    left: BorderSide(color: _primary, width: 4),
                  )
                : null,
          ),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MESAJE CARD (light)
// ─────────────────────────────────────────────────────────────────────────────
class _MesajeCard extends StatefulWidget {
  final List<String> childrenUids;
  final DateTime? inboxLastOpened;
  final VoidCallback onTap;

  const _MesajeCard({
    required this.childrenUids,
    required this.inboxLastOpened,
    required this.onTap,
  });

  @override
  State<_MesajeCard> createState() => _MesajeCardState();
}

class _MesajeCardState extends State<_MesajeCard> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _decisionStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _pendingRequestsStream;
  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _secretariatStreams = [];

  @override
  void initState() {
    super.initState();
    _buildStreams(widget.childrenUids);
  }

  @override
  void didUpdateWidget(_MesajeCard old) {
    super.didUpdateWidget(old);
    if (old.childrenUids.join() != widget.childrenUids.join()) {
      _buildStreams(widget.childrenUids);
    }
  }

  void _buildStreams(List<String> uids) {
    final parentUid = (AppSession.uid ?? '').trim();
    _decisionStream = uids.isNotEmpty
        ? FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('studentUid', whereIn: uids)
              .where('status', whereIn: ['approved', 'rejected'])
              .snapshots()
        : null;
    _pendingRequestsStream = parentUid.isNotEmpty
        ? FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('targetUid', isEqualTo: parentUid)
              .where('targetRole', isEqualTo: 'parent')
              .where('status', isEqualTo: 'pending')
              .snapshots()
              .handleError((_) {})
        : null;
    _secretariatStreams = _buildSecretariatStreams(uids);
  }

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildSecretariatStreams(
    List<String> uids,
  ) {
    if (uids.isEmpty) {
      return const <Stream<QuerySnapshot<Map<String, dynamic>>>>[];
    }
    final base = FirebaseFirestore.instance.collection('secretariatMessages');
    return [
      base
          .where('recipientRole', isEqualTo: 'parent')
          .where('studentUid', isEqualTo: '')
          .snapshots(),
      ...uids.map(
        (childUid) => base
            .where('recipientRole', isEqualTo: 'parent')
            .where('studentUid', isEqualTo: childUid)
            .snapshots(),
      ),
    ];
  }

  DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DateTime? _decisionMessageTime(Map<String, dynamic> data) {
    return _readDateTime(data['reviewedAt']) ??
        _readDateTime(data['updatedAt']) ??
        _readDateTime(data['requestedAt']);
  }

  int _countUnreadDecisions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final lastViewed = widget.inboxLastOpened;
    return docs.where((doc) {
      final data = doc.data();
      final source = (data['source'] ?? '').toString();
      if (source == 'secretariat') {
        return false;
      }

      final when = _decisionMessageTime(data);
      if (when == null) {
        return lastViewed == null;
      }
      return lastViewed == null || when.isAfter(lastViewed);
    }).length;
  }

  int _countUnreadSecretariat(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final lastViewed = widget.inboxLastOpened;
    final uniqueDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final doc in docs) doc.id: doc,
    };
    return uniqueDocs.values.where((doc) {
      final when =
          _readDateTime(doc.data()['createdAt']) ??
          _readDateTime(doc.data()['reviewedAt']) ??
          _readDateTime(doc.data()['requestedAt']);
      if (when == null) {
        return lastViewed == null;
      }
      return lastViewed == null || when.isAfter(lastViewed);
    }).length;
  }

  int _countUnreadPendingRequests(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final lastViewed = widget.inboxLastOpened;
    return docs.where((doc) {
      final when =
          _readDateTime(doc.data()['requestedAt']) ??
          _readDateTime(doc.data()['createdAt']) ??
          _readDateTime(doc.data()['updatedAt']);
      if (when == null) {
        return lastViewed == null;
      }
      return lastViewed == null || when.isAfter(lastViewed);
    }).length;
  }

  Widget _buildMergedStream(
    List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams,
    Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs)
    onReady,
  ) {
    if (streams.isEmpty) {
      return onReady(const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }

    Widget step(
      int index,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> acc,
    ) {
      if (index >= streams.length) {
        return onReady(acc);
      }

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: streams[index],
        builder: (context, snap) {
          if (!snap.hasData) {
            return onReady(acc);
          }
          return step(index + 1, [...acc, ...snap.data!.docs]);
        },
      );
    }

    return step(0, const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
  }

  @override
  Widget build(BuildContext context) {
    // Single set of StreamBuilders — compute unread count once, use for both badge and text.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingRequestsStream,
      builder: (context, pendingSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _decisionStream,
          builder: (context, decisionSnap) {
            return _buildMergedStream(_secretariatStreams, (secretariatDocs) {
              final unread =
                  _countUnreadPendingRequests(
                    pendingSnap.data?.docs ?? const [],
                  ) +
                  _countUnreadDecisions(decisionSnap.data?.docs ?? const []) +
                  _countUnreadSecretariat(secretariatDocs);

              final hasNew = unread > 0;
              return GestureDetector(
                onTap: widget.onTap,
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
                        decoration: BoxDecoration(
                          border: hasNew
                              ? const Border(
                                  left: BorderSide(color: _primary, width: 4),
                                )
                              : null,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            hasNew ? 14 : 18,
                            16,
                            14,
                            16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          _primary.withValues(alpha: 0.12),
                                          _primary.withValues(alpha: 0.06),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _primary.withValues(alpha: 0.10),
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
                              const Spacer(),
                              Row(
                                children: [
                                  const Text(
                                    'Messages',
                                    style: TextStyle(
                                      color: _onSurface,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                                  ),
                                  if (hasNew) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _pencilYellow,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'NEW',
                                        style: TextStyle(
                                          color: _onSurface,
                                          fontSize: 9,
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
                                          ? '1 new message'
                                          : '$unread new messages')
                                    : 'No new messages',
                                style: TextStyle(
                                  color: hasNew ? _primary : _labelColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
            });
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARENT PROFILE PAGE
// ─────────────────────────────────────────────────────────────────────────────
class ParentProfilePage extends StatelessWidget {
  final bool showBack;

  const ParentProfilePage({super.key, this.showBack = true});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    AppSession.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPageFirestore()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid ?? '';
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _ProfileTopHeader(
              onBack: showBack ? () => Navigator.of(context).maybePop() : null,
            ),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data() ?? <String, dynamic>{};
                  final fullName = (data['fullName'] ?? '').toString().trim();
                  final email = FirebaseAuth.instance.currentUser?.email ?? '';
                  final rawChildren = data['children'];
                  final childCount = rawChildren is List
                      ? rawChildren.length
                      : 0;
                  final displayName = fullName.isNotEmpty
                      ? fullName
                      : (AppSession.username ?? 'Parent');

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ParentIdentityCard(
                          displayName: displayName,
                          email: email,
                          childCount: snap.hasData ? childCount : null,
                        ),
                        const SizedBox(height: 22),
                        const _ProfileSectionLabel('ACCOUNT'),
                        const SizedBox(height: 10),
                        _ProfileTile(
                          icon: Icons.group_rounded,
                          title: 'Children',
                          subtitle: childCount == 0
                              ? 'No linked accounts'
                              : '$childCount linked ${childCount == 1 ? 'account' : 'accounts'}',
                          onTap: () => Navigator.of(context).push(
                            noAnimRoute(
                              (_) => const ParentStudentsPage(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ProfileTile(
                          icon: Icons.edit_outlined,
                          title: 'Edit profile',
                          subtitle: 'Email · Password',
                          onTap: () => showDialog<void>(
                            context: context,
                            barrierDismissible: true,
                            builder: (_) =>
                                const _ParentAccountSettingsDialog(),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _ProfileSignOutButton(
                          onSignOut: () => _signOut(context),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTopHeader extends StatelessWidget {
  final VoidCallback? onBack;

  const _ProfileTopHeader({this.onBack});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3CA0), Color(0xFF2E58D0), Color(0xFF4070E0)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x302848B0),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: const decor.HeaderSparklesPainter(variant: 4),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (onBack != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 42,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _pencilYellow,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your account',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// PARENT IDENTITY + ACCOUNT TILES (mirrors student profile layout)
// ─────────────────────────────────────────────────────────────────────────────
class _ParentIdentityCard extends StatelessWidget {
  final String displayName;
  final String email;
  final int? childCount;

  const _ParentIdentityCard({
    required this.displayName,
    required this.email,
    required this.childCount,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
            parts[1].characters.take(1).toString())
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = childCount == null
        ? 'Parent'
        : 'Parent · $childCount ${childCount == 1 ? 'child' : 'children'}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Text(
              _initials(displayName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _pencilYellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _outline,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _outline,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  final String text;

  const _ProfileSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: _outline,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: _surfaceLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outlineVariant.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: _primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _outline,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _outline,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSignOutButton extends StatelessWidget {
  final VoidCallback onSignOut;

  const _ProfileSignOutButton({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0D0D8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onSignOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFB03040), size: 20),
              SizedBox(width: 10),
              Text(
                'Sign out',
                style: TextStyle(
                  color: Color(0xFFB03040),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT SETTINGS DIALOG  (Email · Password)
// ─────────────────────────────────────────────────────────────────────────────
class _ParentAccountSettingsDialog extends StatefulWidget {
  const _ParentAccountSettingsDialog();

  @override
  State<_ParentAccountSettingsDialog> createState() =>
      _ParentAccountSettingsDialogState();
}

class _ParentAccountSettingsDialogState
    extends State<_ParentAccountSettingsDialog> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmPasswordC = TextEditingController();
  final _verificationCodeC = TextEditingController();
  final _api = AdminApi();

  bool _editingEmail = false;
  bool _editingPassword = false;
  bool _saving = false;
  bool _sendingCode = false;
  bool _codeSent = false;
  bool _emailVerified = false;
  bool _obscurePassword = true;
  String? _passwordError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _emailC.text = user?.email ?? '';
    _passwordC.text = '••••••••••••';
    final uid = user?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
        if (mounted) {
          setState(() {
            final email = (doc.data()?['personalEmail'] ?? '').toString();
            if (email.isNotEmpty) _emailC.text = email;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    _confirmPasswordC.dispose();
    _verificationCodeC.dispose();
    super.dispose();
  }

  Future<bool> _reauthenticate() async {
    final currentPassword = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const _ParentReauthDialog(),
    );
    if (currentPassword == null || currentPassword.isEmpty) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
      return true;
    } on FirebaseAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current password is incorrect.')),
        );
      }
      return false;
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    var closed = false;
    try {
      final updates = <String, dynamic>{};
      if (_editingEmail && _emailC.text.trim().isNotEmpty) {
        if (!_emailVerified) {
          setState(() {
            _emailError = 'Verify the new email first.';
            _saving = false;
          });
          return;
        }
        updates['personalEmail'] = _emailC.text.trim();
      }
      if (_editingPassword &&
          _passwordC.text.trim().isNotEmpty &&
          _passwordC.text.trim() != '••••••••••••') {
        if (_passwordC.text.trim() != _confirmPasswordC.text.trim()) {
          setState(() {
            _passwordError = 'Passwords do not match.';
            _saving = false;
          });
          return;
        }
        if (_passwordC.text.trim().length < 8) {
          setState(() {
            _passwordError = 'Password must be at least 8 characters.';
            _saving = false;
          });
          return;
        }
        setState(() => _passwordError = null);
        final ok = await _reauthenticate();
        if (!ok) return;
        await FirebaseAuth.instance.currentUser?.updatePassword(
          _passwordC.text.trim(),
        );
      }
      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update(updates);
      }
      if (mounted) {
        closed = true;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Settings updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (!closed && mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ScrollbarTheme(
          data: const ScrollbarThemeData(
            thickness: WidgetStatePropertyAll(2),
            radius: Radius.circular(2),
            crossAxisMargin: -12,
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Account Settings',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: _outline,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: Color(0xFFE8EAF2)),
                  const SizedBox(height: 18),

                  // ── EMAIL ──
                  const Text(
                    'EMAIL',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mail_outlined, color: _primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _editingEmail
                              ? TextField(
                                  controller: _emailC,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                  ),
                                  decoration: const InputDecoration.collapsed(
                                    hintText: 'Email',
                                  ),
                                )
                              : Text(
                                  _emailC.text,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _editingEmail = !_editingEmail;
                            _codeSent = false;
                            _emailVerified = false;
                            _emailError = null;
                            _verificationCodeC.clear();
                          }),
                          child: Icon(
                            Icons.edit_outlined,
                            color: _outline,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_editingEmail && !_emailVerified) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _sendingCode
                            ? null
                            : () async {
                                final email = _emailC.text.trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  setState(
                                    () => _emailError = 'Email invalid.',
                                  );
                                  return;
                                }
                                final uid =
                                    FirebaseAuth.instance.currentUser?.uid;
                                if (uid == null) return;
                                setState(() {
                                  _sendingCode = true;
                                  _emailError = null;
                                });
                                try {
                                  await _api.sendVerificationEmail(
                                    uid: uid,
                                    email: email,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _codeSent = true;
                                      _sendingCode = false;
                                    });
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    setState(() {
                                      _emailError = 'Could not send the code.';
                                      _sendingCode = false;
                                    });
                                  }
                                }
                              },
                        icon: _sendingCode
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_codeSent ? 'Resend code' : 'Send code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_codeSent && !_emailVerified) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: _outline,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'A code was sent to ${_emailC.text.trim()}. Enter it below.',
                            style: const TextStyle(
                              color: _outline,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.pin_outlined, color: _primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _verificationCodeC,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 15,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration.collapsed(
                                hintText: '••••••',
                                hintStyle: TextStyle(
                                  color: _outlineVariant,
                                  fontSize: 15,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final code = _verificationCodeC.text.trim();
                              if (code.isEmpty) {
                                setState(() => _emailError = 'Enter the code.');
                                return;
                              }
                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid;
                              if (uid == null) return;
                              setState(() => _emailError = null);
                              try {
                                final result = await _api.verifyEmailCode(
                                  uid: uid,
                                  code: code,
                                );
                                if (result['verified'] == true) {
                                  if (mounted) {
                                    setState(() => _emailVerified = true);
                                  }
                                } else {
                                  if (mounted) {
                                    setState(
                                      () => _emailError = 'Invalid code.',
                                    );
                                  }
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(() => _emailError = 'Invalid code.');
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Verify',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_emailVerified) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: _primary, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Email verificat cu succes!',
                          style: TextStyle(
                            color: _primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_emailError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _emailError!,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),

                  // ── PAROLĂ ──
                  const Text(
                    'PAROLĂ',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outlined, color: _primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _editingPassword
                              ? TextField(
                                  controller: _passwordC,
                                  autofocus: true,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                  ),
                                  decoration: const InputDecoration.collapsed(
                                    hintText: 'New password',
                                  ),
                                )
                              : const Text(
                                  '••••••••••••',
                                  style: TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            if (!_editingPassword) {
                              _editingPassword = true;
                              _passwordC.clear();
                              _confirmPasswordC.clear();
                              _passwordError = null;
                            } else {
                              _editingPassword = false;
                              _passwordC.text = '••••••••••••';
                              _confirmPasswordC.clear();
                              _passwordError = null;
                            }
                          }),
                          child: Icon(
                            Icons.edit_outlined,
                            color: _outline,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_editingPassword) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_outlined, color: _primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _confirmPasswordC,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 15,
                              ),
                              decoration: const InputDecoration.collapsed(
                                hintText: 'Confirm password',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_passwordError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _passwordError!,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REAUTH DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _ParentReauthDialog extends StatefulWidget {
  const _ParentReauthDialog();

  @override
  State<_ParentReauthDialog> createState() => _ParentReauthDialogState();
}

class _ParentReauthDialogState extends State<_ParentReauthDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm identity',
              style: TextStyle(
                color: _onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your current password to continue.',
              style: TextStyle(color: _outline, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              obscureText: _obscure,
              autofocus: true,
              style: const TextStyle(color: _onSurface, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Current password',
                hintStyle: const TextStyle(color: _outline),
                filled: true,
                fillColor: _surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFBFC3D9),
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFBFC3D9),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primary, width: 1.6),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _outline,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: _surfaceContainerLow,
                      foregroundColor: _onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _ctrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
