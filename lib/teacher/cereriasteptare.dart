import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import '../student/widgets/school_decor.dart';

const _kPageBg = Color(0xFFF2F4F8);
const _kPrimary = Color(0xFF2848B0);
const _kOnSurface = Color(0xFF1A2050);
const _kOnSurfaceMid = Color(0xFF3A4A80);
const _kLabelColor = Color(0xFF7A7E9A);

class CereriAsteptarePage extends StatefulWidget {
  const CereriAsteptarePage({super.key});

  @override
  State<CereriAsteptarePage> createState() => _CereriAsteptarePageState();
}

class _CereriAsteptarePageState extends State<CereriAsteptarePage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _teacherStream;
  String _classId = '';
  String? _busyDocId;

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
        final classId = ((doc.data() ?? {})['classId'] ?? '').toString().trim();
        if (classId.isNotEmpty && classId != _classId) {
          setState(() => _classId = classId);
        }
      });
    }
  }

  Future<void> _reviewRequest({
    required String requestId,
    required String status,
  }) async {
    final teacherUid = AppSession.uid;
    if (teacherUid == null || teacherUid.isEmpty) return;
    if (_busyDocId != null) return;
    setState(() => _busyDocId = requestId);
    try {
      await FirebaseFirestore.instance
          .collection('leaveRequests')
          .doc(requestId)
          .update({
            'status': status,
            'reviewedAt': Timestamp.now(),
            'reviewedByUid': teacherUid,
            'reviewedByName': (AppSession.username ?? '').toString(),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Request approved' : 'Request rejected',
          ),
          backgroundColor: status == 'approved'
              ? _kPrimary
              : const Color(0xFFB03040),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyDocId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('No session')));
    }

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PageBlueHeader(
              title: 'Leave requests',
              subtitle: 'Approve or reject',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: _classId.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('leaveRequests')
                          .where('classId', isEqualTo: _classId)
                          .where('status', isEqualTo: 'pending')
                          .orderBy('requestedAt', descending: true)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Could not load requests.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _kLabelColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final docs = snap.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final targets = (data['targets'] as List?)
                              ?.map((e) => e.toString())
                              .toList();
                          if (targets != null && targets.isNotEmpty) {
                            return targets.contains('teacher');
                          }
                          // Legacy doc fallback (single-recipient schema).
                          final legacyRole =
                              (data['targetRole'] ?? '').toString();
                          return legacyRole.isEmpty ||
                              legacyRole == 'teacher';
                        }).toList();
                        if (docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: _kPrimary.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.inbox_rounded,
                                      size: 44,
                                      color: _kPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No pending requests',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: _kOnSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'New leave requests from your class will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _kLabelColor,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final d = doc.data() as Map<String, dynamic>;
                            final requestId = doc.id;
                            final busy = _busyDocId == requestId;
                            final disabled = _busyDocId != null && !busy;

                            return _RequestCard(
                              data: d,
                              classId: _classId,
                              busy: busy,
                              disabled: disabled,
                              onAccept: () => _reviewRequest(
                                requestId: requestId,
                                status: 'approved',
                              ),
                              onReject: () => _reviewRequest(
                                requestId: requestId,
                                status: 'rejected',
                              ),
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

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String classId;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool busy;
  final bool disabled;

  const _RequestCard({
    required this.data,
    required this.classId,
    required this.onAccept,
    required this.onReject,
    this.busy = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final studentName = (data['studentName'] ?? '').toString().trim();
    final dateText = (data['dateText'] ?? '').toString();
    final timeText = (data['timeText'] ?? '').toString();
    final message = (data['message'] ?? '').toString();

    final initials = _initials(studentName);
    final classLabel = classId.isEmpty
        ? 'STUDENT'
        : 'STUDENT • CLASS ${classId.toUpperCase()}';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
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
          const Positioned.fill(
            child: CustomPaint(
              painter: WhiteCardSparklesPainter(
                primary: _kPrimary,
                variant: 2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _kPrimary.withValues(alpha: 0.14),
                                _kPrimary.withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _kPrimary.withValues(alpha: 0.10),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _kPrimary,
                              height: 1,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: kPencilYellow,
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
                            studentName.isEmpty
                                ? 'Unnamed student'
                                : studentName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              color: _kOnSurface,
                              fontWeight: FontWeight.w800,
                              height: 1.18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: cs.outlineVariant,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              classLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800,
                                color: _kPrimary,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoLine(
                  icon: Icons.calendar_today_rounded,
                  text: dateText.isEmpty ? '-' : dateText,
                ),
                const SizedBox(height: 10),
                _InfoLine(
                  icon: Icons.access_time_filled_rounded,
                  text: timeText.isEmpty ? '-' : timeText,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: const Border(
                      left: BorderSide(color: _kPrimary, width: 3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.description_rounded,
                          size: 26,
                          color: _kPrimary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'REASON',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _kLabelColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message.isEmpty ? '-' : '"$message"',
                              style: const TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: _kOnSurfaceMid,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: (busy || disabled) ? null : onAccept,
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _kPrimary.withValues(
                              alpha: 0.5,
                            ),
                            disabledForegroundColor: Colors.white.withValues(
                              alpha: 0.85,
                            ),
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: (busy || disabled) ? null : onReject,
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFB03040),
                                    ),
                                  ),
                                )
                              : const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF8E0E5),
                            foregroundColor: const Color(0xFFB03040),
                            disabledBackgroundColor: const Color(0xFFF8E0E5)
                                .withValues(alpha: 0.6),
                            disabledForegroundColor: const Color(0xFFB03040)
                                .withValues(alpha: 0.7),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim())
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _kPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: _kOnSurfaceMid,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
