import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _primaryGreen = Color(0xFF6AA2CE);
const _headerGreen = Color(0xFF1F8BE7);
const _surfaceColor = Color(0xFFF5FBFF);
const _cardBg = Color(0xFFFFFFFF);
const _outline = Color(0xFF717B6E);
const _onSurface = Color(0xFF587F9E);

class AdminVoluntariatPage extends StatefulWidget {
  const AdminVoluntariatPage({super.key});

  @override
  State<AdminVoluntariatPage> createState() => _AdminVoluntariatPageState();
}

class _AdminVoluntariatPageState extends State<AdminVoluntariatPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '2');
  final _maxCtrl = TextEditingController(text: '30');
  DateTime? _selectedDate;
  bool _creating = false;

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
    if (picked != null) setState(() => _selectedDate = picked);
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
      'maxParticipants': int.tryParse(_maxCtrl.text) ?? 30,
      'createdBy': AppSession.uid,
      'createdByName': AppSession.fullName ?? '',
      'createdByRole': 'admin',
      'classId': null,
      'status': 'active',
      'hoursWorth': int.tryParse(_hoursCtrl.text) ?? 2,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _titleCtrl.clear();
    _descCtrl.clear();
    _locationCtrl.clear();
    _hoursCtrl.text = '2';
    _maxCtrl.text = '30';
    setState(() {
      _selectedDate = null;
      _creating = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Oportunitate creata cu succes!')),
    );
  }

  Future<void> _archiveOpportunity(String docId) async {
    await FirebaseFirestore.instance
        .collection('volunteerOpportunities')
        .doc(docId)
        .update({'status': 'archived'});
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
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surfaceColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voluntariat',
              style: TextStyle(
                color: _onSurface,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gestioneaza oportunitatile de voluntariat la nivel de scoala',
              style: TextStyle(color: _outline, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _buildStats(),
            const SizedBox(height: 24),
            _buildCreateForm(),
            const SizedBox(height: 24),
            const Text(
              'Toate oportunitatile',
              style: TextStyle(
                color: _onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildAllOpportunities(),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('volunteerOpportunities')
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return _StatCard(
                icon: Icons.volunteer_activism_rounded,
                value: '$count',
                label: 'Active',
                color: _headerGreen,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('volunteerSignups')
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              int totalHours = 0;
              for (final doc in docs) {
                final d = doc.data() as Map<String, dynamic>;
                totalHours += (d['hoursLogged'] as num?)?.toInt() ?? 0;
              }
              return _StatCard(
                icon: Icons.access_time_rounded,
                value: '$totalHours',
                label: 'Ore totale',
                color: const Color(0xFF48A3EF),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('volunteerSignups')
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final uniqueStudents =
                  docs.map((d) => (d.data() as Map)['studentUid']).toSet();
              return _StatCard(
                icon: Icons.people_rounded,
                value: '${uniqueStudents.length}',
                label: 'Voluntari',
                color: const Color(0xFFE65100),
              );
            },
          ),
        ),
      ],
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
          const Row(
            children: [
              Icon(Icons.add_circle_rounded, color: _headerGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Oportunitate noua (nivel scoala)',
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AdminInput(controller: _titleCtrl, hint: 'Titlu *'),
          const SizedBox(height: 8),
          _AdminInput(
              controller: _descCtrl, hint: 'Descriere', maxLines: 3),
          const SizedBox(height: 8),
          _AdminInput(controller: _locationCtrl, hint: 'Locatie'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F0F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            color: _outline, size: 15),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: _selectedDate != null
                                ? _onSurface
                                : _outline,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 65,
                child:
                    _AdminInput(controller: _hoursCtrl, hint: 'Ore', isNum: true),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 65,
                child:
                    _AdminInput(controller: _maxCtrl, hint: 'Max', isNum: true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _creating ? null : _createOpportunity,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: _headerGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Creeaza',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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

  Widget _buildAllOpportunities() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('volunteerOpportunities')
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
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Nicio oportunitate inca',
              textAlign: TextAlign.center,
              style: TextStyle(color: _outline, fontSize: 13),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AdminOppCard(
                docId: doc.id,
                data: data,
                onArchive: () => _archiveOpportunity(doc.id),
                onValidate: _validateHours,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// STAT CARD
// ────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: _outline, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// ADMIN OPP CARD
// ────────────────────────────────────────────────────────────────────────────
class _AdminOppCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onArchive;
  final Future<void> Function(String signupId, int hours) onValidate;

  const _AdminOppCard({
    required this.docId,
    required this.data,
    required this.onArchive,
    required this.onValidate,
  });

  @override
  State<_AdminOppCard> createState() => _AdminOppCardState();
}

class _AdminOppCardState extends State<_AdminOppCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final title = (widget.data['title'] ?? '').toString();
    final status = (widget.data['status'] ?? '').toString();
    final createdByRole = (widget.data['createdByRole'] ?? '').toString();
    final classId = widget.data['classId'];
    final hoursWorth = (widget.data['hoursWorth'] as num?)?.toInt() ?? 0;
    final dateTs = widget.data['date'] as Timestamp?;
    final dateStr = dateTs != null
        ? '${dateTs.toDate().day.toString().padLeft(2, '0')}.'
          '${dateTs.toDate().month.toString().padLeft(2, '0')}.'
          '${dateTs.toDate().year}'
        : '';
    final isArchived = status == 'archived';
    final scope = classId != null ? 'Clasa $classId' : 'Toata scoala';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
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
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isArchived
                      ? _outline.withValues(alpha: 0.1)
                      : _headerGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.volunteer_activism_rounded,
                  color: isArchived ? _outline : _headerGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isArchived ? _outline : _onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$dateStr  •  $hoursWorth ore  •  $scope  •  ${createdByRole == 'admin' ? 'Secretariat' : 'Diriginte'}',
                      style: const TextStyle(
                        color: _outline,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isArchived) ...[
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: _outline,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onArchive,
                  child: const Icon(Icons.archive_rounded,
                      color: _outline, size: 18),
                ),
              ] else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _outline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Arhivat',
                      style: TextStyle(color: _outline, fontSize: 10)),
                ),
            ],
          ),
          if (_expanded && !isArchived) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
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
                  return const Text('Nicio inscriere',
                      style: TextStyle(color: _outline, fontSize: 12));
                }

                return Column(
                  children: active.map((doc) {
                    final d = doc.data();
                    final name = (d['studentName'] ?? '').toString();
                    final sStatus = (d['status'] ?? '').toString();
                    final cId = (d['classId'] ?? '').toString();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                _headerGreen.withValues(alpha: 0.1),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: _headerGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$name  ${cId.isNotEmpty ? '($cId)' : ''}',
                              style: const TextStyle(
                                  color: _onSurface, fontSize: 12),
                            ),
                          ),
                          if (sStatus == 'completed')
                            const Icon(Icons.check_circle_rounded,
                                color: _headerGreen, size: 16)
                          else
                            GestureDetector(
                              onTap: () =>
                                  widget.onValidate(doc.id, hoursWorth),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _headerGreen,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Valideaza',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
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
// ADMIN INPUT
// ────────────────────────────────────────────────────────────────────────────
class _AdminInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool isNum;

  const _AdminInput({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.isNum = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: _onSurface, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _outline, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFE7F0F6),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
