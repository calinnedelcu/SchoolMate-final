import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'gate_scan_result_page.dart';

class GateScanPage extends StatefulWidget {
  const GateScanPage({super.key});

  @override
  State<GateScanPage> createState() => _GateScanPageState();
}

class _GateScanPageState extends State<GateScanPage> {
  static const String _scanSoundAsset = 'sounds/gate_scan.mp3';

  bool _lock = false;
  final AudioPlayer _scanPlayer = AudioPlayer();

  @override
  void dispose() {
    _scanPlayer.dispose();
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
    if (data is! Map) throw Exception('Răspuns invalid de la server');
    return Map<String, dynamic>.from(data);
  }

  // Logging is now handled in the backend (Cloud Function)

  Future<void> _handleToken(String tokenId) async {
    // Navigation logic handles UI updates now

    try {
      final res = await _redeemToken(tokenId);

      final ok = res["ok"] == true;
      final userId = (res["userId"] ?? "-").toString();
      final fullName = (res["fullName"] ?? "").toString();
      final classId = (res["classId"] ?? "").toString();
      final reason = (res["reason"] ?? "").toString();
      final scanType = (res["type"] ?? (ok ? "entry" : "deny")).toString();
      final hasActiveLeave = (res["hasActiveLeave"] ?? false) as bool;
      
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
          scanType: scanType,
          hasActiveLeave: hasActiveLeave,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        '/gateScanResult',
        arguments: GateScanResultPageArguments(
          isAllowed: false,
          errorMessage: "Eroare validare: $e",
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _lock = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gate - QR Scanner"),
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
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
          ),
        ],
      ),
    );
  }
}