import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _primary = Color(0xFF1F8BE7);
const _surfaceColor = Color(0xFFF5FBFF);
const _cardBg = Color(0xFFFFFFFF);
const _outline = Color(0xFF717B6E);
const _onSurface = Color(0xFF587F9E);
const _fieldBg = Color(0xFFE7F0F6);
const _danger = Color(0xFFC62828);

/// Audience sentinel for school-wide broadcasts.
const String kAudienceAll = '__ALL__';

enum PostKind { announcement, competition, camp, volunteer }

extension PostKindLabel on PostKind {
  String get label {
    switch (this) {
      case PostKind.announcement:
        return 'Anunț școlar';
      case PostKind.competition:
        return 'Competiție';
      case PostKind.camp:
        return 'Tabără';
      case PostKind.volunteer:
        return 'Voluntariat';
    }
  }

  IconData get icon {
    switch (this) {
      case PostKind.announcement:
        return Icons.campaign_rounded;
      case PostKind.competition:
        return Icons.emoji_events_rounded;
      case PostKind.camp:
        return Icons.forest_rounded;
      case PostKind.volunteer:
        return Icons.volunteer_activism_rounded;
    }
  }

  String get categoryKey {
    switch (this) {
      case PostKind.announcement:
        return 'announcement';
      case PostKind.competition:
        return 'competition';
      case PostKind.camp:
        return 'camp';
      case PostKind.volunteer:
        return 'volunteer';
    }
  }
}

/// Post composer page.
///
/// - In `mode = secretariat`, the user can target the whole school OR pick
///   any combination of classes, and can post all 4 categories.
/// - In `mode = teacher`, the audience is locked to the diriginte's own
///   classId, and only Anunț / Competiție / Tabără / Voluntariat for that
///   class are available.
class AdminPostComposerPage extends StatefulWidget {
  /// Whether the composer is rendered embedded inside the secretariat shell
  /// (no AppBar / Scaffold) or as a full-screen page.
  final bool embedded;

  /// `secretariat` (full audience picker) or `teacher` (locked to own class).
  final PostComposerMode mode;

  const AdminPostComposerPage({
    super.key,
    this.embedded = false,
    this.mode = PostComposerMode.secretariat,
  });

  @override
  State<AdminPostComposerPage> createState() => _AdminPostComposerPageState();
}

enum PostComposerMode { secretariat, teacher }

class _AdminPostComposerPageState extends State<AdminPostComposerPage> {
  PostKind _kind = PostKind.announcement;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '2');
  final _maxCtrl = TextEditingController(text: '30');

  DateTime? _eventDate;
  DateTime? _eventEndDate;
  bool _submitting = false;

  /// `null` = school-wide; otherwise an explicit list of classIds.
  Set<String>? _selectedClassIds;

  @override
  void initState() {
    super.initState();
    if (widget.mode == PostComposerMode.teacher) {
      final classId = (AppSession.classId ?? '').trim();
      _selectedClassIds = classId.isEmpty ? <String>{} : {classId};
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _linkCtrl.dispose();
    _hoursCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickEventDate({required bool isEnd}) async {
    final initial = isEnd
        ? (_eventEndDate ?? _eventDate ?? DateTime.now().add(const Duration(days: 1)))
        : (_eventDate ?? DateTime.now().add(const Duration(days: 1)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _eventEndDate = picked;
      } else {
        _eventDate = picked;
      }
    });
  }

  String? _validate() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return 'Adaugă un titlu.';
    final desc = _descCtrl.text.trim();
    if (desc.length < 20) {
      return 'Descrierea trebuie să aibă cel puțin 20 de caractere.';
    }
    if (widget.mode == PostComposerMode.secretariat) {
      if (_selectedClassIds != null && _selectedClassIds!.isEmpty) {
        return 'Alege cel puțin o clasă sau "Toată școala".';
      }
    }
    switch (_kind) {
      case PostKind.competition:
      case PostKind.camp:
      case PostKind.volunteer:
        if (_eventDate == null) return 'Alege data evenimentului.';
        break;
      case PostKind.announcement:
        break;
    }
    final link = _linkCtrl.text.trim();
    if (link.isNotEmpty &&
        !link.startsWith('http://') &&
        !link.startsWith('https://')) {
      return 'Linkul trebuie să înceapă cu http:// sau https://.';
    }
    return null;
  }

  List<String> _audienceClassIds() {
    if (_selectedClassIds == null) return const [kAudienceAll];
    return _selectedClassIds!.toList()..sort();
  }

  String _audienceLabel(List<String> ids) {
    if (ids.contains(kAudienceAll)) return 'Toată școala';
    if (ids.length == 1) return 'Clasa ${ids.first}';
    return '${ids.length} clase';
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _submitting = true);

    try {
      final audience = _audienceClassIds();
      final senderUid = AppSession.uid ?? '';
      final senderName = AppSession.fullName ?? AppSession.username ?? '';
      final senderRole = AppSession.role ?? 'admin';
      final title = _titleCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      final location = _locationCtrl.text.trim();
      final link = _linkCtrl.text.trim();

      if (_kind == PostKind.volunteer) {
        await FirebaseFirestore.instance
            .collection('volunteerOpportunities')
            .add({
              'title': title,
              'description': desc,
              'date': Timestamp.fromDate(_eventDate!),
              'location': location,
              'link': link,
              'maxParticipants': int.tryParse(_maxCtrl.text) ?? 30,
              'hoursWorth': int.tryParse(_hoursCtrl.text) ?? 2,
              'createdBy': senderUid,
              'createdByName': senderName,
              'createdByRole': senderRole,
              'audienceClassIds': audience,
              'classId': audience.contains(kAudienceAll)
                  ? null
                  : (audience.length == 1 ? audience.first : null),
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
            });
      } else {
        // Anunț / Competiție / Tabără → secretariatMessages broadcast
        await FirebaseFirestore.instance
            .collection('secretariatMessages')
            .add({
              'recipientRole': 'student',
              'recipientUid': '',
              'studentUid': '',
              'studentUsername': '',
              'studentName': '',
              'classId': '',
              'recipientName': '',
              'recipientUsername': '',
              'message': desc,
              'title': title,
              'category': _kind.categoryKey,
              'audienceClassIds': audience,
              'audienceLabel': _audienceLabel(audience),
              'location': location,
              'link': link,
              'eventDate': _eventDate != null
                  ? Timestamp.fromDate(_eventDate!)
                  : null,
              'eventEndDate': _eventEndDate != null
                  ? Timestamp.fromDate(_eventEndDate!)
                  : null,
              'createdAt': FieldValue.serverTimestamp(),
              'senderUid': senderUid,
              'senderName': senderName,
              'senderRole': senderRole,
              'broadcastId':
                  '${DateTime.now().millisecondsSinceEpoch}_${_kind.categoryKey}',
              'messageType': 'secretariatGlobal',
              'source': senderRole == 'teacher' ? 'teacher' : 'secretariat',
              'status': 'active',
            });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_kind.label} publicat${_kind == PostKind.competition || _kind == PostKind.camp ? 'ă' : ''}!')),
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _locationCtrl.clear();
    _linkCtrl.clear();
    _hoursCtrl.text = '2';
    _maxCtrl.text = '30';
    setState(() {
      _eventDate = null;
      _eventEndDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Container(
      color: _surfaceColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Postări',
              style: TextStyle(
                color: _onSurface,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.mode == PostComposerMode.teacher
                  ? 'Trimite anunțuri, competiții, tabere și voluntariat pentru clasa ta.'
                  : 'Compune anunțuri, competiții, tabere și voluntariat pentru toată școala sau clase selectate.',
              style: const TextStyle(color: _outline, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _buildKindChips(),
            const SizedBox(height: 16),
            _buildComposerCard(),
            const SizedBox(height: 24),
            const Text(
              'Postări recente',
              style: TextStyle(
                color: _onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _PostsManagementList(
              mode: widget.mode,
              ownerUid: AppSession.uid ?? '',
              ownerClassId: (AppSession.classId ?? '').trim(),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text('Postări'),
      ),
      body: body,
    );
  }

  Widget _buildKindChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PostKind.values.map((k) {
        final selected = _kind == k;
        return GestureDetector(
          onTap: () => setState(() => _kind = k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _primary : _cardBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? _primary : const Color(0xFFD2DEE7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  k.icon,
                  size: 16,
                  color: selected ? Colors.white : _primary,
                ),
                const SizedBox(width: 8),
                Text(
                  k.label,
                  style: TextStyle(
                    color: selected ? Colors.white : _onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildComposerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_kind.icon, color: _primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Postare nouă · ${_kind.label}',
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ComposerInput(
            controller: _titleCtrl,
            hint: 'Titlu *',
            maxLength: 90,
          ),
          const SizedBox(height: 10),
          _ComposerInput(
            controller: _descCtrl,
            hint: 'Descriere * (min. 20 caractere)',
            maxLines: 4,
            maxLength: 800,
          ),
          const SizedBox(height: 10),
          if (_kind != PostKind.announcement) ...[
            _ComposerInput(controller: _locationCtrl, hint: 'Locație'),
            const SizedBox(height: 10),
          ],
          _ComposerInput(
            controller: _linkCtrl,
            hint: 'Link extern (opțional, https://...)',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 10),
          if (_kind == PostKind.volunteer) ...[
            Row(
              children: [
                Expanded(
                  child: _ComposerInput(
                    controller: _hoursCtrl,
                    hint: 'Ore acordate',
                    isNum: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ComposerInput(
                    controller: _maxCtrl,
                    hint: 'Max participanți',
                    isNum: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (_kind != PostKind.announcement) _buildDatePickers(),
          const SizedBox(height: 14),
          _buildAudienceSelector(),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _submitting ? null : _submit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: _submitting ? const Color(0xFF9DBED9) : _primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Publică',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickers() {
    final showRange = _kind == PostKind.camp;
    return Row(
      children: [
        Expanded(
          child: _DateField(
            label: showRange ? 'Început' : 'Data *',
            date: _eventDate,
            onTap: () => _pickEventDate(isEnd: false),
          ),
        ),
        if (showRange) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _DateField(
              label: 'Sfârșit',
              date: _eventEndDate,
              onTap: () => _pickEventDate(isEnd: true),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAudienceSelector() {
    if (widget.mode == PostComposerMode.teacher) {
      final classId = (AppSession.classId ?? '').trim();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, size: 16, color: _outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                classId.isEmpty
                    ? 'Audiență: clasa ta (lipsește configurarea)'
                    : 'Audiență: clasa $classId',
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final allSelected = _selectedClassIds == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AUDIENȚĂ',
          style: TextStyle(
            color: _outline,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _selectedClassIds = null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: allSelected ? _primary : _fieldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  allSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: allSelected ? Colors.white : _outline,
                ),
                const SizedBox(width: 10),
                Text(
                  'Toată școala',
                  style: TextStyle(
                    color: allSelected ? Colors.white : _onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('classes')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 30,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final classes = snap.data!.docs.map((d) {
              final m = d.data();
              return _ClassOption(
                id: d.id,
                name: (m['name'] ?? d.id).toString(),
              );
            }).toList()
              ..sort((a, b) => a.name.compareTo(b.name));
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: classes.map((c) {
                final selected =
                    _selectedClassIds != null && _selectedClassIds!.contains(c.id);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedClassIds ??= <String>{};
                      if (_selectedClassIds!.contains(c.id)) {
                        _selectedClassIds!.remove(c.id);
                      } else {
                        _selectedClassIds!.add(c.id);
                      }
                      if (_selectedClassIds!.isEmpty) {
                        _selectedClassIds = null;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? _primary : _fieldBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      c.name,
                      style: TextStyle(
                        color: selected ? Colors.white : _onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ClassOption {
  final String id;
  final String name;
  const _ClassOption({required this.id, required this.name});
}

// ────────────────────────────────────────────────────────────────────────────
// COMPOSER INPUT
// ────────────────────────────────────────────────────────────────────────────
class _ComposerInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final bool isNum;
  final TextInputType? keyboardType;

  const _ComposerInput({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.isNum = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType:
          keyboardType ?? (isNum ? TextInputType.number : TextInputType.text),
      style: const TextStyle(
        color: _onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _outline, fontSize: 13),
        filled: true,
        fillColor: _fieldBg,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// DATE FIELD
// ────────────────────────────────────────────────────────────────────────────
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final txt = date == null
        ? label
        : '${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: _outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                txt,
                style: TextStyle(
                  color: date == null ? _outline : _onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// POSTS MANAGEMENT LIST
// ────────────────────────────────────────────────────────────────────────────
class _PostsManagementList extends StatelessWidget {
  final PostComposerMode mode;
  final String ownerUid;
  final String ownerClassId;

  const _PostsManagementList({
    required this.mode,
    required this.ownerUid,
    required this.ownerClassId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('secretariatMessages')
              .where('messageType', isEqualTo: 'secretariatGlobal')
              .where('recipientRole', isEqualTo: 'student')
              .where('recipientUid', isEqualTo: '')
              .limit(80)
              .snapshots(),
          builder: (context, msgSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('volunteerOpportunities')
                  .limit(80)
                  .snapshots(),
              builder: (context, volSnap) {
                if (!msgSnap.hasData || !volSnap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final items = <_PostItem>[];

                for (final doc in msgSnap.data!.docs) {
                  final d = doc.data();
                  if (!_canSee(d)) continue;
                  final created = (d['createdAt'] as Timestamp?)?.toDate();
                  items.add(_PostItem(
                    id: doc.id,
                    collection: 'secretariatMessages',
                    title: (d['title'] ?? '').toString(),
                    message: (d['message'] ?? '').toString(),
                    category: (d['category'] ?? 'announcement').toString(),
                    audienceLabel: (d['audienceLabel'] ?? '').toString(),
                    audienceClassIds: List<String>.from(
                      (d['audienceClassIds'] ?? const []) as List,
                    ),
                    createdAt: created,
                    archived: (d['status'] ?? 'active').toString() == 'archived',
                    senderName: (d['senderName'] ?? '').toString(),
                  ));
                }

                for (final doc in volSnap.data!.docs) {
                  final d = doc.data();
                  if (!_canSee(d)) continue;
                  final created = (d['createdAt'] as Timestamp?)?.toDate();
                  items.add(_PostItem(
                    id: doc.id,
                    collection: 'volunteerOpportunities',
                    title: (d['title'] ?? '').toString(),
                    message: (d['description'] ?? '').toString(),
                    category: 'volunteer',
                    audienceLabel: _legacyAudienceLabel(d),
                    audienceClassIds: List<String>.from(
                      (d['audienceClassIds'] ?? const []) as List,
                    ),
                    createdAt: created,
                    archived: (d['status'] ?? 'active').toString() == 'archived',
                    senderName: (d['createdByName'] ?? '').toString(),
                  ));
                }

                items.sort((a, b) {
                  final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bd.compareTo(ad);
                });

                if (items.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Nicio postare încă.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _outline, fontSize: 13),
                    ),
                  );
                }

                return Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PostCard(item: item),
                        ),
                      )
                      .toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  bool _canSee(Map<String, dynamic> d) {
    if (mode == PostComposerMode.secretariat) return true;
    // Teacher: only posts targeted at their class OR created by them.
    final senderUid = (d['createdBy'] ?? d['senderUid'] ?? '').toString();
    if (senderUid == ownerUid) return true;
    final audience = List<String>.from(
      (d['audienceClassIds'] ?? const []) as List,
    );
    if (audience.contains(ownerClassId)) return true;
    return false;
  }

  String _legacyAudienceLabel(Map<String, dynamic> d) {
    final audience = (d['audienceClassIds'] as List?) ?? const [];
    if (audience.isNotEmpty) {
      if (audience.contains(kAudienceAll)) return 'Toată școala';
      if (audience.length == 1) return 'Clasa ${audience.first}';
      return '${audience.length} clase';
    }
    final classId = d['classId'];
    if (classId == null) return 'Toată școala';
    return 'Clasa $classId';
  }
}

class _PostItem {
  final String id;
  final String collection;
  final String title;
  final String message;
  final String category;
  final String audienceLabel;
  final List<String> audienceClassIds;
  final DateTime? createdAt;
  final bool archived;
  final String senderName;

  const _PostItem({
    required this.id,
    required this.collection,
    required this.title,
    required this.message,
    required this.category,
    required this.audienceLabel,
    required this.audienceClassIds,
    required this.createdAt,
    required this.archived,
    required this.senderName,
  });
}

class _PostCard extends StatelessWidget {
  final _PostItem item;
  const _PostCard({required this.item});

  IconData get _icon {
    switch (item.category) {
      case 'competition':
        return Icons.emoji_events_rounded;
      case 'camp':
        return Icons.forest_rounded;
      case 'volunteer':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  String get _label {
    switch (item.category) {
      case 'competition':
        return 'Competiție';
      case 'camp':
        return 'Tabără';
      case 'volunteer':
        return 'Voluntariat';
      default:
        return 'Anunț';
    }
  }

  Future<void> _archive(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection(item.collection)
        .doc(item.id)
        .update({'status': item.archived ? 'active' : 'archived'});
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Șterge postarea?'),
        content: Text(
          'Postarea "${item.title}" va fi ștearsă definitiv. Ești sigur?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Șterge',
              style: TextStyle(color: _danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection(item.collection)
        .doc(item.id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final created = item.createdAt;
    final dateStr = created == null
        ? '—'
        : '${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')}.${created.year}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.archived ? const Color(0xFFF0F4F7) : _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? '(fără titlu)' : item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Tag(text: _label, color: _primary),
                        _Tag(
                          text: item.audienceLabel.isEmpty
                              ? 'Toată școala'
                              : item.audienceLabel,
                          color: const Color(0xFF6F8FA9),
                        ),
                        _Tag(text: dateStr, color: _outline),
                        if (item.archived)
                          const _Tag(text: 'Arhivat', color: _danger),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _outline,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (item.senderName.isNotEmpty)
                Expanded(
                  child: Text(
                    'de ${item.senderName}',
                    style: const TextStyle(
                      color: _outline,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                const Spacer(),
              TextButton.icon(
                onPressed: () => _archive(context),
                icon: Icon(
                  item.archived
                      ? Icons.unarchive_rounded
                      : Icons.archive_rounded,
                  size: 16,
                ),
                label: Text(item.archived ? 'Reactivează' : 'Arhivează'),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _delete(context),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Șterge'),
                style: TextButton.styleFrom(
                  foregroundColor: _danger,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
