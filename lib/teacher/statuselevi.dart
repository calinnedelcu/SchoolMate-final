import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import '../student/widgets/school_decor.dart';

const _kPageBg = Color(0xFFF2F4F8);
const _kCardBg = Color(0xFFFFFFFF);

/// Placeholder status page for teachers. Currently mirrors the dashboard UI.
class StatusEleviPage extends StatefulWidget {
  final bool showBack;
  const StatusEleviPage({super.key, this.showBack = true});

  @override
  State<StatusEleviPage> createState() => _StatusEleviPageState();
}

class _StatusEleviPageState extends State<StatusEleviPage> {

  @override
  Widget build(BuildContext context) {
    final teacherUid = AppSession.uid;
    if (teacherUid == null || teacherUid.isEmpty) {
      return const Scaffold(body: Center(child: Text("No session")));
    }

    final teacherDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(teacherUid);

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PageBlueHeader(
              title: 'My class',
              subtitle: 'Class roster',
              onBack: widget.showBack
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: teacherDoc.get(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snap.data!.exists) {
                    return const Center(child: Text('Teacher not found'));
                  }

                  final data = snap.data!.data() as Map<String, dynamic>;
                  final classId = (data['classId'] ?? '').toString().trim();

                  if (classId.isEmpty) {
                    return const Center(
                      child: Text(
                        'No class assigned.\nAsk the secretariat to set your classId.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final studentsStream = FirebaseFirestore.instance
                      .collection('users')
                      .where('classId', isEqualTo: classId)
                      .where('role', isEqualTo: 'student')
                      .orderBy('fullName')
                      .snapshots();

                  return StreamBuilder<QuerySnapshot>(
                    stream: studentsStream,
                    builder: (context, stuSnap) {
                      if (stuSnap.hasError) {
                        return Center(
                          child: Text('Error loading students: ${stuSnap.error}'),
                        );
                      }
                      if (!stuSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final students = stuSnap.data!.docs;
                      if (students.isEmpty) {
                        return const Center(
                          child: Text('No students in this class.'),
                        );
                      }

                      final sortedStudents = [...students]
                            ..sort((a, b) {
                              final aData = a.data() as Map<String, dynamic>;
                              final bData = b.data() as Map<String, dynamic>;
                              final aName =
                                  (aData['fullName'] ??
                                          aData['username'] ??
                                          a.id)
                                      .toString()
                                      .toLowerCase();
                              final bName =
                                  (bData['fullName'] ??
                                          bData['username'] ??
                                          b.id)
                                      .toString()
                                      .toLowerCase();
                              return aName.compareTo(bName);
                            });

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  18,
                                  16,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Class $classId',
                                      style: const TextStyle(
                                        color: Color(0xFF1A2050),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${sortedStudents.length} ${sortedStudents.length == 1 ? 'student' : 'students'}',
                                      style: const TextStyle(
                                        color: Color(0xFF7A7E9A),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    24,
                                  ),
                                  itemCount: sortedStudents.length,
                                  itemBuilder: (context, index) {
                                    final stu = sortedStudents[index];
                                    final ud =
                                        stu.data() as Map<String, dynamic>;
                                    final uid = stu.id;
                                    final name =
                                        (ud['fullName'] ??
                                                ud['username'] ??
                                                uid)
                                            .toString();
                                    final username = (ud['username'] ?? '')
                                        .toString()
                                        .trim();
                                    final email =
                                        (ud['personalEmail'] ??
                                                ud['email'] ??
                                                ud['authEmail'] ??
                                                '')
                                            .toString()
                                            .trim();
                                    final photoUrl =
                                        (ud['profilePictureUrl'] ??
                                                ud['photoUrl'] ??
                                                ud['avatarUrl'] ??
                                                '')
                                            .toString()
                                            .trim();
                                    final parentsRaw = ud['parents'];
                                    final parentUid = parentsRaw is List
                                        ? parentsRaw
                                              .map(
                                                (parent) =>
                                                    parent.toString().trim(),
                                              )
                                              .firstWhere(
                                                (parent) => parent.isNotEmpty,
                                                orElse: () => '',
                                              )
                                        : (ud['parentUid'] ?? '')
                                              .toString()
                                              .trim();
                                    final initials = name
                                        .trim()
                                        .split(' ')
                                        .where((w) => w.isNotEmpty)
                                        .take(2)
                                        .map((w) => w[0].toUpperCase())
                                        .join();

                                    return _StudentListCard(
                                      avatarSeed: uid,
                                      photoUrl: photoUrl,
                                      initials: initials,
                                      name: name,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder: (_, _, _) =>
                                                _StudentDetailPage(
                                                  avatarSeed: uid,
                                                  name: name,
                                                  username: username,
                                                  email: email,
                                                  photoUrl: photoUrl,
                                                  parentUid: parentUid,
                                                  classId: classId,
                                                ),
                                            transitionDuration: Duration.zero,
                                            reverseTransitionDuration:
                                                Duration.zero,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
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
}

class _StudentListCard extends StatelessWidget {
  final String avatarSeed;
  final String photoUrl;
  final String initials;
  final String name;
  final VoidCallback onTap;

  const _StudentListCard({
    required this.avatarSeed,
    required this.photoUrl,
    required this.initials,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarBg = _avatarBackgroundColor(avatarSeed);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _AvatarInitials(
                              initials: initials,
                              backgroundColor: avatarBg,
                            );
                          },
                        )
                      : _AvatarInitials(
                          initials: initials,
                          backgroundColor: avatarBg,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1A2050),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: Color(0xFF7A7E9A),
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
        : normalized.codeUnits.fold<int>(0, (acc, unit) => acc + unit) %
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

// ─── Student detail page ──────────────────────────────────────────────────────

class _StudentDetailPage extends StatelessWidget {
  final String avatarSeed;
  final String name;
  final String username;
  final String email;
  final String photoUrl;
  final String parentUid;
  final String classId;

  const _StudentDetailPage({
    required this.avatarSeed,
    required this.name,
    required this.username,
    required this.email,
    required this.photoUrl,
    required this.parentUid,
    required this.classId,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2848B0);
    const onSurface = Color(0xFF1A2050);

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageBlueHeader(
              title: 'Student details',
              subtitle: name,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Identity card ──
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
                          const Positioned.fill(
                            child: CustomPaint(
                              painter: WhiteCardSparklesPainter(
                                primary: primary,
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
                                    GestureDetector(
                                      onTap: photoUrl.isNotEmpty
                                          ? () => _openDetailImage(
                                                context,
                                                photoUrl,
                                              )
                                          : null,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: SizedBox(
                                          width: 64,
                                          height: 64,
                                          child: photoUrl.isNotEmpty
                                              ? Image.network(
                                                  photoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) =>
                                                      _DetailAvatarFallback(
                                                        avatarSeed: avatarSeed,
                                                        name: name,
                                                      ),
                                                )
                                              : _DetailAvatarFallback(
                                                  avatarSeed: avatarSeed,
                                                  name: name,
                                                ),
                                        ),
                                      ),
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
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                              color: onSurface,
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
                                                color: primary,
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
                                  icon: Icons.alternate_email_rounded,
                                  label: 'EMAIL',
                                  value: email.isNotEmpty ? email : 'Not set',
                                ),
                                const SizedBox(height: 12),
                                _ParentTutorRow(parentUid: parentUid),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ── Recent leave requests for this student ──
                    _StudentRecentRequestsCard(
                      studentUid: avatarSeed,
                      classId: classId,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT LEAVE REQUESTS (per student, for teacher view)
// ─────────────────────────────────────────────────────────────────────────────
class _StudentRecentRequestsCard extends StatelessWidget {
  final String studentUid;
  final String classId;
  const _StudentRecentRequestsCard({
    required this.studentUid,
    required this.classId,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2848B0);
    const onSurface = Color(0xFF1A2050);
    const labelColor = Color(0xFF7A7E9A);

    final stream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('classId', isEqualTo: classId)
        .where('studentUid', isEqualTo: studentUid)
        .limit(20)
        .snapshots();

    return Container(
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
                        primary.withValues(alpha: 0.12),
                        primary.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.10),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Recent leave requests',
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Could not load requests.',
                      style: const TextStyle(
                        color: labelColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                // Dedupe identical request rows
                final byKey =
                    <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
                for (final d in snap.data!.docs) {
                  final data = d.data();
                  final key =
                      '${data['dateText']}|${data['timeText']}|${data['message']}|${(data['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0}';
                  final existing = byKey[key];
                  if (existing == null) {
                    byKey[key] = d;
                  } else {
                    final existingStatus =
                        (existing.data()['status'] ?? '').toString();
                    if (existingStatus == 'pending') byKey[key] = d;
                  }
                }
                final docs = byKey.values.toList()
                  ..sort((a, b) {
                    final at =
                        (a.data()['requestedAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    final bt =
                        (b.data()['requestedAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    return bt.compareTo(at);
                  });

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No requests yet.',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final doc in docs.take(5)) ...[
                      _RequestSummaryRow(data: doc.data()),
                      if (doc != docs.take(5).last)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(
                            height: 1,
                            color: Color(0xFFE8EAF2),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestSummaryRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RequestSummaryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    const onSurface = Color(0xFF1A2050);
    const labelColor = Color(0xFF7A7E9A);

    final status = (data['status'] ?? 'pending').toString();
    final dateText = (data['dateText'] ?? '').toString();
    final timeText = (data['timeText'] ?? '').toString();
    final message = (data['message'] ?? '').toString();

    Color pillBg;
    Color pillFg;
    String label;
    IconData icon;
    switch (status) {
      case 'approved':
        pillBg = const Color(0xFFD9F2E2);
        pillFg = const Color(0xFF1B8A4D);
        label = 'APPROVED';
        icon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        pillBg = const Color(0xFFFADADF);
        pillFg = const Color(0xFFB03040);
        label = 'REJECTED';
        icon = Icons.cancel_rounded;
        break;
      default:
        pillBg = const Color(0xFFFFF1C4);
        pillFg = const Color(0xFFC58A00);
        label = 'PENDING';
        icon = Icons.hourglass_top_rounded;
    }

    final headline = [
      if (dateText.isNotEmpty) dateText,
      if (timeText.isNotEmpty) timeText,
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: pillFg, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: pillFg,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline.isEmpty ? 'Request' : headline,
                style: const TextStyle(
                  color: onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: labelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

void _openDetailImage(BuildContext context, String url) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: true,
      pageBuilder: (_, _, _) => _DetailFullScreenImage(url: url),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _DetailFullScreenImage extends StatelessWidget {
  final String url;

  const _DetailFullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 56,
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
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
      : normalized.codeUnits.fold<int>(0, (acc, unit) => acc + unit) %
            palette.length;
  return palette[index];
}

class _ParentTutorRow extends StatelessWidget {
  final String parentUid;

  const _ParentTutorRow({required this.parentUid});

  @override
  Widget build(BuildContext context) {
    if (parentUid.isEmpty) {
      return const _PersonMetaRow(
        icon: Icons.family_restroom_rounded,
        label: 'PARENT / GUARDIAN',
        value: 'Not set',
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .get(),
      builder: (context, snapshot) {
        final parentData = snapshot.data?.data() ?? const <String, dynamic>{};
        final parentName =
            (parentData['fullName'] ?? parentData['username'] ?? 'Not set')
                .toString()
                .trim();

        return _PersonMetaRow(
          icon: Icons.family_restroom_rounded,
          label: 'PARENT / GUARDIAN',
          value: parentName.isEmpty ? 'Not set' : parentName,
        );
      },
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

// ignore: unused_element
class _DetailCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final Widget trailing;

  const _DetailCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1C),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}
