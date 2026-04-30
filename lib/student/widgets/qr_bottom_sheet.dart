import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:school_mate/core/session.dart';
import 'package:school_mate/student/widgets/no_anim_route.dart';
import 'package:school_mate/student/widgets/school_decor.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _surfaceLowest = Color(0xFFFFFFFF);
const _onSurface = Color(0xFF1A2050);
const _outline = Color(0xFF7A7E9A);

/// Opens the QR access page (full screen).
Future<void> showQrSheet(BuildContext context) async {
  await Navigator.of(context).push(
    noAnimRoute<void>((_) => const QrAccessPage()),
  );
}

class QrAccessPage extends StatefulWidget {
  const QrAccessPage({super.key});

  @override
  State<QrAccessPage> createState() => _QrAccessPageState();
}

class _QrAccessPageState extends State<QrAccessPage> {
  static const int _renewIntervalSeconds = 15;
  Timer? _regenTimer;
  String _token = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _regenerateToken();
    _regenTimer = Timer.periodic(
      const Duration(seconds: _renewIntervalSeconds),
      (_) => _regenerateToken(),
    );
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    super.dispose();
  }

  Future<void> _regenerateToken() async {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) return;
    if (mounted) setState(() => _loading = true);

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('generateQrToken');
      final res = await callable.call();
      final tokenId = (res.data as Map?)?['token']?.toString() ?? '';

      if (!mounted) return;
      setState(() => _token = tokenId);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = (AppSession.fullName?.trim().isNotEmpty ?? false)
        ? AppSession.fullName!.trim()
        : (AppSession.username?.trim() ?? 'Student');
    final classId = (AppSession.classId ?? '').trim();
    final username = (AppSession.username ?? '').trim();
    final passLine = classId.isNotEmpty ? '$fullName · $classId' : fullName;
    final idLine = username.isNotEmpty ? '@$username' : '—';

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _Header(onBack: () => Navigator.of(context).maybePop()),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: _PassCard(
                passLine: passLine,
                idLine: idLine,
                token: _token,
                loading: _loading,
                refreshSeconds: _renewIntervalSeconds,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

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
            child: CustomPaint(
              painter: HeaderSparklesPainter(variant: 4),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
            child: Row(
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
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gate access',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.05,
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
                        'Show this code at the entrance',
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

class _PassCard extends StatelessWidget {
  final String passLine;
  final String idLine;
  final String token;
  final bool loading;
  final int refreshSeconds;

  const _PassCard({
    required this.passLine,
    required this.idLine,
    required this.token,
    required this.loading,
    required this.refreshSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final qrSize = (MediaQuery.of(context).size.width * 0.62)
        .clamp(200.0, 260.0);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: WhiteCardSparklesPainter(
                primary: _primary,
                variant: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
              children: [
                const Text(
                  'STUDENT PASS',
                  style: TextStyle(
                    color: _outline,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  passLine,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 38,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: kPencilYellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: SizedBox(
                    width: qrSize,
                    height: qrSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (token.isNotEmpty)
                          QrImageView(
                            data: token,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: _primary,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: _primary,
                            ),
                          )
                        else
                          const Icon(
                            Icons.qr_code_2_rounded,
                            color: _primary,
                            size: 140,
                          ),
                        if (loading)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: _primary,
                                strokeWidth: 2.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Refreshes every $refreshSeconds s',
                  style: const TextStyle(
                    color: _outline,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ID · $idLine',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
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

