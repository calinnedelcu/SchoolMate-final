import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Loads an image from a Firebase Storage download URL via the SDK
/// (`refFromURL(...).getData()`) instead of `Image.network`.
///
/// This avoids platform-specific HTTP/CORS issues (Flutter Web fetch
/// failures, Windows desktop `HttpClient` quirks) that plain
/// `Image.network` can hit on Firebase Storage URLs.
class StorageImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext) loadingBuilder;
  final Widget Function(BuildContext, Object) errorBuilder;

  const StorageImage({
    super.key,
    required this.url,
    required this.fit,
    required this.loadingBuilder,
    required this.errorBuilder,
  });

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant StorageImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _future = _load();
    }
  }

  Future<Uint8List?> _load() {
    final ref = FirebaseStorage.instance.refFromURL(widget.url);
    return ref.getData(12 * 1024 * 1024);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return widget.loadingBuilder(ctx);
        }
        if (snap.hasError || snap.data == null) {
          return widget.errorBuilder(ctx, snap.error ?? 'No data');
        }
        return Image.memory(snap.data!, fit: widget.fit);
      },
    );
  }
}
