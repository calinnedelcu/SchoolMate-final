import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';
import '../student/widgets/no_anim_route.dart';
import '../student/widgets/school_decor.dart';
import '../student/widgets/timetable.dart';

const _kPrimary = Color(0xFF2848B0);
const _kOnSurface = Color(0xFF1A2050);
const _kLabelColor = Color(0xFF7A7E9A);
const _kPageBg = Color(0xFFF2F4F8);

class ParentStudentViewData {
  final String uid;
  final String fullName;
  final String username;
  final String role;
  final String classId;
  final bool inSchool;
  final String photoUrl;

  const ParentStudentViewData({
    required this.uid,
    required this.fullName,
    required this.username,
    required this.role,
    required this.classId,
    required this.inSchool,
    required this.photoUrl,
  });
}

class ParentStudentsPage extends StatelessWidget {
  final bool showBack;

  const ParentStudentsPage({super.key, this.showBack = true});

  @override
  Widget build(BuildContext context) {
    final parentUid = (AppSession.uid ?? '').trim();
    final users = FirebaseFirestore.instance.collection('users');

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _TopHeader(
              onBack: showBack ? () => Navigator.of(context).pop() : null,
            ),
            Expanded(
              child: parentUid.isEmpty
                  ? const Center(child: Text('Invalid session'))
                  : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(parentUid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final parentData = snapshot.data!.data();
                        if (parentData == null) {
                          return const Center(child: Text('Nu exista date.'));
                        }

                        final childIds = _extractChildUids(
                          parentData,
                          parentUid,
                        );
                        if (childIds.isEmpty) {
                          return const Center(
                            child: Text('No children linked yet.'),
                          );
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: childIds.length,
                          itemBuilder: (context, index) {
                            final uid = childIds[index];

                            return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: users.doc(uid).snapshots(),
                              builder: (context, studentSnap) {
                                if (!studentSnap.hasData ||
                                    !studentSnap.data!.exists) {
                                  return const SizedBox();
                                }

                                final data = studentSnap.data!.data()!;
                                final viewData = _toStudentViewData(
                                  studentSnap.data!.id,
                                  data,
                                );
                                final name = viewData.fullName.trim().isNotEmpty
                                    ? viewData.fullName.trim()
                                    : viewData.username.trim().isNotEmpty
                                    ? viewData.username.trim()
                                    : 'Elev necunoscut';
                                final initials = name
                                    .trim()
                                    .split(' ')
                                    .where((w) => w.isNotEmpty)
                                    .take(2)
                                    .map((w) => w[0].toUpperCase())
                                    .join();
                                return _StudentCard(
                                  avatarSeed: viewData.uid,
                                  photoUrl: viewData.photoUrl,
                                  initials: initials,
                                  name: name,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      noAnimRoute(
                                        (_) => _StudentDetailPage(
                                          avatarSeed: viewData.uid,
                                          name: name,
                                          username: viewData.username,
                                          classId: viewData.classId,
                                          photoUrl: viewData.photoUrl,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _extractChildUids(
    Map<String, dynamic> parentData,
    String parentUid,
  ) {
    final raw = (parentData['children'] as List?) ?? const [];
    final idsSet = <String>{};

    for (final value in raw) {
      if (value is String) {
        final id = value.trim();
        if (id.isNotEmpty) {
          idsSet.add(id);
        }
        continue;
      }

      if (value is Map<String, dynamic>) {
        final id = ((value['uid'] ?? value['studentUid'] ?? value['id']) ?? '')
            .toString()
            .trim();
        if (id.isNotEmpty) {
          idsSet.add(id);
        }
      }
    }

    final ids = idsSet.toList()..sort();
    return ids;
  }

  ParentStudentViewData _toStudentViewData(
    String uid,
    Map<String, dynamic> data,
  ) {
    return ParentStudentViewData(
      uid: uid,
      fullName: (data['fullName'] ?? data['name'] ?? '').toString(),
      username: (data['username'] ?? data['uid'] ?? '').toString(),
      role: (data['role'] ?? 'student').toString(),
      classId: (data['classId'] ?? '').toString(),
      inSchool: data['inSchool'] == true,
      photoUrl:
          (data['profilePictureUrl'] ??
                  data['photoUrl'] ??
                  data['avatarUrl'] ??
                  '')
              .toString()
              .trim(),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final VoidCallback? onBack;
  final String title;
  final int variant;

  const _TopHeader({
    this.onBack,
    this.title = 'My children',
    this.variant = 0,
  });

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
              painter: HeaderSparklesPainter(variant: variant),
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
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: onBack == null ? 32 : 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 42,
                        height: 3,
                        decoration: BoxDecoration(
                          color: kPencilYellow,
                          borderRadius: BorderRadius.circular(2),
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

class _StudentCard extends StatelessWidget {
  final String avatarSeed;
  final String photoUrl;
  final String initials;
  final String name;
  final VoidCallback onTap;

  const _StudentCard({
    required this.avatarSeed,
    required this.photoUrl,
    required this.initials,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
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
              painter: WhiteCardSparklesPainter(
                primary: _kPrimary,
                variant: avatarSeed.length % 5,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) =>
                              _AvatarInitials(initials: initials),
                        )
                      : _AvatarInitials(initials: initials),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1A2050),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EAF2),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 26,
                        color: _kPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _AvatarInitials extends StatelessWidget {
  final String initials;

  const _AvatarInitials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          height: 1,
        ),
      ),
    );
  }
}

class _StudentDetailPage extends StatelessWidget {
  final String avatarSeed;
  final String name;
  final String username;
  final String classId;
  final String photoUrl;

  const _StudentDetailPage({
    required this.avatarSeed,
    required this.name,
    required this.username,
    required this.classId,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopHeader(
              onBack: () => Navigator.of(context).maybePop(),
              title: 'Student details',
              variant: 3,
            ),
            Expanded(
              child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>?>(
                future: classId.isEmpty
                    ? Future.value(null)
                    : FirebaseFirestore.instance
                        .collection('users')
                        .where('classId', isEqualTo: classId)
                        .where('role', isEqualTo: 'teacher')
                        .limit(1)
                        .get(),
                builder: (context, snap) {
                  String diriginte = '';
                  final teacherSnap = snap.data;
                  if (teacherSnap != null && teacherSnap.docs.isNotEmpty) {
                    final td = teacherSnap.docs.first.data();
                    diriginte = (td['fullName'] ?? td['username'] ?? '')
                        .toString()
                        .trim();
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Info card ──
                        Container(
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x10000000),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: const WhiteCardSparklesPainter(
                                    primary: _kPrimary,
                                    variant: 0,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          child: photoUrl.isNotEmpty
                                              ? Image.network(
                                                  photoUrl,
                                                  width: 64,
                                                  height: 64,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (ctx, err, st) =>
                                                          _DetailAvatarFallback(
                                                              name: name),
                                                )
                                              : _DetailAvatarFallback(
                                                  name: name),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w800,
                                                  color: _kOnSurface,
                                                  height: 1.1,
                                                ),
                                              ),
                                              if (username.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  '@$username',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: _kPrimary,
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 8),
                                              Container(
                                                width: 32,
                                                height: 2.5,
                                                decoration: BoxDecoration(
                                                  color: kPencilYellow,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    Container(
                                      height: 1,
                                      color: const Color(0xFFE8EAF2),
                                    ),
                                    const SizedBox(height: 18),
                                    _PersonMetaRow(
                                      icon: Icons.person_rounded,
                                      label: 'HOMEROOM TEACHER',
                                      value: diriginte.isNotEmpty
                                          ? diriginte
                                          : 'Not set',
                                    ),
                                    const SizedBox(height: 12),
                                    _PersonMetaRow(
                                      icon: Icons.school_rounded,
                                      label: 'CLASS',
                                      value: classId.isNotEmpty
                                          ? 'Class $classId'
                                          : 'Not set',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // ── Recent leave requests ──
                        _RecentRequestsCard(studentUid: avatarSeed),
                        const SizedBox(height: 14),
                        // ── Schedule timetable ──
                        Container(
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x10000000),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              _kPrimary.withValues(alpha: 0.12),
                                              _kPrimary.withValues(alpha: 0.06),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _kPrimary
                                                .withValues(alpha: 0.10),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.calendar_today_rounded,
                                          color: _kPrimary,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          classId.isNotEmpty
                                              ? 'Class $classId timetable'
                                              : 'Timetable',
                                          style: const TextStyle(
                                            color: _kOnSurface,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const TimetableGrid(),
                              ],
                            ),
                          ),
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

// ─────────────────────────────────────────────────────────────────────────────
// RECENT LEAVE REQUESTS
// ─────────────────────────────────────────────────────────────────────────────
class _RecentRequestsCard extends StatelessWidget {
  final String studentUid;

  const _RecentRequestsCard({required this.studentUid});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', isEqualTo: studentUid)
        .orderBy('requestedAt', descending: true)
        .limit(15)
        .snapshots();

    return _SectionCard(
      icon: Icons.description_rounded,
      title: 'Recent leave requests',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          // Dedupe — a single request can be split into teacher + parent rows.
          final byKey = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
          for (final d in snap.data!.docs) {
            final data = d.data();
            final key = '${data['dateText']}|${data['timeText']}|${data['message']}|${(data['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0}';
            // Prefer rows with a final status (approved/rejected) when deduping.
            final existing = byKey[key];
            if (existing == null) {
              byKey[key] = d;
            } else {
              final newStatus = (data['status'] ?? '').toString();
              final oldStatus = (existing.data()['status'] ?? '').toString();
              const order = {'approved': 4, 'active': 4, 'rejected': 3, 'pending': 2, '': 1};
              if ((order[newStatus] ?? 0) > (order[oldStatus] ?? 0)) {
                byKey[key] = d;
              }
            }
          }
          final items = byKey.values.take(5).toList();
          if (items.isEmpty) {
            return _EmptyHint(text: 'No leave requests yet.');
          }
          return Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _RequestRow(data: items[i].data()),
                if (i != items.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RequestRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final dateText = (data['dateText'] ?? '').toString();
    final timeText = (data['timeText'] ?? '').toString();
    final message = (data['message'] ?? '').toString().trim();
    final status = (data['status'] ?? 'pending').toString();
    final ({String label, Color bg, Color fg}) info = switch (status) {
      'approved' || 'active' => (
          label: 'Approved',
          bg: const Color(0xFFE2E7FA),
          fg: const Color(0xFF2848B0),
        ),
      'rejected' => (
          label: 'Rejected',
          bg: const Color(0xFFFADBE0),
          fg: const Color(0xFFB03040),
        ),
      _ => (
          label: 'Pending',
          bg: const Color(0xFFFFF1C4),
          fg: const Color(0xFFB07A00),
        ),
    };

    final subtitle = [
      if (dateText.isNotEmpty) dateText,
      if (timeText.isNotEmpty) timeText,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle.isEmpty ? 'Leave request' : subtitle,
                  style: const TextStyle(
                    color: _kOnSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: info.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  info.label,
                  style: TextStyle(
                    color: info.fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF3A4A80),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared section card wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _kPrimary.withValues(alpha: 0.12),
                        _kPrimary.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _kPrimary.withValues(alpha: 0.10),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: _kPrimary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _kOnSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _kLabelColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailAvatarFallback extends StatelessWidget {
  final String name;

  const _DetailAvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();

    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

class _PersonMetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PersonMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAF2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF2848B0), size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF7A7E9A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2050),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

