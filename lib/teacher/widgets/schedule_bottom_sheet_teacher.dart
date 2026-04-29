import 'package:school_mate/common/class_timetable.dart';
import 'package:school_mate/student/widgets/school_decor.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF2848B0);
const _surfaceLowest = Color(0xFFFFFFFF);
const _surfaceContainerHigh = Color(0xFFDDE0EC);
const _onSurface = Color(0xFF1A2050);
const _outline = Color(0xFF7A7E9A);
const _outlineVariant = Color(0xFFC0C4D8);

Future<void> showTeacherScheduleSheet(BuildContext context, String classId) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TeacherScheduleBottomSheet(classId: classId),
  );
}

class _TeacherScheduleBottomSheet extends StatelessWidget {
  final String classId;
  const _TeacherScheduleBottomSheet({required this.classId});

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
                      color: Color(0xFFF5C518),
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

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClassTimetable(classId: classId),
                  ),

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

