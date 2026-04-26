import 'package:flutter/material.dart';
import 'package:school_mate/student/widgets/school_decor.dart';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _surfaceLowest = Color(0xFFFFFFFF);
const _onSurface = Color(0xFF1A2050);
const _labelColor = Color(0xFF7A7E9A);
const _statusGreen = Color(0xFF1FA876);
const _statusRed = Color(0xFFD84A4A);
const _hairline = Color(0xFFEFF1F6);

class GateScanResultPageArguments {
  final bool isAllowed;
  final String? userId;
  final String? fullName;
  final String? classId;
  final String? reason;
  final String? scanType;
  final String? studentId;
  final bool hasActiveLeave;
  final String? errorMessage;

  GateScanResultPageArguments({
    required this.isAllowed,
    this.userId,
    this.fullName,
    this.classId,
    this.reason,
    this.studentId,
    this.scanType,
    this.hasActiveLeave = false,
    this.errorMessage,
  });
}

class GateScanResultPage extends StatelessWidget {
  const GateScanResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as GateScanResultPageArguments;

    final initials = (args.fullName ?? '??')
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();

    final scanType = (args.scanType ?? '').toLowerCase();
    final isExit = scanType == 'exit';

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PageBlueHeader(
              title: 'Scan result',
              subtitle: args.isAllowed
                  ? (isExit ? 'Exit recorded' : 'Entry recorded')
                  : 'Access denied',
              onBack: () => Navigator.of(context).pop(),
              trailing: _GatePill(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StudentCard(
                      initials: initials,
                      fullName: args.fullName,
                      classId: args.classId,
                      userId: args.userId,
                    ),
                    const SizedBox(height: 14),
                    _LeaveRequestCard(hasActiveLeave: args.hasActiveLeave),
                    const SizedBox(height: 14),
                    _ScheduleCard(),
                  ],
                ),
              ),
            ),
            _ResultFooter(args: args),
          ],
        ),
      ),
    );
  }
}

class _GatePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.shield_rounded, size: 12, color: Colors.white),
          SizedBox(width: 5),
          Text(
            'GATE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final String initials;
  final String? fullName;
  final String? classId;
  final String? userId;
  const _StudentCard({
    required this.initials,
    required this.fullName,
    required this.classId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return _ThemedCard(
      variant: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2848B0), Color(0xFF4070E0)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName ?? 'Unknown student',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: kPencilYellow,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CLASS ${classId ?? '—'}',
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ID: ${userId ?? '---'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _labelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// LEAVE REQUEST CARD
// ─────────────────────────────────────────────────────────────────────────────
class _LeaveRequestCard extends StatelessWidget {
  final bool hasActiveLeave;
  const _LeaveRequestCard({required this.hasActiveLeave});

  @override
  Widget build(BuildContext context) {
    final color = hasActiveLeave ? _statusGreen : _statusRed;
    final title = hasActiveLeave ? 'LEAVE APPROVED' : 'NO ACTIVE REQUEST';
    final desc = hasActiveLeave
        ? 'Approved leave for today.'
        : 'No leave request for today.';
    final icon = hasActiveLeave
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;

    return _ThemedCard(
      variant: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_available_rounded, color: _labelColor, size: 16),
              SizedBox(width: 6),
              Text(
                'LEAVE REQUEST',
                style: TextStyle(
                  color: _labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: const TextStyle(
                        color: _labelColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULE CARD (placeholder mock — wired to real schedule when available)
// ─────────────────────────────────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _ThemedCard(
      variant: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded, color: _labelColor, size: 16),
              SizedBox(width: 6),
              Text(
                "TODAY'S SCHEDULE",
                style: TextStyle(
                  color: _labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ScheduleItem(time: '08:00', subject: 'Mathematics', isCompleted: true),
          _DottedDivider(),
          _ScheduleItem(time: '09:00', subject: 'Physics', isCompleted: true),
          _DottedDivider(),
          _ScheduleItem(time: '10:00', subject: 'History', isCompleted: true),
          _DottedDivider(),
          _ScheduleItem(time: '11:00', subject: 'Chemistry', isNow: true),
          _DottedDivider(),
          _ScheduleItem(time: '12:00', subject: '—', isFuture: true),
        ],
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final String time;
  final String subject;
  final bool isCompleted;
  final bool isNow;
  final bool isFuture;
  const _ScheduleItem({
    required this.time,
    required this.subject,
    this.isCompleted = false,
    this.isNow = false,
    this.isFuture = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              time,
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isFuture ? _labelColor : _onSurface,
                fontWeight: isNow ? FontWeight.w900 : FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          if (isNow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kPencilYellow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'NOW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: _onSurface,
                  letterSpacing: 0.6,
                ),
              ),
            )
          else if (isCompleted)
            const Icon(Icons.check_rounded, color: _statusGreen, size: 18),
        ],
      ),
    );
  }
}

class _DottedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DottedLinePainter(),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 3.0, dashSpace = 3.0;
    double startX = 0;
    final paint = Paint()
      ..color = _hairline
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT FOOTER — banner + back button
// ─────────────────────────────────────────────────────────────────────────────
class _ResultFooter extends StatelessWidget {
  final GateScanResultPageArguments args;
  const _ResultFooter({required this.args});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPad),
      decoration: const BoxDecoration(
        color: _surfaceLowest,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusBanner(args: args),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.qr_code_scanner_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Back to scanner',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final GateScanResultPageArguments args;
  const _StatusBanner({required this.args});

  @override
  Widget build(BuildContext context) {
    final ok = args.isAllowed;
    final color = ok ? _statusGreen : _statusRed;
    final scanType = (args.scanType ?? '').toLowerCase();
    final isExit = scanType == 'exit';
    final title = ok
        ? (isExit ? 'EXIT GRANTED' : 'ENTRY GRANTED')
        : 'ACCESS DENIED';
    final desc = ok
        ? (args.hasActiveLeave
            ? 'Approved leave on file.'
            : 'Student access verified.')
        : (args.errorMessage?.isNotEmpty ?? false)
            ? args.errorMessage!
            : (args.reason?.isNotEmpty ?? false)
                ? args.reason!
                : 'Leave not yet approved by form master.';
    final icon = ok ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 12,
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

// ─────────────────────────────────────────────────────────────────────────────
// SHARED — themed card with sparkles
// ─────────────────────────────────────────────────────────────────────────────
class _ThemedCard extends StatelessWidget {
  final Widget child;
  final int variant;
  const _ThemedCard({required this.child, this.variant = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(20),
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
              painter: WhiteCardSparklesPainter(
                primary: _primary,
                variant: variant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
