import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firster/core/session.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF0D631B);
const _surface = Color(0xFFF7F9F0);
const _surfaceLowest = Color(0xFFFFFFFF);
const _outline = Color(0xFF717B6E);
const _onSurface = Color(0xFF151A14);

class VoluntariatDetailPage extends StatefulWidget {
  final String opportunityId;

  const VoluntariatDetailPage({super.key, required this.opportunityId});

  @override
  State<VoluntariatDetailPage> createState() => _VoluntariatDetailPageState();
}

class _VoluntariatDetailPageState extends State<VoluntariatDetailPage> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _oppStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _signupsStream;

  @override
  void initState() {
    super.initState();
    _oppStream = FirebaseFirestore.instance
        .collection('volunteerOpportunities')
        .doc(widget.opportunityId)
        .snapshots();

    _signupsStream = FirebaseFirestore.instance
        .collection('volunteerSignups')
        .where('opportunityId', isEqualTo: widget.opportunityId)
        .orderBy('signedUpAt', descending: false)
        .snapshots();
  }

  Future<void> _signUp(Map<String, dynamic> opp) async {
    final uid = AppSession.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('volunteerSignups').add({
      'opportunityId': widget.opportunityId,
      'opportunityTitle': opp['title'] ?? '',
      'studentUid': uid,
      'studentName': AppSession.fullName ?? '',
      'classId': AppSession.classId ?? '',
      'signedUpAt': FieldValue.serverTimestamp(),
      'status': 'signed_up',
      'hoursLogged': 0,
      'validatedBy': null,
      'validatedAt': null,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Te-ai inscris cu succes!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _surface,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _oppStream,
        builder: (context, oppSnap) {
          if (oppSnap.connectionState == ConnectionState.waiting &&
              !oppSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final opp = oppSnap.data?.data() ?? {};
          final title = (opp['title'] ?? '').toString();
          final description = (opp['description'] ?? '').toString();
          final location = (opp['location'] ?? '').toString();
          final hoursWorth = (opp['hoursWorth'] as num?)?.toInt() ?? 0;
          final maxParticipants =
              (opp['maxParticipants'] as num?)?.toInt() ?? 0;
          final dateTs = opp['date'] as Timestamp?;
          final dateStr = dateTs != null
              ? '${dateTs.toDate().day.toString().padLeft(2, '0')}.'
                '${dateTs.toDate().month.toString().padLeft(2, '0')}.'
                '${dateTs.toDate().year}'
              : '';
          final createdByRole =
              (opp['createdByRole'] ?? '').toString();

          return Column(
            children: [
              // Header
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
                child: Container(
                  padding:
                      EdgeInsets.only(top: topPadding + 12, bottom: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0D631B), Color(0xFF19802E)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _signupsStream,
                  builder: (context, signupsSnap) {
                    final signupDocs = signupsSnap.data?.docs ?? [];
                    final activeSignups = signupDocs
                        .where((d) => d.data()['status'] != 'cancelled')
                        .toList();
                    final uid = AppSession.uid;
                    final mySignup = activeSignups
                        .where((d) => d.data()['studentUid'] == uid)
                        .toList();
                    final isSignedUp = mySignup.isNotEmpty;
                    final myStatus = isSignedUp
                        ? (mySignup.first.data()['status'] ?? '')
                        : '';

                    return SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _surfaceLowest,
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
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (description.isNotEmpty) ...[
                                  const Text(
                                    'Descriere',
                                    style: TextStyle(
                                      color: _onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    description,
                                    style: const TextStyle(
                                      color: _outline,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                _InfoRow(
                                  icon: Icons.calendar_today_rounded,
                                  label: 'Data',
                                  value: dateStr,
                                ),
                                if (location.isNotEmpty)
                                  _InfoRow(
                                    icon: Icons.location_on_rounded,
                                    label: 'Locatie',
                                    value: location,
                                  ),
                                _InfoRow(
                                  icon: Icons.access_time_rounded,
                                  label: 'Ore',
                                  value: '$hoursWorth ore',
                                ),
                                if (maxParticipants > 0)
                                  _InfoRow(
                                    icon: Icons.people_rounded,
                                    label: 'Participanti',
                                    value:
                                        '${activeSignups.length} / $maxParticipants',
                                  ),
                                _InfoRow(
                                  icon: Icons.person_rounded,
                                  label: 'Organizator',
                                  value: createdByRole == 'admin'
                                      ? 'Secretariat'
                                      : 'Diriginte',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Action button
                          if (myStatus == 'completed')
                            _StatusBanner(
                              icon: Icons.check_circle_rounded,
                              label: 'Ore validate',
                              color: _primary,
                              bgColor: _primary.withValues(alpha: 0.1),
                            )
                          else if (isSignedUp)
                            _StatusBanner(
                              icon: Icons.hourglass_top_rounded,
                              label: 'Esti inscris — asteapta validarea',
                              color: const Color(0xFFE65100),
                              bgColor: const Color(0xFFFFF3E0),
                            )
                          else if (maxParticipants > 0 &&
                              activeSignups.length >= maxParticipants)
                            _StatusBanner(
                              icon: Icons.block_rounded,
                              label: 'Locuri ocupate',
                              color: const Color(0xFFC62828),
                              bgColor: const Color(0xFFFCE4EC),
                            )
                          else
                            GestureDetector(
                              onTap: () => _signUp(opp),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0D631B),
                                      Color(0xFF19802E),
                                    ],
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x350D631B),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_rounded,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Ma inscriu',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Participants list
                          if (activeSignups.isNotEmpty) ...[
                            Text(
                              'Participanti (${activeSignups.length})',
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...activeSignups.map((doc) {
                              final d = doc.data();
                              final name =
                                  (d['studentName'] ?? '').toString();
                              final status =
                                  (d['status'] ?? '').toString();
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _surfaceLowest,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: _primary
                                            .withValues(alpha: 0.1),
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: _primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            color: _onSurface,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (status == 'completed')
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: _primary,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: _outline, size: 18),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
              color: _outline,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  const _StatusBanner({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
