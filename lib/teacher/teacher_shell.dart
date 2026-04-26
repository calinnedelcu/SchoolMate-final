import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Auth/login_page_firestore.dart';
import '../core/session.dart';
import '../student/widgets/maniubara.dart';
import '../student/widgets/school_decor.dart' as decor;
import 'account_bottom_sheet.dart';
import 'statuselevi.dart';
import 'teacher_dashboard_page.dart';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _surfaceLowest = Color(0xFFFFFFFF);
const _outline = Color(0xFF7A7E9A);
const _outlineVariant = Color(0xFFBFC3D9);
const _onSurface = Color(0xFF1A2050);
const _pencilYellow = Color(0xFFF5C518);

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key});

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _index = 0;

  static const _items = <BottomNavItemSpec>[
    BottomNavItemSpec(icon: Icons.home_rounded, label: 'Home'),
    BottomNavItemSpec(icon: Icons.group_rounded, label: 'My class'),
    BottomNavItemSpec(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: FixedBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _items,
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          TeacherDashboardPage(),
          StatusEleviPage(showBack: false),
          TeacherProfilePage(showBack: false),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEACHER PROFILE PAGE
// ─────────────────────────────────────────────────────────────────────────────
class TeacherProfilePage extends StatelessWidget {
  final bool showBack;

  const TeacherProfilePage({super.key, this.showBack = true});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    AppSession.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPageFirestore()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid ?? '';
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _ProfileTopHeader(
              onBack: showBack ? () => Navigator.of(context).maybePop() : null,
            ),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data() ?? <String, dynamic>{};
                  final fullName = (data['fullName'] ?? '').toString().trim();
                  final email = FirebaseAuth.instance.currentUser?.email ?? '';
                  final classId = (data['classId'] ?? '').toString().trim();
                  final displayName = fullName.isNotEmpty
                      ? fullName
                      : (AppSession.username ?? 'Teacher');

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TeacherIdentityCard(
                          displayName: displayName,
                          email: email,
                          classId: classId,
                        ),
                        const SizedBox(height: 22),
                        const _ProfileSectionLabel('ACCOUNT'),
                        const SizedBox(height: 10),
                        _ProfileTile(
                          icon: Icons.edit_outlined,
                          title: 'Edit profile',
                          subtitle: 'Email · Password',
                          onTap: () => showTeacherEditProfileDialog(context),
                        ),
                        const SizedBox(height: 22),
                        _ProfileSignOutButton(
                          onSignOut: () => _signOut(context),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTopHeader extends StatelessWidget {
  final VoidCallback? onBack;

  const _ProfileTopHeader({this.onBack});

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
          Positioned.fill(
            child: CustomPaint(
              painter: const decor.HeaderSparklesPainter(variant: 4),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (onBack != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                          color: _pencilYellow,
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
          ),
        ],
      ),
    );
  }
}

class _TeacherIdentityCard extends StatelessWidget {
  final String displayName;
  final String email;
  final String classId;

  const _TeacherIdentityCard({
    required this.displayName,
    required this.email,
    required this.classId,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
            parts[1].characters.take(1).toString())
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = classId.isEmpty
        ? 'Teacher'
        : 'Teacher · Class $classId';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
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
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                    color: _pencilYellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _outline,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _outline,
                      fontSize: 12.5,
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
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  final String text;

  const _ProfileSectionLabel(this.text);

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

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: _surfaceLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outlineVariant.withValues(alpha: 0.18)),
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

class _ProfileSignOutButton extends StatelessWidget {
  final VoidCallback onSignOut;

  const _ProfileSignOutButton({required this.onSignOut});

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
              Icon(Icons.logout_rounded, color: Color(0xFFB03040), size: 20),
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
