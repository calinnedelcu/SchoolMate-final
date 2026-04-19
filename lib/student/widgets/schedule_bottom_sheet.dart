import 'package:firster/student/widgets/school_decor.dart';
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
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: Container(
        decoration: const BoxDecoration(color: _surfaceLowest),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(
                painter: WhiteCardSparklesPainter(
                  primary: _primary,
                  variant: 3,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  Container(
                    width: 42,
                    height: 3,
                    decoration: BoxDecoration(
                      color: kPencilYellow,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Your class timetable for the week.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _outline.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _TimetableGrid(),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lesson {
  final String subject;
  final String teacher;
  const _Lesson(this.subject, this.teacher);
}

class _TimetableGrid extends StatelessWidget {
  const _TimetableGrid();

  static const double _cellW = 62;
  static const double _cellH = 58;
  static const double _headerH = 28;
  static const double _dayW = 34;
  static const double _gap = 4;

  static const List<String> _times = [
    '7:30\n8:20',
    '8:30\n9:20',
    '9:30\n10:20',
    '10:30\n11:20',
    '11:30\n12:20',
    '12:30\n13:20',
    '13:30\n14:20',
  ];

  static const List<String> _days = ['Mo', 'Tu', 'We', 'Th', 'Fr'];

  static const List<List<_Lesson?>> _week = [
    // Monday
    [
      _Lesson('LbEng', 'GiCoj'),
      _Lesson('LbFr', 'ManuMac'),
      _Lesson('Info', 'Slon'),
      _Lesson('LbEng', 'GiCoj'),
      _Lesson('Mate', 'ChiCos'),
      _Lesson('Mate', 'ChiCos'),
      null,
    ],
    // Tuesday
    [
      _Lesson('Geo', 'DiaPet'),
      _Lesson('Ist-evHol', 'StefR'),
      _Lesson('LbFr', 'ManuMac'),
      _Lesson('Bio', 'SiVas'),
      _Lesson('Chim', 'MirMar'),
      _Lesson('LbRo', 'ATim'),
      null,
    ],
    // Wednesday
    [
      _Lesson('Fiz', 'VicSt'),
      _Lesson('Fiz', 'VicSt'),
      _Lesson('Info', 'CaMi'),
      _Lesson('Info', 'Slon'),
      null,
      _Lesson('LbRo', 'ATim'),
      null,
    ],
    // Thursday
    [
      _Lesson('Isto', 'DanC'),
      _Lesson('Fiz', 'VicSt'),
      _Lesson('Rel', 'MariG'),
      _Lesson('Info', 'Slon'),
      _Lesson('Econ', 'CriVas'),
      _Lesson('Info', 'Slon'),
      null,
    ],
    // Friday
    [
      _Lesson('Mate', 'ChiCos'),
      _Lesson('Mate', 'ChiCos'),
      _Lesson('Mate', 'ChiCos'),
      _Lesson('LbRo', 'ATim'),
      _Lesson('EdFiz', 'SoMar'),
      _Lesson('Info', 'Slon'),
      null,
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final todayIdx = DateTime.now().weekday - 1;
    final isWeekday = todayIdx >= 0 && todayIdx < _days.length;

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sticky day column
          Column(
            children: [
              const SizedBox(height: _headerH),
              for (int d = 0; d < _days.length; d++)
                Padding(
                  padding: const EdgeInsets.only(bottom: _gap),
                  child: Container(
                    width: _dayW,
                    height: _cellH,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (isWeekday && d == todayIdx)
                          ? _primary
                          : _surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _days[d],
                      style: TextStyle(
                        color: (isWeekday && d == todayIdx)
                            ? Colors.white
                            : _onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          // Horizontally scrollable grid with right-edge fade hint
          Expanded(
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.0, 0.88, 1.0],
                  colors: [
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time header row
                    SizedBox(
                      height: _headerH,
                      child: Row(
                        children: [
                          for (final t in _times)
                            Padding(
                              padding: const EdgeInsets.only(right: _gap),
                              child: SizedBox(
                                width: _cellW,
                                child: Text(
                                  t,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _outline,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Day rows
                    for (int d = 0; d < _week.length; d++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: _gap),
                        child: Row(
                          children: [
                            for (int t = 0; t < _times.length; t++)
                              Padding(
                                padding: const EdgeInsets.only(right: _gap),
                                child: _LessonCell(
                                  lesson: _week[d][t],
                                  isToday: isWeekday && d == todayIdx,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCell extends StatelessWidget {
  final _Lesson? lesson;
  final bool isToday;

  const _LessonCell({required this.lesson, required this.isToday});

  @override
  Widget build(BuildContext context) {
    const w = _TimetableGrid._cellW;
    const h = _TimetableGrid._cellH;

    if (lesson == null) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: _surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      );
    }

    return Container(
      width: w,
      height: h,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      decoration: BoxDecoration(
        color: isToday
            ? _primary.withValues(alpha: 0.09)
            : _surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isToday
              ? _primary.withValues(alpha: 0.45)
              : _outlineVariant.withValues(alpha: 0.55),
          width: isToday ? 1.2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              lesson!.subject,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isToday ? _primary : _onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            lesson!.teacher,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isToday
                  ? _primary.withValues(alpha: 0.8)
                  : _outline,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
