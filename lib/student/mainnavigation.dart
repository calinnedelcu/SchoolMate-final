import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_mate/core/session.dart';
import 'package:school_mate/student/meniu.dart';
import 'package:school_mate/student/profile_page.dart';
import 'package:school_mate/student/schedule_page.dart';
import 'package:school_mate/student/widgets/maniubara.dart';
import 'package:school_mate/student/leave_requests_overview.dart';
import 'package:school_mate/student/inbox.dart';
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;
  String? _inboxHighlightId;

  static const int _maxIndex = 4; // 5 children: 0..4 (4 = Profile)

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

  int _navIndexForCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 4:
        return 2;
      default:
        return -1;
    }
  }

  void _onBottomNavTap(int index) {
    if (index == 2) {
      _setTab(4);
      return;
    }
    _setTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: FixedBottomNav(
        currentIndex: _navIndexForCurrentTab(),
        onTap: _onBottomNavTap,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MeniuScreen(
            onNavigateTab: _setTab,
            onNavigateToActiveLeave: _openInboxWithHighlight,
          ),
          SchedulePage(onBackToHome: () => _setTab(0)),
          LeaveRequestsOverviewScreen(onNavigateTab: _setTab),
          InboxScreen(
            onNavigateTab: _setTab,
            highlightDocId: _inboxHighlightId,
            onHighlightConsumed: () =>
                setState(() => _inboxHighlightId = null),
          ),
          ProfilePage(onBackToHome: () => _setTab(0)),
        ],
      ),
    );
  }
}
