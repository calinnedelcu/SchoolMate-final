import 'dart:ui';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';
import '../services/admin_api.dart';
import 'admin_classes_page.dart' show AdminClassesPage;
import 'admin_notifications.dart';
import 'admin_parents_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_vacante.dart' as admin_vacante;
import 'utils/admin_ui.dart';

// --- Helpers -----------------------------------------------------------

String _timeAgo(Timestamp ts) {
  final diff = DateTime.now().difference(ts.toDate());
  if (diff.inSeconds < 60) return '${diff.inSeconds} sec ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  return '${diff.inDays} days ago';
}

String _hhmm(Timestamp ts) {
  final dt = ts.toDate();
  final h = dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:$m $ampm';
}

String _humanizeAccessReason(String reason) {
  switch (reason.trim().toUpperCase()) {
    case 'ALREADY_IN_SCHOOL':
      return 'The student was already in school.';
    case 'ALREADY_USED':
      return 'The QR code has already been used.';
    case 'EXPIRED':
      return 'The QR code has expired.';
    case 'NOT_FOUND':
      return 'The QR code was not found.';
    case 'USER_NOT_FOUND':
      return 'The user was not found.';
    case 'USER_DISABLED':
      return 'The student account is disabled.';
    case 'NO_CLASS_ASSIGNED':
      return 'The student has no class assigned.';
    case 'NO_SCHEDULE':
      return 'There is no schedule for the student\'s class.';
    case 'BAD_SCHEDULE':
      return 'The class schedule is invalid.';
    case 'BAD_EXPIRES':
      return 'The QR code does not have a valid expiration.';
    default:
      return reason.isEmpty ? 'No additional reason.' : reason;
  }
}

String _eventActionLabel(Map<String, dynamic> data) {
  final type = (data['type'] ?? '').toString();
  switch (type) {
    case 'entry':
      return 'Student entered';
    case 'exit':
      return 'Student exited';
    case 'deny':
      return 'Access denied';
    default:
      return 'Access processed';
  }
}

String _eventReasonText(Map<String, dynamic> data) {
  final reason = (data['reason'] ?? '').toString().trim();
  if (reason.isNotEmpty) {
    return _humanizeAccessReason(reason);
  }

  final type = (data['type'] ?? '').toString();
  if (type == 'entry') return 'Access granted for entry into school.';
  if (type == 'exit') return 'Access granted for exit from school.';
  return 'Event recorded without additional details.';
}

String _eventMetaText(Map<String, dynamic> data, {String? fallbackClassId}) {
  final parts = <String>[];
  final classId = (data['classId'] ?? '').toString().trim();
  final scanResult = (data['scanResult'] ?? '').toString().trim();

  final effectiveClassId = classId.isNotEmpty
      ? classId
      : (fallbackClassId ?? '');

  if (effectiveClassId.isNotEmpty) parts.add('Class $effectiveClassId');
  if (scanResult.isNotEmpty) {
    parts.add(scanResult == 'allowed' ? 'Scan accepted' : 'Scan denied');
  }

  return parts.join(' · ');
}

Future<T?> _showBlurDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Duration transitionDuration = const Duration(milliseconds: 220),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel:
        barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: transitionDuration,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return builder(dialogContext);
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );

      return AnimatedBuilder(
        animation: curvedAnimation,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 14 * curvedAnimation.value,
                    sigmaY: 14 * curvedAnimation.value,
                  ),
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: 0.55 * curvedAnimation.value,
                    ),
                  ),
                ),
              ),
              FadeTransition(opacity: curvedAnimation, child: child),
            ],
          );
        },
      );
    },
  );
}

// -----------------------------------------------------------------------
//  AdminTurnstilesPage
// -----------------------------------------------------------------------

class AdminTurnstilesPage extends StatefulWidget {
  const AdminTurnstilesPage({
    super.key,
    this.embedded = false,
    this.searchQuery,
  });
  final bool embedded;
  final String? searchQuery;

  @override
  State<AdminTurnstilesPage> createState() => _AdminTurnstilesPageState();
}

class _AdminTurnstilesPageState extends State<AdminTurnstilesPage> {
  int _refreshKey = 0;
  bool _sidebarBusy = false;
  final TextEditingController _searchC = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _searchQuery = widget.searchQuery!.trim().toLowerCase();
      _searchC.text = widget.searchQuery!;
    }
  }

  @override
  void didUpdateWidget(AdminTurnstilesPage old) {
    super.didUpdateWidget(old);
    final q = widget.searchQuery ?? '';
    if (q != (old.searchQuery ?? '')) {
      setState(() {
        _searchQuery = q.trim().toLowerCase();
        _searchC.text = q;
      });
    }
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _replacePage(Widget page) async {
    if (_sidebarBusy || !mounted) return;
    _sidebarBusy = true;
    try {
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => page,
        ),
      );
    } finally {
      _sidebarBusy = false;
    }
  }

  Future<void> _showLogoutDialog() async {
    await _showBlurDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Container(
      color: const Color(0xFFF2F4F8),
      child: Column(
        children: [
          if (!widget.embedded)
            _TurnstilesTopBar(
              displayName: AppSession.username ?? 'Admin',
              searchController: _searchC,
              onSearch: (value) => setState(() => _searchQuery = value),
            ),
          Expanded(
            child: _TurnstileBody(
              key: ValueKey(_refreshKey),
              onRefresh: () => setState(() => _refreshKey++),
              searchQuery: _searchQuery,
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: const Color(0xFF2848B0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                _TurnstilesSidebar(
                  selected: 'turnstiles',
                  onMenuTap: () => Navigator.of(context).pop(),
                  onStudentsTap: () => _replacePage(const AdminStudentsPage()),
                  onPersonalTap: () => _replacePage(const AdminTeachersPage()),
                  onTurnichetiTap: () {},
                  onClaseTap: () =>
                      _replacePage(const AdminClassesPage()),
                  onVacanteTap: () =>
                      _replacePage(const admin_vacante.AdminVacantePage()),
                  onParintiTap: () => _replacePage(const AdminParentsPage()),
                  onLogoutTap: _showLogoutDialog,
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
//  _TurnstileBody
// -----------------------------------------------------------------------

class _TurnstileBody extends StatelessWidget {
  final VoidCallback onRefresh;
  final String searchQuery;

  const _TurnstileBody({
    super.key,
    required this.onRefresh,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'gate')
          .snapshots(),
      builder: (context, gateSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .snapshots(),
          builder: (context, studentSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('accessEvents')
                  .orderBy('timestamp', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, eventSnap) {
                final gates = List<QueryDocumentSnapshot>.from(
                  gateSnap.data?.docs ?? [],
                );
                final students = List<QueryDocumentSnapshot>.from(
                  studentSnap.data?.docs ?? [],
                );
                final allEvents = List<QueryDocumentSnapshot>.from(
                  eventSnap.data?.docs ?? [],
                );

                // gate UID -> name map
                final gateMap = <String, String>{};
                for (final g in gates) {
                  final d = g.data() as Map<String, dynamic>;
                  gateMap[g.id] = (d['username'] ?? d['fullName'] ?? g.id)
                      .toString();
                }

                final studentClassMap = <String, String>{};
                final studentNameMap = <String, String>{};
                for (final student in students) {
                  final d = student.data() as Map<String, dynamic>;
                  studentClassMap[student.id] = (d['classId'] ?? '').toString();
                  studentNameMap[student.id] =
                      (d['fullName'] ?? d['username'] ?? student.id).toString();
                }

                // Filter gates by search query
                final searchLower = searchQuery.toLowerCase().trim();
                final filteredGates = gates.where((g) {
                  final d = g.data() as Map<String, dynamic>;
                  final name = (d['fullName'] ?? d['username'] ?? g.id)
                      .toString();
                  return name.toLowerCase().contains(searchLower);
                }).toList();

                // Daily stats (client-side filter)
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final yesterdayStart = todayStart.subtract(
                  const Duration(days: 1),
                );

                final todayCount = allEvents.where((e) {
                  final d = e.data() as Map<String, dynamic>;
                  final ts = d['timestamp'] as Timestamp?;
                  if (ts == null) return false;
                  return !ts.toDate().isBefore(todayStart);
                }).length;

                final exitsTodayCount = allEvents.where((e) {
                  final d = e.data() as Map<String, dynamic>;
                  final ts = d['timestamp'] as Timestamp?;
                  if (ts == null) return false;
                  if (ts.toDate().isBefore(todayStart)) return false;
                  return (d['type'] ?? '').toString() == 'exit';
                }).length;

                final deniedTodayCount = allEvents.where((e) {
                  final d = e.data() as Map<String, dynamic>;
                  final ts = d['timestamp'] as Timestamp?;
                  if (ts == null) return false;
                  if (ts.toDate().isBefore(todayStart)) return false;
                  final scanResult = (d['scanResult'] ?? '')
                      .toString()
                      .toLowerCase();
                  final type = (d['type'] ?? '').toString().toLowerCase();
                  return scanResult == 'denied' || type == 'deny';
                }).length;

                final yesterdayCount = allEvents.where((e) {
                  final d = e.data() as Map<String, dynamic>;
                  final ts = d['timestamp'] as Timestamp?;
                  if (ts == null) return false;
                  final dt = ts.toDate();
                  return !dt.isBefore(yesterdayStart) &&
                      dt.isBefore(todayStart);
                }).length;

                final liveEvents = allEvents.take(30).toList();

                final loaded =
                    gateSnap.hasData &&
                    studentSnap.hasData &&
                    eventSnap.hasData;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Stats row -----------------------------------
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              icon: Icons.door_front_door_rounded,
                              iconBg: const Color(0xFFEEF1FB),
                              iconColor: const Color(0xFF2848B0),
                              label: 'TURNSTILE GATES',
                              value: loaded ? '${gates.length}' : '—',
                              subtitle: 'Active access points',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _statCard(
                              icon: Icons.qr_code_scanner_rounded,
                              iconBg: const Color(0xFFEDF7F0),
                              iconColor: const Color(0xFF2E8B57),
                              label: "TODAY'S SCANS",
                              value: loaded ? '$todayCount' : '—',
                              subtitle: 'Total scan events',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _statCard(
                              icon: Icons.logout_rounded,
                              iconBg: const Color(0xFFF3EDFB),
                              iconColor: const Color(0xFF7B4FCC),
                              label: 'EXITS TODAY',
                              value: loaded ? '$exitsTodayCount' : '—',
                              subtitle: 'Students exited',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _statCard(
                              icon: Icons.block_rounded,
                              iconBg: const Color(0xFFFFF8E8),
                              iconColor: const Color(0xFFF5A623),
                              label: 'DENIED TODAY',
                              value: loaded ? '$deniedTodayCount' : '—',
                              subtitle: deniedTodayCount == 0
                                  ? 'All clear'
                                  : 'Access denied',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Two-column content --------------------------
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: turnstiles
                            Expanded(
                              flex: 6,
                              child: _ActiveHubsPanel(
                                gates: filteredGates,
                                allEvents: allEvents,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Right: live traffic + daily scans
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _LiveTrafficPanel(
                                      events: liveEvents,
                                      gateMap: gateMap,
                                      studentClassMap: studentClassMap,
                                      studentNameMap: studentNameMap,
                                      allEvents: allEvents,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _DailyScansCard(
                                    todayCount: todayCount,
                                    yesterdayCount: yesterdayCount,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2848B0).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9BA3B8),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9BA3B8),
                    fontWeight: FontWeight.w500,
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

// -----------------------------------------------------------------------
//  _ActiveHubsPanel
// -----------------------------------------------------------------------

class _ActiveHubsPanel extends StatefulWidget {
  final List<QueryDocumentSnapshot> gates;
  final List<QueryDocumentSnapshot> allEvents;

  const _ActiveHubsPanel({required this.gates, required this.allEvents});

  @override
  State<_ActiveHubsPanel> createState() => _ActiveHubsPanelState();
}

class _ActiveHubsPanelState extends State<_ActiveHubsPanel> {
  static const int _pageSize = 6;
  int _currentPage = 0;

  List<Widget> _buildPageButtons(int totalPages, int currentPage) {
    final pages = <Widget>[];
    const maxVisible = 5;

    void addPage(int index) {
      pages.add(
        GestureDetector(
          onTap: () => setState(() => _currentPage = index),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: currentPage == index
                  ? const Color(0xFF1A2050)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: currentPage == index
                    ? const Color(0xFF1A2050)
                    : const Color(0xFFE8EAF2),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: currentPage == index
                    ? Colors.white
                    : const Color(0xFF1A2050),
              ),
            ),
          ),
        ),
      );
    }

    void addEllipsis() {
      pages.add(
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          child: const Text(
            '...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7A7E9A),
            ),
          ),
        ),
      );
    }

    if (totalPages <= maxVisible) {
      for (int i = 0; i < totalPages; i++) {
        addPage(i);
      }
    } else {
      addPage(0);

      if (currentPage > 2) addEllipsis();

      final start = (currentPage - 1).clamp(1, totalPages - 2);
      final end = (currentPage + 1).clamp(1, totalPages - 2);
      for (int i = start; i <= end; i++) {
        addPage(i);
      }

      if (currentPage < totalPages - 3) addEllipsis();

      addPage(totalPages - 1);
    }

    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.gates.isEmpty
        ? 0
        : (widget.gates.length / _pageSize).ceil();
    final currentPage = totalPages == 0
        ? 0
        : _currentPage.clamp(0, totalPages - 1);
    final visibleGates = totalPages == 0
        ? <QueryDocumentSnapshot>[]
        : widget.gates.skip(currentPage * _pageSize).take(_pageSize).toList();

    if (currentPage != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPage = currentPage);
      });
    }

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.door_front_door_rounded,
                  color: Color(0xFF2848B0),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Guardians',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2848B0),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF2F4F8)),
          Expanded(
            child: widget.gates.isEmpty
                ? const Center(
                    child: Text(
                      'No turnstiles registered.',
                      style: TextStyle(color: Color(0xFF7A7E9A), fontSize: 14),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const listPadding = EdgeInsets.fromLTRB(
                              16,
                              12,
                              16,
                              12,
                            );
                            const separatorHeight = 10.0;
                            final visibleCount = visibleGates.length;
                            final availableHeight =
                                constraints.maxHeight -
                                listPadding.vertical -
                                (max(visibleCount - 1, 0) * separatorHeight);
                            final collapsedHeight =
                                visibleCount == _pageSize && visibleCount > 0
                                ? availableHeight / visibleCount
                                : null;

                            return ListView.separated(
                              padding: listPadding,
                              itemCount: visibleCount,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: separatorHeight),
                              itemBuilder: (_, i) => _GateCard(
                                key: ValueKey(visibleGates[i].id),
                                doc: visibleGates[i],
                                allEvents: widget.allEvents,
                                collapsedHeight: collapsedHeight,
                              ),
                            );
                          },
                        ),
                      ),
                      if (totalPages > 1)
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFE8EAF2)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _PaginationButton(
                                icon: Icons.chevron_left_rounded,
                                enabled: currentPage > 0,
                                onTap: () => setState(
                                  () => _currentPage = currentPage - 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              ..._buildPageButtons(totalPages, currentPage),
                              const SizedBox(width: 4),
                              _PaginationButton(
                                icon: Icons.chevron_right_rounded,
                                enabled: currentPage < totalPages - 1,
                                onTap: () => setState(
                                  () => _currentPage = currentPage + 1,
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

// -----------------------------------------------------------------------
//  _GateCard
// -----------------------------------------------------------------------

class _GateCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final List<QueryDocumentSnapshot> allEvents;
  final double? collapsedHeight;

  const _GateCard({
    super.key,
    required this.doc,
    required this.allEvents,
    this.collapsedHeight,
  });

  @override
  State<_GateCard> createState() => _GateCardState();
}

class _GateCardState extends State<_GateCard> {
  final AdminApi _api = AdminApi();
  bool _isExpanded = false;
  bool _actionBusy = false;

  Future<void> _showSettingsDialog() async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final username = (data['username'] ?? data['fullName'] ?? widget.doc.id)
        .toString();
    var currentName = (data['fullName'] ?? data['username'] ?? widget.doc.id)
        .toString();
    final email = (data['email'] ?? '').toString().trim();
    final photoUrl = (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString();

    final nameC = TextEditingController(text: currentName);
    var busy = false;
    String? msg;
    bool msgIsError = false;

    Future<void> saveName(StateSetter setDialogState) async {
      final newName = nameC.text.trim();
      if (newName.isEmpty || newName == currentName) return;

      setDialogState(() {
        busy = true;
        msg = null;
      });
      setState(() => _actionBusy = true);

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.doc.id)
            .update({
              'fullName': newName,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        if (!mounted) return;

        setDialogState(() {
          busy = false;
          currentName = newName;
          msg = 'The name was changed to "$newName".';
          msgIsError = false;
        });
      } catch (e) {
        if (!mounted) return;

        setDialogState(() {
          busy = false;
          msg = e.toString().replaceFirst('Exception: ', '');
          msgIsError = true;
        });
      } finally {
        if (mounted) {
          setState(() => _actionBusy = false);
        }
      }
    }

    Future<void> deleteTurnstile(
      BuildContext dialogContext,
      StateSetter setDialogState,
    ) async {
      // Capture navigator before any async gaps so it stays valid
      // even after the Firestore stream triggers a rebuild.
      final nav = Navigator.of(context);
      final confirmed = await _showBlurDialog<bool>(
        context: dialogContext,
        barrierDismissible: true,
        barrierLabel: 'Confirm turnstile deletion',
        builder: (confirmContext) => SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0D0D8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFB03040),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delete turnstile',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2848B0),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'The confirmation is permanent and will delete the turnstile account and its associated data.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Color(0xFF7A7E9A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F8),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE8EAF2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selected turnstile',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: Color(0xFF7A7E9A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0D0D8),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  currentName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB03040),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                username,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7A7E9A),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(confirmContext).pop(false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFE8EAF2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFB03040),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(confirmContext).pop(true),
                                child: const Text('Delete turnstile'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      if (confirmed != true) return;

      setDialogState(() {
        busy = true;
        msg = null;
      });
      setState(() => _actionBusy = true);
      try {
        await _api.deleteUser(username: username);
        if (!mounted) return;
        nav.pop();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Turnstile $username has been deleted.')),
        );
      } catch (e) {
        if (!mounted) return;

        setDialogState(() {
          busy = false;
          msg = e.toString().replaceFirst('Exception: ', '');
          msgIsError = true;
        });
      } finally {
        if (mounted) setState(() => _actionBusy = false);
      }
    }

    Future<void> resetPassword(StateSetter setDialogState) async {
      final newPass = randPassword(10);

      setDialogState(() {
        busy = true;
        msg = null;
      });
      setState(() => _actionBusy = true);

      try {
        final excel = xls.Excel.createExcel();
        final sheet = excel['Turnstile'];
        sheet.appendRow([
          xls.TextCellValue('Full Name'),
          xls.TextCellValue('Username'),
          xls.TextCellValue('Email'),
          xls.TextCellValue('New Password'),
        ]);
        sheet.appendRow([
          xls.TextCellValue(currentName),
          xls.TextCellValue(username),
          xls.TextCellValue(email.isEmpty ? '-' : email),
          xls.TextCellValue(newPass),
        ]);

        final bytes = excel.encode();
        if (bytes != null) {
          await FileSaver.instance.saveFile(
            name: 'turnstile_$username',
            bytes: Uint8List.fromList(bytes),
            ext: 'xlsx',
            mimeType: MimeType.microsoftExcel,
          );
        }

        await _api.resetPassword(username: username, newPassword: newPass);
        if (!mounted) return;

        setDialogState(() {
          busy = false;
          msg = 'Data exported and the password has been reset automatically.';
          msgIsError = false;
        });
      } catch (e) {
        if (!mounted) return;

        setDialogState(() {
          busy = false;
          msg = e.toString().replaceFirst('Exception: ', '');
          msgIsError = true;
        });
      } finally {
        if (mounted) {
          setState(() => _actionBusy = false);
        }
      }
    }

    await _showBlurDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          InputDecoration fieldDeco(String hint) => InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: const Color(0xFFF2F4F8),
          );

          final initials = currentName
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

          return PopScope(
            canPop: !busy,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 55,
                vertical: 16,
              ),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 860,
                  minHeight: 620,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 18, 30, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'User Settings',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2848B0),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: busy ? null : () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF7A7E9A),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    final newName = nameC.text.trim();
                                    if (newName.isNotEmpty &&
                                        newName != currentName) {
                                      await saveName(setDialogState);
                                      return;
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2848B0),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Save changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 18, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (msg != null) ...[
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 560,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: msgIsError
                                                    ? const Color(0xFFF0D0D8)
                                                    : const Color(0xFFE8EAF2),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: msgIsError
                                                      ? const Color(0xFFB03040)
                                                      : const Color(0xFF2848B0),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    msgIsError
                                                        ? Icons.error_outline
                                                        : Icons
                                                              .check_circle_outline,
                                                    size: 16,
                                                    color: msgIsError
                                                        ? const Color(
                                                            0xFFB03040,
                                                          )
                                                        : const Color(
                                                            0xFF5F9CCF,
                                                          ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: SelectableText(
                                                      msg!,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: msgIsError
                                                            ? const Color(
                                                                0xFFB71C1C,
                                                              )
                                                            : const Color(
                                                                0xFF2848B0,
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        const Text(
                                          'Turnstile Details',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF2848B0),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'You can update the displayed name and quickly manage account access from the actions below.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.45,
                                            color: Color(0xFF87A0B5),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'FULL NAME',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                            color: Color(0xFF2848B0),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: double.infinity,
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8EAF2),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: TextField(
                                            controller: nameC,
                                            enabled: !busy,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF000000),
                                            ),
                                            decoration: InputDecoration(
                                              hintText: currentName,
                                              hintStyle: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF000000),
                                              ),
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                            ),
                                            onSubmitted: (val) async {
                                              if (busy) return;
                                              final newName = val.trim();
                                              if (newName.isEmpty ||
                                                  newName == currentName) {
                                                return;
                                              }
                                              await saveName(setDialogState);
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'USERNAME',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 1,
                                                      color: Color(0xFF2848B0),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  TextField(
                                                    enabled: false,
                                                    controller:
                                                        TextEditingController(
                                                          text: username,
                                                        ),
                                                    decoration: fieldDeco(''),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Color(0xFF1A2050),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'USER TYPE',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 1,
                                                      color: Color(0xFF2848B0),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  TextField(
                                                    enabled: false,
                                                    controller:
                                                        TextEditingController(
                                                          text:
                                                              'Access turnstile',
                                                        ),
                                                    decoration: fieldDeco(''),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Color(0xFF1A2050),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 132,
                                  child: Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: 16,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundColor: const Color(
                                          0xFFCFDFEB,
                                        ),
                                        backgroundImage: photoUrl.isNotEmpty
                                            ? NetworkImage(photoUrl)
                                            : null,
                                        child: photoUrl.isEmpty
                                            ? Text(
                                                initials.isNotEmpty
                                                    ? initials
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Color(0xFF1A2050),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 27,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: Center(
                                child: ElevatedButton.icon(
                                  icon: busy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.download_outlined,
                                          size: 18,
                                        ),
                                  label: const Text(
                                    'Export Data / Reset Password',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB03040),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 36,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () => resetPassword(setDialogState),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Divider(height: 1, color: Color(0xFFE8EAF2)),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: Center(
                                child: TextButton.icon(
                                  icon: busy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFB03040),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_outline,
                                          size: 22,
                                        ),
                                  label: const Text('Delete User'),
                                  style: ButtonStyle(
                                    foregroundColor:
                                        WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.disabled,
                                          )) {
                                            return const Color(0xFFB03040);
                                          }
                                          return const Color(0xFFB03040);
                                        }),
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.hovered,
                                          )) {
                                            return const Color(0xFFF0D0D8);
                                          }
                                          if (states.contains(
                                            WidgetState.pressed,
                                          )) {
                                            return const Color(0xFFF0D0D8);
                                          }
                                          return Colors.transparent;
                                        }),
                                    overlayColor:
                                        WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                                WidgetState.hovered,
                                              ) ||
                                              states.contains(
                                                WidgetState.pressed,
                                              )) {
                                            return Colors.transparent;
                                          }
                                          return null;
                                        }),
                                    elevation: const WidgetStatePropertyAll(0),
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 18,
                                      ),
                                    ),
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    textStyle: const WidgetStatePropertyAll(
                                      TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () => deleteTurnstile(
                                          ctx,
                                          setDialogState,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    nameC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final gateName = (data['fullName'] ?? data['username'] ?? widget.doc.id)
        .toString();
    final gateUsername = (data['username'] ?? widget.doc.id).toString();
    final isOnline = (data['status'] ?? 'active') != 'disabled';

    final gateScans = widget.allEvents
        .where((e) {
          final d = e.data() as Map<String, dynamic>;
          return (d['gateUid'] ?? '') == widget.doc.id;
        })
        .take(3)
        .toList();

    void toggle() => setState(() => _isExpanded = !_isExpanded);

    return Container(
      constraints: widget.collapsedHeight == null
          ? null
          : BoxConstraints(minHeight: widget.collapsedHeight!),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3ECF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gate header row
            InkWell(
              onTap: toggle,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFFE8EAF2)
                            : const Color(0xFFF5F0E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.door_front_door_rounded,
                        color: isOnline
                            ? const Color(0xFF2848B0)
                            : const Color(0xFFA08030),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  gateName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Color(0xFF2848B0),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'username: $gateUsername',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _actionBusy ? null : _showSettingsDialog,
                      tooltip: 'Turnstile settings',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF2F4F8),
                        foregroundColor: const Color(0xFF7A7E9A),
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _actionBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF7A7E9A),
                              ),
                            )
                          : const Icon(Icons.settings_rounded, size: 18),
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: Color(0xFF7A7E9A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Last 3 scans
            if (_isExpanded && gateScans.isNotEmpty)
              _LastScansSection(docs: gateScans),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
//  _LastScansSection
// -----------------------------------------------------------------------

class _LastScansSection extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;

  const _LastScansSection({required this.docs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: Color(0xFFE8EAF2)),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            'LAST 3 SCANS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A7E9A),
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...docs.map((e) {
          final d = e.data() as Map<String, dynamic>;
          final fullName = (d['fullName'] ?? '').toString();
          final ts = d['timestamp'] as Timestamp?;
          final isDenied = (d['type'] ?? '') == 'deny' || fullName.isEmpty;
          final parts = fullName
              .trim()
              .split(RegExp(r'\s+'))
              .where((p) => p.isNotEmpty)
              .toList();
          final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                isDenied
                    ? Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE8E8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.block_rounded,
                          size: 14,
                          color: Color(0xFF6B1A1A),
                        ),
                      )
                    : Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6E4F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials.isEmpty ? '?' : initials,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2848B0),
                          ),
                        ),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fullName.isEmpty ? 'Unknown ID label' : fullName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDenied
                          ? const Color(0xFF6B1A1A)
                          : const Color(0xFF4A82B3),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDenied)
                  const Text(
                    'DENIED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B1A1A),
                    ),
                  )
                else if (ts != null)
                  Text(
                    _hhmm(ts),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7A7E9A),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// -----------------------------------------------------------------------
//  _LiveTrafficPanel
// -----------------------------------------------------------------------

class _LiveTrafficPanel extends StatelessWidget {
  final List<QueryDocumentSnapshot> events;
  final Map<String, String> gateMap;
  final Map<String, String> studentClassMap;
  final Map<String, String> studentNameMap;
  final List<QueryDocumentSnapshot> allEvents;

  const _LiveTrafficPanel({
    required this.events,
    required this.gateMap,
    required this.studentClassMap,
    required this.studentNameMap,
    required this.allEvents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.sensors_rounded,
                  color: Color(0xFF2848B0),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Real-time traffic',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2848B0),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EAF2)),

          // Events list
          Expanded(
            child: events.isEmpty
                ? const Center(
                    child: Text(
                      'No recent activity.',
                      style: TextStyle(color: Color(0xFF7A7E9A), fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: events.length,
                    itemBuilder: (_, i) {
                      final d = events[i].data() as Map<String, dynamic>;
                      final gateUid = (d['gateUid'] ?? '').toString();
                      final gateName = gateMap[gateUid] ?? 'Unknown gate';
                      final userId = (d['userId'] ?? '').toString();
                      final fullName = (d['fullName'] ?? '').toString();
                      final fallbackName = studentNameMap[userId] ?? '';
                      final fallbackClassId = studentClassMap[userId] ?? '';
                      final ts = d['timestamp'] as Timestamp?;
                      final isDenied =
                          (d['type'] ?? '') == 'deny' || fullName.isEmpty;

                      return _TrafficEntry(
                        gateName: gateName,
                        personName: fullName.isEmpty
                            ? (fallbackName.isEmpty
                                  ? 'Unregistered subject detected'
                                  : fallbackName)
                            : fullName,
                        actionLabel: _eventActionLabel(d),
                        reasonText: _eventReasonText(d),
                        metaText: _eventMetaText(
                          d,
                          fallbackClassId: fallbackClassId,
                        ),
                        timeAgo: ts != null ? _timeAgo(ts) : '',
                        isDenied: isDenied,
                        showConnector: i != events.length - 1,
                      );
                    },
                  ),
          ),

          // Button for all logs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: Color(0xFFC6D6E3)),
                foregroundColor: const Color(0xFF2848B0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showAllLogsDialog(
                context,
                allEvents,
                gateMap,
                studentClassMap,
                studentNameMap,
              ),
              child: const Text(
                'See all logs',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
//  _TrafficEntry
// -----------------------------------------------------------------------

class _TrafficEntry extends StatelessWidget {
  final String gateName;
  final String personName;
  final String actionLabel;
  final String reasonText;
  final String metaText;
  final String timeAgo;
  final bool isDenied;
  final bool showConnector;

  const _TrafficEntry({
    required this.gateName,
    required this.personName,
    required this.actionLabel,
    required this.reasonText,
    required this.metaText,
    required this.timeAgo,
    required this.isDenied,
    this.showConnector = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isDenied
                        ? const Color(0xFFB03040)
                        : const Color(0xFF2848B0),
                    shape: BoxShape.circle,
                  ),
                ),
                if (showConnector)
                  Container(
                    width: 2,
                    height: 86,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: isDenied
                          ? const Color(0xFFE7C8D3)
                          : const Color(0xFFC9DCEC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        gateName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF2848B0),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A7E9A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: isDenied
                        ? const Color(0xFFFDF2F4)
                        : const Color(0xFFF2F4F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF5987AF),
                          ),
                          children: [
                            const TextSpan(
                              text: 'User: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5987AF),
                              ),
                            ),
                            TextSpan(text: personName),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            isDenied
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 14,
                            color: isDenied
                                ? const Color(0xFFB03040)
                                : const Color(0xFF2848B0),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              actionLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDenied
                                    ? const Color(0xFFB03040)
                                    : const Color(0xFF2848B0),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reasonText,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF7A7E9A),
                        ),
                      ),
                      if (metaText.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 13,
                              color: Color(0xFF7A7E9A),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                metaText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7A7E9A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

// -----------------------------------------------------------------------
//  _DailyScansCard
// -----------------------------------------------------------------------

class _DailyScansCard extends StatelessWidget {
  final int todayCount;
  final int yesterdayCount;

  const _DailyScansCard({
    required this.todayCount,
    required this.yesterdayCount,
  });

  static String _fmt(int n) {
    if (n < 1000) return '$n';
    final t = n ~/ 1000;
    final r = n % 1000;
    return '$t,${r.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final double pct;
    if (yesterdayCount == 0) {
      pct = todayCount > 0 ? 100.0 : 0.0;
    } else {
      pct = ((todayCount - yesterdayCount) / yesterdayCount * 100).abs();
    }

    final isUp = todayCount >= yesterdayCount;
    final pctStr = '${pct.toStringAsFixed(0)}%';

    String trendText;
    if (pct < 0.5) {
      trendText = 'No change from yesterday';
    } else if (isUp) {
      trendText = 'Increase of $pctStr from yesterday';
    } else {
      trendText = 'Decrease of $pctStr from yesterday';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2848B0), Color(0xFF4A7FD4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2848B0).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL DAILY SCANS',
            style: TextStyle(
              color: Color(0xFFAEC6F0),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _fmt(todayCount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                pct < 0.5
                    ? Icons.trending_flat_rounded
                    : (isUp
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded),
                color: pct < 0.5
                    ? const Color(0xFFAEC6F0)
                    : (isUp
                          ? const Color(0xFF7EEAAA)
                          : const Color(0xFFFF9090)),
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  trendText,
                  style: TextStyle(
                    color: pct < 0.5
                        ? const Color(0xFFAEC6F0)
                        : (isUp
                              ? const Color(0xFF7EEAAA)
                              : const Color(0xFFFF9090)),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
//  Dialog All Logs
// -----------------------------------------------------------------------

void _showAllLogsDialog(
  BuildContext context,
  List<QueryDocumentSnapshot> fallbackEvents,
  Map<String, String> gateMap,
  Map<String, String> studentClassMap,
  Map<String, String> studentNameMap,
) {
  _showBlurDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 740, maxHeight: 840),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 48,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(28, 24, 24, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(bottom: BorderSide(color: Color(0xFFE8EAF2))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF1FB),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.sensors_rounded,
                      color: Color(0xFF2848B0),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Access logs',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2050),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Last 100 events · updates in real time',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9BA3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF1FB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFBFD1E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sensors_rounded,
                          size: 13,
                          color: Color(0xFF2848B0),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2848B0),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF7A7E9A),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Logs
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('accessEvents')
                    .orderBy('timestamp', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snap) {
                  final docs = List<QueryDocumentSnapshot>.from(
                    snap.data?.docs ?? fallbackEvents,
                  );
                  if (snap.connectionState == ConnectionState.waiting &&
                      docs.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2848B0),
                      ),
                    );
                  }
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF1FB),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              size: 28,
                              color: Color(0xFF2848B0),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No access events yet',
                            style: TextStyle(
                              color: Color(0xFF1A2050),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Events will appear here as they happen',
                            style: TextStyle(
                              color: Color(0xFF9BA3B8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final gateUid = (d['gateUid'] ?? '').toString();
                      final gateName = gateMap[gateUid] ?? 'Unknown gate';
                      final userId = (d['userId'] ?? '').toString();
                      final fullName = (d['fullName'] ?? '').toString();
                      final fallbackName = studentNameMap[userId] ?? '';
                      final fallbackClassId = studentClassMap[userId] ?? '';
                      final ts = d['timestamp'] as Timestamp?;
                      final isDenied =
                          (d['type'] ?? '') == 'deny' || fullName.isEmpty;
                      final personName = fullName.isEmpty
                          ? (fallbackName.isEmpty
                                ? 'Unregistered subject detected'
                                : fallbackName)
                          : fullName;
                      final actionLabel = _eventActionLabel(d);
                      final reasonText = _eventReasonText(d);
                      final metaText = _eventMetaText(
                        d,
                        fallbackClassId: fallbackClassId,
                      );
                      final timeStr = ts != null ? _timeAgo(ts) : '';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDenied
                              ? const Color(0xFFFFF8F8)
                              : const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDenied
                                ? const Color(0xFFEDD4D4)
                                : const Color(0xFFD4E3F5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isDenied
                                    ? const Color(0xFFF0D0D8)
                                    : const Color(0xFFEEF1FB),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                isDenied
                                    ? Icons.block_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 19,
                                color: isDenied
                                    ? const Color(0xFFB03040)
                                    : const Color(0xFF2848B0),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          personName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111111),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDenied
                                              ? const Color(0xFFF0D0D8)
                                              : const Color(0xFFD4E3F5),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          actionLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isDenied
                                                ? const Color(0xFFB03040)
                                                : const Color(0xFF2848B0),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (metaText.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      metaText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7A7E9A),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.door_front_door_rounded,
                                        size: 12,
                                        color: Color(0xFFB0B8C8),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        gateName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFB0B8C8),
                                        ),
                                      ),
                                      if (reasonText.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        const Text(
                                          '·',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFB0B8C8),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            reasonText,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFB0B8C8),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ] else
                                        const Spacer(),
                                      if (timeStr.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          timeStr,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFB0B8C8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFFE8EAF2) : const Color(0xFFE8EAF2),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? const Color(0xFF1A2050) : const Color(0xFFC0C4D8),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
//  _TurnstilesSidebar
// -----------------------------------------------------------------------

class _TurnstilesSidebar extends StatelessWidget {
  final String selected;
  final VoidCallback onMenuTap;
  final VoidCallback onStudentsTap;
  final VoidCallback onPersonalTap;
  final VoidCallback onTurnichetiTap;
  final VoidCallback onClaseTap;
  final VoidCallback onVacanteTap;
  final VoidCallback onParintiTap;
  final VoidCallback onLogoutTap;

  const _TurnstilesSidebar({
    required this.selected,
    required this.onMenuTap,
    required this.onStudentsTap,
    required this.onPersonalTap,
    required this.onTurnichetiTap,
    required this.onClaseTap,
    required this.onVacanteTap,
    required this.onParintiTap,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (AppSession.fullName?.isNotEmpty ?? false)
        ? AppSession.fullName!
        : (AppSession.username ?? 'Admin');

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2848B0), Color(0xFF2848B0)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'Office',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _SidebarTile(
            label: 'Menu',
            icon: Icons.grid_view_rounded,
            selected: selected == 'menu',
            onTap: onMenuTap,
          ),
          _SidebarTile(
            label: 'Students',
            icon: Icons.school_rounded,
            selected: selected == 'students',
            onTap: onStudentsTap,
          ),
          _SidebarTile(
            label: 'Staff',
            icon: Icons.badge_rounded,
            selected: selected == 'personal',
            onTap: onPersonalTap,
          ),
          _SidebarTile(
            label: 'Parents',
            icon: Icons.family_restroom_rounded,
            selected: selected == 'parents',
            onTap: onParintiTap,
          ),
          _SidebarTile(
            label: 'Classes',
            icon: Icons.table_chart_rounded,
            selected: selected == 'classes',
            onTap: onClaseTap,
          ),
          _SidebarTile(
            label: 'Holidays',
            icon: Icons.event_available_rounded,
            selected: selected == 'holidays',
            onTap: onVacanteTap,
          ),
          _SidebarTile(
            label: 'Guardians',
            icon: Icons.door_front_door_rounded,
            selected: selected == 'turnstiles',
            onTap: onTurnichetiTap,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1988E6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: onLogoutTap,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
              ),
            ),
          ),

          const SizedBox(height: 10),
          // User card at bottom
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7E2C5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7A4A10),
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Central High School',
                        style: TextStyle(
                          color: Color(0xFFE8EAF2),
                          fontSize: 11,
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

// -----------------------------------------------------------------------
//  _SidebarTile
// -----------------------------------------------------------------------

class _SidebarTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.17)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFE8EAF2), size: 18),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFE8EAF2),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
//  _TurnstilesTopBar
// -----------------------------------------------------------------------

class _TurnstilesTopBar extends StatelessWidget {
  final String displayName;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;

  const _TurnstilesTopBar({
    required this.displayName,
    required this.searchController,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3CA0), Color(0xFF2E58D0), Color(0xFF4070E0)],
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Guardians',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4395DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: Color(0xFFC0C4D8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearch,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: 'Search by name...',
                            hintStyle: TextStyle(
                              color: Color(0xFFC0C4D8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          cursorColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const AdminNotificationBell(),
        ],
      ),
    );
  }
}
