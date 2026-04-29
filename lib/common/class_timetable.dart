import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../student/widgets/timetable.dart';

const _primary = Color(0xFF2848B0);
const _surfaceLowest = Color(0xFFFFFFFF);
const _outlineVariant = Color(0xFFC0C4D8);
const _outline = Color(0xFF7A7E9A);
const _onSurface = Color(0xFF1A2050);

/// Renders the timetable for [classId] by streaming the
/// `timetables/{classId}` document together with the `subjects` and
/// teacher `users` collections, and feeding the result into [TimetableGrid].
///
/// Same logic the student schedule page uses — extracted so the parent
/// schedule page and the teacher schedule sheet stay in sync.
class ClassTimetable extends StatelessWidget {
  final String classId;

  const ClassTimetable({super.key, required this.classId});

  static int _toMin(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String _fromMin(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  static String _shortTeacher(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return full;
    return '${parts.first} ${parts.last[0]}.';
  }

  static String _abbreviateSubject(String name) {
    final trimmed = name.trim();
    if (trimmed.length <= 5) return trimmed;
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length == 1) {
      final w = words.first;
      return '${w[0].toUpperCase()}${w.substring(1, 4).toLowerCase()}';
    }
    final last = words.last;
    final leadInitials = words
        .sublist(0, words.length - 1)
        .map((w) => w[0].toUpperCase())
        .join();
    final lastPart = last.length > 3 ? last.substring(0, 3) : last;
    return '$leadInitials${lastPart[0].toUpperCase()}${lastPart.substring(1).toLowerCase()}';
  }

  ({List<TimetableSlot> slots, List<List<TimetableLesson?>> schedule})
  _build({
    required Map<String, dynamic> timetableData,
    required Map<String, String> subjectNames,
    required Map<String, String> teacherNames,
    required bool teachersLoaded,
  }) {
    final startTime = timetableData['startTime'] as String? ?? '08:00';
    final rawSlots =
        (timetableData['slots'] as List?)?.cast<dynamic>() ?? const [];
    final days =
        (timetableData['days'] as Map?)?.cast<String, dynamic>() ?? const {};

    final slotTimes = <TimetableSlot>[];
    final lessonIndices = <int>[];
    int cur = _toMin(startTime);
    int li = 0;
    for (final raw in rawSlots) {
      final m = (raw as Map).cast<String, dynamic>();
      final type = m['type'] as String? ?? 'lesson';
      final duration = (m['duration'] as num?)?.toInt() ?? 50;
      final end = cur + duration;
      if (type == 'lesson') {
        slotTimes.add(TimetableSlot(_fromMin(cur), _fromMin(end)));
        lessonIndices.add(li);
        li++;
      }
      cur = end;
    }

    final schedule = List<List<TimetableLesson?>>.generate(5, (di) {
      final dayMap = (days['${di + 1}'] as Map?)?.cast<String, dynamic>();
      return List<TimetableLesson?>.generate(slotTimes.length, (i) {
        final lessonIdx = lessonIndices[i];
        final entry = dayMap?['$lessonIdx'];
        if (entry is Map) {
          final sid = (entry['subjectId'] ?? '').toString();
          final tu = (entry['teacherUsername'] ?? '').toString();
          if (teachersLoaded && tu.isNotEmpty && !teacherNames.containsKey(tu)) {
            return null;
          }
          final subject = subjectNames[sid] ?? sid;
          final teacher = teacherNames[tu] ?? tu;
          if (subject.isEmpty && teacher.isEmpty) return null;
          return TimetableLesson(
            subject,
            teacher,
            shortLabel: _abbreviateSubject(subject),
          );
        }
        return null;
      });
    });

    return (slots: slotTimes, schedule: schedule);
  }

  @override
  Widget build(BuildContext context) {
    if (classId.trim().isEmpty) {
      return const _TimetableEmptyState(
        message: 'No class assigned.',
      );
    }
    final db = FirebaseFirestore.instance;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('timetables').doc(classId).snapshots(),
      builder: (context, ttSnap) {
        if (ttSnap.connectionState == ConnectionState.waiting &&
            !ttSnap.hasData) {
          return const _TimetableLoadingState();
        }
        if (ttSnap.data?.exists != true) {
          return const _TimetableEmptyState(
            message: 'No timetable has been published yet.',
          );
        }
        final ttData = ttSnap.data!.data() ?? const <String, dynamic>{};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('subjects').snapshots(),
          builder: (context, subSnap) {
            final subjectNames = <String, String>{
              for (final d in subSnap.data?.docs ?? const [])
                d.id: (d.data()['name'] as String?)?.trim() ?? d.id,
            };

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection('users')
                  .where('role', isEqualTo: 'teacher')
                  .snapshots(),
              builder: (context, teachSnap) {
                final teacherNames = <String, String>{};
                for (final d in teachSnap.data?.docs ?? const []) {
                  final m = d.data();
                  final username = (m['username'] as String?) ?? d.id;
                  final fullName = (m['fullName'] as String?)?.trim() ?? '';
                  teacherNames[username] = _shortTeacher(
                    fullName.isEmpty ? username : fullName,
                  );
                }

                final built = _build(
                  timetableData: ttData,
                  subjectNames: subjectNames,
                  teacherNames: teacherNames,
                  teachersLoaded: teachSnap.hasData,
                );

                if (built.slots.isEmpty) {
                  return const _TimetableEmptyState(
                    message: 'Timetable structure is empty.',
                  );
                }

                return TimetableGrid(
                  slots: built.slots,
                  schedule: built.schedule,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TimetableLoadingState extends StatelessWidget {
  const _TimetableLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.4)),
      ),
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: _primary),
      ),
    );
  }
}

class _TimetableEmptyState extends StatelessWidget {
  final String message;
  const _TimetableEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            color: _outline.withValues(alpha: 0.7),
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
