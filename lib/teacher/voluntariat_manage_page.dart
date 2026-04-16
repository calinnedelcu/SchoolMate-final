import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _kHeaderGreen = Color(0xFF0D631B);
const _kPageBg = Color(0xFFF7F9F0);
const _kCardBg = Color(0xFFFFFFFF);
const _kOutline = Color(0xFF717B6E);
const _kOnSurface = Color(0xFF151A14);

class VoluntariatManagePage extends StatefulWidget {
  const VoluntariatManagePage({super.key});

  @override
  State<VoluntariatManagePage> createState() => _VoluntariatManagePageState();
}

class _VoluntariatManagePageState extends State<VoluntariatManagePage> {
  String _classId = '';
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _teacherStream;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '2');
  final _maxCtrl = TextEditingController(text: '20');
  DateTime? _selectedDate;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      _teacherStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
      _teacherStream!.listen((doc) {
        if (!mounted) return;
        final classId =
            ((doc.data() ?? {})['classId'] ?? '').toString().trim();
        if (classId.isNotEmpty && classId != _classId) {
          setState(() => _classId = classId);
        }
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _hoursCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _createOpportunity() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completeaza titlul si data')),
      );
      return;
    }

    setState(() => _creating = true);

    await FirebaseFirestore.instance.collection('volunteerOpportunities').add({
      'title': title,
      'description': _descCtrl.text.trim(),
      'date': Timestamp.fromDate(_selectedDate!),
      'location': _locationCtrl.text.trim(),
      'maxParticipants': int.tryParse(_maxCtrl.text) ?? 20,
      'createdBy': AppSession.uid,
      'createdByName': AppSession.fullName ?? '',
      'createdByRole': 'teacher',
      'classId': _classId,
      'status': 'active',
      'hoursWorth': int.tryParse(_hoursCtrl.text) ?? 2,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _titleCtrl.clear();
    _descCtrl.clear();
    _locationCtrl.clear();
    _hoursCtrl.text = '2';
    _maxCtrl.text = '20';
    setState(() {
      _selectedDate = null;
      _creating = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Oportunitate creata cu succes!')),
    );
  }

  Future<void> _validateHours(String signupId, int hours) async {
    await FirebaseFirestore.instance
        .collection('volunteerSignups')
        .doc(signupId)
        .update({
      'status': 'completed',
      'hoursLogged': hours,
      'validatedBy': AppSession.uid,
      'validatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ore validate!')),
    );
  }

  Future<void> _archiveOpportunity(String docId) async {
    await FirebaseFirestore.instance
        .collection('volunteerOpportunities')
        .doc(docId)
        .update({'status': 'archived'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _TopHeader(
              title: 'Voluntariat',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: _classId.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCreateForm(),
                          const SizedBox(height: 24),
                          const Text(
                            'Oportunitatile mele',
                            style: TextStyle(
                              color: _kOnSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildOpportunitiesList(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateForm() {
    final dateStr = _selectedDate != null
        ? '${_selectedDate!.day.toString().padLeft(2, '0')}.'
          '${_selectedDate!.month.toString().padLeft(2, '0')}.'
          '${_selectedDate!.year}'
        : 'Alege data';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle_rounded, color: _kHeaderGreen, size: 22),
              SizedBox(width: 8),
              Text(
                'Creeaza oportunitate',
                style: TextStyle(
                  color: _kOnSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InputField(controller: _titleCtrl, label: 'Titlu *'),
          const SizedBox(height: 10),
          _InputField(
            controller: _descCtrl,
            label: 'Descriere',
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          _InputField(controller: _locationCtrl, label: 'Locatie'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            color: _kOutline, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: _selectedDate != null
                                ? _kOnSurface
                                : _kOutline,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: _InputField(
                  controller: _hoursCtrl,
                  label: 'Ore',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: _InputField(
                  controller: _maxCtrl,
                  label: 'Max',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _creating ? null : _createOpportunity,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D631B), Color(0xFF19802E)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Creeaza',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunitiesList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('volunteerOpportunities')
          .where('createdBy', isEqualTo: AppSession.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Nicio oportunitate creata inca',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kOutline, fontSize: 14),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OpportunityManageCard(
                docId: doc.id,
                data: data,
                onValidate: _validateHours,
                onArchive: () => _archiveOpportunity(doc.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// OPPORTUNITY MANAGE CARD (with signups)
// ────────────────────────────────────────────────────────────────────────────
class _OpportunityManageCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Future<void> Function(String signupId, int hours) onValidate;
  final VoidCallback onArchive;

  const _OpportunityManageCard({
    required this.docId,
    required this.data,
    required this.onValidate,
    required this.onArchive,
  });

  @override
  State<_OpportunityManageCard> createState() =>
      _OpportunityManageCardState();
}

class _OpportunityManageCardState extends State<_OpportunityManageCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final title = (widget.data['title'] ?? '').toString();
    final status = (widget.data['status'] ?? '').toString();
    final hoursWorth = (widget.data['hoursWorth'] as num?)?.toInt() ?? 0;
    final dateTs = widget.data['date'] as Timestamp?;
    final dateStr = dateTs != null
        ? '${dateTs.toDate().day.toString().padLeft(2, '0')}.'
          '${dateTs.toDate().month.toString().padLeft(2, '0')}.'
          '${dateTs.toDate().year}'
        : '';
    final isArchived = status == 'archived';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isArchived
                      ? _kOutline.withValues(alpha: 0.1)
                      : _kHeaderGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.volunteer_activism_rounded,
                  color: isArchived ? _kOutline : _kHeaderGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isArchived ? _kOutline : _kOnSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$dateStr  •  $hoursWorth ore',
                      style: const TextStyle(
                        color: _kOutline,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isArchived)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kOutline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Arhivat',
                    style: TextStyle(color: _kOutline, fontSize: 11),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: _kOutline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: widget.onArchive,
                      child: const Icon(
                        Icons.archive_rounded,
                        color: _kOutline,
                        size: 20,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_expanded && !isArchived) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('volunteerSignups')
                  .where('opportunityId', isEqualTo: widget.docId)
                  .orderBy('signedUpAt')
                  .snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                final active = docs
                    .where((d) => d.data()['status'] != 'cancelled')
                    .toList();

                if (active.isEmpty) {
                  return const Text(
                    'Nicio inscriere inca',
                    style: TextStyle(color: _kOutline, fontSize: 13),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inscrisi (${active.length})',
                      style: const TextStyle(
                        color: _kOnSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...active.map((doc) {
                      final d = doc.data();
                      final name = (d['studentName'] ?? '').toString();
                      final signupStatus = (d['status'] ?? '').toString();
                      final isCompleted = signupStatus == 'completed';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  _kHeaderGreen.withValues(alpha: 0.1),
                              child: Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: _kHeaderGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: _kOnSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _kHeaderGreen.withValues(
                                      alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_rounded,
                                        color: _kHeaderGreen, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Validat',
                                      style: TextStyle(
                                        color: _kHeaderGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () => widget.onValidate(
                                  doc.id,
                                  hoursWorth,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _kHeaderGreen,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Valideaza',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// INPUT FIELD
// ────────────────────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: _kOnSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: _kOutline, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF0F4E9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HEADER (same pattern as cereriasteptare.dart)
// ────────────────────────────────────────────────────────────────────────────
class _TopHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final headerHeight = compact ? 138.0 : 146.0;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(54),
        bottomRight: Radius.circular(54),
      ),
      child: Container(
        height: headerHeight,
        width: double.infinity,
        color: _kHeaderGreen,
        child: Stack(
          children: [
            Positioned(top: -72, right: -52, child: _decorCircle(220)),
            Positioned(top: 44, right: 34, child: _decorCircle(72)),
            Positioned(left: 156, bottom: -28, child: _decorCircle(82)),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: onBack,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
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
    );
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}
