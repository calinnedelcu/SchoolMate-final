import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firster/core/session.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF2848B0);
const _surfaceLowest = Color(0xFFFFFFFF);
const _surfaceContainerLow = Color(0xFFE8EAF2);
const _surfaceContainerHigh = Color(0xFFDDE0EC);
const _onSurface = Color(0xFF1A2050);
const _outline = Color(0xFF7A7E9A);
const _outlineVariant = Color(0xFFC0C4D8);

Future<void> showScheduleSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ScheduleBottomSheet(),
  );
}

class _ScheduleBottomSheet extends StatelessWidget {
  const _ScheduleBottomSheet();

  @override
  Widget build(BuildContext context) {
    final classId = AppSession.classId ?? '';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: _outlineVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Weekly Schedule',
            style: TextStyle(
              color: _onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your class timetable for the week.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _outline.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          if (classId.isEmpty)
            _emptyState('No class assigned.')
          else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('classes')
                  .doc(classId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(color: _primary),
                  );
                }

                final classData = snapshot.data?.data() ?? {};
                final rows = _buildScheduleRows(classData);

                if (rows.isEmpty) {
                  return _emptyState('No schedule defined for your class.');
                }

                return Column(
                  children: [
                    for (int i = 0; i < rows.length; i++) ...[
                      _ScheduleRowTile(
                        dayName: rows[i].dayName,
                        intervalText: rows[i].intervalText,
                        isToday: rows[i].dayNumber == DateTime.now().weekday,
                      ),
                      if (i < rows.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: _onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _emptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _outline,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ScheduleRowTile extends StatelessWidget {
  final String dayName;
  final String intervalText;
  final bool isToday;

  const _ScheduleRowTile({
    required this.dayName,
    required this.intervalText,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isToday ? _primary : _surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            dayName,
            style: TextStyle(
              color: isToday ? Colors.white : _onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            intervalText,
            style: TextStyle(
              color: isToday ? Colors.white : _onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRowData {
  final String dayName;
  final String intervalText;
  final int dayNumber;
  const _ScheduleRowData({
    required this.dayName,
    required this.intervalText,
    required this.dayNumber,
  });
}

List<_ScheduleRowData> _buildScheduleRows(Map<String, dynamic> classData) {
  final result = <_ScheduleRowData>[];
  final schedule = classData['schedule'];

  if (schedule is Map) {
    const dayMap = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
    };

    final dayKeys = <int>[];
    for (final key in schedule.keys) {
      final day = int.tryParse(key.toString());
      if (day != null && day >= 1 && day <= 5) dayKeys.add(day);
    }
    dayKeys.sort();

    for (final day in dayKeys) {
      final row = schedule['$day'];
      if (row is Map) {
        final start = (row['start'] ?? '').toString().trim();
        final end = (row['end'] ?? '').toString().trim();
        if (start.isNotEmpty && end.isNotEmpty) {
          result.add(_ScheduleRowData(
            dayName: dayMap[day] ?? 'Day $day',
            intervalText: '$start - $end',
            dayNumber: day,
          ));
        }
      }
    }
  }

  if (result.isNotEmpty) return result;

  final oldStart = (classData['noExitStart'] ?? '').toString().trim();
  final oldEnd = (classData['noExitEnd'] ?? '').toString().trim();
  final oldDays = classData['noExitDays'];

  if (oldStart.isEmpty || oldEnd.isEmpty || oldDays is! List) return const [];

  const dayMap = {1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday'};
  final normalizedDays = oldDays.whereType<int>().toList()..sort();
  return normalizedDays
      .where((day) => day >= 1 && day <= 5)
      .map((day) => _ScheduleRowData(
            dayName: dayMap[day] ?? 'Day $day',
            intervalText: '$oldStart - $oldEnd',
            dayNumber: day,
          ))
      .toList();
}
