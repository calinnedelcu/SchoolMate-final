import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firster/core/session.dart';
import 'package:firster/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _primary = Color(0xFF1F8BE7);
const _surfaceLowest = Color(0xFFFFFFFF);
const _surfaceContainerLow = Color(0xFFE7F0F6);
const _surfaceContainerHigh = Color(0xFFDEE8F0);
const _onSurface = Color(0xFF587F9E);
const _outline = Color(0xFF717B6E);
const _outlineVariant = Color(0xFFBACCD9);

/// Opens the QR access bottom sheet.
Future<void> showQrSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const QrBottomSheet(),
  );
}

class QrBottomSheet extends StatefulWidget {
  const QrBottomSheet({super.key});

  @override
  State<QrBottomSheet> createState() => _QrBottomSheetState();
}

class _QrBottomSheetState extends State<QrBottomSheet> {
  static const int _renewIntervalSeconds = 15;
  Timer? _regenTimer;
  Timer? _countdownTimer;
  String _token = '';
  bool _loading = false;
  int _secondsLeft = _renewIntervalSeconds;

  @override
  void initState() {
    super.initState();
    _regenerateToken();
    _regenTimer = Timer.periodic(
      const Duration(seconds: _renewIntervalSeconds),
      (_) => _regenerateToken(),
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
    });
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _regenerateToken() async {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) return;
    if (mounted) setState(() => _loading = true);

    try {
      final random = Random();
      final tokenId = List.generate(16, (_) => random.nextInt(10)).join();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(seconds: _renewIntervalSeconds + 1)),
      );

      await FirebaseFirestore.instance.collection('qrTokens').doc(tokenId).set({
        'userId': uid,
        'expiresAt': expiresAt,
        'used': false,
      });

      if (!mounted) return;
      setState(() {
        _token = tokenId;
        _secondsLeft = _renewIntervalSeconds;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: _outlineVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l.qrSheetTitle,
            style: const TextStyle(
              color: _onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              l.qrSheetSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _outline.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              width: 220,
              height: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_token.isNotEmpty)
                    QrImageView(
                      data: _token,
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
                      size: 120,
                    ),
                  if (_loading)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(18),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded, color: _primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  l.qrSheetExpiresIn(_secondsLeft),
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
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
              child: Center(
                child: Text(
                  l.qrSheetClose,
                  style: const TextStyle(
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
}
