import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_api.dart';
import 'services/admin_store.dart';
import 'admin_classes_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_parents_page.dart';
import 'admin_turnstiles_page.dart';
import 'admin_posts_announcements_page.dart';
import 'admin_timetable_page.dart';
import 'widgets/admin_create_user_dialog.dart';
import '../services/security_flags_service.dart';
import '../core/session.dart';

class SecretariatRawPage extends StatefulWidget {
  const SecretariatRawPage({super.key});

  @override
  State<SecretariatRawPage> createState() => _SecretariatRawPageState();
}

class _SecretariatRawPageState extends State<SecretariatRawPage> {
  final api = AdminApi();
  final store = AdminStore();
  String activeSidebarLabel = "Menu";
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  String get _globalSearchQuery => _searchQueryNotifier.value;
  set _globalSearchQuery(String v) => _searchQueryNotifier.value = v;

  // create user
  final fullNameC = TextEditingController();
  final usernameC = TextEditingController();
  final passwordC = TextEditingController();
  String selectedCreateUserClassId = "";

  String role = "student";

  // actions
  final targetUserC = TextEditingController();
  final targetUserFullNameC = TextEditingController();
  final targetUserNewPasswordC = TextEditingController();
  String selectedMoveClassId = "";

  // assign parents
  Map<String, String>? selectedAssignStudent; // {'id': uid, 'name': display}
  Map<String, String>? selectedAssignParent; // {'id': uid, 'name': display}

  // class
  int selectedNumber = 9;
  String selectedLetter = "A";

  String log = "";
  final Set<String> _busyActions = <String>{};

  // top bar search
  final _topSearchController = TextEditingController();
  final FocusNode _topSearchFocus = FocusNode();
  final LayerLink _topSearchLink = LayerLink();
  final OverlayPortalController _topSearchOverlay =
      OverlayPortalController();

  void _log(String s) => setState(() => log = "$s\n$log");

  void _logSuccess(String message) {
    _log("OK: $message");
  }

  void _logFailure(String message) {
    _log("ERROR: $message");
  }

  void _showInfoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(String operation) {
    switch (operation) {
      case 'create-user':
        return 'The user could not be created.';
      case 'create-class':
        return 'The class could not be created.';
      case 'delete-class':
        return 'The class could not be deleted.';
      case 'reset-password':
        return 'The password could not be reset.';
      case 'disable-user':
        return 'The account could not be disabled.';
      case 'enable-user':
        return 'The account could not be enabled.';
      case 'move-user':
        return 'The user could not be moved to the selected class.';
      case 'delete-user':
        return 'The user could not be deleted.';
      case 'rename-user':
        return 'The user\'s name could not be updated.';
      case 'assign-parent':
        return 'The parent could not be assigned to the student.';
      case 'remove-parent':
        return 'The parent could not be removed from the student.';
      case 'toggle-onboarding-global':
        return 'The global onboarding setting could not be updated.';
      case 'toggle-2fa-global':
        return 'The global 2FA setting could not be updated.';
      default:
        return 'The operation could not be completed.';
    }
  }

  bool _isActionBusy(String key) => _busyActions.contains(key);

  Future<void> _runGuarded(
    String key,
    Future<void> Function() action, {
    StateSetter? onBusyChanged,
  }) async {
    if (_busyActions.contains(key)) return;
    setState(() => _busyActions.add(key));
    onBusyChanged?.call(() {});
    try {
      await action();
    } finally {
      _busyActions.remove(key);
      if (mounted) setState(() {});
      onBusyChanged?.call(() {});
    }
  }

  Future<void> _showLogoutDialog() async {
    const Color primaryGreen = Color(0xFF2848B0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "Sign Out",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        content: const Text(
          "Are you sure you want to sign out?",
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "No",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text(
              "Yes",
              style: TextStyle(
                color: primaryGreen,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFullActivityLog(BuildContext context) async {
    const Color primaryBlue = Color(0xFF2848B0);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Admin activity log',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 520,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.68,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Admin Activity Log",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A2050),
                              fontSize: 18,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 22),
                            onPressed: () => Navigator.of(context).pop(),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE8EAF2)),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('secretariatActivity')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, activitySnap) {
                          if (activitySnap.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'Error loading activity: ${activitySnap.error}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }

                          if (activitySnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }

                          final entries = activitySnap.data?.docs ?? [];

                          if (entries.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'No activity logged yet.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A2050),
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            itemCount: entries.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: Color(0xFFE8EAF2),
                            ),
                            itemBuilder: (context, index) {
                              final doc = entries[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final createdAt =
                                  (data['createdAt'] as Timestamp?)?.toDate();
                              final time = createdAt == null
                                  ? '--:--'
                                  : '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
                              final title =
                                  (data['message'] ?? data['title'] ?? '')
                                      .toString();
                              final subtitle =
                                  (data['detail'] ?? data['subtitle'] ?? '')
                                      .toString();

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 54,
                                      child: Text(
                                        time,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1A2050),
                                            ),
                                          ),
                                          if (subtitle.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              subtitle,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF7A7E9A),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
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
          ),
        );
      },
    );
  }

  Future<void> _showCreateUserPopup() async {
    await showAdminCreateUserDialog(context);
  }

  Future<void> _ensureRecentAdminActivityDoc() async {
    try {
      final collection = FirebaseFirestore.instance.collection(
        'secretariatActivity',
      );
      final snapshot = await collection.limit(1).get();
      if (snapshot.docs.isEmpty) {
        await collection.add({
          'title': 'Recent admin activity',
          'subtitle': 'Secretariat actions',
          'message': 'Welcome to the new Secretariat activity log.',
          'detail': 'Recent actions will appear here once they are recorded.',
          'createdAt': Timestamp.now(),
        });
      }
    } catch (e, st) {
      debugPrint('secretariat_raw_page: seed secretariat activity log: $e\n$st');
    }
  }

  Future<void> _recordSecretariatActivity({
    required String message,
    required String detail,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('secretariatActivity').add({
        'title': message,
        'subtitle': 'Secretariat actions',
        'message': message,
        'detail': detail,
        'createdAt': Timestamp.now(),
      });
      debugPrint('Activity logged: $message');
    } catch (e) {
      debugPrint('Failed to log activity: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureRecentAdminActivityDoc();
    _topSearchFocus.addListener(_handleTopSearchFocusChange);
  }

  void _handleTopSearchFocusChange() {
    if (_topSearchFocus.hasFocus) {
      if (_globalSearchQuery.isNotEmpty) _topSearchOverlay.show();
    } else {
      // delay so a tap on a result registers before the overlay closes
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        if (!_topSearchFocus.hasFocus) _topSearchOverlay.hide();
      });
    }
  }

  Widget _buildTopSearchOverlay(BuildContext context) {
    return Positioned(
      width: 360,
      child: CompositedTransformFollower(
        link: _topSearchLink,
        targetAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topRight,
        offset: const Offset(0, 6),
        showWhenUnlinked: false,
        child: TapRegion(
          onTapOutside: (_) => _topSearchOverlay.hide(),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: _TopSearchResults(
                queryListenable: _searchQueryNotifier,
                onSelect: _handleTopSearchResultTap,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTopSearchResultTap(_TopSearchHit hit) {
    _topSearchOverlay.hide();
    _topSearchFocus.unfocus();
    final String label = switch (hit.kind) {
      _TopSearchKind.student => 'Students',
      _TopSearchKind.teacher => 'Teachers',
      _TopSearchKind.parent => 'Parents',
      _TopSearchKind.classRoom => 'Classes',
    };
    setState(() {
      activeSidebarLabel = label;
      // For users we pre-fill the per-page search by name. Classes have no
      // searchQuery prop on AdminClassesPage today, so we just navigate there.
      if (hit.kind == _TopSearchKind.classRoom) {
        _globalSearchQuery = '';
        _topSearchController.clear();
      } else {
        _globalSearchQuery = hit.searchTerm;
        _topSearchController.text = hit.searchTerm;
      }
    });
  }

  @override
  void dispose() {
    fullNameC.dispose();
    usernameC.dispose();
    passwordC.dispose();
    targetUserC.dispose();
    targetUserFullNameC.dispose();
    targetUserNewPasswordC.dispose();
    _topSearchController.dispose();
    _topSearchFocus.removeListener(_handleTopSearchFocusChange);
    _topSearchFocus.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color surfaceColor = Color(0xFFF2F4F8);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 270,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF2040A0),
                            Color(0xFF2848B0),
                            Color(0xFF2E58D0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(left: -45, top: -45, child: _bubble(160, 0.09)),
                  Positioned(right: -60, bottom: 60, child: _bubble(200, 0.06)),
                  Positioned(left: -20, bottom: 180, child: _bubble(90, 0.07)),
                  Container(
                    width: 270,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 20,
                                    bottom: 16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Secretariat',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 28,
                                        height: 2.5,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5C518),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Column(
                                  children: [
                                    _buildSidebarItem(
                                      icon: Icons.grid_view_rounded,
                                      label: "Menu",
                                      onTap: () => _goTo("Menu"),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.school_rounded,
                                      label: "Students",
                                      onTap: () => _goTo('Students'),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.badge_rounded,
                                      label: "Teachers",
                                      onTap: () => _goTo('Teachers'),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.family_restroom_rounded,
                                      label: "Parents",
                                      onTap: () => _goTo('Parents'),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.table_chart_rounded,
                                      label: "Classes",
                                      onTap: () => _goTo('Classes'),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.door_front_door_rounded,
                                      label: "Guardians",
                                      onTap: () => _goTo('Guardians'),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.dynamic_feed_rounded,
                                      label: "Posts",
                                      onTap: () => _goTo('Posts'),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.calendar_month_rounded,
                                      label: "Schedules",
                                      onTap: () => _goTo('Schedules'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _showLogoutDialog,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white24,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // White top bar
                Container(
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE8EAF2)),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // Left: breadcrumb + school name + yellow bar
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'SECRETARIAT',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF7A7E9A),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: Color(0xFF7A7E9A),
                                ),
                              ),
                              Text(
                                activeSidebarLabel.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2848B0),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                'Tudor Vianu · 2025/26',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A2050),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 32,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5C518),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Right side: search bar (fixed width, not full stretch)
                      CompositedTransformTarget(
                        link: _topSearchLink,
                        child: OverlayPortal(
                          controller: _topSearchOverlay,
                          overlayChildBuilder: _buildTopSearchOverlay,
                          child: SizedBox(
                            width: 300,
                            height: 42,
                            child: TextField(
                              controller: _topSearchController,
                              focusNode: _topSearchFocus,
                              decoration: InputDecoration(
                                hintText:
                                    'Search students, teachers, classes...',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF7A7E9A),
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: Color(0xFF7A7E9A),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF2F4F8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE8EAF2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE8EAF2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2848B0),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onChanged: (v) {
                                final trimmed = v.trim();
                                _searchQueryNotifier.value = trimmed;
                                if (trimmed.isEmpty) {
                                  _topSearchOverlay.hide();
                                } else if (_topSearchFocus.hasFocus &&
                                    !_topSearchOverlay.isShowing) {
                                  _topSearchOverlay.show();
                                }
                              },
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1A2050),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right: New post button
                      FilledButton.icon(
                        onPressed: () => _goTo('Posts'),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          '+ New post',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2848B0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: activeSidebarLabel != 'Menu'
                      ? _buildEmbeddedPage(activeSidebarLabel)
                      : Container(
                          color: surfaceColor,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // STATISTICS
                                if (activeSidebarLabel == 'Menu') ...[
                                  const SizedBox(height: 12),
                                  _buildStatsRow(),
                                  const SizedBox(height: 20),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 46,
                                    ),
                                    child: _buildStatCards(),
                                  ),
                                  const SizedBox(height: 28),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 46,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: _buildClassDistributionCard(),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 1,
                                          child:
                                              _buildRecentAdminActivityCard(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 46,
                                    ),
                                    child: _buildRecentPostsCard(),
                                  ),
                                  const SizedBox(height: 28),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 46,
                                    ),
                                    child: _buildGlobalSecurityControls(),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required Color primaryGreen,
    required Widget child,
    bool hasBorder = false,
  }) {
    const Color darkGreen = Color(0xFF2848B0);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasBorder ? const Color(0xFFE8EAF2) : const Color(0xFFE8EAF2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withValues(alpha: 0.06),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ColoredBox(
              color: const Color(0xFFF2F5F8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2848B0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Color(0xFFE8EAF2), height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedPage(String label) {
    switch (label) {
      case 'Classes':
        return const AdminClassesPage(embedded: true);
      case 'Students':
        return ValueListenableBuilder<String>(
          valueListenable: _searchQueryNotifier,
          builder: (_, q, _) => AdminStudentsPage(
            key: const ValueKey('students-page-v2'),
            searchQuery: q,
          ),
        );
      case 'Parents':
        return ValueListenableBuilder<String>(
          valueListenable: _searchQueryNotifier,
          builder: (_, q, _) => AdminParentsPage(searchQuery: q),
        );
      case 'Teachers':
        return ValueListenableBuilder<String>(
          valueListenable: _searchQueryNotifier,
          builder: (_, q, _) => AdminTeachersPage(searchQuery: q),
        );
      case 'Guardians':
        return ValueListenableBuilder<String>(
          valueListenable: _searchQueryNotifier,
          builder: (_, q, _) =>
              AdminTurnstilesPage(embedded: true, searchQuery: q),
        );
      case 'Posts':
        return const AdminPostsAnnouncementsPage(embedded: true);
      case 'Schedules':
        return const AdminTimetablePage(embedded: true);
      default:
        return const SizedBox.shrink();
    }
  }

  void _goTo(String label) {
    setState(() {
      activeSidebarLabel = label;
      _globalSearchQuery = '';
      _topSearchController.clear();
    });
  }

  Widget _buildStatsRow() {
    final adminName = (AppSession.fullName ?? 'Admin').trim().split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('classes').snapshots(),
          builder: (context, classesSnap) {
            final users = usersSnap.data?.docs ?? [];
            final totalElevi = users
                .where(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['role'] == 'student',
                )
                .length;
            final totalDiriginti = users
                .where(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['role'] == 'teacher',
                )
                .length;
            final totalClase = classesSnap.data?.docs.length ?? 0;
            final totalParinti = users
                .where(
                  (d) => (d.data() as Map<String, dynamic>)['role'] == 'parent',
                )
                .length;

            final loaded = usersSnap.hasData && classesSnap.hasData;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 46),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E3CA0),
                      Color(0xFF2E58D0),
                      Color(0xFF4070E0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3CA0).withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // decorative bubbles
                    Positioned(
                      right: -30,
                      top: -40,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 80,
                      bottom: -50,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(36, 28, 36, 28),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // greeting line
                                Text(
                                  '$greeting, $adminName'.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF70A0D8),
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // title
                                const Text(
                                  'School year in session',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // yellow accent bar
                                Container(
                                  width: 40,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5C518),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // stats row
                                if (!loaded)
                                  const Text(
                                    'Loading...',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 28,
                                    runSpacing: 12,
                                    children: [
                                      _bannerStat(
                                        Icons.school_rounded,
                                        '$totalElevi',
                                        'students',
                                      ),
                                      _bannerStat(
                                        Icons.badge_rounded,
                                        '$totalDiriginti',
                                        'teachers',
                                      ),
                                      _bannerStat(
                                        Icons.menu_book_rounded,
                                        '$totalClase',
                                        'classes',
                                      ),
                                      _bannerStat(
                                        Icons.family_restroom_rounded,
                                        '$totalParinti',
                                        'parent accounts',
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: _showCreateUserPopup,
                              borderRadius: BorderRadius.circular(14),
                              splashColor: Colors.white.withValues(alpha: 0.15),
                              highlightColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    width: 1,
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'New User',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('classes').snapshots(),
          builder: (context, classesSnap) {
            final users = usersSnap.data?.docs ?? [];
            final totalStudents = users
                .where(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['role'] == 'student',
                )
                .length;
            final teacherDocs = users
                .where(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['role'] == 'teacher',
                )
                .toList();
            final totalTeachers = teacherDocs.length;
            final awaitingOnboarding = teacherDocs
                .where(
                  (d) =>
                      (d.data()
                          as Map<String, dynamic>)['onboardingComplete'] !=
                      true,
                )
                .length;
            final totalClasses = classesSnap.data?.docs.length ?? 0;
            final totalParents = users
                .where(
                  (d) => (d.data() as Map<String, dynamic>)['role'] == 'parent',
                )
                .length;
            final coverage = totalStudents == 0
                ? 0
                : ((totalParents / totalStudents) * 100).round().clamp(0, 100);

            final loaded = usersSnap.hasData && classesSnap.hasData;

            return Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.person_rounded,
                    iconBg: const Color(0xFFEEF1FB),
                    iconColor: const Color(0xFF2848B0),
                    label: 'STUDENTS',
                    value: loaded ? '$totalStudents' : '—',
                    subtitle: 'Enrolled 2025/26',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _statCard(
                    icon: Icons.school_rounded,
                    iconBg: const Color(0xFFEDF7F0),
                    iconColor: const Color(0xFF2E8B57),
                    label: 'TEACHERS',
                    value: loaded ? '$totalTeachers' : '—',
                    subtitle: loaded && awaitingOnboarding > 0
                        ? '$awaitingOnboarding awaiting onboarding'
                        : 'All onboarded',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _statCard(
                    icon: Icons.menu_book_rounded,
                    iconBg: const Color(0xFFFFF8E8),
                    iconColor: const Color(0xFFF5A623),
                    label: 'CLASSES',
                    value: loaded ? '$totalClasses' : '—',
                    subtitle: 'Active this year',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _statCard(
                    icon: Icons.family_restroom_rounded,
                    iconBg: const Color(0xFFF3EDFB),
                    iconColor: const Color(0xFF7B4FCC),
                    label: 'PARENT ACCTS',
                    value: loaded ? '$totalParents' : '—',
                    subtitle: loaded ? '$coverage% coverage' : '',
                  ),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A7E9A),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A2050),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7A7E9A),
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

  Widget _bannerStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF70A0D8)),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF70A0D8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  int _classSortIndex(String rawLabel) {
    final label = rawLabel.toUpperCase().replaceAll('CLASA', '').trim();
    final romanMatch = RegExp(r'(XII|XI|IX|X|VIII|VII|VI|V)').firstMatch(label);
    final roman = romanMatch?.group(0) ?? '';
    switch (roman) {
      case 'V':
        return 5;
      case 'VI':
        return 6;
      case 'VII':
        return 7;
      case 'VIII':
        return 8;
      case 'IX':
        return 9;
      case 'X':
        return 10;
      case 'XI':
        return 11;
      case 'XII':
        return 12;
      default:
        return 99;
    }
  }

  Widget _buildClassDistributionCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('classes').snapshots(),
          builder: (context, classesSnap) {
            final users = usersSnap.data?.docs ?? <QueryDocumentSnapshot>[];
            final classes = classesSnap.data?.docs ?? <QueryDocumentSnapshot>[];

            // Build maps for fast lookup
            final Map<String, int> studentCountByClass = {};
            final Map<String, String> teacherNameByClass = {};
            for (final u in users) {
              final data = u.data() as Map<String, dynamic>;
              final role = (data['role'] ?? '').toString();
              final classId = (data['classId'] ?? '').toString().trim();
              if (classId.isEmpty) continue;
              if (role == 'student') {
                studentCountByClass[classId] =
                    (studentCountByClass[classId] ?? 0) + 1;
              } else if (role == 'teacher') {
                teacherNameByClass[classId] =
                    (data['displayName'] ?? data['fullName'] ?? 'Prof.')
                        .toString();
              }
            }

            final rows = classes.map((c) {
              final data = c.data() as Map<String, dynamic>;
              final name = (data['name'] ?? c.id).toString();
              return _ClassTableRow(
                classId: c.id,
                className: name,
                teacherName: teacherNameByClass[c.id] ?? '—',
                studentCount: studentCountByClass[c.id] ?? 0,
              );
            }).toList();

            rows.sort((a, b) {
              final ai = _classSortIndex(a.className);
              final bi = _classSortIndex(b.className);
              if (ai != bi) return ai.compareTo(bi);
              return a.className.compareTo(b.className);
            });

            final loaded = usersSnap.hasData && classesSnap.hasData;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8EAF2)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2848B0).withValues(alpha: 0.06),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 22, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Classes',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A2050),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Form masters & headcount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7A7E9A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _goTo('Classes'),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View all',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2848B0),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 15,
                                  color: Color(0xFF2848B0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE8EAF2)),
                    // Column headers
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
                      child: Row(
                        children: const [
                          SizedBox(width: 68),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'CLASS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7A7E9A),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              'FORM MASTER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7A7E9A),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              'STUDENTS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7A7E9A),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          SizedBox(width: 24),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE8EAF2)),
                    if (!loaded)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Loading...',
                          style: TextStyle(color: Color(0xFF7A7E9A)),
                        ),
                      )
                    else if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No classes found.',
                          style: TextStyle(color: Color(0xFF7A7E9A)),
                        ),
                      )
                    else
                      ...rows.take(7).toList().asMap().entries.map((entry) {
                        final i = entry.key;
                        final row = entry.value;
                        return Column(
                          children: [
                            InkWell(
                              onTap: () => _goTo('Classes'),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  14,
                                  20,
                                  14,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 68,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2848B0),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          row.className,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 0),
                                    Expanded(
                                      flex: 3,
                                      child: const SizedBox.shrink(),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        row.teacherName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A2050),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        '${row.studentCount}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A2050),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: Color(0xFFB0B8D0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (i < rows.take(7).length - 1)
                              const Divider(
                                height: 1,
                                indent: 28,
                                endIndent: 28,
                                color: Color(0xFFEEF0F8),
                              ),
                          ],
                        );
                      }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentAdminActivityCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('secretariatActivity')
          .orderBy('createdAt', descending: true)
          .limit(6)
          .snapshots(),
      builder: (context, activitySnap) {
        if (activitySnap.hasError) {
          return _buildCard(
            title: 'Recent admin activity',
            primaryGreen: const Color(0xFF5E96C5),
            child: Text(
              'Error loading activity: ${activitySnap.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final entries = activitySnap.data?.docs ?? [];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EAF2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2848B0).withValues(alpha: 0.06),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 22, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Recent admin activity',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A2050),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Secretariat actions',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7A7E9A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showFullActivityLog(context),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View all',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2848B0),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: Color(0xFF2848B0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE8EAF2)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activitySnap.connectionState ==
                          ConnectionState.waiting)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (entries.isEmpty)
                        const Text(
                          'No recent activity yet.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A2050),
                          ),
                        )
                      else
                        Column(
                          children: entries.asMap().entries.map((entry) {
                            final i = entry.key;
                            final doc = entry.value;
                            final data = doc.data() as Map<String, dynamic>;
                            final createdAt = (data['createdAt'] as Timestamp?)
                                ?.toDate();
                            final time = createdAt == null
                                ? '--:--'
                                : '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
                            final title =
                                (data['message'] ?? data['title'] ?? '')
                                    .toString();
                            final subtitle =
                                (data['detail'] ?? data['subtitle'] ?? '')
                                    .toString();
                            return Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 54,
                                      child: Text(
                                        time,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2848B0),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1A2050),
                                            ),
                                          ),
                                          if (subtitle.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              subtitle,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF7A7E9A),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (i < entries.length - 1)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Divider(
                                      color: Color(0xFFE8EAF2),
                                      height: 1,
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentPostsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('secretariatMessages')
          .where('messageType', isEqualTo: 'secretariatGlobal')
          .snapshots(),
      builder: (context, snap) {
        final allDocs = snap.data?.docs ?? [];
        final docs = (List.of(allDocs)
              ..sort((a, b) {
                final ta = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                final tb = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                return tb.compareTo(ta);
              }))
            .take(3)
            .toList();
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EAF2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2848B0).withValues(alpha: 0.06),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 22, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Recent Posts',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A2050),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Latest announcements',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7A7E9A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _goTo('Posts'),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View all',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2848B0),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: Color(0xFF2848B0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE8EAF2)),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (snap.hasError)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading: ${snap.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  )
                else if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No posts yet.',
                      style: TextStyle(color: Color(0xFF7A7E9A)),
                    ),
                  )
                else
                  ...docs.asMap().entries.map((entry) {
                    final i = entry.key;
                    final data = entry.value.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? data['subject'] ?? '').toString();
                    final message = (data['message'] ?? data['body'] ?? '').toString();
                    final ts = (data['createdAt'] as Timestamp?)?.toDate();
                    final dateStr = ts == null
                        ? ''
                        : '${ts.day.toString().padLeft(2, '0')}.${ts.month.toString().padLeft(2, '0')}.${ts.year}';
                    return Column(
                      children: [
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: 28,
                            endIndent: 28,
                            color: Color(0xFFEEF0F8),
                          ),
                        InkWell(
                          onTap: () => _goTo('Posts'),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 14, 20, 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEBF1F8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.campaign_rounded,
                                    size: 20,
                                    color: Color(0xFF2848B0),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title.isEmpty ? '(no title)' : title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A2050),
                                        ),
                                      ),
                                      if (message.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          message,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF7A7E9A),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7A7E9A),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: Color(0xFFB0B8D0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bubble(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool selected = label == activeSidebarLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          splashColor: Colors.white.withValues(alpha: 0.04),
          highlightColor: Colors.white.withValues(alpha: 0.03),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
            child: Stack(
              children: [
                if (selected)
                  Positioned(
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5C518),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.65),
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.78),
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalSecurityControls() {
    return StreamBuilder<SecurityFlags>(
      stream: SecurityFlagsService.watch(),
      initialData: SecurityFlags.defaults,
      builder: (context, snapshot) {
        final flags = snapshot.data ?? SecurityFlags.defaults;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC0C4D8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Global security settings',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2848B0),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ON/OFF for onboarding and 2FA at the application level.',
                style: TextStyle(color: Color(0xFF7A7E9A), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Global onboarding'),
                        Text(
                          flags.onboardingEnabled ? 'On' : 'Off',
                          style: TextStyle(
                            fontSize: 12,
                            color: flags.onboardingEnabled
                                ? const Color(0xFF4C8DC1)
                                : const Color(0xFF7C3A3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    activeTrackColor: const Color(0xFF2848B0),
                    value: flags.onboardingEnabled,
                    onChanged: _isActionBusy('toggle-onboarding-global')
                        ? null
                        : (value) {
                            _runGuarded('toggle-onboarding-global', () async {
                              try {
                                await SecurityFlagsService.setOnboardingEnabled(
                                  value,
                                );
                                _logSuccess(
                                  'Global onboarding ${value ? 'on' : 'off'}.',
                                );
                                unawaited(
                                  _recordSecretariatActivity(
                                    message:
                                        'Global onboarding ${value ? 'enabled' : 'disabled'}',
                                    detail:
                                        'Application-level onboarding setting changed.',
                                  ),
                                );
                                _showInfoMessage(
                                  'Global onboarding ${value ? 'on' : 'off'}.',
                                );
                              } catch (_) {
                                final message = _friendlyError(
                                  'toggle-onboarding-global',
                                );
                                _logFailure(message);
                                _showInfoMessage(message);
                              }
                            });
                          },
                  ),
                ],
              ),
              const Divider(height: 8, color: Color(0xFFB8D8F0)),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Global 2FA'),
                        Text(
                          flags.twoFactorEnabled ? 'On' : 'Off',
                          style: TextStyle(
                            fontSize: 12,
                            color: flags.twoFactorEnabled
                                ? const Color(0xFF4C8DC1)
                                : const Color(0xFF7C3A3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    activeTrackColor: const Color(0xFF2848B0),
                    value: flags.twoFactorEnabled,
                    onChanged: _isActionBusy('toggle-2fa-global')
                        ? null
                        : (value) {
                            _runGuarded('toggle-2fa-global', () async {
                              try {
                                await SecurityFlagsService.setTwoFactorEnabled(
                                  value,
                                );
                                _logSuccess(
                                  'Global 2FA ${value ? 'on' : 'off'}.',
                                );
                                unawaited(
                                  _recordSecretariatActivity(
                                    message:
                                        'Global 2FA ${value ? 'enabled' : 'disabled'}',
                                    detail:
                                        'Application-level two-factor authentication setting changed.',
                                  ),
                                );
                                _showInfoMessage(
                                  'Global 2FA ${value ? 'on' : 'off'}.',
                                );
                              } catch (_) {
                                final message = _friendlyError(
                                  'toggle-2fa-global',
                                );
                                _logFailure(message);
                                _showInfoMessage(message);
                              }
                            });
                          },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClassTableRow {
  final String classId;
  final String className;
  final String teacherName;
  final int studentCount;

  const _ClassTableRow({
    required this.classId,
    required this.className,
    required this.teacherName,
    required this.studentCount,
  });
}

enum _TopSearchKind { student, teacher, parent, classRoom }

class _TopSearchHit {
  final _TopSearchKind kind;
  final String title;
  final String subtitle;
  final String searchTerm;

  const _TopSearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.searchTerm,
  });
}

class _TopSearchResults extends StatelessWidget {
  const _TopSearchResults({
    required this.queryListenable,
    required this.onSelect,
  });

  final ValueListenable<String> queryListenable;
  final ValueChanged<_TopSearchHit> onSelect;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: queryListenable,
      builder: (context, query, _) => _buildBody(context, query),
    );
  }

  Widget _buildBody(BuildContext context, String query) {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) {
      return const _TopSearchEmpty(text: 'Type to search…');
    }

    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .snapshots();
    final classesStream = FirebaseFirestore.instance
        .collection('classes')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: usersStream,
      builder: (context, usersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: classesStream,
          builder: (context, classesSnap) {
            if (usersSnap.connectionState == ConnectionState.waiting ||
                classesSnap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final hits = <_TopSearchHit>[];

            for (final doc in usersSnap.data?.docs ?? const []) {
              final data = doc.data() as Map<String, dynamic>;
              final fullName = (data['fullName'] ?? '').toString();
              final username = (data['username'] ?? doc.id).toString();
              final classId = (data['classId'] ?? '').toString();
              final role = (data['role'] ?? '').toString().toLowerCase();
              final haystack =
                  '$fullName $username $classId'.toLowerCase();
              if (!haystack.contains(lower)) continue;

              _TopSearchKind? kind;
              switch (role) {
                case 'student':
                  kind = _TopSearchKind.student;
                  break;
                case 'teacher':
                  kind = _TopSearchKind.teacher;
                  break;
                case 'parent':
                  kind = _TopSearchKind.parent;
                  break;
              }
              if (kind == null) continue;

              final title = fullName.isNotEmpty ? fullName : username;
              final subtitleParts = <String>[
                if (role.isNotEmpty)
                  role[0].toUpperCase() + role.substring(1),
                if (classId.isNotEmpty) classId,
                if (username.isNotEmpty && username != title) '@$username',
              ];
              hits.add(
                _TopSearchHit(
                  kind: kind,
                  title: title,
                  subtitle: subtitleParts.join(' · '),
                  searchTerm: title,
                ),
              );
            }

            for (final doc in classesSnap.data?.docs ?? const []) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? doc.id).toString();
              final teacher = (data['teacherUsername'] ?? '').toString();
              final haystack = '$name ${doc.id} $teacher'.toLowerCase();
              if (!haystack.contains(lower)) continue;
              hits.add(
                _TopSearchHit(
                  kind: _TopSearchKind.classRoom,
                  title: name,
                  subtitle: teacher.isEmpty
                      ? 'Class'
                      : 'Class · @$teacher',
                  searchTerm: doc.id,
                ),
              );
            }

            if (hits.isEmpty) {
              return _TopSearchEmpty(text: 'No results for "$query"');
            }

            // Show user hits before classes; cap to keep dropdown short.
            const int maxResults = 12;
            final shown = hits.take(maxResults).toList();

            return ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                color: Color(0xFFEEF0F6),
              ),
              itemBuilder: (context, i) {
                final hit = shown[i];
                final IconData icon;
                final Color iconBg;
                final Color iconFg;
                switch (hit.kind) {
                  case _TopSearchKind.student:
                    icon = Icons.school_rounded;
                    iconBg = const Color(0xFFE7EDFF);
                    iconFg = const Color(0xFF2848B0);
                    break;
                  case _TopSearchKind.teacher:
                    icon = Icons.menu_book_rounded;
                    iconBg = const Color(0xFFFFF3D6);
                    iconFg = const Color(0xFF9A6B00);
                    break;
                  case _TopSearchKind.parent:
                    icon = Icons.family_restroom_rounded;
                    iconBg = const Color(0xFFE5F6EC);
                    iconFg = const Color(0xFF1F7A45);
                    break;
                  case _TopSearchKind.classRoom:
                    icon = Icons.class_rounded;
                    iconBg = const Color(0xFFF1E8FF);
                    iconFg = const Color(0xFF6A3DBE);
                    break;
                }
                return InkWell(
                  onTap: () => onSelect(hit),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 18, color: iconFg),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hit.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A2050),
                                ),
                              ),
                              if (hit.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  hit.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF7A7E9A),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFF8F94AD),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TopSearchEmpty extends StatelessWidget {
  const _TopSearchEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF7A7E9A)),
      ),
    );
  }
}
