import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/core/session.dart';
import 'package:firster/student/meniu.dart';
import 'package:firster/student/orar.dart';
import 'package:firster/student/widgets/profile_bottom_sheet.dart';
import 'package:firster/student/cereri.dart';
import 'package:firster/student/inbox.dart';
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;
  bool _profilePressed = false;
  String? _inboxHighlightId;

  static const int _maxIndex = 3; // 4 children: 0..3

  @override
  void initState() {
    super.initState();
    final idx = widget.initialIndex;
    _currentIndex = idx < 0 ? 0 : (idx > _maxIndex ? _maxIndex : idx);
  }

  void _openInboxWithHighlight(String docId) {
    setState(() {
      _currentIndex = 3;
      _inboxHighlightId = docId;
    });
  }

  void _setTab(int index) {
    if (_currentIndex == index) {
      return;
    }

    // Marcare ca văzut când se selectează tab-ul inbox (index 3)
    if (index == 3) {
      final uid = AppSession.uid;
      if (uid != null && uid.isNotEmpty) {
        FirebaseFirestore.instance.collection('users').doc(uid).set({
          'inboxLastOpenedAt': FieldValue.serverTimestamp(),
          'unreadCount': 0,
        }, SetOptions(merge: true));
      }
    }

    setState(() {
      _currentIndex = (index < 0) ? 0 : (index > _maxIndex ? _maxIndex : index);
    });
  }

  Widget _buildAvatar() {
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(
        photoUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, e, s) => Container(
          width: 44,
          height: 44,
          color: const Color(0xFF2848B0),
          child: const Icon(Icons.person, color: Colors.white, size: 22),
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      color: const Color(0xFF2848B0),
      child: const Icon(Icons.person, color: Colors.white, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              MeniuScreen(
                onNavigateTab: _setTab,
                onNavigateToActiveLeave: _openInboxWithHighlight,
              ),
              OrarScreen(onBackToHome: () => _setTab(0)),
              CereriScreen(onNavigateTab: _setTab),
              InboxScreen(
                onNavigateTab: _setTab,
                highlightDocId: _inboxHighlightId,
                onHighlightConsumed: () =>
                    setState(() => _inboxHighlightId = null),
              ),
            ],
          ),
          if (_currentIndex == 0)
            Positioned(
              top: topPadding + 6,
              right: 16,
              child: GestureDetector(
                onTapDown: (_) => setState(() => _profilePressed = true),
                onTapUp: (_) {
                  setState(() => _profilePressed = false);
                  showProfileSheet(context);
                },
                onTapCancel: () => setState(() => _profilePressed = false),
                child: AnimatedScale(
                  scale: _profilePressed ? 0.78 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2848B0),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _buildAvatar(),
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
