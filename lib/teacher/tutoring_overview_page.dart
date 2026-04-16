import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _kHeaderGreen = Color(0xFF1F8BE7);
const _kPageBg = Color(0xFFEFF5FA);
const _kCardBg = Color(0xFFFFFFFF);
const _kSurfaceLow = Color(0xFFE7F0F6);
const _kOutline = Color(0xFF717B6E);
const _kOnSurface = Color(0xFF587F9E);

class TutoringOverviewPage extends StatefulWidget {
  const TutoringOverviewPage({super.key});

  @override
  State<TutoringOverviewPage> createState() => _TutoringOverviewPageState();
}

class _TutoringOverviewPageState extends State<TutoringOverviewPage> {
  String _classId = '';

  @override
  void initState() {
    super.initState();
    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((doc) {
        if (!mounted) return;
        final classId =
            ((doc.data() ?? {})['classId'] ?? '').toString().trim();
        if (classId.isNotEmpty && classId != _classId) {
          setState(() => _classId = classId);
        }
      });
    }
  }

  Future<void> _validateSession(String sessionId, int hours) async {
    await FirebaseFirestore.instance
        .collection('tutoringSessions')
        .doc(sessionId)
        .update({
      'status': 'completed',
      'hoursLogged': hours,
      'validatedBy': AppSession.uid,
      'validatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesiune validata!')),
    );
  }

  Future<void> _showValidateDialog(
    String sessionId,
    String subject,
    String tutorName,
    String learnerName,
  ) async {
    final hoursCtrl = TextEditingController(text: '1');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valideaza ore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$subject — $tutorName → $learnerName',
              style: const TextStyle(fontSize: 13, color: _kOutline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hoursCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Numar ore',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuleaza'),
          ),
          TextButton(
            onPressed: () {
              final h = int.tryParse(hoursCtrl.text) ?? 1;
              Navigator.pop(ctx, h);
            },
            child: const Text('Valideaza'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await _validateSession(sessionId, result);
    }
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
              title: 'Peer Tutoring',
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
                          _buildStats(),
                          const SizedBox(height: 20),
                          const Text(
                            'Sesiuni de validat',
                            style: TextStyle(
                              color: _kOnSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildPendingValidation(),
                          const SizedBox(height: 24),
                          const Text(
                            'Postari clasa',
                            style: TextStyle(
                              color: _kOnSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildClassPosts(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('tutoringSessions')
                .where('classId', isEqualTo: _classId)
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final pending = docs.where((d) {
                final s = d.data()['status'];
                return s == 'pending' || s == 'confirmed';
              }).length;
              return _StatBox(
                icon: Icons.pending_actions_rounded,
                value: '$pending',
                label: 'In curs',
                color: const Color(0xFFE65100),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('tutoringSessions')
                .where('classId', isEqualTo: _classId)
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              int totalHours = 0;
              for (final doc in docs) {
                totalHours += (doc.data()['hoursLogged'] as num?)?.toInt() ?? 0;
              }
              return _StatBox(
                icon: Icons.access_time_rounded,
                value: '$totalHours',
                label: 'Ore logate',
                color: _kHeaderGreen,
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('tutoringSessions')
                .where('classId', isEqualTo: _classId)
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              return _StatBox(
                icon: Icons.school_rounded,
                value: '${docs.length}',
                label: 'Sesiuni',
                color: const Color(0xFF48A3EF),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPendingValidation() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tutoringSessions')
          .where('classId', isEqualTo: _classId)
          .where('status', isEqualTo: 'confirmed')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _emptyBox('Nicio sesiune in asteptarea validarii');
        }
        return Column(
          children: docs.map((doc) {
            final d = doc.data();
            final subject = (d['subject'] ?? '').toString();
            final tutorName = (d['tutorName'] ?? '').toString();
            final learnerName = (d['learnerName'] ?? '').toString();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(16),
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
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _kHeaderGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: _kHeaderGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject,
                                style: const TextStyle(
                                  color: _kOnSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$tutorName → $learnerName',
                                style: const TextStyle(
                                  color: _kOutline,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showValidateDialog(
                              doc.id,
                              subject,
                              tutorName,
                              learnerName,
                            ),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _kHeaderGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Valideaza',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            await FirebaseFirestore.instance
                                .collection('tutoringSessions')
                                .doc(doc.id)
                                .update({'status': 'cancelled'});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE4EC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Respinge',
                              style: TextStyle(
                                color: Color(0xFFC62828),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildClassPosts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PostsBlock(
          collection: 'tutoringOffers',
          classId: _classId,
          title: 'Oferte de ajutor',
          icon: Icons.lightbulb_rounded,
        ),
        const SizedBox(height: 16),
        _PostsBlock(
          collection: 'tutoringRequests',
          classId: _classId,
          title: 'Cereri de ajutor',
          icon: Icons.help_outline_rounded,
        ),
      ],
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: _kOutline, fontSize: 13),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: _kOutline, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PostsBlock extends StatelessWidget {
  final String collection;
  final String classId;
  final String title;
  final IconData icon;

  const _PostsBlock({
    required this.collection,
    required this.classId,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _kOnSurface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(collection)
              .where('classId', isEqualTo: classId)
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurfaceLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Nicio postare',
                  style: TextStyle(color: _kOutline, fontSize: 12),
                ),
              );
            }
            return Column(
              children: docs.map((doc) {
                final d = doc.data();
                final subject = (d['subject'] ?? '').toString();
                final studentName = (d['studentName'] ?? '').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _kOutline.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: _kHeaderGreen, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject,
                                style: const TextStyle(
                                  color: _kOnSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                studentName,
                                style: const TextStyle(
                                  color: _kOutline,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

// ────────────────────────────────────────────────────────────────────────────
// HEADER
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
