import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../common/class_timetable.dart';
import '../core/session.dart';
import '../student/widgets/school_decor.dart';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _surfaceLowest = Color(0xFFFFFFFF);
const _outlineVariant = Color(0xFFC0C4D8);
const _outline = Color(0xFF7A7E9A);
const _onSurface = Color(0xFF1A2050);
const _labelColor = Color(0xFF7A7E9A);

class ParentSchedulePage extends StatefulWidget {
  const ParentSchedulePage({super.key});

  @override
  State<ParentSchedulePage> createState() => _ParentSchedulePageState();
}

class _ChildEntry {
  final String uid;
  final String fullName;
  final String classId;

  const _ChildEntry({
    required this.uid,
    required this.fullName,
    required this.classId,
  });
}

class _ParentSchedulePageState extends State<ParentSchedulePage> {
  String? _selectedChildUid;

  // Cache the children future so it is not recreated on every StreamBuilder
  // rebuild (which would reset FutureBuilder back to a "loading / no data"
  // state and flash the empty placeholder).
  String? _cachedChildrenKey;
  Future<List<_ChildEntry>>? _cachedChildrenFuture;

  Future<List<_ChildEntry>> _getOrCreateChildrenFuture(List<String> uids) {
    final key = uids.join(',');
    if (key != _cachedChildrenKey || _cachedChildrenFuture == null) {
      _cachedChildrenKey = key;
      final future = _loadChildren(uids);
      _cachedChildrenFuture = future;
      // Invalidate the cache slot if this attempt fails so a later rebuild
      // can retry the load instead of being pinned to a rejected future.
      unawaited(
        future.catchError((Object _) {
          if (_cachedChildrenFuture == future) {
            _cachedChildrenKey = null;
            _cachedChildrenFuture = null;
          }
          return const <_ChildEntry>[];
        }),
      );
    }
    return _cachedChildrenFuture!;
  }

  String _academicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 9 ? now.year : now.year - 1;
    final endYear = startYear + 1;
    return '$startYear–${endYear.toString().substring(2)}';
  }

  ({DateTime monday, DateTime friday, int weekNumber}) _weekInfo() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final friday = monday.add(const Duration(days: 4));
    final firstJan = DateTime(monday.year, 1, 1);
    final daysOffset = monday.difference(firstJan).inDays;
    final weekNumber = ((daysOffset + firstJan.weekday) / 7).ceil();
    return (monday: monday, friday: friday, weekNumber: weekNumber);
  }

  String _formatDay(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  List<String> _extractChildUids(Map<String, dynamic> parentData) {
    final raw = (parentData['children'] as List?) ?? const [];
    final ids = <String>{};
    for (final value in raw) {
      if (value is String) {
        final id = value.trim();
        if (id.isNotEmpty) ids.add(id);
      } else if (value is Map<String, dynamic>) {
        final id = ((value['uid'] ?? value['studentUid'] ?? value['id']) ?? '')
            .toString()
            .trim();
        if (id.isNotEmpty) ids.add(id);
      }
    }
    final list = ids.toList()..sort();
    return list;
  }

  Future<List<_ChildEntry>> _loadChildren(List<String> uids) async {
    if (uids.isEmpty) return const [];
    final users = FirebaseFirestore.instance.collection('users');
    final docs = await Future.wait(
      uids.map(
        (u) => users.doc(u).collection('publicProfile').doc('main').get(),
      ),
    );
    final out = <_ChildEntry>[];
    for (var i = 0; i < docs.length; i++) {
      final d = docs[i];
      final uid = uids[i];
      final data = d.data() ?? const <String, dynamic>{};
      out.add(
        _ChildEntry(
          uid: uid,
          fullName: (data['fullName'] ?? data['username'] ?? '')
              .toString()
              .trim(),
          classId: (data['classId'] ?? '').toString().trim(),
        ),
      );
    }
    out.sort((a, b) => a.fullName.compareTo(b.fullName));
    return out;
  }

  Future<void> _pickChild(BuildContext context, List<_ChildEntry> children) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surfaceLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: _outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'Choose child',
                    style: TextStyle(
                      color: _onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final c in children)
                  _ChildPickerTile(
                    name: c.fullName.isEmpty ? c.uid : c.fullName,
                    classId: c.classId,
                    selected: c.uid == _selectedChildUid,
                    onTap: () => Navigator.pop(ctx, c.uid),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && picked != _selectedChildUid) {
      setState(() => _selectedChildUid = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentUid = (AppSession.uid ?? '').trim();

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        child: parentUid.isEmpty
            ? const Center(child: Text('Invalid session'))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(parentUid)
                    .snapshots(),
                builder: (context, parentSnap) {
                  if (!parentSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final parentData = parentSnap.data?.data() ?? {};
                  final childUids = _extractChildUids(parentData);

                  return FutureBuilder<List<_ChildEntry>>(
                    future: _getOrCreateChildrenFuture(childUids),
                    builder: (context, childSnap) {
                      final isLoading = childUids.isNotEmpty &&
                          childSnap.connectionState == ConnectionState.waiting;
                      final children = childSnap.data ?? const <_ChildEntry>[];

                      _ChildEntry? selected;
                      if (children.isNotEmpty) {
                        selected = children.firstWhere(
                          (c) => c.uid == _selectedChildUid,
                          orElse: () => children.first,
                        );
                        if (_selectedChildUid != selected.uid) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() => _selectedChildUid = selected!.uid);
                            }
                          });
                        }
                      }

                      return _buildBody(
                        context,
                        children,
                        selected,
                        hasLinkedChildren: childUids.isNotEmpty,
                        isLoading: isLoading,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<_ChildEntry> children,
    _ChildEntry? selected, {
    required bool hasLinkedChildren,
    required bool isLoading,
  }) {
    final week = _weekInfo();
    final isOdd = week.weekNumber.isOdd;

    Stream<DocumentSnapshot<Map<String, dynamic>>>? classStream;
    final classId = selected?.classId ?? '';
    if (classId.isNotEmpty) {
      classStream = FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .snapshots();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: classStream,
      builder: (context, classSnap) {
        final classData = classSnap.data?.data() ?? const <String, dynamic>{};
        final className = (classData['className'] ?? classId).toString().trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScheduleHeader(
              onBack: () => Navigator.of(context).maybePop(),
              className: className.isEmpty ? 'Unknown class' : className,
              academicYear: _academicYear(),
            ),
            Expanded(
              child: children.isEmpty
                  ? Center(
                      child: isLoading
                          ? const CircularProgressIndicator()
                          : Text(
                              hasLinkedChildren
                                  ? 'Could not load children.'
                                  : 'No children linked yet.',
                              style: const TextStyle(
                                color: _labelColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ChildPickerPill(
                            label: selected?.fullName.isNotEmpty == true
                                ? selected!.fullName
                                : 'Select child',
                            subtitle: selected?.classId ?? '',
                            multiple: children.length > 1,
                            onTap: children.length > 1
                                ? () => _pickChild(context, children)
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _WeekSwitcher(
                            rangeText:
                                'Week ${_formatDay(week.monday)} — ${_formatDay(week.friday)}',
                            parityText: isOdd ? 'ODD WEEK' : 'EVEN WEEK',
                          ),
                          const SizedBox(height: 14),
                          ClassTimetable(classId: classId),
                          const SizedBox(height: 14),
                          const _LegendRow(),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  final String className;
  final String academicYear;
  final VoidCallback onBack;

  const _ScheduleHeader({
    required this.className,
    required this.academicYear,
    required this.onBack,
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
          const Positioned.fill(
            child: CustomPaint(painter: HeaderSparklesPainter(variant: 4)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Schedule',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
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
                      const SizedBox(height: 6),
                      Text(
                        'Class $className · $academicYear',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

class _ChildPickerPill extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool multiple;
  final VoidCallback? onTap;

  const _ChildPickerPill({
    required this.label,
    required this.subtitle,
    required this.multiple,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outlineVariant.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Class $subtitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _labelColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (multiple)
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.expand_more_rounded,
                    color: _primary,
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildPickerTile extends StatelessWidget {
  final String name;
  final String classId;
  final bool selected;
  final VoidCallback onTap;

  const _ChildPickerTile({
    required this.name,
    required this.classId,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected
                ? _primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? _primary.withValues(alpha: 0.25)
                  : _outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (classId.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Class $classId',
                        style: const TextStyle(
                          color: _labelColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: _primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  final String rangeText;
  final String parityText;

  const _WeekSwitcher({
    required this.rangeText,
    required this.parityText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            rangeText,
            style: const TextStyle(
              color: _onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            parityText,
            style: const TextStyle(
              color: _outline,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Weekly schedule',
          style: TextStyle(
            color: _onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: _outline,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Tap any cell for lesson details',
            style: TextStyle(
              color: _outline,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
