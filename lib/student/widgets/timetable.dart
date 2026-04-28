import 'package:flutter/material.dart';

const _primary = Color(0xFF2848B0);
const _surfaceLowest = Color(0xFFFFFFFF);
const _surfaceContainerLow = Color(0xFFE8EAF2);
const _outlineVariant = Color(0xFFC0C4D8);
const _outline = Color(0xFF7A7E9A);
const _onSurface = Color(0xFF1A2050);

class TimetableSlot {
  final String start;
  final String end;
  const TimetableSlot(this.start, this.end);
}

class TimetableLesson {
  final String subject;
  final String teacher;
  final String? shortLabel;
  const TimetableLesson(this.subject, this.teacher, {this.shortLabel});
}

const kTimetableSlots = <TimetableSlot>[
  TimetableSlot('7:30', '8:20'),
  TimetableSlot('8:30', '9:20'),
  TimetableSlot('9:30', '10:20'),
  TimetableSlot('10:30', '11:20'),
  TimetableSlot('11:30', '12:20'),
  TimetableSlot('12:30', '13:20'),
  TimetableSlot('13:30', '14:20'),
];

const kTimetableDayLabels = <String>['Mo', 'Tu', 'We', 'Th', 'Fr'];

const List<List<TimetableLesson?>> kDemoSchedule = [
  // Monday
  [
    TimetableLesson('LbEng', 'GiCoj'),
    TimetableLesson('LbFr', 'ManuMac'),
    TimetableLesson('Info', 'Slon'),
    TimetableLesson('LbEng', 'GiCoj'),
    TimetableLesson('Mate', 'ChiCos'),
    TimetableLesson('Mate', 'ChiCos'),
    TimetableLesson('Ro', 'MarSte'),
  ],
  // Tuesday
  [
    null,
    TimetableLesson('Bio', 'AdriPop'),
    TimetableLesson('Ist', 'ValHer'),
    TimetableLesson('Mate', 'ChiCos'),
    TimetableLesson('LbEng', 'GiCoj'),
    TimetableLesson('Geo', 'TomaEn'),
    TimetableLesson('Fiz', 'NiAle'),
  ],
  // Wednesday
  [
    TimetableLesson('LbFr', 'ManuMac'),
    TimetableLesson('Chim', 'BoriCo'),
    TimetableLesson('Ro', 'MarSte'),
    TimetableLesson('Info', 'Slon'),
    TimetableLesson('Ed.F', 'Haide'),
    TimetableLesson('Ed.F', 'Haide'),
    null,
  ],
  // Thursday
  [
    TimetableLesson('Mate', 'ChiCos'),
    TimetableLesson('Mate', 'ChiCos'),
    TimetableLesson('Fiz', 'NiAle'),
    TimetableLesson('Ist', 'ValHer'),
    TimetableLesson('Rel', 'PrPa'),
    TimetableLesson('Ro', 'MarSte'),
    TimetableLesson('LbEng', 'GiCoj'),
  ],
  // Friday
  [
    TimetableLesson('Geo', 'TomaEn'),
    TimetableLesson('Bio', 'AdriPop'),
    TimetableLesson('LbFr', 'ManuMac'),
    TimetableLesson('Chim', 'BoriCo'),
    TimetableLesson('Info', 'Slon'),
    null,
    null,
  ],
];

class TimetableGrid extends StatelessWidget {
  final List<List<TimetableLesson?>> schedule;
  final List<TimetableSlot>? slots;

  const TimetableGrid({
    super.key,
    this.schedule = kDemoSchedule,
    this.slots,
  });

  @override
  Widget build(BuildContext context) {
    const dayColumnWidth = 34.0;
    const gap = 4.0;
    final effectiveSlots = slots ?? kTimetableSlots;

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: dayColumnWidth + gap),
            for (final slot in effectiveSlots)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      slot.start,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      slot.end,
                      style: const TextStyle(
                        color: _outline,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var dayIndex = 0; dayIndex < kTimetableDayLabels.length; dayIndex++) ...[
          _DayRow(
            dayLabel: kTimetableDayLabels[dayIndex],
            lessons: schedule[dayIndex],
            dayColumnWidth: dayColumnWidth,
            gap: gap,
          ),
          if (dayIndex != kTimetableDayLabels.length - 1)
            const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  final String dayLabel;
  final List<TimetableLesson?> lessons;
  final double dayColumnWidth;
  final double gap;

  const _DayRow({
    required this.dayLabel,
    required this.lessons,
    required this.dayColumnWidth,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: dayColumnWidth,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dayLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: gap),
          for (var i = 0; i < lessons.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == lessons.length - 1 ? 0 : 2,
                ),
                child: _LessonCell(lesson: lessons[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _LessonCell extends StatelessWidget {
  final TimetableLesson? lesson;

  const _LessonCell({required this.lesson});

  @override
  Widget build(BuildContext context) {
    if (lesson == null) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: _surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _outlineVariant.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showLessonDetail(context, lesson!),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: _surfaceLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _outlineVariant.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  lesson!.shortLabel ?? lesson!.subject,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  lesson!.teacher,
                  style: const TextStyle(
                    color: _outline,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showLessonDetail(BuildContext context, TimetableLesson lesson) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            lesson.subject,
            style: const TextStyle(
              color: _onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Teacher: ${lesson.teacher}',
            style: const TextStyle(
              color: _outline,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
