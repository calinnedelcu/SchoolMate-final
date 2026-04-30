import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:school_mate/student/widgets/school_decor.dart';
import 'gate_scan_result_page.dart';

const _primary = Color(0xFF2848B0);
const _live = Color(0xFF22C55E);

class GateScanPage extends StatefulWidget {
  const GateScanPage({super.key});

  @override
  State<GateScanPage> createState() => _GateScanPageState();
}

class _GateScanPageState extends State<GateScanPage> {
  static const String _scanSoundAsset = 'sounds/gate_scan.mp3';

  bool _lock = false;
  final AudioPlayer _scanPlayer = AudioPlayer();
  final MobileScannerController _scannerController = MobileScannerController();
  bool _torchOn = false;

  @override
  void dispose() {
    _scanPlayer.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _playScanSound() async {
    try {
      await _scanPlayer.stop();
      await _scanPlayer.play(AssetSource(_scanSoundAsset));
    } catch (_) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<Map<String, dynamic>> _redeemToken(String tokenId) async {
    final callable = FirebaseFunctions.instance.httpsCallable('redeemQrToken');
    final res = await callable.call(<String, dynamic>{'token': tokenId});
    final data = res.data;
    if (data is! Map) throw Exception('Invalid response from server');
    return Map<String, dynamic>.from(data);
  }

  Future<void> _handleToken(String tokenId) async {
    try {
      final res = await _redeemToken(tokenId);

      final ok = res['ok'] == true;
      final userId = (res['userId'] ?? '-').toString();
      final fullName = (res['fullName'] ?? '').toString();
      final classId = (res['classId'] ?? '').toString();
      final reason = (res['reason'] ?? '').toString(); // Will be null if ok is true
      final hasActiveLeave = (res['hasActiveLeave'] ?? false) as bool;

      if (ok) {
        await _playScanSound();
      }

      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        '/gateScanResult',
        arguments: GateScanResultPageArguments(
          isAllowed: ok,
          userId: userId,
          fullName: fullName,
          classId: classId,
          reason: reason,
          hasActiveLeave: hasActiveLeave,
          tokenId: tokenId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        '/gateScanResult',
        arguments: GateScanResultPageArguments(
          isAllowed: false,
          errorMessage: 'Validation error. Please try again.',
        ),
      );
    }

    if (!mounted) return;
    setState(() => _lock = false);
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    if (!mounted) return;
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_lock) return;
              _lock = true;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) {
                _lock = false;
                return;
              }
              final raw = barcodes.first.rawValue;
              if (raw == null || raw.isEmpty) {
                _lock = false;
                return;
              }
              _handleToken(raw);
            },
          ),
          // Dim overlay around the viewfinder area
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ScannerDimPainter(),
            ),
          ),
          // Top bar
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'GATE SCANNER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _live,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _CircleIconButton(
                  icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  onTap: _toggleTorch,
                  highlight: _torchOn,
                ),
              ],
            ),
          ),
          // Viewfinder overlay
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(painter: _ViewfinderPainter()),
            ),
          ),
          // Hint
          Positioned(
            left: 24,
            right: 24,
            bottom: bottomPad + 32,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 16,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: kPencilYellow,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Align student QR within the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Detection happens automatically',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
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

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: highlight 
                ? kPencilYellow.withOpacity(0.95)
                : Colors.black.withOpacity(0.42),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: highlight ? const Color(0xFF1A2050) : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ScannerDimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const boxSize = 260.0;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: boxSize,
      height: boxSize,
    );
    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    final dim = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath( 
      dim,
      Paint()..color = Colors.black.withOpacity(0.55),
    );
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
    const len = 32.0;
    // Top-left
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
    // Top-right
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
    // Bottom-left
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
    // Bottom-right
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

    // Faint ring around primary brand
    final ring = Paint()
      ..color = _primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(20),
      ),
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}