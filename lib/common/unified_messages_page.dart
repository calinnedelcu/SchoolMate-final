import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';
import '../student/widgets/school_decor.dart';

const _kPrimary = Color(0xFF2848B0);
const _kPageBg = Color(0xFFF2F4F8);
const _kTextPrimary = Color(0xFF1A2050);
const _kTextMid = Color(0xFF3A4A80);
const _kTextMuted = Color(0xFF7A7E9A);

enum UnifiedInboxRole { student, parent, teacher }

enum _MessageKind { decision, system }

enum _MessageState { pending, approved, rejected, system }

enum _MessageCategory { requests, announcements, competition, camp, volunteer }

class UnifiedMessagesPage extends StatefulWidget {
  final UnifiedInboxRole role;
  final VoidCallback? onBack;
  final VoidCallback? onCreatePost;

  const UnifiedMessagesPage({
    super.key,
    required this.role,
    this.onBack,
    this.onCreatePost,
  });

  @override
  State<UnifiedMessagesPage> createState() => _UnifiedMessagesPageState();
}

class _UnifiedMessagesPageState extends State<UnifiedMessagesPage> {
  bool _loadingChildren = false;
  List<String> _childrenUids = const <String>[];
  Map<String, String> _childNames = const <String, String>{};
  String _teacherClassId = '';
  bool _loadingTeacherClass = false;
  _MessageCategory? _filter; // null == "All"

  @override
  void initState() {
    super.initState();
    if (widget.role == UnifiedInboxRole.parent) {
      _loadingChildren = true;
      _loadChildren();
    } else if (widget.role == UnifiedInboxRole.teacher) {
      _loadingTeacherClass = true;
      _loadTeacherClass();
    }
  }

  Future<void> _loadTeacherClass() async {
    final uid = (AppSession.uid ?? '').trim();
    if (uid.isEmpty) {
      if (mounted) setState(() => _loadingTeacherClass = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final classId = (doc.data()?['classId'] ?? '').toString().trim();
      if (mounted) {
        setState(() {
          _teacherClassId = classId;
          _loadingTeacherClass = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTeacherClass = false);
    }
  }

  Future<void> _loadChildren() async {
    final uid = (AppSession.uid ?? '').trim();
    if (uid.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingChildren = false;
          _childrenUids = const <String>[];
          _childNames = const <String, String>{};
        });
      }
      return;
    }

    try {
      final parentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final parentData = parentDoc.data() ?? const <String, dynamic>{};
      final childIds = await _loadLinkedChildrenUids(uid, parentData);
      final childNames = await _loadUserLabels(childIds.toSet());

      if (mounted) {
        setState(() {
          _loadingChildren = false;
          _childrenUids = childIds;
          _childNames = childNames;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingChildren = false;
          _childrenUids = const <String>[];
          _childNames = const <String, String>{};
        });
      }
    }
  }

  Future<List<String>> _loadLinkedChildrenUids(
    String parentUid,
    Map<String, dynamic> parentData,
  ) async {
    final ids = <String>{
      ...((parentData['children'] as List? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty && value != parentUid)),
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

    final sorted = ids.toList()..sort();
    return sorted;
  }

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildSecretariatStreams(
    String uid,
  ) {
    final base = FirebaseFirestore.instance.collection('secretariatMessages');
    switch (widget.role) {
      case UnifiedInboxRole.student:
        return [
          base
              .where('recipientRole', isEqualTo: 'student')
              .where('recipientUid', isEqualTo: '')
              .snapshots(),
          base
              .where('recipientRole', isEqualTo: 'student')
              .where('recipientUid', isEqualTo: uid)
              .snapshots(),
        ];
      case UnifiedInboxRole.teacher:
        return [
          // Teacher-targeted broadcasts + direct messages
          base
              .where('recipientRole', isEqualTo: 'teacher')
              .where('recipientUid', isEqualTo: '')
              .snapshots(),
          base
              .where('recipientRole', isEqualTo: 'teacher')
              .where('recipientUid', isEqualTo: uid)
              .snapshots(),
          // Same student-broadcasts the teacher's class sees
          base
              .where('recipientRole', isEqualTo: 'student')
              .where('recipientUid', isEqualTo: '')
              .snapshots(),
        ];
      case UnifiedInboxRole.parent:
        return [
          // Parent-targeted: broadcasts + per-child messages
          base
              .where('recipientRole', isEqualTo: 'parent')
              .where('studentUid', isEqualTo: '')
              .snapshots(),
          ..._childrenUids.map(
            (childUid) => base
                .where('recipientRole', isEqualTo: 'parent')
                .where('studentUid', isEqualTo: childUid)
                .snapshots(),
          ),
          // Student-targeted: parents see school-wide broadcasts and
          // messages addressed to any of their children.
          base
              .where('recipientRole', isEqualTo: 'student')
              .where('recipientUid', isEqualTo: '')
              .snapshots(),
          ..._childrenUids.map(
            (childUid) => base
                .where('recipientRole', isEqualTo: 'student')
                .where('recipientUid', isEqualTo: childUid)
                .snapshots(),
          ),
        ];
    }
  }

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildParentDecisionStreams(
    String uid,
  ) {
    final leave = FirebaseFirestore.instance.collection('leaveRequests');
    return [
      ..._childrenUids.map(
        (childUid) => leave
            .where('studentUid', isEqualTo: childUid)
            .orderBy('requestedAt', descending: true)
            .limit(50)
            .snapshots(),
      ),
    ];
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>?
  _buildTeacherDecisionsStream() {
    if (_teacherClassId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('classId', isEqualTo: _teacherClassId)
        .orderBy('requestedAt', descending: true)
        .limit(80)
        .snapshots();
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
        final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final doc in acc) {
          byId[doc.id] = doc;
        }
        return onReady(byId.values.toList());
      }

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: streams[index],
        builder: (context, snap) {
          if (snap.hasError) {
            // Do not block the whole inbox if one query is denied by rules.
            return step(index + 1, acc);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return step(index + 1, [...acc, ...snap.data!.docs]);
        },
      );
    }

    return step(0, const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStudentDecisionsStream(
    String uid,
  ) {
    return FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', isEqualTo: uid)
        .orderBy('requestedAt', descending: true)
        .limit(80)
        .snapshots();
  }

  Future<Map<String, String>> _loadUserLabels(Set<String> uids) async {
    if (uids.isEmpty) return const <String, String>{};

    final result = <String, String>{};
    const chunkSize = 10;
    final ids = uids.toList();

    for (int index = 0; index < ids.length; index += chunkSize) {
      final chunk = ids.skip(index).take(chunkSize).toList();
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final fullName = (data['fullName'] ?? '').toString().trim();
        final username = (data['username'] ?? '').toString().trim();
        final label = fullName.isNotEmpty ? fullName : username;
        if (label.isNotEmpty) {
          result[doc.id] = label;
        }
      }
    }

    return result;
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) {
      final hh = dateTime.hour.toString().padLeft(2, '0');
      final mm = dateTime.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    if (diff == 1) return 'Yesterday';
    return _formatDate(dateTime);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _normalizeSender(String sender) {
    final value = sender.trim();
    if (value.isEmpty) return 'Secretariat';
    final lower = value.toLowerCase();
    if (lower.contains('secretariat')) return 'Secretariat';
    if (lower.contains('dirigin') || lower.contains('prof') ||
        lower.contains('teacher') || lower.contains('homeroom')) {
      return 'Homeroom teacher';
    }
    if (lower.contains('parinte') || lower.contains('parent')) return 'Parent';
    return value;
  }

  void _goBack(BuildContext context) {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final uid = (AppSession.uid ?? '').trim();
    if (uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('Invalid session.')));
    }

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PageBlueHeader(
              title: 'Messages',
              subtitle: widget.role == UnifiedInboxRole.parent
                  ? "Children's school announcements"
                  : 'Activities, requests & announcements',
              onBack: () => _goBack(context),
            ),
            if (widget.onCreatePost != null) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _CreatePostButton(onTap: widget.onCreatePost!),
              ),
            ],
            const SizedBox(height: 12),
            _FilterPills(
              selected: _filter,
              onSelect: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                child: (_loadingChildren || _loadingTeacherClass)
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(uid),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String uid) {
    final secretariatStreams = _buildSecretariatStreams(uid);

    return _buildMergedStream(secretariatStreams, (secretariatDocs) {
      final secretariatItems = _mapSecretariatItems(secretariatDocs)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (widget.role == UnifiedInboxRole.parent) {
        final decisionStreams = _buildParentDecisionStreams(uid);
        return _buildMergedStream(decisionStreams, (decisionDocs) {
          final decisionItems = _mapParentDecisionItems(decisionDocs);
          final allItems = <_UnifiedMessageItem>[
            ...decisionItems,
            ...secretariatItems,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return _buildItemsList(allItems);
        });
      }

      if (widget.role == UnifiedInboxRole.teacher) {
        final teacherStream = _buildTeacherDecisionsStream();
        if (teacherStream == null) {
          return _buildItemsList(secretariatItems);
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: teacherStream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final decisionDocs =
                snap.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final studentUids = decisionDocs
                .map((d) => (d.data()['studentUid'] ?? '').toString().trim())
                .where((s) => s.isNotEmpty)
                .toSet();
            return FutureBuilder<Map<String, String>>(
              future: _loadUserLabels(studentUids),
              builder: (context, namesSnap) {
                final names = namesSnap.data ?? const <String, String>{};
                final decisionItems = _mapTeacherDecisionItems(
                  decisionDocs,
                  names,
                );
                final allItems = <_UnifiedMessageItem>[
                  ...decisionItems,
                  ...secretariatItems,
                ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return _buildItemsList(allItems);
              },
            );
          },
        );
      }

      if (widget.role != UnifiedInboxRole.student) {
        return _buildItemsList(secretariatItems);
      }

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildStudentDecisionsStream(uid),
        builder: (context, leaveSnap) {
          if (leaveSnap.hasError) {
            return Center(child: Text('Error: ${leaveSnap.error}'));
          }

          final decisionDocs =
              leaveSnap.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final reviewerUids = decisionDocs
              .map(
                (doc) => (doc.data()['reviewedByUid'] ?? '').toString().trim(),
              )
              .where((reviewerUid) => reviewerUid.isNotEmpty)
              .toSet();

          return FutureBuilder<Map<String, String>>(
            future: _loadUserLabels(reviewerUids),
            builder: (context, usersSnap) {
              final usernames = usersSnap.data ?? const <String, String>{};
              final decisionItems = _mapStudentDecisionItems(
                decisionDocs,
                usernames,
              );
              final allItems = <_UnifiedMessageItem>[
                ...decisionItems,
                ...secretariatItems,
              ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return _buildItemsList(allItems);
            },
          );
        },
      );
    });
  }

  List<_UnifiedMessageItem> _mapSecretariatItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      final title = (data['title'] ?? 'Office message').toString().trim();
      final sender = _normalizeSender(
        (data['senderName'] ?? 'Secretariat').toString(),
      );
      final message = (data['message'] ?? '').toString().trim();
      final createdAt =
          ((data['createdAt'] as Timestamp?)?.toDate() ??
              (data['reviewedAt'] as Timestamp?)?.toDate() ??
              (data['requestedAt'] as Timestamp?)?.toDate()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final categoryKey = (data['category'] ?? '').toString().trim();
      final category = switch (categoryKey) {
        'competition' => _MessageCategory.competition,
        'camp' => _MessageCategory.camp,
        'volunteer' => _MessageCategory.volunteer,
        _ => _MessageCategory.announcements,
      };

      return _UnifiedMessageItem(
        kind: _MessageKind.system,
        state: _MessageState.system,
        category: category,
        title: title.isEmpty ? 'Office message' : title,
        sender: sender,
        message: message,
        createdAt: createdAt,
      );
    }).toList();
  }

  List<_UnifiedMessageItem> _mapParentDecisionItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().trim();
          final source = (data['source'] ?? '').toString().trim();
          final targetRole = (data['targetRole'] ?? '').toString().trim();
          return source != 'secretariat' &&
              targetRole == 'parent' &&
              (status == 'pending' ||
                  status == 'approved' ||
                  status == 'rejected');
        })
        .map((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().trim();
          final studentUid = (data['studentUid'] ?? '').toString().trim();
          final studentName = (data['studentName'] ?? '').toString().trim();
          final resolvedStudentName = studentName.isNotEmpty
              ? studentName
              : (_childNames[studentUid] ?? 'Student');

          final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
          final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
          final when =
              reviewedAt ??
              requestedAt ??
              DateTime.fromMillisecondsSinceEpoch(0);

          final state = status == 'approved'
              ? _MessageState.approved
              : (status == 'rejected'
                    ? _MessageState.rejected
                    : _MessageState.pending);

          return _UnifiedMessageItem(
            kind: _MessageKind.decision,
            state: state,
            category: _MessageCategory.requests,
            title: state == _MessageState.pending
                ? 'New request - $resolvedStudentName'
                : '${state == _MessageState.approved ? 'Request approved' : 'Request rejected'} - $resolvedStudentName',
            sender: state == _MessageState.pending
                ? 'Awaiting parent approval'
                : _normalizeSender(
                    (data['reviewedByName'] ?? 'Parent').toString(),
                  ),
            message: (data['message'] ?? '').toString().trim(),
            createdAt: when,
            dateLabel: (data['dateText'] ?? '').toString().trim(),
            timeLabel: (data['timeText'] ?? '').toString().trim(),
          );
        })
        .toList();
  }

  List<_UnifiedMessageItem> _mapStudentDecisionItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, String> usernamesByUid,
  ) {
    return docs
        .where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().trim();
          final source = (data['source'] ?? '').toString().trim();
          return source != 'secretariat' &&
              (status == 'approved' || status == 'rejected');
        })
        .map((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().trim();
          final reviewedByUid = (data['reviewedByUid'] ?? '').toString().trim();
          final sender =
              usernamesByUid[reviewedByUid] ??
              (data['reviewedByName'] ?? 'Homeroom teacher').toString();
          final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
          final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
          final when =
              reviewedAt ??
              requestedAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final approved = status == 'approved';

          return _UnifiedMessageItem(
            kind: _MessageKind.decision,
            state: approved ? _MessageState.approved : _MessageState.rejected,
            category: _MessageCategory.requests,
            title: approved ? 'Request approved' : 'Request rejected',
            sender: _normalizeSender(sender),
            message: (data['message'] ?? '').toString().trim(),
            createdAt: when,
            dateLabel: (data['dateText'] ?? '').toString().trim(),
            timeLabel: (data['timeText'] ?? '').toString().trim(),
          );
        })
        .toList();
  }

  List<_UnifiedMessageItem> _mapTeacherDecisionItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, String> studentNamesByUid,
  ) {
    return docs
        .where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().trim();
          final source = (data['source'] ?? '').toString().trim();
          return source != 'secretariat' &&
              (status == 'pending' ||
                  status == 'approved' ||
                  status == 'rejected');
        })
        .map((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().trim();
          final studentUid = (data['studentUid'] ?? '').toString().trim();
          final studentName = (data['studentName'] ?? '').toString().trim();
          final resolved = studentName.isNotEmpty
              ? studentName
              : (studentNamesByUid[studentUid] ?? 'Student');

          final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
          final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
          final when =
              reviewedAt ??
              requestedAt ??
              DateTime.fromMillisecondsSinceEpoch(0);

          final state = status == 'approved'
              ? _MessageState.approved
              : (status == 'rejected'
                    ? _MessageState.rejected
                    : _MessageState.pending);

          return _UnifiedMessageItem(
            kind: _MessageKind.decision,
            state: state,
            category: _MessageCategory.requests,
            title: state == _MessageState.pending
                ? 'Pending request - $resolved'
                : '${state == _MessageState.approved ? 'Request approved' : 'Request rejected'} - $resolved',
            sender: state == _MessageState.pending
                ? 'Awaiting your decision'
                : _normalizeSender(
                    (data['reviewedByName'] ?? 'Homeroom teacher').toString(),
                  ),
            message: (data['message'] ?? '').toString().trim(),
            createdAt: when,
            dateLabel: (data['dateText'] ?? '').toString().trim(),
            timeLabel: (data['timeText'] ?? '').toString().trim(),
          );
        })
        .toList();
  }

  Widget _buildItemsList(List<_UnifiedMessageItem> items) {
    final filtered = _filter == null
        ? items
        : items.where((it) => it.category == _filter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              _filter == null
                  ? 'No messages yet.'
                  : 'No messages in this category.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextMuted, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 2, bottom: 24),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _MessageCard(
          item: filtered[index],
          timeAgoLabel: _timeAgo(filtered[index].createdAt),
          fallbackDate: _formatDate(filtered[index].createdAt),
        );
      },
    );
  }
}

class _FilterPills extends StatelessWidget {
  final _MessageCategory? selected;
  final ValueChanged<_MessageCategory?> onSelect;

  const _FilterPills({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final pills = <(_MessageCategory?, String)>[
      (null, 'All'),
      (_MessageCategory.requests, 'Requests'),
      (_MessageCategory.announcements, 'Announcements'),
      (_MessageCategory.volunteer, 'Volunteering'),
      (_MessageCategory.competition, 'Competitions'),
      (_MessageCategory.camp, 'Camps'),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: pills.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (cat, label) = pills[i];
          final active = selected == cat;
          return _Pill(
            label: label,
            active: active,
            onTap: () => onSelect(cat),
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: active ? _kPrimary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? _kPrimary : const Color(0xFFE0E3F0),
              width: 1,
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x352848B0),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : _kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final _UnifiedMessageItem item;
  final String timeAgoLabel;
  final String fallbackDate;

  const _MessageCard({
    required this.item,
    required this.timeAgoLabel,
    required this.fallbackDate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = _cardScheme(item.state);
    final isSystem = item.kind == _MessageKind.system;

    final titleParts = item.title.split(' - ');
    final mainTitle = titleParts.first;
    final nameSubtitle = titleParts.length > 1
        ? titleParts.skip(1).join(' - ')
        : null;

    // Compact date+time for leave requests
    String? metaText;
    if (!isSystem) {
      final datePart = item.dateLabel?.isNotEmpty == true
          ? item.dateLabel!
          : fallbackDate;
      final timePart = item.timeLabel?.isNotEmpty == true
          ? item.timeLabel
          : null;
      metaText = timePart != null ? '$datePart, $timePart' : datePart;
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border(
          left: BorderSide(color: scheme.accent, width: 4),
        ),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mainTitle,
                            style: const TextStyle(
                              color: _kTextPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                          ),
                          if (nameSubtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              nameSubtitle,
                              style: const TextStyle(
                                color: _kTextMid,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgoLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _kTextMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (metaText != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAF2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      metaText,
                      style: const TextStyle(
                        color: _kPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  item.message.isEmpty ? 'No content.' : item.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kTextMid,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                _StatusPill(
                  label: scheme.badgeLabel,
                  icon: scheme.badgeIcon,
                  bg: scheme.pillBg,
                  fg: scheme.pillFg,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color bg;
  final Color fg;

  const _StatusPill({
    required this.label,
    this.icon,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: 15),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnifiedMessageItem {
  final _MessageKind kind;
  final _MessageState state;
  final _MessageCategory category;
  final String title;
  final String sender;
  final String message;
  final DateTime createdAt;
  final String? dateLabel;
  final String? timeLabel;

  const _UnifiedMessageItem({
    required this.kind,
    required this.state,
    required this.category,
    required this.title,
    required this.sender,
    required this.message,
    required this.createdAt,
    this.dateLabel,
    this.timeLabel,
  });
}

class _CardScheme {
  final String badgeLabel;
  final IconData badgeIcon;
  final Color accent;
  final Color pillBg;
  final Color pillFg;

  const _CardScheme({
    required this.badgeLabel,
    required this.badgeIcon,
    required this.accent,
    required this.pillBg,
    required this.pillFg,
  });
}

_CardScheme _cardScheme(_MessageState state) {
  switch (state) {
    case _MessageState.pending:
      return const _CardScheme(
        badgeLabel: 'Pending',
        badgeIcon: Icons.watch_later_rounded,
        accent: Color(0xFFB0B5CC),
        pillBg: Color(0xFFE8EAF2),
        pillFg: Color(0xFF3A4A80),
      );
    case _MessageState.approved:
      return const _CardScheme(
        badgeLabel: 'Approved',
        badgeIcon: Icons.check_circle_rounded,
        accent: _kPrimary,
        pillBg: Color(0xFFE8EAF2),
        pillFg: _kPrimary,
      );
    case _MessageState.rejected:
      return const _CardScheme(
        badgeLabel: 'Rejected',
        badgeIcon: Icons.cancel_rounded,
        accent: Color(0xFFB03040),
        pillBg: Color(0xFFF8E0E5),
        pillFg: Color(0xFFB03040),
      );
    case _MessageState.system:
      return const _CardScheme(
        badgeLabel: 'System',
        badgeIcon: Icons.campaign_rounded,
        accent: _kPrimary,
        pillBg: Color(0xFFE8EAF2),
        pillFg: _kPrimary,
      );
  }
}

class _CreatePostButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreatePostButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kPrimary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Create new post',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
