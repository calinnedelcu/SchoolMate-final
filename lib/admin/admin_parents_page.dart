import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import '../common/state_views.dart';
import '../core/session.dart';
import '../services/admin_api.dart';
import 'services/admin_store.dart';
import 'utils/admin_ui.dart';
import 'widgets/admin_create_user_dialog.dart';

class AdminParentsPage extends StatefulWidget {
  const AdminParentsPage({super.key, this.searchQuery});
  final String? searchQuery;

  @override
  State<AdminParentsPage> createState() => _AdminParentsPageState();
}

class _AdminParentsPageState extends State<AdminParentsPage> {
  final store = AdminStore();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final String _sortBy = 'name';

  // --- Cursor-based pagination state ---
  // We fetch parents in chunks of [_pageSize] from Firestore, ordered by
  // 'fullName', and use the last document of each chunk as the cursor for
  // the next .startAfterDocument() call. This avoids loading 1000+ docs
  // into memory on first paint and keeps Firestore reads bounded.
  static const int _pageSize = 50;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _loadedDocs = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _isLoadingPage = false;
  bool _hasMore = true;
  bool _initialLoadDone = false;
  Object? _loadError;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _searchQuery = widget.searchQuery!.toLowerCase();
      _searchController.text = widget.searchQuery!;
    }
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void didUpdateWidget(AdminParentsPage old) {
    super.didUpdateWidget(old);
    final q = widget.searchQuery ?? '';
    if (q != (old.searchQuery ?? '')) {
      setState(() {
        _searchQuery = q.trim().toLowerCase();
        _searchController.text = q;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _baseQuery() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .orderBy('fullName')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingPage || !_hasMore) return;
    _isLoadingPage = true;
    if (mounted) setState(() {});
    try {
      var q = _baseQuery().limit(_pageSize);
      if (_cursor != null) q = q.startAfterDocument(_cursor!);
      final snap = await q.get();
      _loadedDocs.addAll(snap.docs);
      if (snap.docs.length < _pageSize) {
        _hasMore = false;
      } else {
        _cursor = snap.docs.last;
      }
      _loadError = null;
    } catch (e) {
      _loadError = e;
    } finally {
      _isLoadingPage = false;
      _initialLoadDone = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _refresh() async {
    _loadedDocs.clear();
    _cursor = null;
    _hasMore = true;
    _initialLoadDone = false;
    _loadError = null;
    if (mounted) setState(() {});
    await _loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access denied (admin only)")),
      );
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerHighest,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildParentStats(context),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant, width: 1),
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
                      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parent directory',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Invite new parents, link children, revoke access',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: SizedBox(
                                height: 40,
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (val) => setState(() {
                                    _searchQuery = val.trim().toLowerCase();
                                  }),
                                  decoration: InputDecoration(
                                    hintText: 'Search...',
                                    hintStyle: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFB0B8C8),
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 18,
                                      color: Color(0xFFB0B8C8),
                                    ),
                                    filled: true,
                                    fillColor: cs.surfaceContainerHighest,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      vertical: 0,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => showAdminCreateUserDialog(
                              context,
                              lockedRole: 'parent',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: cs.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              '+ Add parent',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Divider(height: 1, color: cs.outlineVariant),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 14, 32, 14),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: _colHeader('PARENT')),
                          Expanded(flex: 4, child: _colHeader('EMAIL')),
                          Expanded(flex: 4, child: _colHeader('CHILDREN')),
                          const SizedBox(width: 30),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: cs.outlineVariant),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (_loadError != null && _loadedDocs.isEmpty) {
                            return ErrorRetryView(
                              message: _loadError.toString(),
                              onRetry: _refresh,
                            );
                          }
                          if (!_initialLoadDone && _loadedDocs.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = [..._loadedDocs];
                          docs.sort((a, b) {
                            final ad = a.data();
                            final bd = b.data();
                            if (_sortBy == 'children') {
                              final ac = (ad['children'] as List?)?.length ?? 0;
                              final bc = (bd['children'] as List?)?.length ?? 0;
                              final cmp = bc.compareTo(ac);
                              if (cmp != 0) return cmp;
                            }
                            return (ad['fullName'] ?? '')
                                .toString()
                                .toLowerCase()
                                .compareTo(
                                  (bd['fullName'] ?? '')
                                      .toString()
                                      .toLowerCase(),
                                );
                          });

                          final filtered = _searchQuery.isEmpty
                              ? docs
                              : docs.where((d) {
                                  final data = d.data();
                                  final name = (data['fullName'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final user = (data['username'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  return name.contains(_searchQuery) ||
                                      user.contains(_searchQuery);
                                }).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'No parents found'
                                    : 'No results for "$_searchQuery"',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }

                          final visibleDocs = filtered;
                          // Footer slots: loading indicator while fetching the
                          // next page, or an "end of list" hint when exhausted.
                          final showLoadingFooter = _isLoadingPage;
                          final showEndFooter =
                              !_hasMore &&
                              _searchQuery.isEmpty &&
                              visibleDocs.isNotEmpty;
                          final extraFooter =
                              (showLoadingFooter || showEndFooter) ? 1 : 0;

                          return RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: EdgeInsets.zero,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: visibleDocs.length + extraFooter,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: cs.outlineVariant,
                              ),
                              itemBuilder: (_, i) {
                                if (i >= visibleDocs.length) {
                                  if (showLoadingFooter) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'No more parents',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8FABC1),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final d = visibleDocs[i];
                                final data = d.data();
                                    final uid = d.id;
                                    final username = (data['username'] ?? uid)
                                        .toString();
                                    final fullName =
                                        (data['fullName'] ?? username)
                                            .toString();
                                    final classId = (data['classId'] ?? '')
                                        .toString();
                                    final email =
                                        (data['personalEmail'] ?? data['email'])
                                            ?.toString();
                                    final phone =
                                        (data['phone'] ?? data['phoneNumber'])
                                            ?.toString();
                                    final status = (data['status'] ?? 'active')
                                        .toString();
                                    final onboardingComplete =
                                        data['onboardingComplete'] as bool? ??
                                        false;
                                    final emailVerified =
                                        data['emailVerified'] as bool? ?? false;
                                    final passwordChanged =
                                        data['passwordChanged'] as bool? ??
                                        false;
                                    final childrenIds = List<String>.from(
                                      data['children'] ?? [],
                                    );

                                    return InkWell(
                                      onTap: () => _openStudentDialog(
                                        context,
                                        uid: uid,
                                        username: username,
                                        fullName: fullName,
                                        classId: classId,
                                        status: status,
                                        onboardingComplete: onboardingComplete,
                                        emailVerified: emailVerified,
                                        passwordChanged: passwordChanged,
                                        email: email,
                                        childrenIds: childrenIds,
                                      ),
                                      hoverColor: const Color(0xFFF7F8FA),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          32,
                                          16,
                                          32,
                                          16,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // PARENT
                                            Expanded(
                                              flex: 4,
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 20,
                                                    backgroundColor:
                                                        avatarColor(fullName),
                                                    child: Text(
                                                      initials(fullName),
                                                      style: TextStyle(
                                                        color: cs.onSurface,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      fullName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                        color: Color(
                                                          0xFF111111,
                                                        ),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // CONTACT
                                            Expanded(
                                              flex: 4,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (email != null &&
                                                      email.isNotEmpty)
                                                    Text(
                                                      email.length > 22
                                                          ? '${email.substring(0, 20)}...'
                                                          : email,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Color(
                                                          0xFF111111,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    const Text(
                                                      '—',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Color(
                                                          0xFF9E9E9E,
                                                        ),
                                                      ),
                                                    ),
                                                  if (phone != null &&
                                                      phone.isNotEmpty)
                                                    Text(
                                                      phone.length > 18
                                                          ? '${phone.substring(0, 16)}...'
                                                          : phone,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: cs.onSurfaceVariant,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // CHILDREN
                                            Expanded(
                                              flex: 4,
                                              child: childrenIds.isEmpty
                                                  ? const Text(
                                                      '—',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Color(
                                                          0xFF9E9E9E,
                                                        ),
                                                      ),
                                                    )
                                                  : FutureBuilder<
                                                      List<DocumentSnapshot>
                                                    >(
                                                      future: Future.wait(
                                                        childrenIds.map(
                                                          (id) =>
                                                              FirebaseFirestore
                                                                  .instance
                                                                  .collection(
                                                                    'users',
                                                                  )
                                                                  .doc(id)
                                                                  .get(),
                                                        ),
                                                      ),
                                                      builder: (ctx, csnap) {
                                                        if (!csnap.hasData) {
                                                          return const SizedBox.shrink();
                                                        }
                                                        return Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: csnap.data!.map((
                                                            ds,
                                                          ) {
                                                            final md =
                                                                ds.data()
                                                                    as Map<
                                                                      String,
                                                                      dynamic
                                                                    >? ??
                                                                {};
                                                            final childName =
                                                                (md['fullName'] ??
                                                                        md['username'] ??
                                                                        ds.id)
                                                                    .toString();
                                                            final childClass =
                                                                (md['classId'] ??
                                                                        '')
                                                                    .toString();
                                                            final label =
                                                                childClass
                                                                    .isNotEmpty
                                                                ? '$childName ($childClass)'
                                                                : childName;
                                                            return Text(
                                                              '· $label',
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Color(
                                                                      0xFF333333,
                                                                    ),
                                                                  ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            );
                                                          }).toList(),
                                                        );
                                                      },
                                                    ),
                                            ),
                                            // CHEVRON
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Color(0xFFB0B8C8),
                                              size: 22,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.black,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildParentStats(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .snapshots(),
      builder: (context, snap) {
        final parents = snap.data?.docs ?? [];
        final loaded = snap.hasData;

        final total = parents.length;
        final withChildren = parents.where((d) {
          final children =
              (d.data() as Map<String, dynamic>)['children'] as List?;
          return children != null && children.isNotEmpty;
        }).length;
        final noChildren = total - withChildren;
        final configured = parents
            .where(
              (d) =>
                  (d.data() as Map<String, dynamic>)['onboardingComplete'] ==
                  true,
            )
            .length;

        return Row(
          children: [
            Expanded(
              child: _statCard(
                context: context,
                icon: Icons.people_rounded,
                iconBg: const Color(0xFFEEF1FB),
                iconColor: Theme.of(context).colorScheme.primary,
                label: 'TOTAL PARENTS',
                value: loaded ? '$total' : '—',
                subtitle: 'Registered this year',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _statCard(
                context: context,
                icon: Icons.family_restroom_rounded,
                iconBg: const Color(0xFFEDF7F0),
                iconColor: const Color(0xFF2E8B57),
                label: 'CHILDREN LINKED',
                value: loaded ? '$withChildren' : '—',
                subtitle: loaded && total > 0
                    ? '${((withChildren / total) * 100).round()}% linked'
                    : 'No data',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _statCard(
                context: context,
                icon: Icons.warning_amber_rounded,
                iconBg: const Color(0xFFFFF8E8),
                iconColor: const Color(0xFFF5A623),
                label: 'NO CHILDREN YET',
                value: loaded ? '$noChildren' : '—',
                subtitle: noChildren == 0 ? 'All linked' : 'Need linking',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _statCard(
                context: context,
                icon: Icons.verified_user_rounded,
                iconBg: const Color(0xFFF3EDFB),
                iconColor: const Color(0xFF7B4FCC),
                label: 'ACCOUNT CONFIGURED',
                value: loaded ? '$configured' : '—',
                subtitle: loaded && total > 0
                    ? '${total - configured} pending setup'
                    : 'No data',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.05),
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

  Future<void> _openStudentDialog(
    BuildContext context, {
    required String uid,
    required String username,
    required String fullName,
    required String classId,
    required String status,
    required bool onboardingComplete,
    required bool emailVerified,
    required bool passwordChanged,
    required String? email,
    required List<String> childrenIds,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final addChildC = TextEditingController();
    final renameC = TextEditingController(text: fullName);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10 * animation.value,
            sigmaY: 10 * animation.value,
          ),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55 * animation.value),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        bool busy = false;
        String? msg;
        bool msgIsError = false;
        final assignedChildren = List<String>.from(childrenIds);
        final studentsFuture = FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .get();
        String currentFullName = fullName;

        return StatefulBuilder(
          builder: (ctx, setS) {
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
                    minHeight: 760,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // HEADER
                      Container(
                        padding: const EdgeInsets.fromLTRB(32, 22, 36, 22),
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
                            Text(
                              'User Settings',
                              style: TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                                color: cs.primary,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: busy ? null : () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                foregroundColor: cs.onSurfaceVariant,
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
                                      final newName = renameC.text.trim();
                                      if (newName.isNotEmpty &&
                                          newName != currentFullName) {
                                        setS(() {
                                          busy = true;
                                          msg = null;
                                        });
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(uid)
                                              .update({
                                                'fullName': newName,
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                              });
                                          setS(() {
                                            busy = false;
                                            currentFullName = newName;
                                            renameC.clear();
                                            msg =
                                                'Name changed to "$newName".';
                                            msgIsError = false;
                                          });
                                          return; // stay open to show success message
                                        } catch (e) {
                                          setS(() {
                                            busy = false;
                                            msg = e.toString().replaceFirst(
                                              'Exception: ',
                                              '',
                                            );
                                            msgIsError = true;
                                          });
                                          return;
                                        }
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
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
                      // SCROLLABLE BODY
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 36, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // main content row: left form + right avatar
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // LEFT
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
                                                      : cs.outlineVariant,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: msgIsError
                                                        ? const Color(
                                                            0xFFB03040,
                                                          )
                                                        : cs.primary,
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
                                                              : cs.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                          ],
                                          // title + badge
                                          Row(
                                            children: [
                                              Text(
                                                'Parent Details',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  color: cs.primary,
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: onboardingComplete
                                                      ? cs.outlineVariant
                                                      : const Color(0xFFF0D0D8),
                                                  border: Border.all(
                                                    color: onboardingComplete
                                                        ? const Color(
                                                            0xFFBFD1E1,
                                                          )
                                                        : const Color(
                                                            0xFFE8AAAA,
                                                          ),
                                                    width: 1.5,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      onboardingComplete
                                                          ? 'ACCOUNT CONFIGURED'
                                                          : 'ACCOUNT NOT CONFIGURED',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            onboardingComplete
                                                            ? const Color(
                                                                0xFF4F92CC,
                                                              )
                                                            : const Color(
                                                                0xFFC0392B,
                                                              ),
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    if (onboardingComplete)
                                                      _PulsingDot(
                                                        colorA: const Color(
                                                          0xFFBFD1E1,
                                                        ),
                                                        colorB: const Color(
                                                          0xFF4F92CC,
                                                        ),
                                                      )
                                                    else
                                                      _PulsingDot(
                                                        colorA: const Color(
                                                          0xFFE8AAAA,
                                                        ),
                                                        colorB: const Color(
                                                          0xFFC0392B,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          // FULL NAME
                                          Text(
                                            'FULL NAME',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1,
                                              color: cs.primary,
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
                                              color: cs.outlineVariant,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: TextField(
                                              controller: renameC,
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
                                                hintText: currentFullName,
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
                                                    newName ==
                                                        currentFullName) {
                                                  return;
                                                }
                                                setS(() {
                                                  busy = true;
                                                  msg = null;
                                                });
                                                try {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(uid)
                                                      .update({
                                                        'fullName': newName,
                                                        'updatedAt':
                                                            FieldValue.serverTimestamp(),
                                                      });
                                                  setS(() {
                                                    busy = false;
                                                    currentFullName = newName;
                                                    renameC.clear();
                                                    msg =
                                                        'Name changed to "$newName".';
                                                    msgIsError = false;
                                                  });
                                                } catch (e) {
                                                  setS(() {
                                                    busy = false;
                                                    msg = e
                                                        .toString()
                                                        .replaceFirst(
                                                          'Exception: ',
                                                          '',
                                                        );
                                                    msgIsError = true;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          // USERNAME + EMAIL
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'USERNAME',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 1,
                                                        color: cs.primary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      width: double.infinity,
                                                      height: 48,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: cs.surfaceContainerHighest,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        username,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: cs.onSurface,
                                                        ),
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
                                                    Text(
                                                      'EMAIL',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 1,
                                                        color: cs.primary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      width: double.infinity,
                                                      height: 48,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: cs.surfaceContainerHighest,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        email ?? '-',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: cs.onSurface,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          // REGISTERED CHILDREN
                                          Text(
                                            'REGISTERED CHILDREN',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1,
                                              color: cs.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          FutureBuilder<QuerySnapshot>(
                                            future: studentsFuture,
                                            builder: (_, snap) {
                                              if (!snap.hasData) {
                                                return const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                                  child:
                                                      LinearProgressIndicator(
                                                        minHeight: 2,
                                                      ),
                                                );
                                              }

                                              final allStudents =
                                                  snap.data!.docs.map((d) {
                                                    final data =
                                                        d.data()
                                                            as Map<
                                                              String,
                                                              dynamic
                                                            >;
                                                    final parentsList =
                                                        List<String>.from(
                                                          data['parents'] ??
                                                              const [],
                                                        );
                                                    return {
                                                      'uid': d.id,
                                                      'fullName':
                                                          (data['fullName'] ??
                                                                  data['username'] ??
                                                                  d.id)
                                                              .toString(),
                                                      'username':
                                                          (data['username'] ??
                                                                  d.id)
                                                              .toString(),
                                                      'parentsCount':
                                                          parentsList.length
                                                              .toString(),
                                                    };
                                                  }).toList()..sort(
                                                    (a, b) => a['fullName']!
                                                        .compareTo(
                                                          b['fullName']!,
                                                        ),
                                                  );

                                              String labelFor(String childUid) {
                                                final hit = allStudents
                                                    .cast<
                                                      Map<String, String>?
                                                    >()
                                                    .firstWhere(
                                                      (s) =>
                                                          s?['uid'] == childUid,
                                                      orElse: () => null,
                                                    );
                                                return hit?['fullName'] ??
                                                    childUid;
                                              }

                                              Future<void> addChild(
                                                String childUid,
                                              ) async {
                                                if (assignedChildren.contains(
                                                  childUid,
                                                )) {
                                                  setS(() {
                                                    msg =
                                                        'This child is already assigned to this parent.';
                                                    msgIsError = true;
                                                  });
                                                  return;
                                                }
                                                setS(() {
                                                  busy = true;
                                                  msg = null;
                                                });
                                                try {
                                                  final childRef =
                                                      FirebaseFirestore.instance
                                                          .collection('users')
                                                          .doc(childUid);
                                                  final childSnap =
                                                      await childRef.get();
                                                  if (!childSnap.exists) {
                                                    setS(() {
                                                      busy = false;
                                                      msg =
                                                          'The selected student no longer exists.';
                                                      msgIsError = true;
                                                    });
                                                    return;
                                                  }
                                                  final existingParents =
                                                      List<String>.from(
                                                        childSnap.data()?[
                                                                'parents'] ??
                                                            const [],
                                                      );
                                                  if (!existingParents
                                                          .contains(uid) &&
                                                      existingParents.length >=
                                                          2) {
                                                    setS(() {
                                                      busy = false;
                                                      msg =
                                                          'A student cannot have more than 2 assigned parents.';
                                                      msgIsError = true;
                                                    });
                                                    return;
                                                  }
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(uid)
                                                      .update({
                                                        'children':
                                                            FieldValue.arrayUnion(
                                                              [childUid],
                                                            ),
                                                      });
                                                  await childRef.update({
                                                    'parents':
                                                        FieldValue.arrayUnion(
                                                          [uid],
                                                        ),
                                                  });
                                                  setS(() {
                                                    assignedChildren.add(
                                                      childUid,
                                                    );
                                                    busy = false;
                                                    msg =
                                                        'Child added to parent.';
                                                    msgIsError = false;
                                                  });
                                                } catch (e) {
                                                  setS(() {
                                                    busy = false;
                                                    msg = e
                                                        .toString()
                                                        .replaceFirst(
                                                          'Exception: ',
                                                          '',
                                                        );
                                                    msgIsError = true;
                                                  });
                                                }
                                              }

                                              Future<void> removeChild(
                                                String childUid,
                                              ) async {
                                                setS(() {
                                                  busy = true;
                                                  msg = null;
                                                });
                                                try {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(uid)
                                                      .update({
                                                        'children':
                                                            FieldValue.arrayRemove(
                                                              [childUid],
                                                            ),
                                                      });
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(childUid)
                                                      .update({
                                                        'parents':
                                                            FieldValue.arrayRemove(
                                                              [uid],
                                                            ),
                                                      });
                                                  setS(() {
                                                    assignedChildren.remove(
                                                      childUid,
                                                    );
                                                    busy = false;
                                                    msg =
                                                        'Child removed from the list.';
                                                    msgIsError = false;
                                                  });
                                                } catch (e) {
                                                  setS(() {
                                                    busy = false;
                                                    msg = e
                                                        .toString()
                                                        .replaceFirst(
                                                          'Exception: ',
                                                          '',
                                                        );
                                                    msgIsError = true;
                                                  });
                                                }
                                              }

                                              final query = addChildC.text
                                                  .trim()
                                                  .toLowerCase();
                                              final suggestions = allStudents
                                                  .where(
                                                    (s) =>
                                                        !assignedChildren
                                                            .contains(
                                                              s['uid'],
                                                            ) &&
                                                        (query.isEmpty ||
                                                            s['fullName']!
                                                                .toLowerCase()
                                                                .contains(
                                                                  query,
                                                                ) ||
                                                            s['username']!
                                                                .toLowerCase()
                                                                .contains(
                                                                  query,
                                                                )),
                                                  )
                                                  .take(8)
                                                  .toList();

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // chips
                                                  if (assignedChildren.isEmpty)
                                                    const Text(
                                                      'No assigned children',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Color(
                                                          0xFF6F7B6F,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Wrap(
                                                      spacing: 10,
                                                      runSpacing: 10,
                                                      children: assignedChildren.map((
                                                        childUid,
                                                      ) {
                                                        return Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 14,
                                                                vertical: 8,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: const Color(
                                                              0xFFCCDAE4,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  24,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                labelFor(
                                                                  childUid,
                                                                ),
                                                                style: TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: cs.primary,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                              GestureDetector(
                                                                onTap: busy
                                                                    ? null
                                                                    : () => removeChild(
                                                                        childUid,
                                                                      ),
                                                                child: Icon(
                                                                  Icons.close,
                                                                  size: 17,
                                                                  color: cs.primary,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  const SizedBox(height: 12),
                                                  // search bar
                                                  Container(
                                                    width: double.infinity,
                                                    height: 48,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: cs.outlineVariant,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .manage_search_rounded,
                                                          size: 20,
                                                          color: Color(
                                                            0xFF789BB2,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: TextField(
                                                            controller:
                                                                addChildC,
                                                            onChanged: (_) =>
                                                                setS(() {}),
                                                            decoration: const InputDecoration(
                                                              hintText:
                                                                  'Add a new student...',
                                                              hintStyle: TextStyle(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                  0xFF8A9792,
                                                                ),
                                                              ),
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                              isDense: true,
                                                            ),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          onPressed:
                                                              busy ||
                                                                  suggestions
                                                                      .isEmpty
                                                              ? null
                                                              : () async {
                                                                  await addChild(
                                                                    suggestions
                                                                        .first['uid']!,
                                                                  );
                                                                  addChildC
                                                                      .clear();
                                                                  setS(() {});
                                                                },
                                                          icon: const Icon(
                                                            Icons
                                                                .add_circle_outline,
                                                            color: Color(
                                                              0xFF1D8BEF,
                                                            ),
                                                            size: 24,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // dropdown suggestions
                                                  if (query.isNotEmpty &&
                                                      suggestions
                                                          .isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      width: double.infinity,
                                                      constraints:
                                                          const BoxConstraints(
                                                            maxHeight: 140,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: cs.surfaceContainerHighest,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: cs.outlineVariant,
                                                        ),
                                                      ),
                                                      child: ListView.separated(
                                                        shrinkWrap: true,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 6,
                                                            ),
                                                        itemCount:
                                                            suggestions.length,
                                                        separatorBuilder:
                                                            (_, _) =>
                                                                const Divider(
                                                                  height: 1,
                                                                  color: Color(
                                                                    0xFFDEE8EF,
                                                                  ),
                                                                ),
                                                        itemBuilder: (_, index) {
                                                          final student =
                                                              suggestions[index];
                                                          return InkWell(
                                                            onTap: busy
                                                                ? null
                                                                : () async {
                                                                    await addChild(
                                                                      student['uid']!,
                                                                    );
                                                                    addChildC
                                                                        .clear();
                                                                    setS(() {});
                                                                  },
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical:
                                                                        10,
                                                                  ),
                                                              child: Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      '${student['fullName']} (${student['username']})',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w600,
                                                                        color: cs.primary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: cs.outlineVariant,
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                        10,
                                                                      ),
                                                                    ),
                                                                    child: Text(
                                                                      '${student['parentsCount'] ?? '0'}/2 parents',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w700,
                                                                        color: cs.onSurfaceVariant,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // RIGHT: avatar
                                  Column(
                                    children: [
                                      const SizedBox(height: 8),
                                      CircleAvatar(
                                        radius: 63,
                                        backgroundColor: avatarColor(
                                          currentFullName,
                                        ),
                                        child: Text(
                                          initials(currentFullName),
                                          style: TextStyle(
                                            color: cs.onSurface,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 32,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 72),
                              // Export / Reset password button
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
                                        vertical: 18,
                                        horizontal: 30,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final newPass = randPassword(10);
                                            setS(() {
                                              busy = true;
                                              msg = null;
                                            });
                                            try {
                                              final excel =
                                                  xls.Excel.createExcel();
                                              final sheet = excel['Parent'];
                                              sheet.appendRow([
                                                xls.TextCellValue(
                                                  'Full Name',
                                                ),
                                                xls.TextCellValue('Username'),
                                                xls.TextCellValue('Email'),
                                                xls.TextCellValue(
                                                  'Assigned Children',
                                                ),
                                                xls.TextCellValue(
                                                  'New Password',
                                                ),
                                              ]);
                                              sheet.appendRow([
                                                xls.TextCellValue(
                                                  currentFullName,
                                                ),
                                                xls.TextCellValue(username),
                                                xls.TextCellValue(email ?? '-'),
                                                xls.TextCellValue(
                                                  '${assignedChildren.length}',
                                                ),
                                                xls.TextCellValue(newPass),
                                              ]);
                                              final bytes = excel.encode();
                                              if (bytes != null) {
                                                await FileSaver.instance
                                                    .saveFile(
                                                      name: 'parent_$username',
                                                      bytes: Uint8List.fromList(
                                                        bytes,
                                                      ),
                                                      ext: 'xlsx',
                                                      mimeType: MimeType
                                                          .microsoftExcel,
                                                    );
                                              }
                                              await AdminApi().resetPassword(
                                                username: username,
                                                newPassword: newPass,
                                              );
                                              setS(() {
                                                busy = false;
                                                msg =
                                                    'Data exported and password reset automatically.';
                                                msgIsError = false;
                                              });
                                            } catch (e) {
                                              setS(() {
                                                busy = false;
                                                msg = e.toString().replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                );
                                                msgIsError = true;
                                              });
                                            }
                                          },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 44),
                              Divider(
                                height: 1,
                                color: cs.outlineVariant,
                              ),
                              const SizedBox(height: 28),
                              // Delete button
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
                                      elevation: const WidgetStatePropertyAll(
                                        0,
                                      ),
                                      padding: const WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 18,
                                        ),
                                      ),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                        : () async {
                                            final ok = await showGeneralDialog<bool>(
                                              context: ctx,
                                              barrierDismissible: true,
                                              barrierLabel:
                                                  'Confirm parent deletion',
                                              barrierColor: Colors.transparent,
                                              transitionDuration:
                                                  const Duration(
                                                    milliseconds: 220,
                                                  ),
                                              transitionBuilder:
                                                  (
                                                    dialogContext,
                                                    animation,
                                                    secondaryAnimation,
                                                    child,
                                                  ) {
                                                    return BackdropFilter(
                                                      filter: ImageFilter.blur(
                                                        sigmaX:
                                                            10 *
                                                            animation.value,
                                                        sigmaY:
                                                            10 *
                                                            animation.value,
                                                      ),
                                                      child: Container(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha:
                                                                  0.55 *
                                                                  animation
                                                                      .value,
                                                            ),
                                                        child: FadeTransition(
                                                          opacity:
                                                              CurvedAnimation(
                                                                parent:
                                                                    animation,
                                                                curve: Curves
                                                                    .easeOut,
                                                              ),
                                                          child: child,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                              pageBuilder:
                                                  (
                                                    dialogCtx,
                                                    animation,
                                                    secondaryAnimation,
                                                  ) {
                                                    return SafeArea(
                                                      child: Center(
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 24,
                                                                vertical: 24,
                                                              ),
                                                          child: Material(
                                                            color: Colors
                                                                .transparent,
                                                            child: Container(
                                                              constraints:
                                                                  const BoxConstraints(
                                                                    maxWidth:
                                                                        520,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .white,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      28,
                                                                    ),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .black
                                                                        .withValues(
                                                                          alpha:
                                                                              0.16,
                                                                        ),
                                                                    blurRadius:
                                                                        32,
                                                                    offset:
                                                                        const Offset(
                                                                          0,
                                                                          14,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets.fromLTRB(
                                                                      24,
                                                                      24,
                                                                      24,
                                                                      20,
                                                                    ),
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Row(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Container(
                                                                          width:
                                                                              52,
                                                                          height:
                                                                              52,
                                                                          decoration: BoxDecoration(
                                                                            color: const Color(
                                                                              0xFFF0D0D8,
                                                                            ),
                                                                            borderRadius: BorderRadius.circular(
                                                                              16,
                                                                            ),
                                                                          ),
                                                                          child: const Icon(
                                                                            Icons.delete_outline_rounded,
                                                                            color: Color(
                                                                              0xFFB03040,
                                                                            ),
                                                                            size:
                                                                                26,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              14,
                                                                        ),
                                                                        Expanded(
                                                                          child: Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              Text(
                                                                                'Delete parent',
                                                                                style: TextStyle(
                                                                                  fontSize: 24,
                                                                                  fontWeight: FontWeight.w800,
                                                                                  color: cs.primary,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(
                                                                                height: 6,
                                                                              ),
                                                                              Text(
                                                                                'Confirmation is permanent and will delete the parent account along with its associated data.',
                                                                                style: TextStyle(
                                                                                  fontSize: 13,
                                                                                  height: 1.4,
                                                                                  color: cs.onSurfaceVariant,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          18,
                                                                    ),
                                                                    Container(
                                                                      width: double
                                                                          .infinity,
                                                                      padding:
                                                                          const EdgeInsets.all(
                                                                            16,
                                                                          ),
                                                                      decoration: BoxDecoration(
                                                                        color: cs.surfaceContainerHighest,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              18,
                                                                            ),
                                                                        border: Border.all(
                                                                          color: cs.outlineVariant,
                                                                        ),
                                                                      ),
                                                                      child: Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            'Selected parent',
                                                                            style: TextStyle(
                                                                              fontSize: 11,
                                                                              fontWeight: FontWeight.w700,
                                                                              letterSpacing: 1,
                                                                              color: cs.onSurfaceVariant,
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            height:
                                                                                10,
                                                                          ),
                                                                          Container(
                                                                            padding: const EdgeInsets.symmetric(
                                                                              horizontal: 12,
                                                                              vertical: 8,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              color: const Color(
                                                                                0xFFF0D0D8,
                                                                              ),
                                                                              borderRadius: BorderRadius.circular(
                                                                                999,
                                                                              ),
                                                                            ),
                                                                            child: Text(
                                                                              currentFullName,
                                                                              style: const TextStyle(
                                                                                fontSize: 13,
                                                                                fontWeight: FontWeight.w800,
                                                                                color: Color(
                                                                                  0xFFB03040,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            height:
                                                                                12,
                                                                          ),
                                                                          Text(
                                                                            username,
                                                                            style: TextStyle(
                                                                              fontSize: 12,
                                                                              color: cs.onSurfaceVariant,
                                                                              height: 1.4,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          22,
                                                                    ),
                                                                    Row(
                                                                      children: [
                                                                        Expanded(
                                                                          child: OutlinedButton(
                                                                            onPressed: () =>
                                                                                Navigator.of(
                                                                                  dialogCtx,
                                                                                ).pop(
                                                                                  false,
                                                                                ),
                                                                            style: OutlinedButton.styleFrom(
                                                                              padding: const EdgeInsets.symmetric(
                                                                                vertical: 16,
                                                                              ),
                                                                              side: BorderSide(
                                                                                color: cs.outlineVariant,
                                                                              ),
                                                                              shape: RoundedRectangleBorder(
                                                                                borderRadius: BorderRadius.circular(
                                                                                  14,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            child: const Text(
                                                                              'Cancel',
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              12,
                                                                        ),
                                                                        Expanded(
                                                                          child: FilledButton(
                                                                            style: FilledButton.styleFrom(
                                                                              backgroundColor: const Color(
                                                                                0xFFB03040,
                                                                              ),
                                                                              foregroundColor: Colors.white,
                                                                              padding: const EdgeInsets.symmetric(
                                                                                vertical: 16,
                                                                              ),
                                                                              shape: RoundedRectangleBorder(
                                                                                borderRadius: BorderRadius.circular(
                                                                                  14,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            onPressed: () =>
                                                                                Navigator.of(
                                                                                  dialogCtx,
                                                                                ).pop(
                                                                                  true,
                                                                                ),
                                                                            child: const Text(
                                                                              'Delete parent',
                                                                            ),
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
                                                    );
                                                  },
                                            );
                                            if (ok != true) return;
                                            setS(() {
                                              busy = true;
                                              msg = null;
                                            });
                                            try {
                                              await store.deleteUser(username);
                                              if (ctx.mounted) {
                                                Navigator.pop(ctx);
                                              }
                                            } catch (e) {
                                              setS(() {
                                                busy = false;
                                                msg = e.toString().replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                );
                                                msgIsError = true;
                                              });
                                            }
                                          },
                                  ),
                                ),
                              ),
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
        );
      },
    );

    addChildC.dispose();
    renameC.dispose();
  }
}

class _PulsingDot extends StatefulWidget {
  final Color colorA;
  final Color colorB;
  const _PulsingDot({required this.colorA, required this.colorB});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _color;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _color = ColorTween(
      begin: widget.colorA,
      end: widget.colorB,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _color,
      builder: (context, child) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: _color.value, shape: BoxShape.circle),
      ),
    );
  }
}
