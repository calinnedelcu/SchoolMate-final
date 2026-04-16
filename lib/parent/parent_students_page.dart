import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';

const _kHeaderGreen = Color(0xFF1F8BE7);
const _kPageBg = Color(0xFFEFF5FA);

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
  const ParentStudentsPage({super.key});

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
            _TopHeader(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: parentUid.isEmpty
                  ? const Center(child: Text('Sesiune invalidă'))
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
                            child: Text('Nu exista copii asignati.'),
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
                                  inSchool: viewData.inSchool,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (_, __, ___) =>
                                            _StudentDetailPage(
                                              avatarSeed: viewData.uid,
                                              name: name,
                                              username: viewData.username,
                                              classId: viewData.classId,
                                              status: viewData.inSchool
                                                  ? 'IN INCINTA'
                                                  : 'IN AFARA INCINTEI',
                                            ),
                                        transitionDuration: Duration.zero,
                                        reverseTransitionDuration:
                                            Duration.zero,
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
  final VoidCallback onBack;

  const _TopHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final headerHeight = compact ? 138.0 : 146.0;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(54),
        bottomRight: Radius.circular(54),
      ),
      child: Container(
        height: headerHeight,
        width: double.infinity,
        color: _kHeaderGreen,
        child: Stack(
          children: [
            Positioned(top: -72, right: -52, child: _decorCircle(220)),
            Positioned(top: 44, right: 34, child: _decorCircle(72)),
            Positioned(left: 156, bottom: -28, child: _decorCircle(82)),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: onBack,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Copiii Mei',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
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
  }

  Widget _decorCircle(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.08),
    ),
  );
}

class _StudentCard extends StatelessWidget {
  final String avatarSeed;
  final String photoUrl;
  final String initials;
  final String name;
  final bool inSchool;
  final VoidCallback onTap;

  const _StudentCard({
    required this.avatarSeed,
    required this.photoUrl,
    required this.initials,
    required this.name,
    required this.inSchool,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarBg = _avatarBackgroundColor(avatarSeed);
    final statusText = inSchool ? 'ÎN INCINTĂ' : 'ÎN AFARA INCINTEI';
    final pillBg = inSchool ? const Color(0xFFDFE9F2) : const Color(0xFFF1E4EC);
    final pillBorder = inSchool
        ? const Color(0xFFAAC3D8)
        : const Color(0xFFDCB1C5);
    final pillText = inSchool
        ? const Color(0xFF1F8DEA)
        : const Color(0xFF922255);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => _AvatarInitials(
                            initials: initials,
                            backgroundColor: avatarBg,
                          ),
                        )
                      : _AvatarInitials(
                          initials: initials,
                          backgroundColor: avatarBg,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF5B7A98),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: pillBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: pillText,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  statusText,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: pillText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3ECF2),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 26,
                    color: Color(0xFF5780A3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _avatarBackgroundColor(String seed) {
    const palette = [
      Color(0xFF63B3FF),
      Color(0xFF1C90FF),
      Color(0xFFF4A261),
      Color(0xFFE76F51),
      Color(0xFF7B61FF),
      Color(0xFF5398DB),
      Color(0xFFC04D83),
      Color(0xFF619ECC),
    ];
    final normalized = seed.trim();
    final index = normalized.isEmpty
        ? 0
        : normalized.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
              palette.length;
    return palette[index];
  }
}

class _AvatarInitials extends StatelessWidget {
  final String initials;
  final Color backgroundColor;

  const _AvatarInitials({
    required this.initials,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
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
  final String status;

  const _StudentDetailPage({
    required this.avatarSeed,
    required this.name,
    required this.username,
    required this.classId,
    required this.status,
  });

  static const _dayMap = {
    1: 'Luni',
    2: 'Marti',
    3: 'Miercuri',
    4: 'Joi',
    5: 'Vineri',
  };

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final headerHeight = compact ? 138.0 : 146.0;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF5FA),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(54),
                bottomRight: Radius.circular(54),
              ),
              child: Container(
                height: headerHeight,
                width: double.infinity,
                color: _kHeaderGreen,
                child: Stack(
                  children: [
                    Positioned(top: -72, right: -52, child: _decorCircle(220)),
                    Positioned(top: 44, right: 34, child: _decorCircle(72)),
                    Positioned(left: 156, bottom: -28, child: _decorCircle(82)),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).maybePop(),
                              behavior: HitTestBehavior.opaque,
                              child: const SizedBox(
                                width: 34,
                                height: 34,
                                child: Center(
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Detalii Elev',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 29,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: Future.wait([
                  // fetch teacher for this class
                  classId.isNotEmpty
                      ? FirebaseFirestore.instance
                            .collection('users')
                            .where('classId', isEqualTo: classId)
                            .where('role', isEqualTo: 'teacher')
                            .limit(1)
                            .get()
                      : Future.value(null),
                  // fetch class schedule
                  classId.isNotEmpty
                      ? FirebaseFirestore.instance
                            .collection('classes')
                            .doc(classId)
                            .get()
                      : Future.value(null),
                ]),
                builder: (context, snap) {
                  String diriginte = '';
                  Map<int, Map<String, String>> schedule = {};

                  if (snap.hasData) {
                    final teacherSnap = snap.data![0] as QuerySnapshot?;
                    if (teacherSnap != null && teacherSnap.docs.isNotEmpty) {
                      final td =
                          teacherSnap.docs.first.data() as Map<String, dynamic>;
                      diriginte = (td['fullName'] ?? td['username'] ?? '')
                          .toString()
                          .trim();
                    }

                    final classDoc = snap.data![1] as DocumentSnapshot?;
                    if (classDoc != null && classDoc.exists) {
                      final cd = classDoc.data() as Map<String, dynamic>? ?? {};
                      final raw = cd['schedule'];
                      if (raw is Map) {
                        for (final e in raw.entries) {
                          final day = int.tryParse(e.key.toString());
                          if (day != null &&
                              day >= 1 &&
                              day <= 5 &&
                              e.value is Map) {
                            final t = e.value as Map;
                            final start = (t['start'] ?? '').toString();
                            final end = (t['end'] ?? '').toString();
                            if (start.isNotEmpty && end.isNotEmpty) {
                              schedule[day] = {'start': start, 'end': end};
                            }
                          }
                        }
                      }
                    }
                  }

                  final sortedDays = schedule.keys.toList()..sort();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Info card ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(38),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x121F8BE7),
                                blurRadius: 28,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _DetailAvatarFallback(
                                    avatarSeed: avatarSeed,
                                    name: name,
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
                                            color: Color(0xFF537DA2),
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
                                              color: Color(0xFF1F8BE7),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 26),
                              Container(
                                height: 1,
                                color: const Color(0xFFF0F1EA),
                              ),
                              const SizedBox(height: 22),
                              _PersonMetaRow(
                                icon: Icons.person_rounded,
                                label: 'DIRIGINTE',
                                value: diriginte.isNotEmpty
                                    ? diriginte
                                    : 'Nedefinit',
                              ),
                              const SizedBox(height: 12),
                              _PersonMetaRow(
                                icon: Icons.school_rounded,
                                label: 'CLASĂ',
                                value: classId.isNotEmpty
                                    ? 'Clasa $classId'
                                    : 'Nedefinit',
                              ),
                              const SizedBox(height: 18),
                              _StatusMetaRow(status: status),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        // ── Voluntariat card ──
                        _VoluntariatSection(studentUid: avatarSeed),
                        const SizedBox(height: 18),
                        // ── Tutoring card ──
                        _TutoringSection(studentUid: avatarSeed),
                        const SizedBox(height: 18),
                        // ── Orar card ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(
                                0xFFBACCD9,
                              ).withValues(alpha: 0.18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                classId.isNotEmpty
                                    ? 'Orar Clasa $classId'
                                    : 'Orar',
                                style: const TextStyle(
                                  color: Color(0xFF587F9E),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (!snap.hasData)
                                const Center(child: CircularProgressIndicator())
                              else if (sortedDays.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE7F0F6),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Text(
                                    'Nu există orar definit pentru această clasă.',
                                    style: TextStyle(
                                      color: Color(0xFF717B6E),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              else
                                for (final day in sortedDays) ...[
                                  _OrarRow(
                                    day: _dayMap[day] ?? 'Ziua $day',
                                    interval:
                                        '${schedule[day]!['start']} - ${schedule[day]!['end']}',
                                  ),
                                  if (day != sortedDays.last)
                                    const SizedBox(height: 10),
                                ],
                            ],
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

  Widget _decorCircle(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.08),
    ),
  );
}

class _OrarRow extends StatelessWidget {
  final String day;
  final String interval;

  const _OrarRow({required this.day, required this.interval});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            day,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF537DA2),
              height: 1,
            ),
          ),
          const Spacer(),
          Text(
            interval,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F8BE7),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailAvatarFallback extends StatelessWidget {
  final String avatarSeed;
  final String name;

  const _DetailAvatarFallback({required this.avatarSeed, required this.name});

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
        color: _detailAvatarColor(avatarSeed),
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

Color _detailAvatarColor(String seed) {
  const palette = [
    Color(0xFF63B3FF),
    Color(0xFF1C90FF),
    Color(0xFFF4A261),
    Color(0xFFE76F51),
    Color(0xFF7B61FF),
    Color(0xFF5398DB),
    Color(0xFFC04D83),
    Color(0xFF619ECC),
  ];
  final normalized = seed.trim();
  final index = normalized.isEmpty
      ? 0
      : normalized.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
            palette.length;
  return palette[index];
}

class _StatusMetaRow extends StatelessWidget {
  final String status;

  const _StatusMetaRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final inSchool =
        normalized.contains('incinta') && !normalized.contains('afara');
    final label = inSchool ? 'ÎN INCINTĂ' : 'ÎN AFARA INCINTEI';
    final pillBg = inSchool ? const Color(0xFFDFE9F2) : const Color(0xFFF1E4EC);
    final pillBorder = inSchool
        ? const Color(0xFFAAC3D8)
        : const Color(0xFFDCB1C5);
    final pillText = inSchool
        ? const Color(0xFF1F8DEA)
        : const Color(0xFF922255);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: pillBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: pillText,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: pillText,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1,
              ),
            ),
          ],
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
            color: const Color(0xFFE6EEF4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF1F8BE7), size: 24),
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
                  color: Color(0xFF6E7C70),
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
                  color: Color(0xFF537DA2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// VOLUNTARIAT SECTION (parent child detail)
// ────────────────────────────────────────────────────────────────────────────
class _VoluntariatSection extends StatelessWidget {
  final String studentUid;
  const _VoluntariatSection({required this.studentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('volunteerSignups')
          .where('studentUid', isEqualTo: studentUid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        int totalHours = 0;
        for (final doc in docs) {
          totalHours += (doc.data()['hoursLogged'] as num?)?.toInt() ?? 0;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFFBACCD9).withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Voluntariat',
                      style: TextStyle(
                        color: Color(0xFF587F9E),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kHeaderGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: _kHeaderGreen, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$totalHours ore',
                          style: const TextStyle(
                            color: _kHeaderGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F0F6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Nicio activitate de voluntariat completata.',
                    style: TextStyle(
                      color: Color(0xFF717B6E),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ...docs.map((doc) {
                  final d = doc.data();
                  final title =
                      (d['opportunityTitle'] ?? 'Activitate').toString();
                  final hours = (d['hoursLogged'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F0F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.volunteer_activism_rounded,
                              color: _kHeaderGreen, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF537DA2),
                              ),
                            ),
                          ),
                          Text(
                            '$hours ore',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _kHeaderGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TUTORING SECTION (parent child detail)
// ────────────────────────────────────────────────────────────────────────────
class _TutoringSection extends StatelessWidget {
  final String studentUid;
  const _TutoringSection({required this.studentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tutoringSessions')
          .where('tutorUid', isEqualTo: studentUid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, tutorSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('tutoringSessions')
              .where('learnerUid', isEqualTo: studentUid)
              .where('status', isEqualTo: 'completed')
              .snapshots(),
          builder: (context, learnerSnap) {
            final tutorDocs = tutorSnap.data?.docs ?? [];
            final learnerDocs = learnerSnap.data?.docs ?? [];

            int totalHours = 0;
            for (final doc in tutorDocs) {
              totalHours += (doc.data()['hoursLogged'] as num?)?.toInt() ?? 0;
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0xFFBACCD9).withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Peer Tutoring',
                          style: TextStyle(
                            color: Color(0xFF587F9E),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kHeaderGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded,
                                color: _kHeaderGreen, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$totalHours ore',
                              style: const TextStyle(
                                color: _kHeaderGreen,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TutoringStat(
                          icon: Icons.menu_book_rounded,
                          value: '${tutorDocs.length}',
                          label: 'predate',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TutoringStat(
                          icon: Icons.lightbulb_rounded,
                          value: '${learnerDocs.length}',
                          label: 'invatate',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (tutorDocs.isEmpty && learnerDocs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F0F6),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Nicio sesiune de peer tutoring inca.',
                        style: TextStyle(
                          color: Color(0xFF717B6E),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    ...[...tutorDocs, ...learnerDocs].map((doc) {
                      final d = doc.data();
                      final subject = (d['subject'] ?? 'Materie').toString();
                      final isTutor = d['tutorUid'] == studentUid;
                      final otherName = isTutor
                          ? (d['learnerName'] ?? '').toString()
                          : (d['tutorName'] ?? '').toString();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F0F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isTutor
                                    ? Icons.menu_book_rounded
                                    : Icons.lightbulb_rounded,
                                color: _kHeaderGreen,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subject,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF537DA2),
                                      ),
                                    ),
                                    Text(
                                      isTutor
                                          ? 'Tutor pentru $otherName'
                                          : 'Elev cu $otherName',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF717B6E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TutoringStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _TutoringStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: _kHeaderGreen, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _kHeaderGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF717B6E),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
