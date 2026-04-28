import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_mate/core/session.dart';
import 'package:school_mate/student/widgets/school_decor.dart';
import 'package:school_mate/student/widgets/timetable.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _surfaceLowest = Color(0xFFFFFFFF);
const _outlineVariant = Color(0xFFC0C4D8);
const _outline = Color(0xFF7A7E9A);
const _onSurface = Color(0xFF1A2050);

class SchedulePage extends StatefulWidget {
  final VoidCallback? onBackToHome;
  const SchedulePage({super.key, this.onBackToHome});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _classDocStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _timetableDocStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _subjectsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _teachersStream;
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    final classId = AppSession.classId;
    if (classId != null && classId.isNotEmpty) {
      final db = FirebaseFirestore.instance;
      _classDocStream = db.collection('classes').doc(classId).snapshots();
      _timetableDocStream =
          db.collection('timetables').doc(classId).snapshots();
      _subjectsStream = db.collection('subjects').snapshots();
      _teachersStream =
          db.collection('users').where('role', isEqualTo: 'teacher').snapshots();
    }
  }

  static int _toMin(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String _fromMin(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  ({List<TimetableSlot> slots, List<List<TimetableLesson?>> schedule})
      _buildTimetable({
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

  String _shortTeacher(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return full;
    return '${parts.first} ${parts.last[0]}.';
  }

  String _abbreviateSubject(String name) {
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
    final leadInitials =
        words.sublist(0, words.length - 1).map((w) => w[0].toUpperCase()).join();
    final lastPart = last.length > 3 ? last.substring(0, 3) : last;
    return '$leadInitials${lastPart[0].toUpperCase()}${lastPart.substring(1).toLowerCase()}';
  }

  Widget _buildTimetableSection() {
    if (_timetableDocStream == null) {
      return const _TimetableEmptyState(
        message: 'No class assigned to your account.',
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _timetableDocStream,
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
          stream: _subjectsStream,
          builder: (context, subSnap) {
            final subjectNames = <String, String>{
              for (final d in subSnap.data?.docs ?? const [])
                d.id: (d.data()['name'] as String?)?.trim() ?? d.id,
            };

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _teachersStream,
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

                final built = _buildTimetable(
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

  ({DateTime monday, DateTime friday, int weekNumber}) _weekInfo() {
    final now = DateTime.now().add(Duration(days: 7 * _weekOffset));
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final friday = monday.add(const Duration(days: 4));
    final firstJan = DateTime(monday.year, 1, 1);
    final daysOffset = monday.difference(firstJan).inDays;
    final weekNumber = ((daysOffset + firstJan.weekday) / 7).ceil();
    return (monday: monday, friday: friday, weekNumber: weekNumber);
  }

  String _formatDay(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]}';
  }

  String _academicYear() {
    final now = DateTime.now();
    final startYear = now.month >= 9 ? now.year : now.year - 1;
    final endYear = startYear + 1;
    return '$startYear–${endYear.toString().substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _classDocStream,
          builder: (context, snapshot) {
            final classData = snapshot.data?.data() ?? const <String, dynamic>{};
            final className = (classData['className'] ?? AppSession.classId ?? '')
                .toString()
                .trim();
            final week = _weekInfo();
            final isOdd = week.weekNumber.isOdd;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ScheduleHeader(
                  className: className.isEmpty ? 'Unknown class' : className,
                  academicYear: _academicYear(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WeekSwitcher(
                          rangeText:
                              'Week ${_formatDay(week.monday)} — ${_formatDay(week.friday)}',
                          parityText: isOdd ? 'ODD WEEK' : 'EVEN WEEK',
                          onPrev: () => setState(() => _weekOffset -= 1),
                          onNext: () => setState(() => _weekOffset += 1),
                        ),
                        const SizedBox(height: 14),
                        _buildTimetableSection(),
                        const SizedBox(height: 14),
                        const _LegendRow(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  final String className;
  final String academicYear;

  const _ScheduleHeader({
    required this.className,
    required this.academicYear,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Schedule',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
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
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  final String rangeText;
  final String parityText;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _WeekSwitcher({
    required this.rangeText,
    required this.parityText,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      child: Row(
        children: [
          _SwitchArrow(icon: Icons.chevron_left_rounded, onTap: onPrev),
          Expanded(
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
          ),
          _SwitchArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _SwitchArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SwitchArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, color: _primary, size: 24),
        ),
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
          Icon(Icons.calendar_today_outlined,
              color: _outline.withValues(alpha: 0.7), size: 30),
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
