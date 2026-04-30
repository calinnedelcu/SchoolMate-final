import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import 'services/admin_api.dart';
import 'services/admin_store.dart';
import 'utils/admin_ui.dart';
import 'widgets/admin_create_user_dialog.dart';

class AdminTeachersPage extends StatefulWidget {
  const AdminTeachersPage({super.key, this.searchQuery});
  final String? searchQuery;

  @override
  State<AdminTeachersPage> createState() => _AdminTeachersPageState();
}

class _AdminTeachersPageState extends State<AdminTeachersPage> {
  final store = AdminStore();
  int _currentPage = 0;
  static const int _pageSize = 7;
  String _searchQuery = '';
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _searchQuery = widget.searchQuery!.trim().toLowerCase();
    }
  }

  @override
  void didUpdateWidget(AdminTeachersPage old) {
    super.didUpdateWidget(old);
    final q = widget.searchQuery ?? '';
    if (q != (old.searchQuery ?? '')) {
      setState(() {
        _searchQuery = q.trim().toLowerCase();
        _currentPage = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access denied (admin only)")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTeacherStats(),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8EAF2), width: 1),
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
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Teacher directory',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Manage teacher accounts, classes and contact details.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7A7E9A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 260,
                            height: 40,
                            child: TextField(
                              onChanged: (v) => setState(() {
                                _searchQuery = v.trim().toLowerCase();
                                _currentPage = 0;
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
                                fillColor: const Color(0xFFF2F4F8),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => showAdminCreateUserDialog(
                              context,
                              lockedRole: 'teacher',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF2848B0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              '+ Add teacher',
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
                    const Divider(height: 1, color: Color(0xFFE8EAF2)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 14, 32, 14),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: _colHeader('HOMEROOM TEACHER NAME'),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(child: _colHeader('CLASS')),
                          ),
                          Expanded(
                            flex: 4,
                            child: Center(child: _colHeader('EMAIL')),
                          ),
                          const SizedBox(width: 30),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE8EAF2)),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('role', isEqualTo: 'teacher')
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(
                              child: SelectableText("Error:\n${snap.error}"),
                            );
                          }
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = [...snap.data!.docs];
                          docs.sort((a, b) {
                            final ad = a.data() as Map;
                            final bd = b.data() as Map;
                            if (_sortBy == 'class') {
                              final ac = (ad['classId'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final bc = (bd['classId'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final cmp = ac.compareTo(bc);
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
                                  final data = d.data() as Map;
                                  final name = (data['fullName'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final user = (data['username'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final cls = (data['classId'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  return name.contains(_searchQuery) ||
                                      user.contains(_searchQuery) ||
                                      cls.contains(_searchQuery);
                                }).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'No homeroom teachers'
                                    : 'No results for "$_searchQuery"',
                                style: const TextStyle(
                                  color: Color(0xFF7A7E9A),
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }

                          final visibleDocs = filtered
                              .skip(_currentPage * _pageSize)
                              .take(_pageSize)
                              .toList();
                          final totalPages = (filtered.length / _pageSize)
                              .ceil();

                          return Column(
                            children: [
                              Expanded(
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: visibleDocs.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    height: 1,
                                    color: Color(0xFFE8EAF2),
                                  ),
                                  itemBuilder: (_, i) {
                                    final d = visibleDocs[i];
                                    final data =
                                        d.data() as Map<String, dynamic>;
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
                                    final status = (data['status'] ?? 'active')
                                        .toString();
                                    final onboardingComplete =
                                        data['onboardingComplete'] as bool? ??
                                        false;
                                    final photoUrl =
                                        (data['photoUrl'] ??
                                                data['avatarUrl'] ??
                                                '')
                                            .toString();
                                    return InkWell(
                                      onTap: () => _openTeacherDialog(
                                        context,
                                        uid: uid,
                                        username: username,
                                        fullName: fullName,
                                        classId: classId,
                                        status: status,
                                        onboardingComplete: onboardingComplete,
                                        email: email,
                                        photoUrl: photoUrl,
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
                                            Expanded(
                                              flex: 5,
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 20,
                                                    backgroundColor:
                                                        avatarColor(fullName),
                                                    child: Text(
                                                      initials(fullName),
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF1A2050,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          fullName,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontSize: 14,
                                                                color: Color(
                                                                  0xFF111111,
                                                                ),
                                                              ),
                                                        ),
                                                        Text(
                                                          'Username: $username',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color: Color(
                                                                  0xFF7A7E9A,
                                                                ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.center,
                                                child: classId.isNotEmpty
                                                    ? Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 7,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFE8EAF2,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          formatClassName(
                                                            classId,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Color(
                                                                  0xFF2848B0,
                                                                ),
                                                              ),
                                                        ),
                                                      )
                                                    : const Text('-'),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 4,
                                              child: Text(
                                                (email != null &&
                                                        email.isNotEmpty)
                                                    ? email
                                                    : '-',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF2848B0),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 30,
                                              child: Icon(
                                                Icons.chevron_right_rounded,
                                                color: Color(0xFFB0B8C8),
                                                size: 22,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (totalPages > 1)
                                Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    40,
                                    14,
                                    40,
                                    14,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF2F4F8),
                                    border: Border(
                                      top: BorderSide(color: Color(0xFFE8EAF2)),
                                    ),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(20),
                                      bottomRight: Radius.circular(20),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      _PaginationButton(
                                        icon: Icons.chevron_left_rounded,
                                        enabled: _currentPage > 0,
                                        onTap: () =>
                                            setState(() => _currentPage--),
                                      ),
                                      const SizedBox(width: 4),
                                      ..._buildPageButtons(totalPages),
                                      const SizedBox(width: 4),
                                      _PaginationButton(
                                        icon: Icons.chevron_right_rounded,
                                        enabled: _currentPage < totalPages - 1,
                                        onTap: () =>
                                            setState(() => _currentPage++),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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

  Widget _buildTeacherStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .snapshots(),
      builder: (context, snap) {
        final teachers = snap.data?.docs ?? [];
        final loaded = snap.hasData;

        final total = teachers.length;
        final configured = teachers
            .where(
              (d) =>
                  (d.data() as Map<String, dynamic>)['onboardingComplete'] ==
                  true,
            )
            .length;
        final withClass = teachers
            .where(
              (d) => ((d.data() as Map<String, dynamic>)['classId'] ?? '')
                  .toString()
                  .isNotEmpty,
            )
            .length;
        final notConfigured = total - configured;

        return Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.school_rounded,
                iconBg: const Color(0xFFEEF1FB),
                iconColor: const Color(0xFF2848B0),
                label: 'TOTAL TEACHERS',
                value: loaded ? '$total' : '—',
                subtitle: 'Registered this year',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _statCard(
                icon: Icons.verified_user_rounded,
                iconBg: const Color(0xFFEDF7F0),
                iconColor: const Color(0xFF2E8B57),
                label: 'ACCOUNT CONFIGURED',
                value: loaded ? '$configured' : '—',
                subtitle: loaded && total > 0
                    ? '${((configured / total) * 100).round()}% done'
                    : 'No data',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _statCard(
                icon: Icons.class_rounded,
                iconBg: const Color(0xFFF3EDFB),
                iconColor: const Color(0xFF7B4FCC),
                label: 'CLASS ASSIGNED',
                value: loaded ? '$withClass' : '—',
                subtitle: loaded && total > 0
                    ? '${total - withClass} without class'
                    : 'No data',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _statCard(
                icon: Icons.warning_amber_rounded,
                iconBg: const Color(0xFFFFF8E8),
                iconColor: const Color(0xFFF5A623),
                label: 'NOT CONFIGURED',
                value: loaded ? '$notConfigured' : '—',
                subtitle: notConfigured == 0 ? 'All set up' : 'Pending setup',
              ),
            ),
          ],
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

  Widget _colHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111111),
        letterSpacing: 1.2,
      ),
    );
  }

  List<Widget> _buildPageButtons(int totalPages) {
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
              color: _currentPage == index
                  ? const Color(0xFF1A2050)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _currentPage == index
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
                color: _currentPage == index
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
      if (_currentPage > 2) addEllipsis();
      final start = (_currentPage - 1).clamp(1, totalPages - 2);
      final end = (_currentPage + 1).clamp(1, totalPages - 2);
      for (int i = start; i <= end; i++) {
        addPage(i);
      }
      if (_currentPage < totalPages - 3) addEllipsis();
      addPage(totalPages - 1);
    }

    return pages;
  }

  Future<void> _openTeacherDialog(
    BuildContext context, {
    required String uid,
    required String username,
    required String fullName,
    required String classId,
    required String status,
    required bool onboardingComplete,
    required String? email,
    required String photoUrl,
  }) async {
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
        String currentFullName = fullName;
        String currentClassId = classId;

        return StatefulBuilder(
          builder: (ctx, setS) => PopScope(
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
                                          msg = 'Name changed to "$newName".';
                                          msgIsError = false;
                                        });
                                        return;
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
                        padding: const EdgeInsets.fromLTRB(32, 36, 36, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (msg != null) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 560,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: msgIsError
                                          ? const Color(0xFFF0D0D8)
                                          : const Color(0xFFE8EAF2),
                                      borderRadius: BorderRadius.circular(10),
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
                                              : Icons.check_circle_outline,
                                          size: 16,
                                          color: msgIsError
                                              ? const Color(0xFFB03040)
                                              : const Color(0xFF5F9CCF),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SelectableText(
                                            msg!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: msgIsError
                                                  ? const Color(0xFFB71C1C)
                                                  : const Color(0xFF2848B0),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Teacher Details',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF2848B0),
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: onboardingComplete
                                                  ? const Color(0xFFE8EAF2)
                                                  : const Color(0xFFF0D0D8),
                                              border: Border.all(
                                                color: onboardingComplete
                                                    ? const Color(0xFFBFD1E1)
                                                    : const Color(0xFFE8AAAA),
                                                width: 1.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  onboardingComplete
                                                      ? 'ACCOUNT CONFIGURED'
                                                      : 'ACCOUNT NOT CONFIGURED',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: onboardingComplete
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
                                                newName == currentFullName) {
                                              return;
                                            }
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
                                      const SizedBox(height: 16),
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
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1,
                                                    color: Color(0xFF2848B0),
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
                                                    color: const Color(
                                                      0xFFF2F4F8,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    username,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Color(0xFF1A2050),
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
                                                const Text(
                                                  'EMAIL',
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
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 12,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFF2F4F8,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    email ?? '-',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Color(0xFF1A2050),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'CLASS',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                          color: Color(0xFF2848B0),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('classes')
                                            .snapshots(),
                                        builder: (_, snap) {
                                          // Build list: no teacher, OR this teacher's current class
                                          final availableIds = <String>[];
                                          if (snap.hasData) {
                                            for (final d in snap.data!.docs) {
                                              final t =
                                                  ((d.data()
                                                              as Map<
                                                                String,
                                                                dynamic
                                                              >)['teacherUsername'] ??
                                                          '')
                                                      .toString()
                                                      .trim()
                                                      .toLowerCase();
                                              if (t.isEmpty ||
                                                  d.id == currentClassId ||
                                                  t ==
                                                      username
                                                          .trim()
                                                          .toLowerCase()) {
                                                availableIds.add(d.id);
                                              }
                                            }
                                            availableIds.sort();
                                          }

                                          final dropdownValue =
                                              currentClassId.isEmpty
                                              ? '__NONE__'
                                              : (availableIds.contains(
                                                      currentClassId,
                                                    )
                                                    ? currentClassId
                                                    : '__NONE__');

                                          return Container(
                                            width: double.infinity,
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8EAF2),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: dropdownValue,
                                                isExpanded: true,
                                                icon: const Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  size: 20,
                                                  color: Color(0xFF7A7E9A),
                                                ),
                                                items:
                                                    <DropdownMenuItem<String>>[
                                                      const DropdownMenuItem(
                                                        value: '__NONE__',
                                                        child: Text(
                                                          'None',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                              0xFF7A7E9A,
                                                            ),
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        ),
                                                      ),
                                                      ...availableIds.map(
                                                        (c) => DropdownMenuItem(
                                                          value: c,
                                                          child: Text(
                                                            formatClassName(c),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Color(
                                                                    0xFF000000,
                                                                  ),
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                onChanged: busy
                                                    ? null
                                                    : (val) async {
                                                        if (val == null ||
                                                            val ==
                                                                dropdownValue)
                                                          return;
                                                        final newClassId =
                                                            val == '__NONE__'
                                                            ? ''
                                                            : val;
                                                        setS(() {
                                                          busy = true;
                                                          msg = null;
                                                        });
                                                        try {
                                                          final db =
                                                              FirebaseFirestore
                                                                  .instance;
                                                          final batch = db
                                                              .batch();
                                                          final teacherRef = db
                                                              .collection(
                                                                'users',
                                                              )
                                                              .doc(uid);

                                                          if (newClassId
                                                              .isEmpty) {
                                                            // Unassign: remove teacher from old class, clear teacher's classId
                                                            batch.set(
                                                              db
                                                                  .collection(
                                                                    'classes',
                                                                  )
                                                                  .doc(
                                                                    currentClassId,
                                                                  ),
                                                              {
                                                                'teacherUsername':
                                                                    FieldValue.delete(),
                                                                'updatedAt':
                                                                    FieldValue.serverTimestamp(),
                                                              },
                                                              SetOptions(
                                                                merge: true,
                                                              ),
                                                            );
                                                            batch.update(
                                                              teacherRef,
                                                              {
                                                                'classId':
                                                                    FieldValue.delete(),
                                                                'updatedAt':
                                                                    FieldValue.serverTimestamp(),
                                                              },
                                                            );
                                                          } else {
                                                            // Assign to new class
                                                            if (currentClassId
                                                                .isNotEmpty) {
                                                              // Remove from old class first
                                                              batch.set(
                                                                db
                                                                    .collection(
                                                                      'classes',
                                                                    )
                                                                    .doc(
                                                                      currentClassId,
                                                                    ),
                                                                {
                                                                  'teacherUsername':
                                                                      FieldValue.delete(),
                                                                  'updatedAt':
                                                                      FieldValue.serverTimestamp(),
                                                                },
                                                                SetOptions(
                                                                  merge: true,
                                                                ),
                                                              );
                                                            }
                                                            batch.set(
                                                              db
                                                                  .collection(
                                                                    'classes',
                                                                  )
                                                                  .doc(
                                                                    newClassId,
                                                                  ),
                                                              {
                                                                'teacherUsername':
                                                                    username,
                                                                'updatedAt':
                                                                    FieldValue.serverTimestamp(),
                                                              },
                                                              SetOptions(
                                                                merge: true,
                                                              ),
                                                            );
                                                            batch.update(
                                                              teacherRef,
                                                              {
                                                                'classId':
                                                                    newClassId,
                                                                'updatedAt':
                                                                    FieldValue.serverTimestamp(),
                                                              },
                                                            );
                                                          }

                                                          await batch.commit();
                                                          setS(() {
                                                            busy = false;
                                                            currentClassId =
                                                                newClassId;
                                                            msg =
                                                                newClassId
                                                                    .isEmpty
                                                                ? 'Class assignment removed.'
                                                                : 'Teacher assigned to ${formatClassName(newClassId)}.';
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
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    CircleAvatar(
                                      radius: 63,
                                      backgroundColor: avatarColor(
                                        currentFullName,
                                      ),
                                      backgroundImage: photoUrl.isNotEmpty
                                          ? NetworkImage(photoUrl)
                                          : null,
                                      child: photoUrl.isEmpty
                                          ? Text(
                                              initials(currentFullName),
                                              style: const TextStyle(
                                                color: Color(0xFF1A2050),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 32,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 72),
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
                                            final sheet = excel['Teacher'];
                                            sheet.appendRow([
                                              xls.TextCellValue('Full Name'),
                                              xls.TextCellValue('Username'),
                                              xls.TextCellValue('Email'),
                                              xls.TextCellValue('Class'),
                                              xls.TextCellValue('New Password'),
                                            ]);
                                            sheet.appendRow([
                                              xls.TextCellValue(
                                                currentFullName,
                                              ),
                                              xls.TextCellValue(username),
                                              xls.TextCellValue(email ?? '-'),
                                              xls.TextCellValue(
                                                currentClassId.isNotEmpty
                                                    ? formatClassName(
                                                        currentClassId,
                                                      )
                                                    : '-',
                                              ),
                                              xls.TextCellValue(newPass),
                                            ]);
                                            final bytes = excel.encode();
                                            if (bytes != null) {
                                              await FileSaver.instance.saveFile(
                                                name: 'teacher_$username',
                                                bytes: Uint8List.fromList(
                                                  bytes,
                                                ),
                                                ext: 'xlsx',
                                                mimeType:
                                                    MimeType.microsoftExcel,
                                              );
                                            }

                                            await AdminApi().resetPassword(
                                              username: username,
                                              newPassword: newPass,
                                            );

                                            setS(() {
                                              busy = false;
                                              msg =
                                                  'Data exported and password was reset automatically.';
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
                            const Divider(height: 1, color: Color(0xFFE8EAF2)),
                            const SizedBox(height: 28),
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
                                      : () async {
                                          final ok = await showGeneralDialog<bool>(
                                            context: ctx,
                                            barrierDismissible: true,
                                            barrierLabel:
                                                'Confirm teacher deletion',
                                            barrierColor: Colors.transparent,
                                            transitionDuration: const Duration(
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
                                                          10 * animation.value,
                                                      sigmaY:
                                                          10 * animation.value,
                                                    ),
                                                    child: Container(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha:
                                                                0.55 *
                                                                animation.value,
                                                          ),
                                                      child: FadeTransition(
                                                        opacity:
                                                            CurvedAnimation(
                                                              parent: animation,
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
                                                                  maxWidth: 520,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Colors.white,
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
                                                                          Icons
                                                                              .delete_outline_rounded,
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
                                                                      const Expanded(
                                                                        child: Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            Text(
                                                                              'Delete teacher',
                                                                              style: TextStyle(
                                                                                fontSize: 24,
                                                                                fontWeight: FontWeight.w800,
                                                                                color: Color(
                                                                                  0xFF2848B0,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            SizedBox(
                                                                              height: 6,
                                                                            ),
                                                                            Text(
                                                                              'This action is permanent and will delete the teacher account and its associated data.',
                                                                              style: TextStyle(
                                                                                fontSize: 13,
                                                                                height: 1.4,
                                                                                color: Color(
                                                                                  0xFF7A7E9A,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 18,
                                                                  ),
                                                                  Container(
                                                                    width: double
                                                                        .infinity,
                                                                    padding:
                                                                        const EdgeInsets.all(
                                                                          16,
                                                                        ),
                                                                    decoration: BoxDecoration(
                                                                      color: const Color(
                                                                        0xFFF2F4F8,
                                                                      ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            18,
                                                                          ),
                                                                      border: Border.all(
                                                                        color: const Color(
                                                                          0xFFE8EAF2,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    child: Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        const Text(
                                                                          'Selected teacher',
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                11,
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            letterSpacing:
                                                                                1,
                                                                            color: Color(
                                                                              0xFF7A7E9A,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              10,
                                                                        ),
                                                                        Container(
                                                                          padding: const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                12,
                                                                            vertical:
                                                                                8,
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
                                                                          style: const TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color: Color(
                                                                              0xFF7A7E9A,
                                                                            ),
                                                                            height:
                                                                                1.4,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 22,
                                                                  ),
                                                                  Row(
                                                                    children: [
                                                                      Expanded(
                                                                        child: OutlinedButton(
                                                                          onPressed: () => Navigator.pop(
                                                                            dialogCtx,
                                                                            false,
                                                                          ),
                                                                          style: OutlinedButton.styleFrom(
                                                                            padding: const EdgeInsets.symmetric(
                                                                              vertical: 16,
                                                                            ),
                                                                            side: const BorderSide(
                                                                              color: Color(
                                                                                0xFFE8EAF2,
                                                                              ),
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
                                                                          onPressed: () => Navigator.pop(
                                                                            dialogCtx,
                                                                            true,
                                                                          ),
                                                                          style: FilledButton.styleFrom(
                                                                            backgroundColor: const Color(
                                                                              0xFFB03040,
                                                                            ),
                                                                            foregroundColor:
                                                                                Colors.white,
                                                                            padding: const EdgeInsets.symmetric(
                                                                              vertical: 16,
                                                                            ),
                                                                            shape: RoundedRectangleBorder(
                                                                              borderRadius: BorderRadius.circular(
                                                                                14,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          child: const Text(
                                                                            'Delete teacher',
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
          ),
        );
      },
    );

    renameC.dispose();
  }
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
