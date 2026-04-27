import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/admin_api.dart';

Future<void> showAdminCreateUserDialog(
  BuildContext context, {
  String? lockedRole,
}) async {
  final rng = Random.secure();
  final fullNameC = TextEditingController();

  String role = lockedRole ?? 'student';
  String selectedClassId = '';
  bool busy = false;
  String? resultMsg;
  bool resultIsError = false;
  String? createdUsername;
  String? createdPassword;

  String randPassword(int len) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';
    return List.generate(len, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String baseFromFullName(String fullName) {
    final n = fullName.trim().toLowerCase();
    if (n.isEmpty) return 'user';
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'user';
    final first = parts.first;
    final last = parts.length > 1 ? parts.last : '';
    final base = last.isEmpty ? first : '${first[0]}$last';
    return base.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String randDigits(int len) {
    const digits = '0123456789';
    return List.generate(len, (_) => digits[rng.nextInt(digits.length)]).join();
  }

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Create user',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
    pageBuilder: (_, _, _) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Center(
          child: StatefulBuilder(
            builder: (ctx, setS) {
              final showsClassPicker = role == 'student' || role == 'teacher';
              final needsClass = role == 'student';

              InputDecoration fieldDeco(String hint) => InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF7A7E9A), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF2F4F8),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE8EAF2))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE8EAF2))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2848B0), width: 2)),
              );

              Widget fieldLabel(String text) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6F92B0), letterSpacing: 0.8)),
              );

              Widget dropdownBox({
                required List<DropdownMenuItem<String>> items,
                required String? value,
                required ValueChanged<String?> onChanged,
                String hint = '',
              }) => Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(color: const Color(0xFFF2F4F8), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE8EAF2))),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF7A7E9A)),
                    hint: Text(hint, style: const TextStyle(color: Color(0xFF7A7E9A), fontSize: 14)),
                    items: items,
                    onChanged: onChanged,
                  ),
                ),
              );

              return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 680, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildCard(
                        title: 'Create New User',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (resultMsg != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: resultIsError ? const Color(0xFFFFF0F0) : const Color(0xFFF0F6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: resultIsError ? const Color(0xFFE57373) : const Color(0xFF2848B0)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(resultIsError ? Icons.error_outline : Icons.check_circle_outline, size: 16, color: resultIsError ? const Color(0xFFD32F2F) : const Color(0xFF2848B0)),
                                    const SizedBox(width: 8),
                                    Expanded(child: SelectableText(resultMsg!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: resultIsError ? const Color(0xFFB71C1C) : const Color(0xFF2848B0)))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (createdUsername != null) ...[
                              _credentialCopyRow('Username', createdUsername!),
                              const SizedBox(height: 8),
                              _credentialCopyRow('Password', createdPassword!),
                              const SizedBox(height: 20),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ] else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        fieldLabel('FULL NAME'),
                                        TextField(controller: fullNameC, decoration: fieldDeco('Enter name...')),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        fieldLabel('USER ROLE'),
                                        dropdownBox(
                                          value: role,
                                          items: [
                                            const DropdownMenuItem(value: 'student', child: Text('Student')),
                                            const DropdownMenuItem(value: 'teacher', child: Text('Homeroom Teacher')),
                                            const DropdownMenuItem(value: 'parent', child: Text('Parent')),
                                            const DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                            const DropdownMenuItem(value: 'gate', child: Text('Gate')),
                                          ],
                                          onChanged: lockedRole != null
                                              ? (_) {}
                                              : (v) => setS(() {
                                                  role = v ?? 'student';
                                                  if (role != 'student' && role != 'teacher') selectedClassId = '';
                                                }),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (showsClassPicker) ...[
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance.collection('classes').orderBy('name').snapshots(),
                                        builder: (_, snap) {
                                          final options = snap.hasData
                                              ? snap.data!.docs.map((d) {
                                                  final data = d.data() as Map<String, dynamic>;
                                                  return {'id': d.id, 'name': (data['name'] ?? d.id).toString()};
                                                }).toList()
                                              : <Map<String, String>>[];
                                          final hasSelected = options.any((o) => o['id'] == selectedClassId);
                                          if (!hasSelected && selectedClassId.isNotEmpty) {
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              setS(() => selectedClassId = '');
                                            });
                                          }
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              fieldLabel(needsClass ? 'CLASS' : 'CLASS (optional)'),
                                              dropdownBox(
                                                value: hasSelected ? selectedClassId : null,
                                                hint: needsClass ? 'Select...' : 'No class',
                                                items: options.map((o) => DropdownMenuItem<String>(value: o['id'], child: Text(o['name']!))).toList(),
                                                onChanged: (v) => setS(() => selectedClassId = v ?? ''),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Spacer(),
                                  ElevatedButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final full = fullNameC.text.trim();
                                            if (full.isEmpty) {
                                              setS(() { resultMsg = 'Fill in the full name.'; resultIsError = true; });
                                              return;
                                            }
                                            if (needsClass && selectedClassId.trim().isEmpty) {
                                              setS(() { resultMsg = 'Select a class for the student.'; resultIsError = true; });
                                              return;
                                            }
                                            final uname = '${baseFromFullName(full)}${randDigits(3)}';
                                            final pass = randPassword(10);
                                            setS(() { busy = true; resultMsg = null; });
                                            try {
                                              await AdminApi().createUser(
                                                username: uname.toLowerCase(),
                                                password: pass,
                                                role: role,
                                                fullName: full,
                                                classId: showsClassPicker && selectedClassId.trim().isNotEmpty
                                                    ? selectedClassId
                                                    : null,
                                              );
                                              setS(() {
                                                busy = false;
                                                createdUsername = uname.toLowerCase();
                                                createdPassword = pass;
                                                resultMsg = 'Account was created successfully!';
                                                resultIsError = false;
                                                fullNameC.clear();
                                                selectedClassId = '';
                                              });
                                            } catch (e) {
                                              setS(() {
                                                busy = false;
                                                resultMsg = e.toString().replaceFirst('Exception: ', '');
                                                resultIsError = true;
                                              });
                                            }
                                          },
                                    icon: busy
                                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.person_add_rounded, size: 18),
                                    label: Text(busy ? 'Creating...' : 'Create User Account', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2848B0),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: const Color(0xFF2848B0).withValues(alpha: 0.45),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );

  fullNameC.dispose();
}

Widget _credentialCopyRow(String label, String value) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F6FF),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF2848B0).withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2848B0))),
        Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111111)))),
        const SizedBox(width: 8),
        _CopyButton(value: value),
      ],
    ),
  );
}

class _CopyButton extends StatefulWidget {
  final String value;
  const _CopyButton({required this.value});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _copied
              ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
              : const Color(0xFF2848B0).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 14,
              color: _copied
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF2848B0),
            ),
            const SizedBox(width: 6),
            Text(
              _copied ? 'Copied!' : 'Copy',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _copied
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF2848B0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildCard({required String title, required Widget child}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8EAF2)),
      boxShadow: [BoxShadow(color: const Color(0xFF2848B0).withValues(alpha: 0.06), blurRadius: 26, offset: const Offset(0, 14))],
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
                  Container(width: 4, height: 22, decoration: BoxDecoration(color: const Color(0xFF2848B0), borderRadius: BorderRadius.circular(999))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111111)))),
                ],
              ),
            ),
          ),
          const Divider(color: Color(0xFFE8EAF2), height: 1),
          Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 22), child: child),
        ],
      ),
    ),
  );
}
