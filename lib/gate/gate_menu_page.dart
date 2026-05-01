import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:school_mate/core/session.dart';
import 'package:school_mate/student/widgets/school_decor.dart';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _surfaceLowest = Color(0xFFFFFFFF);
const _onSurface = Color(0xFF1A2050);
const _labelColor = Color(0xFF7A7E9A);
const _live = Color(0xFF22C55E);
const _denied = Color(0xFFE54848);
const _hairline = Color(0xFFEFF1F6);

class GateMenuPage extends StatefulWidget {
  const GateMenuPage({super.key});

  @override
  State<GateMenuPage> createState() => _GateMenuPageState();
}

class _GateMenuPageState extends State<GateMenuPage> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final next = DateTime.now();
      if (next.minute != _now.minute || next.hour != _now.hour) {
        setState(() => _now = next);
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Sign out?',
          style: TextStyle(color: _onSurface, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'You will need to sign in again to use the gate scanner.',
          style: TextStyle(color: _labelColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _labelColor, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: _denied, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionName = (AppSession.fullName ?? '').trim();
    final displayName = sessionName.isEmpty ? 'Security User' : sessionName;
    final startOfToday = DateTime(_now.year, _now.month, _now.day);

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('accessEvents')
              .orderBy('timestamp', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            final allDocs = snapshot.data?.docs ?? const [];
            final todayCount = allDocs.where((d) {
              final ts = (d.data()['timestamp'] as Timestamp?)?.toDate();
              return ts != null && ts.isAfter(startOfToday);
            }).length;
            final recent = allDocs.take(5).toList();

            return Column(
              children: [
                _GateHeader(
                  displayName: displayName,
                  now: _now,
                  onLogout: _confirmLogout,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ScanHeroCard(
                          onTap: () =>
                              Navigator.of(context).pushNamed('/gateScan'),
                        ),
                        const SizedBox(height: 24),
                        _SectionTitle(title: 'Gate log', count: todayCount),
                        const SizedBox(height: 12),
                        _RecentList(
                          docs: recent,
                          loading: snapshot.connectionState ==
                              ConnectionState.waiting,
                          error: snapshot.hasError,
                        ),
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

// HEADER: flat compact bar with clock, name, ON DUTY, logout
class _GateHeader extends StatelessWidget {
  final String displayName;
  final DateTime now;
  final VoidCallback onLogout;

  const _GateHeader({
    required this.displayName,
    required this.now,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HeaderDecorPainter())),
          Padding( 
            padding: EdgeInsets.fromLTRB(20, topPadding + 12, 14, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 28,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: kPencilYellow,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _live,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _HeaderIconButton(
                  icon: Icons.logout_rounded,
                  onTap: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width - 20, -10),
      52,
      Paint()..color = Colors.white.withOpacity(0.06),
    );
    canvas.drawCircle(
      Offset(size.width - 20, -10),
      52,
      Paint()
        ..color = Colors.white.withOpacity(0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final c = Colors.white.withValues(alpha: 0.18);
    final cy = kPencilYellow.withValues(alpha: 0.32);
    drawMathSymbol(canvas, 'π', Offset(size.width * 0.62, size.height * 0.32), 13, cy);
    drawMathSymbol(canvas, '∑', Offset(size.width * 0.78, size.height * 0.72), 12, c);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// SCAN HERO: primary action, viewfinder + QR target on themed gradient
class _ScanHeroCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanHeroCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2848B0), Color(0xFF3460CC), Color(0xFF4070E0)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x282848B0),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ScanHeroDecorPainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'GATE SCANNER',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: SizedBox(
                      width: 230,
                      height: 230,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ViewfinderPainter(),
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 150,
                              height: 150, 
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.14),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.qr_code_2_rounded,
                                color: _primary,
                                size: 96,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Scan QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 32,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: kPencilYellow,
                      borderRadius: BorderRadius.circular(2),
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

class _ScanHeroDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    const gridSize = 26.0;
    for (double x = gridSize; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = gridSize; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    canvas.drawCircle(
      Offset(size.width + 10, -10),
      90, 
      Paint()..color = Colors.white.withOpacity(0.06),
    );
    canvas.drawCircle(
      Offset(size.width + 10, -10),
      90, 
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      Offset(-30, size.height + 10),
      70, 
      Paint()..color = Colors.white.withOpacity(0.05),
    );

    final c1 = Colors.white.withOpacity(0.3);
    final c2 = Colors.white.withOpacity(0.22);
    final cy = kPencilYellow.withValues(alpha: 0.35);
    drawMathSymbol(
        canvas, '∑', Offset(size.width - 28, size.height * 0.18), 14, cy);
    drawMathSymbol(
        canvas, '=', Offset(size.width * 0.10, size.height * 0.84), 12, c1);
    drawMathSymbol(
        canvas, '∫', Offset(size.width * 0.92, size.height * 0.42), 14, c2);
    drawMathSymbol(
        canvas, 'π', Offset(size.width * 0.06, size.height * 0.18), 13, c2);
    drawMathSymbol(
        canvas, '+', Offset(size.width * 0.92, size.height * 0.78), 12, cy);
    drawMathSymbol(
        canvas, '√', Offset(size.width * 0.14, size.height * 0.60), 11, c2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = kPencilYellow
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const inset = 0.0;
    const len = 36.0;
    canvas.drawLine(
      const Offset(inset, inset + len),
      const Offset(inset, inset),
      stroke,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + len, inset),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width - inset - len, inset),
      Offset(size.width - inset, inset),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + len),
      stroke,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset - len),
      Offset(inset, size.height - inset),
      stroke,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + len, size.height - inset),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width - inset - len, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset, size.height - inset - len),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// SECTION TITLE
class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: kPencilYellow,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: _onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count today',
            style: const TextStyle(
              color: _primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// GATE LOG
class _RecentList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool loading;
  final bool error;
  const _RecentList({
    required this.docs,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (error) {
      return _emptyMsg(Icons.error_outline_rounded, "Couldn't load gate log");
    }
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _primary,
            ),
          ),
        ),
      );
    }
    if (docs.isEmpty) {
      return _emptyMsg(Icons.inbox_rounded, 'No scans yet');
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(18),
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
                variant: 4,
              ),
            ),
          ),
          Column(
            children: [
              for (var i = 0; i < docs.length; i++) ...[
                if (i > 0)
                  Container(
                    height: 1,
                    color: _hairline,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                _RecentItem(doc: docs[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyMsg(IconData icon, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: _labelColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _labelColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentItem extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _RecentItem({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final timestamp =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final String name = (data['fullName'] ?? 'Unknown').toString();
    final String rawReasonRaw = (data['reason'] ?? '').toString();
    final String rawReason = (rawReasonRaw == 'NO_ACTIVE_LEAVE')
        ? 'no_active_leave_request'
        : (rawReasonRaw == 'EXPIRED')
            ? 'expired_qr_token'
            : rawReasonRaw;

    final String reason = rawReason
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');

    final scanResult = (data['scanResult'] ?? '').toString().toLowerCase();
    final isAllowed = scanResult == 'allowed';
    final displayedName = isAllowed
        ? name
        : (rawReasonRaw == 'NO_ACTIVE_LEAVE'
            ? '$name - $reason'
            : (reason.isNotEmpty ? reason : 'Denied'));
    final classCode = (data['classId'] ?? '').toString();
    final color = isAllowed ? _live : _denied;
    final label = isAllowed ? 'ALLOWED' : 'DENIED';
    final dirIcon = isAllowed ? Icons.logout_rounded : Icons.block_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.14),
                  color.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: color.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Icon(dirIcon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (classCode.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _labelColor,
                        ),
                      ),
                      Text(
                        classCode,
                        style: const TextStyle(
                          color: _labelColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(
              color: _primary,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}