import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/core/session.dart';
import 'package:firster/student/orar.dart' show showEditProfileDialog;
import 'package:firster/student/logout_dialog.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF2848B0);
const _surfaceLowest = Color(0xFFFFFFFF);
const _surfaceContainerLow = Color(0xFFE8EAF2);
const _surfaceContainerHigh = Color(0xFFDDE0EC);
const _onSurface = Color(0xFF1A2050);
const _outline = Color(0xFF7A7E9A);
const _outlineVariant = Color(0xFFC0C4D8);

Future<void> showProfileSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfileBottomSheet(rootContext: context),
  );
}

class _ProfileBottomSheet extends StatelessWidget {
  final BuildContext rootContext;
  const _ProfileBottomSheet({required this.rootContext});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? <String, dynamic>{};
        final fullName = (userData['fullName'] ?? '').toString().trim();
        final username = (userData['username'] ?? '').toString().trim();
        final classId = (userData['classId'] ?? '').toString().trim();
        final profilePictureUrl =
            (userData['profilePictureUrl'] ?? '').toString().trim();
        final displayName = fullName.isNotEmpty
            ? fullName
            : (username.isNotEmpty ? username : 'Student');

        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: _surfaceLowest,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: _outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 22),
              // Profile row
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: profilePictureUrl.isNotEmpty
                        ? Image.network(
                            profilePictureUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                          )
                        : _avatarPlaceholder(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        if (username.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@$username',
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(context);
                        _showSettingsSheet(rootContext);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: _primary,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(height: 1, color: _surfaceContainerLow),
              const SizedBox(height: 18),
              // Teacher info
              _TeacherInfoRow(classId: classId),
              const SizedBox(height: 14),
              // Parent info
              _ParentInfoRow(uid: uid),
              const SizedBox(height: 22),
              // Close button
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: _onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _avatarPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: _surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.person, color: _outline, size: 34),
    );
  }

  static void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsSheet(parentContext: context),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: _primary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _outline,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _resolveDisplayName({
  dynamic fullName,
  dynamic username,
  String fallback = '',
}) {
  final fn = (fullName ?? '').toString().trim();
  if (fn.isNotEmpty) return fn;
  final un = (username ?? '').toString().trim();
  if (un.isNotEmpty) return un;
  return fallback;
}

class _TeacherInfoRow extends StatelessWidget {
  final String classId;
  const _TeacherInfoRow({required this.classId});

  @override
  Widget build(BuildContext context) {
    if (classId.isEmpty) {
      return const _InfoRow(
        icon: Icons.school,
        label: 'HOMEROOM TEACHER',
        value: 'Not set',
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .snapshots(),
      builder: (context, classSnap) {
        final classData = classSnap.data?.data() ?? {};
        final teacherUid = (classData['teacherUid'] ?? '').toString().trim();
        final teacherUsername =
            (classData['teacherUsername'] ?? '').toString().trim();

        if (teacherUid.isEmpty && teacherUsername.isEmpty) {
          return const _InfoRow(
            icon: Icons.school,
            label: 'HOMEROOM TEACHER',
            value: 'Not set',
          );
        }

        if (teacherUid.isNotEmpty) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(teacherUid)
                .snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data() ?? {};
              final name = _resolveDisplayName(
                fullName: data['fullName'],
                username: data['username'],
                fallback: teacherUsername,
              );
              return _InfoRow(
                icon: Icons.school,
                label: 'HOMEROOM TEACHER',
                value: name.isEmpty ? 'Not set' : name,
              );
            },
          );
        }

        return _InfoRow(
          icon: Icons.school,
          label: 'HOMEROOM TEACHER',
          value: teacherUsername.isEmpty ? 'Not set' : teacherUsername,
        );
      },
    );
  }
}

class _ParentInfoRow extends StatelessWidget {
  final String uid;
  const _ParentInfoRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? {};
        final parentIds = List<String>.from(userData['parents'] ?? const [])
            .where((id) => id.trim().isNotEmpty)
            .toList();
        final legacyParentId =
            (userData['parentUid'] ?? userData['parentId'] ?? '')
                .toString()
                .trim();
        final parentId =
            parentIds.isNotEmpty ? parentIds.first : legacyParentId;

        if (parentId.isEmpty) {
          return const _InfoRow(
            icon: Icons.family_restroom,
            label: 'PARENT / GUARDIAN',
            value: 'Not set',
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(parentId)
              .snapshots(),
          builder: (context, parentSnap) {
            final parentData = parentSnap.data?.data() ?? {};
            final name = _resolveDisplayName(
              fullName: parentData['fullName'],
              username: parentData['username'],
              fallback: parentId,
            );
            return _InfoRow(
              icon: Icons.family_restroom,
              label: 'PARENT / GUARDIAN',
              value: name,
            );
          },
        );
      },
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final BuildContext parentContext;
  const _SettingsSheet({required this.parentContext});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: const BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Account settings',
              style: TextStyle(
                color: _onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SettingsTile(
            icon: Icons.edit_outlined,
            label: 'Edit profile',
            onTap: () {
              Navigator.pop(ctx);
              showEditProfileDialog(parentContext);
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Sign out',
            danger: true,
            onTap: () async {
              Navigator.pop(ctx);
              final shouldLogout = await showStudentLogoutDialog(
                parentContext,
                accentColor: _primary,
                surfaceColor: _surfaceLowest,
                softSurfaceColor: _surfaceContainerLow,
                titleColor: _onSurface,
                messageColor: _outline,
              );
              if (!shouldLogout) return;
              await FirebaseAuth.instance.signOut();
              AppSession.clear();
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFB03040) : _onSurface;
    final bg = danger
        ? const Color(0xFFF0D0D8)
        : _surfaceContainerLow;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
