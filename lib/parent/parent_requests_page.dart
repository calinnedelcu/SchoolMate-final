import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../common/linked_children_resolver.dart';
import '../core/session.dart';
import '../student/widgets/school_decor.dart';

const _kPageBg = Color(0xFFF2F4F8);
const _kPrimary = Color(0xFF2848B0);
const _kOnSurface = Color(0xFF1A2050);
const _kOnSurfaceMid = Color(0xFF3A4A80);
const _kLabelColor = Color(0xFF7A7E9A);

class ParentRequestsPage extends StatefulWidget {
  const ParentRequestsPage({super.key});

  @override
  State<ParentRequestsPage> createState() => _ParentRequestsPageState();
}

class _ParentRequestsPageState extends State<ParentRequestsPage> {
  bool _loadedOnce = false;
  String? _busyDocId;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    setState(() => _loadedOnce = true);
  }

  @override
  void dispose() => super.dispose();

  Future<void> _handleRequest(String docId, bool approved) async {
    if (_busyDocId != null) return;
    setState(() => _busyDocId = docId);
    final parentName =
        (AppSession.fullName != null && AppSession.fullName!.isNotEmpty)
        ? AppSession.fullName!
        : (AppSession.username ?? 'Parent');
    try {
      await FirebaseFirestore.instance
          .collection('leaveRequests')
          .doc(docId)
          .update({
            'status': approved ? 'approved' : 'rejected',
            'reviewedAt': FieldValue.serverTimestamp(),
            'reviewedByUid': AppSession.uid,
            'reviewedByName': parentName,
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Request approved!' : 'Request rejected.'),
          backgroundColor: approved ? const Color(0xFF2848B0) : const Color(0xFFB03040),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text('Could not process the request. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyDocId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: _loadedOnce
                    ? _buildRequests()
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequests() {
    final parentUid = (AppSession.uid ?? '').trim();

    return FutureBuilder<List<String>>(
      future: _loadLinkedStudentIds(parentUid),
      builder: (context, linkedSnapshot) {
        if (!linkedSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final linkedChildIds = linkedSnapshot.data!;
        final streams = <Stream<QuerySnapshot<Map<String, dynamic>>>>[
          ..._buildLegacyChildRequestStreams(linkedChildIds),
        ];

        return _buildMergedRequestStream(streams, (mergedDocs) {
          final docs = mergedDocs.where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? '').toString().trim();
            final source = (data['source'] ?? '').toString().trim();
            final studentUid = (data['studentUid'] ?? '').toString().trim();
            final isLegacyLinkedRequest = linkedChildIds.contains(studentUid);

            return status == 'pending' &&
                source != 'secretariat' &&
              isLegacyLinkedRequest;
          }).toList()..sort((a, b) {
            final aTs = a.data()['requestedAt'] as Timestamp?;
            final bTs = b.data()['requestedAt'] as Timestamp?;
            return (bTs?.millisecondsSinceEpoch ?? 0).compareTo(
              aTs?.millisecondsSinceEpoch ?? 0,
            );
          });

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
                      'New leave requests from your child will appear here.',
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
            padding: const EdgeInsets.only(top: 2, bottom: 24),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final busy = _busyDocId == doc.id;
              final disabled = _busyDocId != null && !busy;
              return _RequestCard(
                data: data,
                busy: busy,
                disabled: disabled,
                onAccept: () => _handleRequest(doc.id, true),
                onReject: () => _handleRequest(doc.id, false),
              );
            },
          );
        });
      },
    );
  }

  Future<List<String>> _loadLinkedStudentIds(String parentUid) async {
    if (parentUid.isEmpty) return const <String>[];

    final users = FirebaseFirestore.instance.collection('users');
    final ids = <String>{};

    try {
      final parentDoc = await users.doc(parentUid).get();
      final parentData = parentDoc.data() ?? const <String, dynamic>{};
      ids.addAll(
        ((parentData['children'] as List? ?? const [])
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty && value != parentUid)),
      );
    } catch (e, st) {
      debugPrint('parent_requests_page: load parent doc children list: $e\n$st');
    }

    ids.addAll(await resolveLinkedChildIds(
      parentUid,
      tag: 'parent_requests_page',
    ));

    final sorted = ids.toList()..sort();
    return sorted;
  }

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildLegacyChildRequestStreams(
    List<String> studentIds,
  ) {
    if (studentIds.isEmpty) {
      return const <Stream<QuerySnapshot<Map<String, dynamic>>>>[];
    }

    const chunkSize = 10;
    final streams = <Stream<QuerySnapshot<Map<String, dynamic>>>>[];
    for (int index = 0; index < studentIds.length; index += chunkSize) {
      final chunk = studentIds.skip(index).take(chunkSize).toList();
      streams.add(
        FirebaseFirestore.instance
            .collection('leaveRequests')
            .where('studentUid', whereIn: chunk)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
      );
    }
    return streams;
  }

  Widget _buildMergedRequestStream(
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
        final unique = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
          for (final doc in acc) doc.id: doc,
        };
        return onReady(unique.values.toList());
      }

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: streams[index],
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Continue with other streams if one chunk is denied.
            return step(index + 1, acc);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return step(index + 1, [...acc, ...snapshot.data!.docs]);
        },
      );
    }

    return step(0, const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool busy;
  final bool disabled;

  const _RequestCard({
    required this.data,
    required this.onAccept,
    required this.onReject,
    this.busy = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final studentName = (data['studentName'] ?? 'Unknown student')
        .toString()
        .trim();
    final classId = (data['classId'] ?? '').toString().trim();
    final dateText = (data['dateText'] ?? '-').toString();
    final timeText = (data['timeText'] ?? '-').toString();
    final reason = (data['message'] ?? 'No reason').toString().trim();

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
          Positioned.fill(
            child: CustomPaint(
              painter: const WhiteCardSparklesPainter(
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
                            studentName,
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
                              reason.isEmpty ? '-' : '"$reason"',
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
    if (parts.isEmpty) return 'E';
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

class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _BouncingButton({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> {
  double _scale = 1.0;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() {
        _scale = 0.96;
        _isPressed = true;
      }),
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
          _isPressed = false;
        });
        Future.delayed(const Duration(milliseconds: 90), widget.onTap);
      },
      onTapCancel: () => setState(() {
        _scale = 1.0;
        _isPressed = false;
      }),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 90),
                opacity: _isPressed ? 0.10 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: widget.borderRadius,
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
