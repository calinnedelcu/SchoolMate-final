import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firster/core/session.dart';
import 'package:firster/student/tutoring_session_page.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF1F8BE7);
const _surface = Color(0xFFEFF5FA);
const _surfaceLowest = Color(0xFFFFFFFF);
const _surfaceContainerLow = Color(0xFFE7F0F6);
const _outline = Color(0xFF717B6E);
const _onSurface = Color(0xFF587F9E);

class TutoringPage extends StatefulWidget {
  final VoidCallback? onBack;

  const TutoringPage({super.key, this.onBack});

  @override
  State<TutoringPage> createState() => _TutoringPageState();
}

class _TutoringPageState extends State<TutoringPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _offersStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _requestsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _myTutorSessionsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _myLearnerSessionsStream;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    final classId = AppSession.classId;
    final uid = AppSession.uid;
    if (classId != null && classId.isNotEmpty) {
      _offersStream = FirebaseFirestore.instance
          .collection('tutoringOffers')
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: 'active')
          .snapshots();

      _requestsStream = FirebaseFirestore.instance
          .collection('tutoringRequests')
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: 'active')
          .snapshots();
    }

    if (uid != null && uid.isNotEmpty) {
      _myTutorSessionsStream = FirebaseFirestore.instance
          .collection('tutoringSessions')
          .where('tutorUid', isEqualTo: uid)
          .snapshots();

      _myLearnerSessionsStream = FirebaseFirestore.instance
          .collection('tutoringSessions')
          .where('learnerUid', isEqualTo: uid)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCreateSheet({required bool isOffer}) async {
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final availCtrl = TextEditingController();
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isOffer
                        ? 'Postează o ofertă de ajutor'
                        : 'Postează o cerere de ajutor',
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOffer
                        ? 'Colegii vor putea cere o sesiune cu tine'
                        : 'Colegii care oferă ajutor te vor vedea',
                    style: const TextStyle(color: _outline, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _SheetField(
                    controller: subjectCtrl,
                    label: 'Materie *',
                    hint: 'ex: Matematica, Romana, Engleza',
                  ),
                  const SizedBox(height: 10),
                  _SheetField(
                    controller: descCtrl,
                    label: 'Detalii',
                    hint: isOffer
                        ? 'ex: Pot ajuta la algebra, ecuatii'
                        : 'ex: Am nevoie de ajutor la ecuatii cu doua necunoscute',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  _SheetField(
                    controller: availCtrl,
                    label: 'Disponibilitate',
                    hint: 'ex: Marti, Joi dupa ora 16',
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: saving
                        ? null
                        : () async {
                            final subject = subjectCtrl.text.trim();
                            if (subject.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Completeaza materia'),
                                ),
                              );
                              return;
                            }
                            setSheet(() => saving = true);
                            await _createPost(
                              isOffer: isOffer,
                              subject: subject,
                              description: descCtrl.text.trim(),
                              availability: availCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1F8BE7), Color(0xFF328FDF)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isOffer ? 'Posteaza oferta' : 'Posteaza cerere',
                                style: const TextStyle(
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
          },
        );
      },
    );
  }

  Future<void> _createPost({
    required bool isOffer,
    required String subject,
    required String description,
    required String availability,
  }) async {
    final uid = AppSession.uid;
    final classId = AppSession.classId;
    if (uid == null || classId == null) return;

    final collection = isOffer ? 'tutoringOffers' : 'tutoringRequests';
    await FirebaseFirestore.instance.collection(collection).add({
      'studentUid': uid,
      'studentName': AppSession.fullName ?? '',
      'classId': classId,
      'subject': subject,
      'description': description,
      'availability': availability,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isOffer ? 'Oferta postata!' : 'Cerere postata!'),
      ),
    );
  }

  Future<void> _archivePost({
    required String collection,
    required String docId,
  }) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .update({'status': 'archived'});
  }

  Future<void> _initiateSession({
    required bool fromOffer,
    required Map<String, dynamic> postData,
    required String subject,
  }) async {
    final uid = AppSession.uid;
    final classId = AppSession.classId;
    if (uid == null || classId == null) return;

    final myName = AppSession.fullName ?? '';
    final otherUid = (postData['studentUid'] ?? '').toString();
    final otherName = (postData['studentName'] ?? '').toString();

    if (otherUid == uid) return;

    // fromOffer = true → I am the learner, the post creator is the tutor.
    // fromOffer = false → I am the tutor, the post creator is the learner.
    final tutorUid = fromOffer ? otherUid : uid;
    final tutorName = fromOffer ? otherName : myName;
    final learnerUid = fromOffer ? uid : otherUid;
    final learnerName = fromOffer ? myName : otherName;

    final docRef = await FirebaseFirestore.instance
        .collection('tutoringSessions')
        .add({
      'tutorUid': tutorUid,
      'tutorName': tutorName,
      'learnerUid': learnerUid,
      'learnerName': learnerName,
      'classId': classId,
      'subject': subject,
      'notes': (postData['description'] ?? '').toString(),
      'availability': (postData['availability'] ?? '').toString(),
      'status': 'pending',
      'hoursLogged': 0,
      'initiatedBy': fromOffer ? 'learner' : 'tutor',
      'createdAt': FieldValue.serverTimestamp(),
      'validatedBy': null,
      'validatedAt': null,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesiune solicitata!')),
    );

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => TutoringSessionPage(sessionId: docRef.id),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final classId = AppSession.classId;

    if (classId == null || classId.isEmpty) {
      return Scaffold(
        backgroundColor: _surface,
        body: Column(
          children: [
            _Header(topPadding: topPadding, onBack: widget.onBack),
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nu ai o clasa asignata.\nContacteaza secretariatul.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _outline, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _Header(topPadding: topPadding, onBack: widget.onBack),
          _StatsCard(
            tutorStream: _myTutorSessionsStream,
            learnerStream: _myLearnerSessionsStream,
          ),
          const SizedBox(height: 12),
          _MySessionsSection(
            tutorStream: _myTutorSessionsStream,
            learnerStream: _myLearnerSessionsStream,
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F8BE7), Color(0xFF328FDF)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: _outline,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Ofer ajutor'),
                Tab(text: 'Caut ajutor'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _PostsTab(
                  isOfferTab: true,
                  myPostsStream: _offersStream,
                  classPostsStream: _requestsStream,
                  onCreate: () => _showCreateSheet(isOffer: true),
                  onArchive: (id) => _archivePost(
                    collection: 'tutoringOffers',
                    docId: id,
                  ),
                  onInitiate: (data, subject) => _initiateSession(
                    fromOffer: false,
                    postData: data,
                    subject: subject,
                  ),
                ),
                _PostsTab(
                  isOfferTab: false,
                  myPostsStream: _requestsStream,
                  classPostsStream: _offersStream,
                  onCreate: () => _showCreateSheet(isOffer: false),
                  onArchive: (id) => _archivePost(
                    collection: 'tutoringRequests',
                    docId: id,
                  ),
                  onInitiate: (data, subject) => _initiateSession(
                    fromOffer: true,
                    postData: data,
                    subject: subject,
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
            colors: [Color(0xFF1F8BE7), Color(0xFF328FDF)],
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
                          'Peer Tutoring',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ajuta colegii sau cere ajutor',
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
                      Icons.school_rounded,
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
// STATS CARD
// ────────────────────────────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? tutorStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? learnerStream;

  const _StatsCard({required this.tutorStream, required this.learnerStream});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tutorStream,
        builder: (context, tutorSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: learnerStream,
            builder: (context, learnerSnap) {
              final tutorDocs = tutorSnap.data?.docs ?? [];
              final learnerDocs = learnerSnap.data?.docs ?? [];

              int tutorHours = 0;
              int tutorSessions = 0;
              for (final doc in tutorDocs) {
                final d = doc.data();
                if (d['status'] == 'completed') {
                  tutorHours += (d['hoursLogged'] as num?)?.toInt() ?? 0;
                  tutorSessions++;
                }
              }

              int learnerSessions = 0;
              for (final doc in learnerDocs) {
                final d = doc.data();
                if (d['status'] == 'completed') {
                  learnerSessions++;
                }
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surfaceLowest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x101F8BE7),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.access_time_rounded,
                        value: '$tutorHours',
                        label: 'ore tutor',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: _outline.withValues(alpha: 0.18),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.menu_book_rounded,
                        value: '$tutorSessions',
                        label: 'predate',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: _outline.withValues(alpha: 0.18),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.lightbulb_rounded,
                        value: '$learnerSessions',
                        label: 'invatate',
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: _primary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: _outline, fontSize: 11),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// MY SESSIONS (active list)
// ────────────────────────────────────────────────────────────────────────────
class _MySessionsSection extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? tutorStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? learnerStream;

  const _MySessionsSection({
    required this.tutorStream,
    required this.learnerStream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: tutorStream,
      builder: (context, tutorSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: learnerStream,
          builder: (context, learnerSnap) {
            final all = <QueryDocumentSnapshot<Map<String, dynamic>>>[
              ...?tutorSnap.data?.docs,
              ...?learnerSnap.data?.docs,
            ].where((d) {
              final s = (d.data()['status'] ?? '').toString();
              return s == 'pending' || s == 'confirmed';
            }).toList();

            if (all.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sesiunile mele active',
                    style: TextStyle(
                      color: _onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: all.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final doc = all[i];
                        final d = doc.data();
                        final uid = AppSession.uid;
                        final isTutor = d['tutorUid'] == uid;
                        final otherName = isTutor
                            ? (d['learnerName'] ?? '').toString()
                            : (d['tutorName'] ?? '').toString();
                        final subject = (d['subject'] ?? '').toString();
                        final status = (d['status'] ?? '').toString();

                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) =>
                                  TutoringSessionPage(sessionId: doc.id),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          ),
                          child: Container(
                            width: 200,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _surfaceLowest,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isTutor
                                            ? _primary.withValues(alpha: 0.1)
                                            : const Color(0xFFE3F2FD),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isTutor ? 'Tutor' : 'Elev',
                                        style: TextStyle(
                                          color: isTutor
                                              ? _primary
                                              : const Color(0xFF48A3EF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    _StatusBadge(status: status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subject,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  isTutor
                                      ? 'pentru $otherName'
                                      : 'cu $otherName',
                                  style: const TextStyle(
                                    color: _outline,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
            );
          },
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'pending':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'In asteptare';
        break;
      case 'confirmed':
        bg = const Color(0xFFE6EFF7);
        fg = _primary;
        label = 'Confirmat';
        break;
      case 'completed':
        bg = _primary.withValues(alpha: 0.12);
        fg = _primary;
        label = 'Validat';
        break;
      default:
        bg = const Color(0xFFFCE4EC);
        fg = const Color(0xFFC62828);
        label = 'Anulat';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TAB CONTENT (offers / requests)
// ────────────────────────────────────────────────────────────────────────────
class _PostsTab extends StatelessWidget {
  final bool isOfferTab;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? myPostsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? classPostsStream;
  final VoidCallback onCreate;
  final Future<void> Function(String docId) onArchive;
  final Future<void> Function(Map<String, dynamic> data, String subject)
      onInitiate;

  const _PostsTab({
    required this.isOfferTab,
    required this.myPostsStream,
    required this.classPostsStream,
    required this.onCreate,
    required this.onArchive,
    required this.onInitiate,
  });

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onCreate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F8BE7), Color(0xFF328FDF)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      isOfferTab ? 'Posteaza oferta' : 'Posteaza cerere',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Postările mele
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: myPostsStream,
            builder: (context, snap) {
              final docs = (snap.data?.docs ?? [])
                  .where((d) => d.data()['studentUid'] == uid)
                  .toList();
              if (docs.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOfferTab ? 'Ofertele mele' : 'Cererile mele',
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...docs.map(
                    (doc) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PostCard(
                        data: doc.data(),
                        isMine: true,
                        actionLabel: 'Arhiveaza',
                        onAction: () => onArchive(doc.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // Postări colegi
          Text(
            isOfferTab
                ? 'Colegi care cer ajutor'
                : 'Colegi care ofera ajutor',
            style: const TextStyle(
              color: _onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: classPostsStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = (snap.data?.docs ?? [])
                  .where((d) => d.data()['studentUid'] != uid)
                  .toList();
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surfaceLowest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isOfferTab
                            ? Icons.help_outline_rounded
                            : Icons.school_outlined,
                        color: _outline.withValues(alpha: 0.4),
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isOfferTab
                            ? 'Niciun coleg nu cere ajutor inca'
                            : 'Niciun coleg nu ofera ajutor inca',
                        style: const TextStyle(
                          color: _outline,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PostCard(
                      data: data,
                      isMine: false,
                      actionLabel: isOfferTab ? 'Ajut' : 'Solicit',
                      onAction: () => onInitiate(
                        data,
                        (data['subject'] ?? '').toString(),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMine;
  final String actionLabel;
  final VoidCallback onAction;

  const _PostCard({
    required this.data,
    required this.isMine,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final subject = (data['subject'] ?? '').toString();
    final description = (data['description'] ?? '').toString();
    final availability = (data['availability'] ?? '').toString();
    final studentName = (data['studentName'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: _primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isMine && studentName.isNotEmpty)
                      Text(
                        studentName,
                        style: const TextStyle(
                          color: _outline,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (availability.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    color: _outline, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    availability,
                    style: const TextStyle(color: _outline, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isMine
                      ? const Color(0xFFFCE4EC)
                      : _primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    color: isMine
                        ? const Color(0xFFC62828)
                        : Colors.white,
                    fontSize: 12,
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
}

// ────────────────────────────────────────────────────────────────────────────
// SHEET FIELD
// ────────────────────────────────────────────────────────────────────────────
class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  const _SheetField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: _onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _outline, fontSize: 13),
            filled: true,
            fillColor: _surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
