import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

// ─── Slot definition ──────────────────────────────────────────────────────────

class _SlotDef {
  final String type; // 'lesson' | 'break'
  final int duration; // minutes
  _SlotDef({required this.type, required this.duration});
  Map<String, dynamic> toMap() => {'type': type, 'duration': duration};
  static _SlotDef fromMap(dynamic m) {
    final map = Map<String, dynamic>.from(m as Map);
    return _SlotDef(
      type: map['type'] as String? ?? 'lesson',
      duration: (map['duration'] as num?)?.toInt() ?? 50,
    );
  }
}

// ─── Time helpers ─────────────────────────────────────────────────────────────

int _toMin(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String _fromMin(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

List<(int, String, String)> _lessonTimes(String start, List<_SlotDef> slots) {
  final out = <(int, String, String)>[];
  int cur = _toMin(start);
  int li = 0;
  for (final s in slots) {
    final end = cur + s.duration;
    if (s.type == 'lesson') {
      out.add((li, _fromMin(cur), _fromMin(end)));
      li++;
    }
    cur = end;
  }
  return out;
}

// ─── Color palette ────────────────────────────────────────────────────────────

const List<Color> _kPalette = [
  Color(0xFF4361EE),
  Color(0xFF7B2D8B),
  Color(0xFFE63946),
  Color(0xFFFF8C00),
  Color(0xFF2DC653),
  Color(0xFF00B4D8),
  Color(0xFFFF006E),
  Color(0xFF8338EC),
  Color(0xFFFB5607),
  Color(0xFF118AB2),
  Color(0xFF06D6A0),
  Color(0xFFFFBE0B),
];

// ─── Constants ────────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF2848B0);
const _kDayHeaders = ['MON', 'TUE', 'WED', 'THU', 'FRI'];
const _kDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

// ─── Blur dialog ─────────────────────────────────────────────────────────────

Future<T?> _blurDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, anim, anim2, child) => BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10 * anim.value,
          sigmaY: 10 * anim.value,
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45 * anim.value),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          ),
        ),
      ),
      pageBuilder: (ctx, anim3, anim4) => builder(ctx),
    );

// ─────────────────────────────────────────────────────────────────────────────
// SEARCHABLE CLASS DROPDOWN
// ─────────────────────────────────────────────────────────────────────────────

class _ClassSelector extends StatefulWidget {
  const _ClassSelector({
    required this.classes,
    required this.timetableIds,
    required this.selectedId,
    required this.onSelect,
  });
  final List<QueryDocumentSnapshot> classes;
  final Set<String> timetableIds;
  final String? selectedId;
  final void Function(String) onSelect;

  @override
  State<_ClassSelector> createState() => _ClassSelectorState();
}

class _ClassSelectorState extends State<_ClassSelector> {
  final _link = LayerLink();
  OverlayEntry? _entry;
  bool _hovered = false;

  void _open() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (ctx) => _ClassDropdownOverlay(
        link: _link,
        classes: widget.classes,
        timetableIds: widget.timetableIds,
        onSelect: (id) {
          _close();
          widget.onSelect(id);
        },
        onClose: _close,
      ),
    );
    overlay.insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _entry != null;
    String label = 'Select class';
    if (widget.selectedId != null) {
      final doc = widget.classes.cast<QueryDocumentSnapshot?>().firstWhere(
        (d) => d?.id == widget.selectedId,
        orElse: () => null,
      );
      if (doc != null) {
        final data = doc.data() as Map<String, dynamic>;
        label = (data['name'] ?? doc.id).toString();
      } else {
        label = widget.selectedId!;
      }
    }

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: isOpen ? _close : _open,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: (isOpen || _hovered) ? const Color(0xFFEEF1FB) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOpen ? _kPrimary : (_hovered ? const Color(0xFF2848B0) : const Color(0xFFDDE1EA)),
                width: (isOpen || _hovered) ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CLASS: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9AA0B0),
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2050),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 18,
                color: const Color(0xFF9AA0B0),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _ClassDropdownOverlay extends StatefulWidget {
  const _ClassDropdownOverlay({
    required this.link,
    required this.classes,
    required this.timetableIds,
    required this.onSelect,
    required this.onClose,
  });
  final LayerLink link;
  final List<QueryDocumentSnapshot> classes;
  final Set<String> timetableIds;
  final void Function(String) onSelect;
  final VoidCallback onClose;

  @override
  State<_ClassDropdownOverlay> createState() => _ClassDropdownOverlayState();
}

class _ClassDropdownOverlayState extends State<_ClassDropdownOverlay> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.classes.where((d) {
      return d.id.toLowerCase().contains(_q);
    }).toList();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 260, maxHeight: 340),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search class...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon:
                              const Icon(Icons.search, size: 16),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _q = v.toLowerCase().trim()),
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No class found',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final doc = filtered[i];
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                final name =
                                    (data['name'] ?? doc.id).toString();
                                final hasT =
                                    widget.timetableIds.contains(doc.id);
                                return InkWell(
                                  onTap: () => widget.onSelect(doc.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (hasT)
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F5E9),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: const Text(
                                              'timetable',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF2DC653),
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
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCHABLE TEACHER DROPDOWN
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherSelector extends StatefulWidget {
  const _TeacherSelector({
    required this.teacherDocs,
    required this.selectedUsername,
    required this.onSelect,
  });
  final List<QueryDocumentSnapshot> teacherDocs;
  final String? selectedUsername;
  final void Function(String) onSelect;

  @override
  State<_TeacherSelector> createState() => _TeacherSelectorState();
}

class _TeacherSelectorState extends State<_TeacherSelector> {
  final _link = LayerLink();
  OverlayEntry? _entry;

  void _open() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (ctx) => _TeacherDropdownOverlay(
        link: _link,
        teacherDocs: widget.teacherDocs,
        onSelect: (u) {
          _close();
          widget.onSelect(u);
        },
        onClose: _close,
      ),
    );
    overlay.insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _entry != null;
    String label = 'Select teacher';
    if (widget.selectedUsername != null) {
      final doc = widget.teacherDocs.cast<QueryDocumentSnapshot?>().firstWhere(
        (d) {
          final data = d?.data() as Map<String, dynamic>?;
          return (data?['username'] ?? d?.id) == widget.selectedUsername;
        },
        orElse: () => null,
      );
      if (doc != null) {
        final data = doc.data() as Map<String, dynamic>;
        label = ((data['fullName'] as String?)?.trim().isNotEmpty == true
            ? data['fullName'] as String
            : data['username'] as String? ?? widget.selectedUsername)!;
      } else {
        label = widget.selectedUsername!;
      }
    }

    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: isOpen ? _close : _open,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isOpen ? _kPrimary : const Color(0xFFBBBBBB),
              width: isOpen ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.selectedUsername == null
                        ? const Color(0xFF9E9E9E)
                        : const Color(0xFF1A2050),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 18,
                color: const Color(0xFF9AA0B0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherDropdownOverlay extends StatefulWidget {
  const _TeacherDropdownOverlay({
    required this.link,
    required this.teacherDocs,
    required this.onSelect,
    required this.onClose,
  });
  final LayerLink link;
  final List<QueryDocumentSnapshot> teacherDocs;
  final void Function(String) onSelect;
  final VoidCallback onClose;

  @override
  State<_TeacherDropdownOverlay> createState() =>
      _TeacherDropdownOverlayState();
}

class _TeacherDropdownOverlayState extends State<_TeacherDropdownOverlay> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.teacherDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final fn = (data['fullName'] as String?)?.trim() ?? '';
      final u = (data['username'] as String?) ?? doc.id;
      return fn.toLowerCase().contains(_q) || u.toLowerCase().contains(_q);
    }).toList();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.white,
              elevation: 16,
              shadowColor: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 340, maxHeight: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search teacher...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 16),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _q = v.toLowerCase().trim()),
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No teacher found',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final doc = filtered[i];
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                final u = (data['username'] as String?) ??
                                    doc.id;
                                final fn =
                                    (data['fullName'] as String?)?.trim();
                                final displayName =
                                    (fn?.isNotEmpty == true) ? fn! : u;
                                return InkWell(
                                  onTap: () => widget.onSelect(u),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.person_outline,
                                          size: 15,
                                          color: Color(0xFF9AA0B0),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
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
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class AdminTimetablePage extends StatefulWidget {
  const AdminTimetablePage({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<AdminTimetablePage> createState() => _AdminTimetablePageState();
}

class _AdminTimetablePageState extends State<AdminTimetablePage> {
  String? _selectedClassId;
  final _db = FirebaseFirestore.instance;

  // ─── Streams ────────────────────────────────────────────────────────────────

  Stream<QuerySnapshot> get _classesStream =>
      _db.collection('classes').snapshots();

  Stream<QuerySnapshot> get _timetablesStream =>
      _db.collection('timetables').snapshots();

  Stream<QuerySnapshot> get _subjectsStream =>
      _db.collection('subjects').orderBy('name').snapshots();

  Stream<QuerySnapshot> get _teachersStream =>
      _db.collection('users').where('role', isEqualTo: 'teacher').snapshots();

  Stream<DocumentSnapshot> _timetableDoc(String classId) =>
      _db.collection('timetables').doc(classId).snapshots();

  // ─── Sort ────────────────────────────────────────────────────────────────────

  int _cmpClass(String a, String b) {
    final am = RegExp(r'^\d+').firstMatch(a);
    final bm = RegExp(r'^\d+').firstMatch(b);
    final ai = am != null ? int.tryParse(am.group(0)!) : null;
    final bi = bm != null ? int.tryParse(bm.group(0)!) : null;
    if (ai != null && bi != null && ai != bi) return ai.compareTo(bi);
    if (ai != null && bi == null) return -1;
    if (ai == null && bi != null) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  List<QueryDocumentSnapshot> _sorted(List<QueryDocumentSnapshot> docs) {
    final list = List<QueryDocumentSnapshot>.from(docs);
    list.sort((a, b) {
      final ad = a.data() as Map<String, dynamic>;
      final bd = b.data() as Map<String, dynamic>;
      return _cmpClass(
        (ad['name'] ?? a.id).toString(),
        (bd['name'] ?? b.id).toString(),
      );
    });
    return list;
  }

  // ─── Firestore writes ────────────────────────────────────────────────────────

  Future<void> _saveSubject(String? id, String name, int colorVal) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      'color': colorVal,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('subjects').add(data);
    } else {
      await _db
          .collection('subjects')
          .doc(id)
          .set(data, SetOptions(merge: true));
    }
  }

  Future<void> _deleteSubject(String id) async {
    final timetables = await _db.collection('timetables').get();
    final batch = _db.batch();
    for (final doc in timetables.docs) {
      final data = doc.data();
      final days = data['days'] as Map<String, dynamic>?;
      if (days == null) continue;
      final updates = <String, dynamic>{};
      for (final dayEntry in days.entries) {
        final lessons = dayEntry.value as Map<String, dynamic>?;
        if (lessons == null) continue;
        for (final lessonEntry in lessons.entries) {
          final lesson = lessonEntry.value as Map<String, dynamic>?;
          if (lesson?['subjectId'] == id) {
            updates['days.${dayEntry.key}.${lessonEntry.key}'] =
                FieldValue.delete();
          }
        }
      }
      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        batch.update(doc.reference, updates);
      }
    }
    batch.delete(_db.collection('subjects').doc(id));
    await batch.commit();
  }

  Future<void> _saveTimetable(
    String classId,
    String startTime,
    List<_SlotDef> slots,
  ) =>
      _db.collection('timetables').doc(classId).set({
        'classId': classId,
        'startTime': startTime,
        'slots': slots.map((s) => s.toMap()).toList(),
        'days': {},
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> _updateTimetableStructure(
    String classId,
    String startTime,
    List<_SlotDef> slots,
  ) =>
      _db.collection('timetables').doc(classId).set({
        'startTime': startTime,
        'slots': slots.map((s) => s.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> _assignLesson(
    String classId,
    int day,
    int lessonIdx,
    String subjectId,
    String teacherUsername,
  ) =>
      _db.collection('timetables').doc(classId).update({
        'days.$day.$lessonIdx': {
          'subjectId': subjectId,
          'teacherUsername': teacherUsername,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> _clearLesson(String classId, int day, int lessonIdx) =>
      _db.collection('timetables').doc(classId).update({
        'days.$day.$lessonIdx': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> _deleteTimetable(String classId) =>
      _db.collection('timetables').doc(classId).delete();

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Access denied.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: widget.embedded
          ? null
          : AppBar(
              toolbarHeight: 68,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1A2050)),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Timetables',
                style: TextStyle(
                  color: Color(0xFF1A2050),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _classesStream,
        builder: (ctx, classSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: _timetablesStream,
            builder: (ctx, ttSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: _subjectsStream,
                builder: (ctx, subSnap) {
                  final classDocs = _sorted(classSnap.data?.docs ?? []);
                  final timetableIds =
                      (ttSnap.data?.docs ?? []).map((d) => d.id).toSet();
                  final subjectDocs = subSnap.data?.docs ?? [];

                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatCards(
                          totalClasses: classDocs.length,
                          withTimetable: timetableIds.length,
                          totalSubjects: subjectDocs.length,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _buildMainCard(
                            classDocs: classDocs,
                            timetableIds: timetableIds,
                            subjectDocs: subjectDocs,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }


  // ─── Stat cards ──────────────────────────────────────────────────────────────

  Widget _buildStatCards({
    required int totalClasses,
    required int withTimetable,
    required int totalSubjects,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.class_outlined,
            iconBg: const Color(0xFFEEF1FB),
            iconColor: _kPrimary,
            label: 'TOTAL CLASSES',
            value: '$totalClasses',
            subtitle: 'in system',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _statCard(
            icon: Icons.calendar_today_outlined,
            iconBg: const Color(0xFFEDF7F0),
            iconColor: const Color(0xFF2E8B57),
            label: 'WITH TIMETABLE',
            value: '$withTimetable',
            subtitle: 'of $totalClasses classes',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _statCard(
            icon: Icons.auto_stories_outlined,
            iconBg: const Color(0xFFF3EDFB),
            iconColor: const Color(0xFF7B4FCC),
            label: 'SUBJECTS',
            value: '$totalSubjects',
            subtitle: 'defined',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _statCard(
            icon: Icons.pending_actions_outlined,
            iconBg: const Color(0xFFFFF8E8),
            iconColor: const Color(0xFFF5A623),
            label: 'NO TIMETABLE',
            value: '${totalClasses - withTimetable}',
            subtitle: 'requires setup',
          ),
        ),
      ],
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

  // ─── Main card ───────────────────────────────────────────────────────────────

  Widget _buildMainCard({
    required List<QueryDocumentSnapshot> classDocs,
    required Set<String> timetableIds,
    required List<QueryDocumentSnapshot> subjectDocs,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2848B0).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Weekly Timetable',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2050),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'View and edit the weekly timetable of the class.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7A7E9A),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ClassSelector(
                        classes: classDocs,
                        timetableIds: timetableIds,
                        selectedId: _selectedClassId,
                        onSelect: (id) => setState(() => _selectedClassId = id),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Buttons — centered vertically against the left column
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.menu_book_outlined, size: 15, color: Color(0xFF2848B0)),
                      label: const Text('Subjects', style: TextStyle(color: Color(0xFF2848B0))),
                      style: _headerButtonStyle(),
                      onPressed: () => _showSubjectsPanel(subjectDocs),
                    ),
                    if (_selectedClassId != null &&
                        timetableIds.contains(_selectedClassId)) ...[
                      const SizedBox(width: 10),
                      StreamBuilder<DocumentSnapshot>(
                        stream: _timetableDoc(_selectedClassId!),
                        builder: (ctx, snap) {
                          if (snap.data?.exists != true) return const SizedBox();
                          final data = snap.data!.data() as Map<String, dynamic>;
                          final slots = ((data['slots'] as List?) ?? [])
                              .map(_SlotDef.fromMap)
                              .toList();
                          final startTime = data['startTime'] as String? ?? '08:00';
                          return OutlinedButton.icon(
                            icon: const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFF2848B0)),
                            label: const Text('Edit Structure', style: TextStyle(color: Color(0xFF2848B0))),
                            style: _headerButtonStyle(),
                            onPressed: () => _showSlotEditor(
                              classId: _selectedClassId!,
                              initialStartTime: startTime,
                              initialSlots: slots,
                              isNew: false,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8EAF2)),
          // Content: grid or empty state
          Expanded(
            child: _selectedClassId == null
                ? _buildNoSelection()
                : StreamBuilder<DocumentSnapshot>(
                    stream: _timetableDoc(_selectedClassId!),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.data?.exists != true) {
                        return _buildNoTimetable(_selectedClassId!);
                      }
                      final data = snap.data!.data() as Map<String, dynamic>;
                      return _buildGrid(
                        classId: _selectedClassId!,
                        timetableData: data,
                        subjectDocs: subjectDocs,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─── No selection state ───────────────────────────────────────────────────────

  Widget _buildNoSelection() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 32,
                color: _kPrimary.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a class',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2050),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Use the dropdown above to\nview or create a class timetable.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF9AA0B0)),
            ),
          ],
        ),
      );

  // ─── No timetable state ───────────────────────────────────────────────────────

  Widget _buildNoTimetable(String classId) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFFFBE0B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_chart_outlined,
                size: 32,
                color: Color(0xFFFFBE0B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Class $classId has no timetable',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2050),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create a timetable to assign subjects and teachers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF9AA0B0)),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create timetable'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 13,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => _showSlotEditor(
                classId: classId,
                initialStartTime: '08:00',
                initialSlots: [
                  _SlotDef(type: 'lesson', duration: 50),
                  _SlotDef(type: 'break', duration: 10),
                  _SlotDef(type: 'lesson', duration: 50),
                  _SlotDef(type: 'break', duration: 10),
                  _SlotDef(type: 'lesson', duration: 50),
                  _SlotDef(type: 'break', duration: 20),
                  _SlotDef(type: 'lesson', duration: 50),
                  _SlotDef(type: 'break', duration: 10),
                  _SlotDef(type: 'lesson', duration: 50),
                  _SlotDef(type: 'break', duration: 10),
                  _SlotDef(type: 'lesson', duration: 50),
                ],
                isNew: true,
              ),
            ),
          ],
        ),
      );

  // ─── Grid ────────────────────────────────────────────────────────────────────

  Widget _buildGrid({
    required String classId,
    required Map<String, dynamic> timetableData,
    required List<QueryDocumentSnapshot> subjectDocs,
  }) {
    final startTime = timetableData['startTime'] as String? ?? '08:00';
    final rawSlots =
        (timetableData['slots'] as List?)?.cast<dynamic>() ?? [];
    final slots = rawSlots.map(_SlotDef.fromMap).toList();
    final times = _lessonTimes(startTime, slots);
    final days =
        (timetableData['days'] as Map<String, dynamic>?) ?? {};

    final subjectMap = <String, Map<String, dynamic>>{
      for (final s in subjectDocs) s.id: s.data() as Map<String, dynamic>,
    };

    return StreamBuilder<QuerySnapshot>(
      stream: _teachersStream,
      builder: (ctx, teachSnap) {
        final teacherMap = <String, String>{};
        for (final t in teachSnap.data?.docs ?? []) {
          final d = t.data() as Map<String, dynamic>;
          final u = d['username'] as String? ?? t.id;
          final fn = (d['fullName'] as String?)?.trim() ?? u;
          teacherMap[u] = fn;
        }
        final teacherDocs = teachSnap.data?.docs ?? [];

        if (times.isEmpty) {
          return const Center(
            child: Text('No lesson slots in this structure.'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day header row
                Row(
                  children: [
                    const SizedBox(width: 72), // time col
                    ...List.generate(5, (di) {
                      return Container(
                        width: 162,
                        height: 38,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: _kPrimary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _kDayHeaders[di],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _kPrimary,
                            letterSpacing: 1.4,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                // Lesson rows
                ...times.map((lt) {
                  final (lessonIdx, startT, endT) = lt;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Time label
                        SizedBox(
                          width: 72,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                startT,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A2050),
                                ),
                              ),
                              Text(
                                endT,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFBBBBBB),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Cells
                        ...List.generate(5, (di) {
                          final dayNum = di + 1;
                          final dayMap =
                              days[dayNum.toString()] as Map?;
                          final assignment = dayMap?[
                              lessonIdx.toString()] as Map?;
                          return Container(
                            width: 162,
                            height: 68,
                            margin: const EdgeInsets.only(left: 8),
                            child: _buildCell(
                              classId: classId,
                              day: dayNum,
                              lessonIdx: lessonIdx,
                              slotTime: '$startT – $endT',
                              assignment: assignment != null
                                  ? Map<String, dynamic>.from(assignment)
                                  : null,
                              subjectMap: subjectMap,
                              teacherMap: teacherMap,
                              subjectDocs: subjectDocs,
                              teacherDocs: teacherDocs,
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Cell ────────────────────────────────────────────────────────────────────

  Widget _buildCell({
    required String classId,
    required int day,
    required int lessonIdx,
    required String slotTime,
    Map<String, dynamic>? assignment,
    required Map<String, Map<String, dynamic>> subjectMap,
    required Map<String, String> teacherMap,
    required List<QueryDocumentSnapshot> subjectDocs,
    required List<QueryDocumentSnapshot> teacherDocs,
  }) {
    void onTap() => _showAssignDialog(
          classId: classId,
          day: day,
          lessonIdx: lessonIdx,
          slotTime: slotTime,
          existing: assignment,
          subjectDocs: subjectDocs,
          teacherDocs: teacherDocs,
        );

    return _TimetableCell(
      assignment: assignment,
      subjectMap: subjectMap,
      teacherMap: teacherMap,
      shortName: _shortName,
      onTap: onTap,
    );
  }

  ButtonStyle _headerButtonStyle() => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFFEEF1FB);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.all(const Color(0xFF2848B0)),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return const BorderSide(color: Color(0xFF2848B0), width: 1.5);
          }
          return const BorderSide(color: Color(0xFFC0C4D8));
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      );

  String _shortName(String full) {
    final p = full.trim().split(' ');
    if (p.length <= 1) return full;
    return '${p.first} ${p.last[0]}.';
  }

  // ─── Subjects side panel ──────────────────────────────────────────────────────

  Future<void> _showSubjectsPanel(List<QueryDocumentSnapshot> subjectDocs) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: (ctx, anim, anim2, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
      pageBuilder: (ctx, anim3, anim4) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.white,
          child: SizedBox(
            width: 360,
            height: double.infinity,
            child: _SubjectsPanelContent(
              db: _db,
              onSaveSubject: _saveSubject,
              onDeleteSubject: _deleteSubject,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────────

  Future<void> _showSlotEditor({
    required String classId,
    required String initialStartTime,
    required List<_SlotDef> initialSlots,
    required bool isNew,
  }) async {
    String startTime = initialStartTime;
    final slots = initialSlots
        .map((s) => _SlotDef(type: s.type, duration: s.duration))
        .toList();

    await _blurDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final times = _lessonTimes(startTime, slots);
          return Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 520, maxHeight: 680),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isNew
                                  ? 'Timetable setup – $classId'
                                  : 'Edit structure – $classId',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A2050),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: ListView(
                        padding:
                            const EdgeInsets.fromLTRB(28, 0, 28, 16),
                        children: [
                          // Start time
                          Row(
                            children: [
                              const Text(
                                'Start time:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 14),
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.access_time,
                                  size: 16,
                                ),
                                label: Text(
                                  startTime,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: () async {
                                  final p = startTime.split(':');
                                  final picked = await showTimePicker(
                                    context: ctx,
                                    initialTime: TimeOfDay(
                                      hour: int.parse(p[0]),
                                      minute: int.parse(p[1]),
                                    ),
                                    builder: (c, child) => MediaQuery(
                                      data: MediaQuery.of(c).copyWith(
                                        alwaysUse24HourFormat: true,
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setS(() {
                                      startTime =
                                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Slots header
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Slots',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.add, size: 15),
                                label: const Text('Hour'),
                                onPressed: () => setS(() => slots.add(
                                      _SlotDef(
                                          type: 'lesson', duration: 50),
                                    )),
                              ),
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.free_breakfast_outlined,
                                  size: 15,
                                ),
                                label: const Text('Break'),
                                onPressed: () => setS(() => slots.add(
                                      _SlotDef(
                                          type: 'break', duration: 10),
                                    )),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...List.generate(slots.length, (i) {
                            final slot = slots[i];
                            final isLesson = slot.type == 'lesson';
                            int li = -1;
                            if (isLesson) {
                              li = slots
                                      .take(i + 1)
                                      .where((s) => s.type == 'lesson')
                                      .length -
                                  1;
                            }
                            final ti =
                                isLesson && li < times.length
                                    ? times[li]
                                    : null;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isLesson
                                    ? const Color(0xFFEDF2FF)
                                    : const Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isLesson
                                      ? const Color(0xFFC5D3F5)
                                      : const Color(0xFFE4E4E4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isLesson
                                        ? Icons.menu_book_outlined
                                        : Icons.free_breakfast_outlined,
                                    size: 16,
                                    color: isLesson
                                        ? _kPrimary
                                        : Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isLesson
                                              ? 'Hour ${li + 1}'
                                              : 'Break${slot.duration >= 15 ? ' long' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isLesson
                                                ? _kPrimary
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                        if (ti != null)
                                          Text(
                                            '${ti.$2} – ${ti.$3}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF999999),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Duration stepper ±5 min
                                  Row(
                                    children: [
                                      _stepBtn(
                                        Icons.remove,
                                        enabled: slot.duration > 5,
                                        onTap: () => setS(() {
                                          slots[i] = _SlotDef(
                                            type: slot.type,
                                            duration: slot.duration - 5,
                                          );
                                        }),
                                      ),
                                      SizedBox(
                                        width: 56,
                                        child: Text(
                                          '${slot.duration} min',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      _stepBtn(
                                        Icons.add,
                                        enabled: true,
                                        onTap: () => setS(() {
                                          slots[i] = _SlotDef(
                                            type: slot.type,
                                            duration: slot.duration + 5,
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () =>
                                        setS(() => slots.removeAt(i)),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.red.shade300,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(28, 14, 28, 20),
                      child: Row(
                        children: [
                          if (!isNew)
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.red),
                              label: const Text('Delete timetable',
                                  style: TextStyle(color: Colors.red)),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _confirmDelete(classId);
                              },
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                                vertical: 13,
                              ),
                            ),
                            onPressed: () async {
                              if (slots
                                  .where((s) => s.type == 'lesson')
                                  .isEmpty) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                  content: Text(
                                      'Add at least one lesson.'),
                                ));
                                return;
                              }
                              Navigator.pop(ctx);
                              if (isNew) {
                                await _saveTimetable(
                                    classId, startTime, slots);
                              } else {
                                await _updateTimetableStructure(
                                    classId, startTime, slots);
                              }
                            },
                            child: Text(
                                isNew ? 'Create timetable' : 'Save'),
                          ),
                        ],
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
  }

  Widget _stepBtn(IconData icon,
      {required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(
          icon,
          size: 13,
          color: enabled ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
    );
  }

  Future<void> _showAssignDialog({
    required String classId,
    required int day,
    required int lessonIdx,
    required String slotTime,
    Map<String, dynamic>? existing,
    required List<QueryDocumentSnapshot> subjectDocs,
    required List<QueryDocumentSnapshot> teacherDocs,
  }) async {
    String? selSubject = existing?['subjectId'] as String?;
    String? selTeacher = existing?['teacherUsername'] as String?;

    await _blurDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _kDayNames[day - 1],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A2050),
                                ),
                              ),
                              Text(
                                slotTime,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9AA0B0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (existing != null)
                          TextButton.icon(
                            icon: const Icon(Icons.clear,
                                size: 14, color: Colors.red),
                            label: const Text(
                              'Clear',
                              style: TextStyle(
                                  color: Colors.red, fontSize: 13),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _clearLesson(
                                  classId, day, lessonIdx);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _dropdownLabel('Subject'),
                    const SizedBox(height: 8),
                    subjectDocs.isEmpty
                        ? _hint(
                            'No subjects. Press "Subjects" in the header to add.')
                        : DropdownButtonFormField<String>(
                            initialValue: selSubject,
                            hint: const Text('Select subject'),
                            decoration: _dropDeco(),
                            items: subjectDocs.map((doc) {
                              final d = doc.data()
                                  as Map<String, dynamic>;
                              final c = Color(
                                  d['color'] as int? ?? 0xFF4361EE);
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(d['name'] as String? ?? ''),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setS(() => selSubject = v),
                          ),
                    const SizedBox(height: 16),
                    _dropdownLabel('Teacher'),
                    const SizedBox(height: 8),
                    teacherDocs.isEmpty
                        ? _hint('No teachers registered.')
                        : _TeacherSelector(
                            teacherDocs: teacherDocs,
                            selectedUsername: selTeacher,
                            onSelect: (u) => setS(() => selTeacher = u),
                          ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                          ),
                          onPressed: (selSubject == null ||
                                  selTeacher == null)
                              ? null
                              : () async {
                                  Navigator.pop(ctx);
                                  await _assignLesson(
                                    classId,
                                    day,
                                    lessonIdx,
                                    selSubject!,
                                    selTeacher!,
                                  );
                                },
                          child: const Text('Save'),
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
  }

  Widget _dropdownLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF555555),
        ),
      );

  InputDecoration _dropDeco() => InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        isDense: true,
      );

  Widget _hint(String text) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 14, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      );

  Future<void> _confirmDelete(String classId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete timetable'),
        content: Text(
          'Are you sure you want to delete the timetable for class $classId?\nAll assignments will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteTimetable(classId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBJECTS PANEL (slide-in from right)
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectsPanelContent extends StatelessWidget {
  const _SubjectsPanelContent({
    required this.db,
    required this.onSaveSubject,
    required this.onDeleteSubject,
  });
  final FirebaseFirestore db;
  final Future<void> Function(String? id, String name, int colorVal)
      onSaveSubject;
  final Future<void> Function(String id) onDeleteSubject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Manage subjects',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2050),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        // Add button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add new subject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => _showSubjectDialog(context),
            ),
          ),
        ),
        // Subjects list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('subjects').orderBy('name').snapshots(),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No subjects added',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (ctx, i) =>
                    const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final d = doc.data() as Map<String, dynamic>;
                  final name = d['name'] as String? ?? '';
                  final color = Color(d['color'] as int? ?? 0xFF4361EE);
                  return _SubjectListItem(
                    name: name,
                    color: color,
                    onEdit: () => _showSubjectDialog(context, existing: d, id: doc.id),
                    onDelete: () => _confirmDeleteSubject(context, doc.id, name),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showSubjectDialog(
    BuildContext context, {
    Map<String, dynamic>? existing,
    String? id,
  }) async {
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    Color selected = existing != null
        ? Color(existing['color'] as int)
        : _kPalette.first;
    String? nameError;

    await _blurDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      id == null ? 'New subject' : 'Edit subject',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2050),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        errorText: nameError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (_) =>
                          setS(() => nameError = null),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Color',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555555),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _kPalette.map((c) {
                        final isSel =
                            c.toARGB32() == selected.toARGB32();
                        return GestureDetector(
                          onTap: () => setS(() => selected = c),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 110),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: c.withValues(
                                            alpha: 0.55),
                                        blurRadius: 7,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : [],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              setS(
                                  () => nameError = 'Required field');
                              return;
                            }
                            Navigator.pop(ctx);
                            await onSaveSubject(
                                id, name, selected.toARGB32());
                          },
                          child: Text(
                              id == null ? 'Add' : 'Save'),
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
    nameCtrl.dispose();
  }

  Future<void> _confirmDeleteSubject(
    BuildContext context,
    String id,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subject'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await onDeleteSubject(id);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBJECT LIST ITEM (with hover)
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectListItem extends StatefulWidget {
  const _SubjectListItem({
    required this.name,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });
  final String name;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_SubjectListItem> createState() => _SubjectListItemState();
}

class _SubjectListItemState extends State<_SubjectListItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFEEF1FB) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hovered ? const Color(0xFF2848B0) : Colors.grey.shade200,
            width: _hovered ? 1.5 : 1,
          ),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          tileColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          leading: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
          title: Text(
            widget.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 17, color: Colors.grey.shade500),
                tooltip: 'Edit',
                onPressed: widget.onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 17, color: Colors.redAccent),
                tooltip: 'Delete',
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMETABLE CELL (with hover)
// ─────────────────────────────────────────────────────────────────────────────

class _TimetableCell extends StatefulWidget {
  const _TimetableCell({
    required this.assignment,
    required this.subjectMap,
    required this.teacherMap,
    required this.shortName,
    required this.onTap,
  });
  final Map<String, dynamic>? assignment;
  final Map<String, Map<String, dynamic>> subjectMap;
  final Map<String, String> teacherMap;
  final String Function(String) shortName;
  final VoidCallback onTap;

  @override
  State<_TimetableCell> createState() => _TimetableCellState();
}

class _TimetableCellState extends State<_TimetableCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.assignment == null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: _hovered ? const Color(0xFFEEF1FB) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovered ? const Color(0xFF2848B0) : const Color(0xFFE8EAF2),
                width: _hovered ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.add,
                size: 18,
                color: _hovered ? const Color(0xFF2848B0) : Colors.grey.shade300,
              ),
            ),
          ),
        ),
      );
    }

    final sid = widget.assignment!['subjectId'] as String? ?? '';
    final teacherU = widget.assignment!['teacherUsername'] as String? ?? '';
    final sd = widget.subjectMap[sid];
    final subjectName = sd?['name'] as String? ?? sid;
    final subjectColor = Color(sd?['color'] as int? ?? 0xFF4361EE);
    final teacherName = widget.teacherMap[teacherU] ?? teacherU;

    return Tooltip(
      message: '$subjectName\nTeacher $teacherName',
      preferBelow: true,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2050),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _hovered
                  ? subjectColor.withValues(alpha: 0.15)
                  : subjectColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovered
                    ? subjectColor.withValues(alpha: 0.5)
                    : subjectColor.withValues(alpha: 0.2),
                width: _hovered ? 1.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: ColoredBox(color: subjectColor),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        subjectName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: subjectColor.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Teacher ${widget.shortName(teacherName)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF777777),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
}
