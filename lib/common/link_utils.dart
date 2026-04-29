import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in an external app/browser. If launching fails, surfaces
/// a SnackBar with [messengerContext] so the user knows it didn't open.
Future<void> launchExternalUrl(
  BuildContext messengerContext,
  String url,
) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || (!uri.hasScheme)) {
    _snack(messengerContext, 'Invalid link: $trimmed');
    return;
  }

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && messengerContext.mounted) {
      _snack(messengerContext, 'Could not open: $trimmed');
    }
  } catch (e) {
    if (messengerContext.mounted) {
      _snack(messengerContext, 'Could not open link: $e');
    }
  }
}

void _snack(BuildContext ctx, String text) {
  ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
    SnackBar(content: Text(text)),
  );
}
