import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  String roleLabel(String r) {
    switch (r) {
      case 'student': return 'Student';
      case 'teacher': return 'Homeroom Teacher';
      case 'parent': return 'Parent';
      case 'admin': return 'Admin';
      case 'gate': return 'Gate';
      default: return r;
    }
  }

  String dialogTitle() {
    if (lockedRole != null) return 'Add ${roleLabel(lockedRole)}';
    return 'Create New Account';
  }

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Create user',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (_, animation, _, child) {
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10 * animation.value,
          sigmaY: 10 * animation.value,
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45 * animation.value),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
        ),
      );
    },
    pageBuilder: (_, _, _) {
      return SafeArea(
        child: Center(
          child: StatefulBuilder(
            builder: (ctx, setS) {
              final showsClassPicker = role == 'student' || role == 'teacher';
              final needsClass = role == 'student';

              InputDecoration fieldDeco(String hint) => InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFB0B8C8), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF6F8FB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2848B0), width: 2),
                ),
              );

              Widget fieldLabel(String text) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8FA3BA),
                    letterSpacing: 0.9,
                  ),
                ),
              );

              Widget dropdownBox({
                required List<DropdownMenuItem<String>> items,
                required String? value,
                required ValueChanged<String?> onChanged,
                String hint = '',
              }) => Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE4E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                    hint: Text(
                      hint,
                      style: const TextStyle(color: Color(0xFFB0B8C8), fontSize: 14),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFFB0B8C8)),
                    items: items,
                    onChanged: onChanged,
                  ),
                ),
              );

              return Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 560,
                    maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 48,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── HEADER ─────────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.fromLTRB(28, 24, 20, 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F8FB),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF1FB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person_add_rounded,
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
                                      dialogTitle(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Fill in the details to create the account.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: busy ? null : () => Navigator.pop(ctx),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECEFF4),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Color(0xFF6B7A99),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── BODY ────────────────────────────────────────────
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Feedback banner
                                if (resultMsg != null) ...[
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: resultIsError
                                          ? const Color(0xFFFFF0F0)
                                          : const Color(0xFFEDF7F0),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: resultIsError
                                            ? const Color(0xFFE57373)
                                            : const Color(0xFF5BAD7F),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          resultIsError
                                              ? Icons.error_outline_rounded
                                              : Icons.check_circle_outline_rounded,
                                          size: 16,
                                          color: resultIsError
                                              ? const Color(0xFFD32F2F)
                                              : const Color(0xFF2E8B57),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: SelectableText(
                                            resultMsg!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: resultIsError
                                                  ? const Color(0xFFB71C1C)
                                                  : const Color(0xFF1E6840),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Full Name
                                fieldLabel('FULL NAME'),
                                TextField(
                                  controller: fullNameC,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: fieldDeco('e.g. Maria Ionescu'),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 18),

                                // Role (only if not locked) + Class in same row
                                if (lockedRole == null) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            fieldLabel('ROLE'),
                                            dropdownBox(
                                              value: role,
                                              hint: 'Select role...',
                                              items: const [
                                                DropdownMenuItem(value: 'student', child: Text('Student')),
                                                DropdownMenuItem(value: 'teacher', child: Text('Homeroom Teacher')),
                                                DropdownMenuItem(value: 'parent', child: Text('Parent')),
                                                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                                DropdownMenuItem(value: 'gate', child: Text('Gate')),
                                              ],
                                              onChanged: (v) => setS(() {
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
                                          child: _ClassDropdown(
                                            selectedClassId: selectedClassId,
                                            needsClass: needsClass,
                                            filterNoTeacher: role == 'teacher',
                                            onChanged: (v) => setS(() => selectedClassId = v ?? ''),
                                            fieldLabel: fieldLabel,
                                            dropdownBox: dropdownBox,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                ] else if (showsClassPicker) ...[
                                  _ClassDropdown(
                                    selectedClassId: selectedClassId,
                                    needsClass: needsClass,
                                    filterNoTeacher: role == 'teacher',
                                    onChanged: (v) => setS(() => selectedClassId = v ?? ''),
                                    fieldLabel: fieldLabel,
                                    dropdownBox: dropdownBox,
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                // Action row
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: busy ? null : () => Navigator.pop(ctx),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          side: const BorderSide(color: Color(0xFFD8DFF0)),
                                          foregroundColor: const Color(0xFF6B7A99),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton(
                                        onPressed: busy
                                            ? null
                                            : () async {
                                                final full = fullNameC.text.trim();
                                                if (full.isEmpty) {
                                                  setS(() {
                                                    resultMsg = 'Please enter the full name.';
                                                    resultIsError = true;
                                                  });
                                                  return;
                                                }
                                                if (needsClass && selectedClassId.trim().isEmpty) {
                                                  setS(() {
                                                    resultMsg = 'Please select a class for the student.';
                                                    resultIsError = true;
                                                  });
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
                                                  if (ctx.mounted) Navigator.pop(ctx);
                                                } catch (e) {
                                                  setS(() {
                                                    busy = false;
                                                    resultMsg = e.toString().replaceFirst('Exception: ', '');
                                                    resultIsError = true;
                                                  });
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2848B0),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: const Color(0xFF2848B0).withValues(alpha: 0.45),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: busy
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Text(
                                                'Create Account',
                                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                              ),
                                      ),
                                    ),
                                  ],
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
          ),
        ),
      );
    },
  );

  fullNameC.dispose();
}

class _ClassDropdown extends StatelessWidget {
  final String selectedClassId;
  final bool needsClass;
  final bool filterNoTeacher;
  final ValueChanged<String?> onChanged;
  final Widget Function(String) fieldLabel;
  final Widget Function({
    required List<DropdownMenuItem<String>> items,
    required String? value,
    required ValueChanged<String?> onChanged,
    String hint,
  }) dropdownBox;

  const _ClassDropdown({
    required this.selectedClassId,
    required this.needsClass,
    this.filterNoTeacher = false,
    required this.onChanged,
    required this.fieldLabel,
    required this.dropdownBox,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('classes').orderBy('name').snapshots(),
      builder: (_, snap) {
        var options = snap.hasData
            ? snap.data!.docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return {
                  'id': d.id,
                  'name': (data['name'] ?? d.id).toString(),
                  'teacherUsername': (data['teacherUsername'] ?? '').toString(),
                };
              }).toList()
            : <Map<String, String>>[];

        if (filterNoTeacher) {
          options = options.where((o) => o['teacherUsername']!.isEmpty).toList();
        }

        final hasSelected = options.any((o) => o['id'] == selectedClassId);

        final noneItem = DropdownMenuItem<String>(
          value: '__none__',
          child: Text(
            'None',
            style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fieldLabel(needsClass ? 'CLASS' : 'CLASS (optional)'),
            dropdownBox(
              value: hasSelected ? selectedClassId : (filterNoTeacher ? '__none__' : null),
              hint: needsClass ? 'Select class...' : 'No class',
              items: [
                if (filterNoTeacher) noneItem,
                ...options.map((o) => DropdownMenuItem<String>(value: o['id'], child: Text(o['name']!))),
              ],
              onChanged: (v) => onChanged(v == '__none__' ? '' : v),
            ),
          ],
        );
      },
    );
  }
}
