import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';
import '../student/widgets/school_decor.dart';
import 'link_utils.dart';
import 'linked_children_resolver.dart';
import 'storage_image.dart';

const _kPrimary = Color(0xFF2848B0);
const _kPageBg = Color(0xFFF2F4F8);
const _kTextPrimary = Color(0xFF1A2050);
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

    ids.addAll(await resolveLinkedChildIds(
      parentUid,
      tag: 'unified_messages_page',
    ));

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

  String _reviewerLabel(Map<String, dynamic> data, {String? fallback}) {
    final name = (data['reviewedByName'] ?? '').toString().trim();
    final reviewedByUid = (data['reviewedByUid'] ?? '').toString().trim();
    final teacherUid = (data['targetTeacherUid'] ?? '').toString().trim();
    final parentUid = (data['targetParentUid'] ?? '').toString().trim();
    String role = '';
    if (reviewedByUid.isNotEmpty) {
      if (reviewedByUid == teacherUid) {
        role = 'teacher';
      } else if (reviewedByUid == parentUid) {
        role = 'parent';
      }
    }
    if (role.isEmpty) {
      // Legacy single-recipient docs.
      role = (data['targetRole'] ?? '').toString().trim().toLowerCase();
    }
    final roleLabel = role == 'teacher'
        ? 'Homeroom teacher'
        : role == 'parent'
            ? 'Parent'
            : '';
    if (name.isEmpty && roleLabel.isEmpty) {
      return fallback ?? 'Reviewer';
    }
    if (name.isEmpty) return roleLabel;
    if (roleLabel.isEmpty) return _normalizeSender(name);
    return '$name ($roleLabel)';
  }

  void _openDetail(BuildContext context, _UnifiedMessageItem item) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _UnifiedDetailDialog(item: item),
      transitionBuilder: (_, anim, _, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
    );
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
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Could not load messages.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Could not load messages.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
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
        imageUrl: (data['imageUrl'] ?? '').toString().trim(),
        raw: data,
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
          final targets = (data['targets'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final addressedToParent = (targets != null && targets.isNotEmpty)
              ? targets.contains('parent')
              : (data['targetRole'] ?? '').toString().trim() == 'parent';
          return source != 'secretariat' &&
              addressedToParent &&
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
                : _reviewerLabel(data, fallback: 'Parent'),
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
          // Prefer the resolved username from users collection if available,
          // otherwise fall back to whatever was stored in reviewedByName.
          final resolvedName = usernamesByUid[reviewedByUid];
          final dataForLabel = resolvedName != null && resolvedName.isNotEmpty
              ? {...data, 'reviewedByName': resolvedName}
              : data;
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
            sender: _reviewerLabel(dataForLabel, fallback: 'Reviewer'),
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
          final targets = (data['targets'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final bool addressedToTeacher;
          if (targets != null && targets.isNotEmpty) {
            addressedToTeacher = targets.contains('teacher');
          } else {
            final legacyRole = (data['targetRole'] ?? '').toString().trim();
            addressedToTeacher =
                legacyRole.isEmpty || legacyRole == 'teacher';
          }
          return source != 'secretariat' &&
              addressedToTeacher &&
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
                : _reviewerLabel(data, fallback: 'Homeroom teacher'),
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
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
            decoration: BoxDecoration(
              color: cs.surface,
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
        final it = filtered[index];
        return _MessageCard(
          item: it,
          timeAgoLabel: _timeAgo(it.createdAt),
          fallbackDate: _formatDate(it.createdAt),
          onTap: () => _openDetail(context, it),
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
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: active ? _kPrimary : cs.surface,
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
  final VoidCallback? onTap;

  const _MessageCard({
    required this.item,
    required this.timeAgoLabel,
    required this.fallbackDate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scheme = _cardScheme(item.state);
    final isSystem = item.kind == _MessageKind.system;
    final categoryStyle = _categoryStyleFor(item.category);

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

    // Accent bar uses the category color for system messages,
    // or the request-state color for parent decisions.
    final accent = isSystem ? categoryStyle.fg : scheme.accent;

    return Container(
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: WhiteCardSparklesPainter(
                              primary: accent,
                              variant: item.title.hashCode % 5,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            18,
                            20,
                            item.imageUrl.isEmpty ? 18 : 12,
                            20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mainTitle,
                                          style: const TextStyle(
                                            color: _kTextPrimary,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.3,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: 36,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: kPencilYellow,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        if (nameSubtitle != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            nameSubtitle,
                                            style: const TextStyle(
                                              color: _kTextMuted,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (metaText != null) ...[
                                const SizedBox(height: 10),
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
                              const SizedBox(height: 10),
                              Text(
                                item.message.isEmpty
                                    ? 'No content.'
                                    : item.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _kTextMuted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _SenderBadge(
                                icon: isSystem
                                    ? Icons.mark_chat_read_rounded
                                    : scheme.badgeIcon,
                                label: isSystem
                                    ? (item.sender.isEmpty
                                        ? 'Secretariat'
                                        : item.sender)
                                    : scheme.badgeLabel,
                                bg: isSystem
                                    ? categoryStyle.bg
                                    : scheme.pillBg,
                                fg: isSystem
                                    ? categoryStyle.fg
                                    : scheme.pillFg,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: StorageImage(
                            url: item.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (_) => Container(
                              color: categoryStyle.bg,
                            ),
                            errorBuilder: (_, _) => Container(
                              color: categoryStyle.bg,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: categoryStyle.fg,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryStyle {
  final Color bg;
  final Color fg;
  const _CategoryStyle(this.bg, this.fg);
}

_CategoryStyle _categoryStyleFor(_MessageCategory cat) {
  switch (cat) {
    case _MessageCategory.competition:
      return const _CategoryStyle(Color(0xFFFFF3D6), Color(0xFFCC8A1A));
    case _MessageCategory.camp:
      return const _CategoryStyle(Color(0xFFD9EFD8), Color(0xFF3F8B3A));
    case _MessageCategory.volunteer:
      return const _CategoryStyle(Color(0xFFEDE0F4), Color(0xFF7B1FA2));
    case _MessageCategory.announcements:
    case _MessageCategory.requests:
      return const _CategoryStyle(Color(0xFFDDE0EC), Color(0xFF3460CC));
  }
}

class _SenderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  const _SenderBadge({
    required this.icon,
    required this.label,
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
          Icon(icon, color: fg, size: 15),
          const SizedBox(width: 6),
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
  final String imageUrl;
  final Map<String, dynamic> raw;

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
    this.imageUrl = '',
    this.raw = const <String, dynamic>{},
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

// Detail dialog (shown on tap)

class _UnifiedDetailDialog extends StatelessWidget {
  final _UnifiedMessageItem item;
  const _UnifiedDetailDialog({required this.item});

  IconData _categoryIcon() {
    switch (item.category) {
      case _MessageCategory.competition:
        return Icons.emoji_events_rounded;
      case _MessageCategory.camp:
        return Icons.forest_rounded;
      case _MessageCategory.volunteer:
        return Icons.volunteer_activism_rounded;
      case _MessageCategory.requests:
        return Icons.description_rounded;
      case _MessageCategory.announcements:
        return Icons.campaign_rounded;
    }
  }

  String _categoryText() {
    switch (item.category) {
      case _MessageCategory.competition:
        return 'COMPETITION';
      case _MessageCategory.camp:
        return 'CAMP';
      case _MessageCategory.volunteer:
        return 'VOLUNTEERING';
      case _MessageCategory.requests:
        return 'REQUEST';
      case _MessageCategory.announcements:
        return 'ANNOUNCEMENT';
    }
  }

  String _formatLongDate(DateTime d) {
    const months = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _categoryStyleFor(item.category).fg;
    final raw = item.raw;
    final eventDate = (raw['eventDate'] as Timestamp?)?.toDate();
    final eventEndDate = (raw['eventEndDate'] as Timestamp?)?.toDate();
    final location = (raw['location'] ?? '').toString().trim();
    final link = (raw['link'] ?? '').toString().trim();
    final audienceLabel = (raw['audienceLabel'] ?? '').toString().trim();

    final size = MediaQuery.sizeOf(context);
    final maxW = size.width < 460 ? size.width - 32 : 420.0;
    final maxH = size.height * 0.82;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 40,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DetailHeader(
                      accent: accent,
                      icon: _categoryIcon(),
                      categoryText: _categoryText(),
                      title: item.title,
                      sender: item.sender,
                      onClose: () => Navigator.of(context).maybePop(),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.imageUrl.isNotEmpty) ...[
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 360,
                                    ),
                                    child: StorageImage(
                                      url: item.imageUrl,
                                      fit: BoxFit.scaleDown,
                                      loadingBuilder: (_) => Container(
                                        width: 240,
                                        height: 160,
                                        color: cs.outlineVariant,
                                        alignment: Alignment.center,
                                        child: const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                          ),
                                        ),
                                      ),
                                      errorBuilder: (_, _) => Container(
                                        width: 240,
                                        height: 140,
                                        color: cs.outlineVariant,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_rounded,
                                          color: _kTextMuted,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (eventDate != null || location.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (eventDate != null)
                                    _DetailChip(
                                      icon: Icons.calendar_month_rounded,
                                      text: eventEndDate != null
                                          ? '${_formatLongDate(eventDate)} → ${_formatLongDate(eventEndDate)}'
                                          : _formatLongDate(eventDate),
                                    ),
                                  if (location.isNotEmpty)
                                    _DetailChip(
                                      icon: Icons.place_outlined,
                                      text: location,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                            ],
                            Text(
                              item.message.isEmpty
                                  ? 'No content.'
                                  : item.message,
                              style: const TextStyle(
                                color: _kTextPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                              ),
                            ),
                            if (link.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Material(
                                color: accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () =>
                                      launchExternalUrl(context, link),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.link_rounded,
                                          color: accent,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            link,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: accent,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: accent,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.open_in_new_rounded,
                                          color: accent,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (audienceLabel.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.groups_rounded,
                                    color: _kTextMuted,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    audienceLabel,
                                    style: const TextStyle(
                                      color: _kTextMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String categoryText;
  final String title;
  final String sender;
  final VoidCallback onClose;

  const _DetailHeader({
    required this.accent,
    required this.icon,
    required this.categoryText,
    required this.title,
    required this.sender,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, _lighten(accent, 0.12)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    categoryText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (sender.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sender,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 22,
            ),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.outlineVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _kPrimary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: _kPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final l = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(l).toColor();
}
