import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firster/core/session.dart';
import 'package:firster/student/voluntariat_detail_page.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _surfaceLowest = Color(0xFFFFFFFF);
const _outline = Color(0xFF7A7E9A);
const _onSurface = Color(0xFF1A2050);

class VoluntariatPage extends StatefulWidget {
  final VoidCallback? onBack;

  const VoluntariatPage({super.key, this.onBack});

  @override
  State<VoluntariatPage> createState() => _VoluntariatPageState();
}

class _VoluntariatPageState extends State<VoluntariatPage> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _opportunitiesStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _mySignupsStream;

  @override
  void initState() {
    super.initState();
    final uid = AppSession.uid;
    if (uid == null) return;

    _opportunitiesStream = FirebaseFirestore.instance
        .collection('volunteerOpportunities')
        .where('status', isEqualTo: 'active')
        .orderBy('date', descending: true)
        .snapshots();

    _mySignupsStream = FirebaseFirestore.instance
        .collection('volunteerSignups')
        .where('studentUid', isEqualTo: uid)
        .snapshots();
  }

  Future<void> _signUp(String opportunityId, Map<String, dynamic> opp) async {
    final uid = AppSession.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('volunteerSignups').add({
      'opportunityId': opportunityId,
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
      const SnackBar(content: Text('Successfully signed up!')),
    );
  }

  Future<void> _cancelSignup(String signupDocId) async {
    await FirebaseFirestore.instance
        .collection('volunteerSignups')
        .doc(signupDocId)
        .update({'status': 'cancelled'});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign-up cancelled.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _Header(topPadding: topPadding, onBack: widget.onBack),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _mySignupsStream,
              builder: (context, signupsSnap) {
                final signupDocs = signupsSnap.data?.docs ?? [];
                final signedUpIds = <String, _SignupInfo>{};
                int totalHours = 0;

                for (final doc in signupDocs) {
                  final d = doc.data();
                  final oppId = d['opportunityId'] as String? ?? '';
                  final status = d['status'] as String? ?? '';
                  if (status != 'cancelled') {
                    signedUpIds[oppId] = _SignupInfo(
                      docId: doc.id,
                      status: status,
                    );
                  }
                  if (status == 'completed') {
                    totalHours += (d['hoursLogged'] as num?)?.toInt() ?? 0;
                  }
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _opportunitiesStream,
                  builder: (context, oppSnap) {
                    if (oppSnap.connectionState == ConnectionState.waiting &&
                        !oppSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final oppDocs = oppSnap.data?.docs ?? [];

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HoursSummaryCard(totalHours: totalHours),
                          const SizedBox(height: 20),
                          const Text(
                            'Available opportunities',
                            style: TextStyle(
                              color: _onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (oppDocs.isEmpty)
                            _EmptyState()
                          else
                            ...oppDocs.map((doc) {
                              final data = doc.data();
                              final signupInfo = signedUpIds[doc.id];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _OpportunityCard(
                                  docId: doc.id,
                                  data: data,
                                  signupInfo: signupInfo,
                                  onSignUp: () => _signUp(doc.id, data),
                                  onCancel: signupInfo != null
                                      ? () => _cancelSignup(signupInfo.docId)
                                      : null,
                                  onTap: () => Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) =>
                                          VoluntariatDetailPage(
                                        opportunityId: doc.id,
                                      ),
                                      transitionDuration: Duration.zero,
                                      reverseTransitionDuration: Duration.zero,
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupInfo {
  final String docId;
  final String status;
  const _SignupInfo({required this.docId, required this.status});
}

// ────────────────────────────────────────────────────────────────────────────
// HEADER
// ────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final double topPadding;
  final VoidCallback? onBack;

  const _Header({required this.topPadding, this.onBack});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(36),
        bottomRight: Radius.circular(36),
      ),
      child: Container(
        padding: EdgeInsets.only(top: topPadding + 12, bottom: 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2848B0), Color(0xFF3460CC)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: 30,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (onBack != null)
                    GestureDetector(
                      onTap: onBack,
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
                  if (onBack != null) const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Volunteering',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Get involved in the community',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HOURS SUMMARY
// ────────────────────────────────────────────────────────────────────────────
class _HoursSummaryCard extends StatelessWidget {
  final int totalHours;
  const _HoursSummaryCard({required this.totalHours});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x102848B0),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: _primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalHours hours',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'volunteering accumulated',
                  style: TextStyle(
                    color: _outline,
                    fontSize: 13,
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
}

// ────────────────────────────────────────────────────────────────────────────
// OPPORTUNITY CARD
// ────────────────────────────────────────────────────────────────────────────
class _OpportunityCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final _SignupInfo? signupInfo;
  final VoidCallback onSignUp;
  final VoidCallback? onCancel;
  final VoidCallback onTap;

  const _OpportunityCard({
    required this.docId,
    required this.data,
    required this.signupInfo,
    required this.onSignUp,
    required this.onCancel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? '').toString();
    final location = (data['location'] ?? '').toString();
    final hoursWorth = (data['hoursWorth'] as num?)?.toInt() ?? 0;
    final maxParticipants = (data['maxParticipants'] as num?)?.toInt() ?? 0;
    final dateTs = data['date'] as Timestamp?;
    final dateStr = dateTs != null
        ? '${dateTs.toDate().day.toString().padLeft(2, '0')}.'
          '${dateTs.toDate().month.toString().padLeft(2, '0')}.'
          '${dateTs.toDate().year}'
        : '';

    final isSignedUp =
        signupInfo != null && signupInfo!.status == 'signed_up';
    final isCompleted =
        signupInfo != null && signupInfo!.status == 'completed';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: _primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: _outline,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _outline,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (location.isNotEmpty) ...[
                  Icon(Icons.location_on_rounded,
                      color: _outline, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      location,
                      style: const TextStyle(
                        color: _outline,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.access_time_rounded,
                    color: _outline, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$hoursWorth hrs',
                  style: const TextStyle(color: _outline, fontSize: 12),
                ),
                if (maxParticipants > 0) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.people_rounded,
                      color: _outline, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'max $maxParticipants',
                    style: const TextStyle(color: _outline, fontSize: 12),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (isCompleted)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: _primary, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Completed',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (isSignedUp)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_top_rounded,
                            color: Color(0xFFE65100), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Signed up',
                          style: TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE4EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFFC62828),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: onSignUp,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2848B0), Color(0xFF3460CC)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Sign up',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
}

// ────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.volunteer_activism_rounded,
              color: _outline.withValues(alpha: 0.4), size: 48),
          const SizedBox(height: 12),
          const Text(
            'No opportunities available',
            style: TextStyle(
              color: _outline,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check back later for new activities',
            style: TextStyle(color: _outline, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
