import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';
import '../services/admin_api.dart';
import '../student/logout_dialog.dart';

const _primary = Color(0xFF2848B0);
const _surfaceLowest = Color(0xFFFFFFFF);
const _surfaceContainerLow = Color(0xFFE8EAF2);
const _outline = Color(0xFF7A7E9A);
const _outlineVariant = Color(0xFFBFC3D9);
const _onSurface = Color(0xFF1A2050);
const _danger = Color(0xFFB03040);

/// Opens the teacher's account settings panel.
void showAccountBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

/// Opens the edit-profile dialog directly (without going through the bottom sheet).
void showTeacherEditProfileDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _TeacherAccountSettingsDialog(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showStudentLogoutDialog(
      context,
      accentColor: _primary,
      surfaceColor: Colors.white,
      softSurfaceColor: const Color(0xFFE8EEF4),
      titleColor: _primary,
      messageColor: const Color(0xFF6488A8),
    );

    if (!shouldLogout) return;
    try {
      await FirebaseAuth.instance.signOut();
      AppSession.clear();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e, st) {
      debugPrint('account_bottom_sheet: sign out teacher: $e\n$st');
    }
  }

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
              showTeacherEditProfileDialog(ctx);
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Sign out',
            danger: true,
            onTap: () => _logout(ctx),
          ),
        ],
      ),
    );
  }
}

// ACCOUNT SETTINGS DIALOG  (Email · Password)
class _TeacherAccountSettingsDialog extends StatefulWidget {
  const _TeacherAccountSettingsDialog();

  @override
  State<_TeacherAccountSettingsDialog> createState() =>
      _TeacherAccountSettingsDialogState();
}

class _TeacherAccountSettingsDialogState
    extends State<_TeacherAccountSettingsDialog> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmPasswordC = TextEditingController();
  final _verificationCodeC = TextEditingController();
  final _api = AdminApi();

  bool _editingEmail = false;
  bool _editingPassword = false;
  bool _saving = false;
  bool _sendingCode = false;
  bool _codeSent = false;
  bool _emailVerified = false;
  final bool _obscurePassword = true;
  String? _passwordError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _emailC.text = user?.email ?? '';
    _passwordC.text = '••••••••••••';
    final uid = user?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
        if (mounted) {
          setState(() {
            final email = (doc.data()?['personalEmail'] ?? '').toString();
            if (email.isNotEmpty) _emailC.text = email;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    _confirmPasswordC.dispose();
    _verificationCodeC.dispose();
    super.dispose();
  }

  Future<bool> _reauthenticate() async {
    final currentPassword = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const _TeacherReauthDialog(),
    );
    if (currentPassword == null || currentPassword.isEmpty) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
      return true;
    } on FirebaseAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current password is incorrect.')),
        );
      }
      return false;
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    var closed = false;
    try {
      final updates = <String, dynamic>{};
      if (_editingEmail && _emailC.text.trim().isNotEmpty) {
        if (!_emailVerified) {
          setState(() {
            _emailError = 'Verify the new email first.';
            _saving = false;
          });
          return;
        }
        updates['personalEmail'] = _emailC.text.trim();
      }
      if (_editingPassword &&
          _passwordC.text.trim().isNotEmpty &&
          _passwordC.text.trim() != '••••••••••••') {
        if (_passwordC.text.trim() != _confirmPasswordC.text.trim()) {
          setState(() {
            _passwordError = 'Passwords do not match.';
            _saving = false;
          });
          return;
        }
        if (_passwordC.text.trim().length < 8) {
          setState(() {
            _passwordError = 'Password must be at least 8 characters.';
            _saving = false;
          });
          return;
        }
        setState(() => _passwordError = null);
        final ok = await _reauthenticate();
        if (!ok) return;
        await FirebaseAuth.instance.currentUser?.updatePassword(
          _passwordC.text.trim(),
        );
      }
      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update(updates);
      }
      if (mounted) {
        closed = true;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Settings updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text('Could not save changes. Please try again.'),
          ),
        );
      }
    } finally {
      if (!closed && mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ScrollbarTheme(
          data: const ScrollbarThemeData(
            thickness: WidgetStatePropertyAll(2),
            radius: Radius.circular(2),
            crossAxisMargin: -12,
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Account Settings',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: _outline,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Divider(color: cs.outlineVariant),
                  const SizedBox(height: 18),

                  // EMAIL
                  const Text(
                    'EMAIL',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mail_outlined, color: _primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _editingEmail
                              ? TextField(
                                  controller: _emailC,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                  ),
                                  decoration: const InputDecoration.collapsed(
                                    hintText: 'Email',
                                  ),
                                )
                              : Text(
                                  _emailC.text,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _editingEmail = !_editingEmail;
                            _codeSent = false;
                            _emailVerified = false;
                            _emailError = null;
                            _verificationCodeC.clear();
                          }),
                          child: Icon(
                            Icons.edit_outlined,
                            color: _outline,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_editingEmail && !_emailVerified) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _sendingCode
                            ? null
                            : () async {
                                final email = _emailC.text.trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  setState(
                                    () => _emailError = 'Invalid email.',
                                  );
                                  return;
                                }
                                final uid =
                                    FirebaseAuth.instance.currentUser?.uid;
                                if (uid == null) return;
                                setState(() {
                                  _sendingCode = true;
                                  _emailError = null;
                                });
                                try {
                                  await _api.sendVerificationEmail(
                                    uid: uid,
                                    email: email,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _codeSent = true;
                                      _sendingCode = false;
                                    });
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    setState(() {
                                      _emailError = 'Could not send the code.';
                                      _sendingCode = false;
                                    });
                                  }
                                }
                              },
                        icon: _sendingCode
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_codeSent ? 'Resend code' : 'Send code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_codeSent && !_emailVerified) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: _outline,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'A code was sent to ${_emailC.text.trim()}. Enter it below.',
                            style: const TextStyle(
                              color: _outline,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.pin_outlined, color: _primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _verificationCodeC,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 15,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration.collapsed(
                                hintText: '••••••',
                                hintStyle: TextStyle(
                                  color: _outlineVariant,
                                  fontSize: 15,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final code = _verificationCodeC.text.trim();
                              if (code.isEmpty) {
                                setState(() => _emailError = 'Enter the code.');
                                return;
                              }
                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid;
                              if (uid == null) return;
                              setState(() => _emailError = null);
                              try {
                                final result = await _api.verifyEmailCode(
                                  uid: uid,
                                  code: code,
                                );
                                if (result['verified'] == true) {
                                  if (mounted) {
                                    setState(() => _emailVerified = true);
                                  }
                                } else {
                                  if (mounted) {
                                    setState(
                                      () => _emailError = 'Invalid code.',
                                    );
                                  }
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(() => _emailError = 'Invalid code.');
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Verify',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_emailVerified) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: _primary, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Email verified successfully!',
                          style: TextStyle(
                            color: _primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_emailError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _emailError!,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),

                  // PASSWORD
                  const Text(
                    'PASSWORD',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outlined, color: _primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _editingPassword
                              ? TextField(
                                  controller: _passwordC,
                                  autofocus: true,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                  ),
                                  decoration: const InputDecoration.collapsed(
                                    hintText: 'New password',
                                  ),
                                )
                              : const Text(
                                  '••••••••••••',
                                  style: TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            if (!_editingPassword) {
                              _editingPassword = true;
                              _passwordC.clear();
                              _confirmPasswordC.clear();
                              _passwordError = null;
                            } else {
                              _editingPassword = false;
                              _passwordC.text = '••••••••••••';
                              _confirmPasswordC.clear();
                              _passwordError = null;
                            }
                          }),
                          child: Icon(
                            Icons.edit_outlined,
                            color: _outline,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_editingPassword) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_outlined, color: _primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _confirmPasswordC,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 15,
                              ),
                              decoration: const InputDecoration.collapsed(
                                hintText: 'Confirm password',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_passwordError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _passwordError!,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// REAUTH DIALOG
class _TeacherReauthDialog extends StatefulWidget {
  const _TeacherReauthDialog();

  @override
  State<_TeacherReauthDialog> createState() => _TeacherReauthDialogState();
}

class _TeacherReauthDialogState extends State<_TeacherReauthDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm identity',
              style: TextStyle(
                color: _onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your current password to continue.',
              style: TextStyle(color: _outline, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              obscureText: _obscure,
              autofocus: true,
              style: const TextStyle(color: _onSurface, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Current password',
                hintStyle: const TextStyle(color: _outline),
                filled: true,
                fillColor: _surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFBFC3D9),
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFBFC3D9),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primary, width: 1.6),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _outline,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: _surfaceContainerLow,
                      foregroundColor: _onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _ctrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? _danger : _primary;
    return Material(
      color: danger ? color.withValues(alpha: 0.07) : _surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
