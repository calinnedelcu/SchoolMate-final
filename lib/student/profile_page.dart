import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:school_mate/core/session.dart';
import 'package:school_mate/student/bookmarks_page.dart';
import 'package:school_mate/student/logout_dialog.dart';
import 'package:school_mate/student/orar.dart' show showEditProfileDialog;
import 'package:school_mate/student/widgets/no_anim_route.dart';
import 'package:school_mate/student/widgets/school_decor.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _card = Color(0xFFFFFFFF);
const _surfaceContainerLow = Color(0xFFE8EAF2);
const _onSurface = Color(0xFF1A2050);
const _outline = Color(0xFF7A7E9A);
const _outlineVariant = Color(0xFFC0C4D8);

class ProfilePage extends StatelessWidget {
  final VoidCallback? onBackToHome;

  const ProfilePage({super.key, this.onBackToHome});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: Text('Invalid session.')),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, snap) {
            final userData = snap.data?.data() ?? <String, dynamic>{};
            final fullName = (userData['fullName'] ?? '').toString().trim();
            final username = (userData['username'] ?? '').toString().trim();
            final classId = (userData['classId'] ?? '').toString().trim();
            final className = (userData['className'] ?? '').toString().trim();
            final profilePictureUrl =
                (userData['profilePictureUrl'] ?? '').toString().trim();
            final parentIds =
                List<String>.from(userData['parents'] ?? const [])
                    .where((id) => id.trim().isNotEmpty)
                    .toList();
            final legacyParentId =
                (userData['parentUid'] ?? userData['parentId'] ?? '')
                    .toString()
                    .trim();
            final parentCount = parentIds.isNotEmpty
                ? parentIds.length
                : (legacyParentId.isNotEmpty ? 1 : 0);

            final displayName = fullName.isNotEmpty
                ? fullName
                : (username.isNotEmpty ? username : 'Student');
            final classLabel = className.isNotEmpty
                ? className
                : (classId.isNotEmpty ? classId : 'No class');

            return Column(
              children: [
                const _Header(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _IdentityCard(
                          displayName: displayName,
                          classLabel: classLabel,
                          profilePictureUrl: profilePictureUrl,
                        ),
                        const SizedBox(height: 22),
                        const _SectionLabel('ACCOUNT'),
                        const SizedBox(height: 10),
                        _AccountTile(
                          icon: Icons.bookmark_outline_rounded,
                          title: 'Bookmarks',
                          subtitle: 'Saved competitions, camps, volunteering',
                          onTap: () => Navigator.of(context).push(
                            noAnimRoute((_) => const BookmarksPage()),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ParentsTile(
                          parentCount: parentCount,
                          studentUid: uid,
                        ),
                        const SizedBox(height: 10),
                        _AccountTile(
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          subtitle: 'Edit profile, notifications',
                          onTap: () => showEditProfileDialog(context),
                        ),
                        const SizedBox(height: 22),
                        _SignOutButton(
                          onSignOut: () => _signOut(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final shouldLogout = await showStudentLogoutDialog(
      context,
      accentColor: _primary,
      surfaceColor: _card,
      softSurfaceColor: _surfaceContainerLow,
      titleColor: _onSurface,
      messageColor: _outline,
    );
    if (!shouldLogout) return;
    await FirebaseAuth.instance.signOut();
    AppSession.clear();
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3CA0), Color(0xFF2E58D0), Color(0xFF4070E0)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x302848B0),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: HeaderSparklesPainter(variant: 4),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 42,
                  height: 3,
                  decoration: BoxDecoration(
                    color: kPencilYellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your account',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _IdentityCard extends StatelessWidget {
  final String displayName;
  final String classLabel;
  final String profilePictureUrl;

  const _IdentityCard({
    required this.displayName,
    required this.classLabel,
    required this.profilePictureUrl,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() +
            parts[1].characters.take(1).toString())
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: profilePictureUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: profilePictureUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, _, _) => _initialsAvatar(),
                  )
                : _initialsAvatar(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: kPencilYellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Class $classLabel · Student',
                  style: const TextStyle(
                    color: _outline,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialsAvatar() {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        _initials(displayName),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: _outline,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: _primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _outline,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _outline,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParentsTile extends StatelessWidget {
  final int parentCount;
  final String studentUid;

  const _ParentsTile({required this.parentCount, required this.studentUid});

  @override
  Widget build(BuildContext context) {
    final subtitle = parentCount == 0
        ? 'No linked accounts'
        : '$parentCount linked account${parentCount == 1 ? '' : 's'}';
    return _AccountTile(
      icon: Icons.family_restroom_rounded,
      title: 'Parents & contacts',
      subtitle: subtitle,
      onTap: () => _showParentsDialog(context),
    );
  }

  void _showParentsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _ParentsDialog(studentUid: studentUid),
    );
  }
}

class _ParentsDialog extends StatelessWidget {
  final String studentUid;

  const _ParentsDialog({required this.studentUid});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = size.width < 460 ? size.width - 32 : 420.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Material(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.family_restroom_rounded,
                          color: _primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Parents & contacts',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        splashRadius: 20,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _outline,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(studentUid)
                        .snapshots(),
                    builder: (context, snap) {
                      final data = snap.data?.data() ?? {};
                      final parentIds =
                          List<String>.from(data['parents'] ?? const [])
                              .where((id) => id.trim().isNotEmpty)
                              .toList();
                      final legacy =
                          (data['parentUid'] ?? data['parentId'] ?? '')
                              .toString()
                              .trim();
                      final ids = parentIds.isNotEmpty
                          ? parentIds
                          : (legacy.isNotEmpty ? [legacy] : <String>[]);
                      if (ids.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            'No parent accounts are linked yet.',
                            style: TextStyle(
                              color: _outline,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (int i = 0; i < ids.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            _ParentRow(parentUid: ids[i]),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ParentRow extends StatelessWidget {
  final String parentUid;

  const _ParentRow({required this.parentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .collection('publicProfile')
          .doc('main')
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};
        final fullName = (data['fullName'] ?? '').toString().trim();
        final username = (data['username'] ?? '').toString().trim();
        final name = fullName.isNotEmpty
            ? fullName
            : (username.isNotEmpty ? username : 'Parent');
        final detail = username.isNotEmpty ? '@$username' : '';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: _primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: _outline,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
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
  }
}

class _SignOutButton extends StatelessWidget {
  final VoidCallback onSignOut;

  const _SignOutButton({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0D0D8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onSignOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                color: Color(0xFFB03040),
                size: 20,
              ),
              SizedBox(width: 10),
              Text(
                'Sign out',
                style: TextStyle(
                  color: Color(0xFFB03040),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
