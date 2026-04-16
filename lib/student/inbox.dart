import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/l10n/app_localizations.dart';
import 'package:firster/student/meniu.dart';
import 'package:firster/core/session.dart';
import 'package:flutter/material.dart';

enum _InboxFilter {
  all,
  requests,
  announcements,
  volunteer,
  tutoring,
  competition,
  camp,
}

const String _kAudienceAll = '__ALL__';

const _primary = Color(0xFF1F8BE7);
const _surface = Color(0xFFE3ECF2);
const _card = Color(0xFFF2F6F9);
const _textDark = Color(0xFF557EA1);
const _textMuted = Color(0xFF6F7669);

class InboxScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final String? highlightDocId;
  final VoidCallback? onHighlightConsumed;

  const InboxScreen({
    super.key,
    this.onNavigateTab,
    this.highlightDocId,
    this.onHighlightConsumed,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _leaveStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _secretariatStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _secretariatGlobalStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _volunteerStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _volunteerSignupsStream;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  String? _activeHighlightId;
  Timer? _highlightTimer;
  _InboxFilter _filter = _InboxFilter.all;

  @override
  void initState() {
    super.initState();
    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      _leaveStream = FirebaseFirestore.instance
          .collection('leaveRequests')
          .where('studentUid', isEqualTo: uid)
          .orderBy('requestedAt', descending: true)
          .limit(50)
          .snapshots();

      _secretariatStream = FirebaseFirestore.instance
          .collection('secretariatMessages')
          .where('recipientUid', isEqualTo: uid)
          .where('recipientRole', isEqualTo: 'student')
          .limit(50)
          .snapshots();

      _secretariatGlobalStream = FirebaseFirestore.instance
          .collection('secretariatMessages')
          .where('recipientUid', isEqualTo: '')
          .where('recipientRole', isEqualTo: 'student')
          .limit(50)
          .snapshots();

      _volunteerStream = FirebaseFirestore.instance
          .collection('volunteerOpportunities')
          .where('status', isEqualTo: 'active')
          .orderBy('date', descending: true)
          .limit(30)
          .snapshots();

      _volunteerSignupsStream = FirebaseFirestore.instance
          .collection('volunteerSignups')
          .where('studentUid', isEqualTo: uid)
          .snapshots();
    }
  }

  @override
  void didUpdateWidget(InboxScreen old) {
    super.didUpdateWidget(old);
    final newId = widget.highlightDocId;
    if (newId != null && newId.isNotEmpty && newId != old.highlightDocId) {
      setState(() => _activeHighlightId = newId);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToHighlight(newId),
      );
    }
  }

  void _scrollToHighlight(String docId, {int retries = 8}) {
    widget.onHighlightConsumed?.call();
    final key = _itemKeys[docId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        alignment: 0.25,
      );
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _activeHighlightId = null);
      });
    } else if (retries > 0) {
      // Lista poate să nu fie randată încă — reîncercăm după un frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToHighlight(docId, retries: retries - 1);
      });
    } else {
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _activeHighlightId = null);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _goBack(BuildContext context) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(0);
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const MeniuScreen()),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _openProfile(BuildContext context) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MeniuScreen()));
  }

  String _formatRequestDate(DateTime? date) {
    if (date == null) return '--';
    const months = <String>[
      'Ianuarie',
      'Februarie',
      'Martie',
      'Aprilie',
      'Mai',
      'Iunie',
      'Iulie',
      'August',
      'Septembrie',
      'Octombrie',
      'Noiembrie',
      'Decembrie',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _formatRequestTitle(DateTime? date) {
    if (date == null) return 'Cerere învoire';
    final dateStr = _formatRequestDate(date);
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return 'Cerere învoire - $dateStr, $hh:$mm';
  }

  String? _formatSentLabel(DateTime? sentAt) {
    if (sentAt == null) return '--:--';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(sentAt.year, sentAt.month, sentAt.day);
    final hour = sentAt.hour.toString().padLeft(2, '0');
    final minute = sentAt.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return time;
    if (diff == 1) return 'Ieri';
    if (diff > 10) return null;
    return '${sentAt.day}.${sentAt.month.toString().padLeft(2, '0')}.${sentAt.year}';
  }

  _InboxCardData _toInboxCardData(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    var status = (data['status'] ?? 'pending').toString();
    final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
    final requestedForDate = (data['requestedForDate'] as Timestamp?)?.toDate();
    final message = (data['message'] ?? '').toString().trim();

    // Client-side: expire pending/approved requests once the date has passed
    if ((status == 'pending' || status == 'approved') &&
        requestedForDate != null) {
      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);
      if (requestedForDate.isBefore(todayMidnight)) {
        status = 'expired';
      }
    }

    switch (status) {
      case 'approved':
        return _InboxCardData(
          docId: doc.id,
          category: _InboxFilter.requests,
          title: _formatRequestTitle(requestedForDate),
          topLabel: _formatSentLabel(requestedAt),
          message: message.isEmpty ? 'Cererea a fost aprobată.' : message,
          leadingIcon: Icons.description_rounded,
          leadingBackground: const Color(0xFFDFEAF2),
          leadingForeground: _primary,
          statusIcon: Icons.check_circle_rounded,
          statusLabel: 'Aprobată',
          statusBackground: const Color(0xFFDEE9F3),
          statusForeground: _primary,
          sortAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      case 'rejected':
        return _InboxCardData(
          docId: doc.id,
          category: _InboxFilter.requests,
          title: _formatRequestTitle(requestedForDate),
          topLabel: _formatSentLabel(requestedAt),
          message: message.isEmpty ? 'Cererea a fost respinsă.' : message,
          leadingIcon: Icons.description_rounded,
          leadingBackground: const Color(0xFFF2E4EA),
          leadingForeground: const Color(0xFF9D345F),
          statusIcon: Icons.cancel_rounded,
          statusLabel: 'Respinsă',
          statusBackground: const Color(0xFFF4E6EC),
          statusForeground: const Color(0xFF9D345F),
          sortAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      case 'expired':
        return _InboxCardData(
          docId: doc.id,
          category: _InboxFilter.requests,
          title: _formatRequestTitle(requestedForDate),
          topLabel: _formatSentLabel(requestedAt),
          message: message.isEmpty ? 'Cererea a expirat automat.' : message,
          leadingIcon: Icons.history_toggle_off_rounded,
          leadingBackground: const Color(0xFFF2EEDC),
          leadingForeground: const Color(0xFF8A6A1D),
          statusIcon: Icons.hourglass_bottom_rounded,
          statusLabel: 'Expirată',
          statusBackground: const Color(0xFFF6F0D9),
          statusForeground: const Color(0xFF8A6A1D),
          sortAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      default:
        return _InboxCardData(
          docId: doc.id,
          category: _InboxFilter.requests,
          title: _formatRequestTitle(requestedForDate),
          topLabel: _formatSentLabel(requestedAt),
          message: message.isEmpty
              ? 'Cererea este în așteptarea aprobării.'
              : message,
          leadingIcon: Icons.history_rounded,
          leadingBackground: const Color(0xFFDAE6EF),
          leadingForeground: const Color(0xFF88A2B7),
          statusIcon: Icons.watch_later_rounded,
          statusLabel: 'În așteptare',
          statusBackground: const Color(0xFFD6E5EF),
          statusForeground: const Color(0xFF648AA8),
          sortAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
    }
  }

  _InboxCardData _toSecretariatCardData(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required _InboxFilter fallbackCategory,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final message = (data['message'] ?? '').toString().trim();
    final senderName = (data['senderName'] ?? 'Secretariat').toString().trim();
    final docTitle = (data['title'] ?? '').toString().trim();
    final categoryKey = (data['category'] ?? '').toString().trim();

    // Map server category → filter pill bucket.
    // Direct messages (recipientUid == myUid) ignore `category` and stay
    // in the `requests` bucket.
    _InboxFilter category;
    String fallbackTitle;
    IconData icon;
    Color iconBg;
    Color iconFg;
    switch (categoryKey) {
      case 'competition':
        category = _InboxFilter.competition;
        fallbackTitle = 'Competiție';
        icon = Icons.emoji_events_rounded;
        iconBg = const Color(0xFFFFF3D6);
        iconFg = const Color(0xFFCC8A1A);
        break;
      case 'camp':
        category = _InboxFilter.camp;
        fallbackTitle = 'Tabără';
        icon = Icons.forest_rounded;
        iconBg = const Color(0xFFD9EFD8);
        iconFg = const Color(0xFF3F8B3A);
        break;
      case 'announcement':
        category = _InboxFilter.announcements;
        fallbackTitle = 'Anunț școlar';
        icon = Icons.campaign_rounded;
        iconBg = const Color(0xFFDCEFFF);
        iconFg = const Color(0xFF56A3EB);
        break;
      default:
        category = fallbackCategory;
        fallbackTitle = 'Mesaj Secretariat';
        icon = Icons.campaign_rounded;
        iconBg = const Color(0xFFDCEFFF);
        iconFg = const Color(0xFF56A3EB);
    }

    return _InboxCardData(
      docId: doc.id,
      category: category,
      title: docTitle.isEmpty ? fallbackTitle : docTitle,
      topLabel: _formatSentLabel(createdAt),
      message: message.isEmpty ? 'Ai primit un mesaj nou.' : message,
      leadingIcon: icon,
      leadingBackground: iconBg,
      leadingForeground: iconFg,
      statusIcon: Icons.mark_chat_read_rounded,
      statusLabel: senderName.isEmpty ? 'Secretariat' : senderName,
      statusBackground: iconBg,
      statusForeground: iconFg,
      sortAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Returns true if the broadcast doc should be visible to this student.
  /// Backward-compat: docs missing `audienceClassIds` are treated as
  /// school-wide (visible to everyone).
  bool _broadcastVisibleToMe(Map<String, dynamic> data) {
    final audience = data['audienceClassIds'];
    if (audience is! List || audience.isEmpty) return true;
    if (audience.contains(_kAudienceAll)) return true;
    final myClass = (AppSession.classId ?? '').trim();
    if (myClass.isEmpty) return false;
    return audience.contains(myClass);
  }

  Future<void> _signUpVolunteer(
    String opportunityId,
    Map<String, dynamic> opp,
  ) async {
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
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.inboxVolunteerSignupSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _InboxHeader(
              onBack: () => _goBack(context),
              onProfile: () => _openProfile(context),
              onLogout: _logout,
            ),
            Expanded(child: _buildInboxBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxBody() {
    if (_leaveStream == null) {
      return const Center(child: Text('Sesiune invalidă.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _leaveStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Eroare: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _secretariatStream,
          builder: (context, secretariatSnap) {
            if (secretariatSnap.hasError) {
              return Center(child: Text('Eroare: ${secretariatSnap.error}'));
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _secretariatGlobalStream,
              builder: (context, globalSnap) {
                if (globalSnap.hasError) {
                  return Center(child: Text('Eroare: ${globalSnap.error}'));
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _volunteerStream,
                  builder: (context, volunteerSnap) {
                    return StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>
                    >(
                      stream: _volunteerSignupsStream,
                      builder: (context, signupsSnap) {
                        return _buildLoadedBody(
                          leaveDocs: snapshot.data!.docs,
                          secretariatDocs:
                              secretariatSnap.data?.docs ?? const [],
                          globalDocs: globalSnap.data?.docs ?? const [],
                          volunteerDocs:
                              volunteerSnap.data?.docs ?? const [],
                          signupDocs: signupsSnap.data?.docs ?? const [],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLoadedBody({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> leaveDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> secretariatDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> globalDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> volunteerDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> signupDocs,
  }) {
    final l = AppLocalizations.of(context);

    final leaveItems = leaveDocs
        .where((doc) {
          final data = doc.data();
          final source = (data['source'] ?? '').toString().trim();
          return source != 'secretariat';
        })
        .map(_toInboxCardData)
        .toList();

    // Direct messages addressed personally to the student → "Cereri"
    final schoolItems = secretariatDocs
        .map(
          (doc) => _toSecretariatCardData(
            doc,
            fallbackCategory: _InboxFilter.requests,
          ),
        )
        .toList();
    // Broadcasts (recipientUid == ''): may be announcement / competition / camp.
    // Filter by audience client-side for backward compat.
    final announcementItems = globalDocs
        .where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? 'active').toString();
          if (status == 'archived') return false;
          return _broadcastVisibleToMe(data);
        })
        .map(
          (doc) => _toSecretariatCardData(
            doc,
            fallbackCategory: _InboxFilter.announcements,
          ),
        )
        .toList();

    final cards =
        (<_InboxCardData>[
            ...leaveItems,
            ...schoolItems,
            ...announcementItems,
          ].where((item) => item.topLabel != null).toList())
          ..sort((a, b) => b.sortAt.compareTo(a.sortAt));

    // Build set of opportunity IDs the student is already signed up to (active)
    final signedUpOppIds = <String>{};
    for (final doc in signupDocs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString();
      if (status != 'cancelled') {
        final oppId = (data['opportunityId'] ?? '').toString();
        if (oppId.isNotEmpty) signedUpOppIds.add(oppId);
      }
    }

    final volunteerItems = volunteerDocs
        .where((doc) => _broadcastVisibleToMe(doc.data()))
        .map((doc) {
      final data = doc.data();
      final when = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      return _VolunteerInboxData(
        docId: doc.id,
        title: (data['title'] ?? '').toString(),
        location: (data['location'] ?? '').toString(),
        hoursWorth: ((data['hoursWorth'] as num?) ?? 0).toInt(),
        when: when,
        topLabel: _formatSentLabel(when),
        alreadySignedUp: signedUpOppIds.contains(doc.id),
        raw: data,
      );
    }).toList()
      ..sort((a, b) => b.when.compareTo(a.when));

    // Apply filter
    List<_InboxCardData> filteredCards;
    List<_VolunteerInboxData> filteredVolunteer;
    switch (_filter) {
      case _InboxFilter.all:
        filteredCards = cards;
        filteredVolunteer = volunteerItems;
        break;
      case _InboxFilter.requests:
        filteredCards = cards
            .where((c) => c.category == _InboxFilter.requests)
            .toList();
        filteredVolunteer = const [];
        break;
      case _InboxFilter.announcements:
        filteredCards = cards
            .where((c) => c.category == _InboxFilter.announcements)
            .toList();
        filteredVolunteer = const [];
        break;
      case _InboxFilter.competition:
        filteredCards = cards
            .where((c) => c.category == _InboxFilter.competition)
            .toList();
        filteredVolunteer = const [];
        break;
      case _InboxFilter.camp:
        filteredCards = cards
            .where((c) => c.category == _InboxFilter.camp)
            .toList();
        filteredVolunteer = const [];
        break;
      case _InboxFilter.volunteer:
        filteredCards = const [];
        filteredVolunteer = volunteerItems;
        break;
      case _InboxFilter.tutoring:
        filteredCards = const [];
        filteredVolunteer = const [];
        break;
    }

    // Combine into a single chronologically sorted list
    final combined = <_InboxRow>[
      ...filteredCards.map((c) => _InboxRow.card(c)),
      ...filteredVolunteer.map((v) => _InboxRow.volunteer(v)),
    ]..sort((a, b) => b.sortAt.compareTo(a.sortAt));

    final horizontalPadding =
        MediaQuery.sizeOf(context).width < 390 ? 14.0 : 18.0;

    return Column(
      children: [
        _FilterPillsBar(
          current: _filter,
          onChanged: (next) => setState(() => _filter = next),
        ),
        Expanded(
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              MediaQuery.paddingOf(context).bottom + 28,
            ),
            children: [
              if (combined.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    _filter == _InboxFilter.tutoring
                        ? 'Meditațiile vor fi disponibile în curând.'
                        : l.inboxEmpty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              for (final row in combined) ...[
                if (row.card != null)
                  _InboxRequestTile(
                    key: _itemKeys.putIfAbsent(row.card!.docId, GlobalKey.new),
                    data: row.card!,
                    highlighted: _activeHighlightId == row.card!.docId,
                  ),
                if (row.volunteer != null)
                  _VolunteerInboxTile(
                    data: row.volunteer!,
                    onSignUp: row.volunteer!.alreadySignedUp
                        ? null
                        : () => _signUpVolunteer(
                              row.volunteer!.docId,
                              row.volunteer!.raw,
                            ),
                  ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}

class _InboxRow {
  final _InboxCardData? card;
  final _VolunteerInboxData? volunteer;
  final DateTime sortAt;

  _InboxRow.card(_InboxCardData c)
      : card = c,
        volunteer = null,
        sortAt = c.sortAt;

  _InboxRow.volunteer(_VolunteerInboxData v)
      : card = null,
        volunteer = v,
        sortAt = v.when;
}

class _InboxHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onProfile;
  final Future<void> Function() onLogout;

  const _InboxHeader({
    required this.onBack,
    required this.onProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;
    final headerHeight = compact ? 138.0 : 146.0;
    final titleSize = compact ? 29.0 : 33.0;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(52),
        bottomRight: Radius.circular(52),
      ),
      child: Container(
        height: headerHeight,
        width: double.infinity,
        color: _primary,
        child: Stack(
          children: [
            Positioned(
              right: -56,
              top: -74,
              child: _HeaderCircle(size: 220, opacity: 0.08),
            ),
            Positioned(
              right: 34,
              top: 46,
              child: _HeaderCircle(size: 72, opacity: 0.07),
            ),
            Positioned(
              left: 156,
              bottom: -28,
              child: _HeaderCircle(size: 82, opacity: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _HeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        l.inboxTitle,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
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
}

class _InboxRequestTile extends StatefulWidget {
  final _InboxCardData data;
  final bool highlighted;

  const _InboxRequestTile({
    super.key,
    required this.data,
    this.highlighted = false,
  });

  @override
  State<_InboxRequestTile> createState() => _InboxRequestTileState();
}

class _InboxRequestTileState extends State<_InboxRequestTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    if (widget.highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          _bounceCtrl.forward().then((_) {
            if (mounted) _bounceCtrl.reverse();
          });
      });
    }
  }

  @override
  void didUpdateWidget(_InboxRequestTile old) {
    super.didUpdateWidget(old);
    if (widget.highlighted && !old.highlighted) {
      _bounceCtrl.forward().then((_) {
        if (mounted) _bounceCtrl.reverse();
      });
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceCtrl,
      builder: (context, child) {
        final scale = 1.0 + (_bounceCtrl.value * 0.04);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.data.leadingForeground,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, _card],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.data.title.contains(' - ')
                                          ? 'Cerere învoire'
                                          : widget.data.title,
                                      style: const TextStyle(
                                        color: _textDark,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                        height: 1.2,
                                      ),
                                    ),
                                    if (widget.data.title.contains(' - ')) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.data.title.split(' - ').last,
                                        style: const TextStyle(
                                          color: _textMuted,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.data.topLabel ?? '',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.data.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (widget.data.statusLabel != null)
                            _StatusBadge(data: widget.data),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _InboxCardData data;

  const _StatusBadge({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: data.statusBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.statusIcon, color: data.statusForeground, size: 15),
          const SizedBox(width: 6),
          Text(
            data.statusLabel ?? '',
            style: TextStyle(
              color: data.statusForeground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(child: Icon(icon, color: Colors.white, size: 32)),
      ),
    );
  }
}

class _HeaderCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _HeaderCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _InboxCardData {
  final String docId;
  final _InboxFilter category;
  final String title;
  final String? topLabel;
  final String message;
  final IconData leadingIcon;
  final Color leadingBackground;
  final Color leadingForeground;
  final IconData? statusIcon;
  final String? statusLabel;
  final Color? statusBackground;
  final Color? statusForeground;
  final DateTime sortAt;

  const _InboxCardData({
    required this.docId,
    required this.category,
    required this.title,
    this.topLabel,
    required this.message,
    required this.leadingIcon,
    required this.leadingBackground,
    required this.leadingForeground,
    this.statusIcon,
    this.statusLabel,
    this.statusBackground,
    this.statusForeground,
    required this.sortAt,
  });
}

class _VolunteerInboxData {
  final String docId;
  final String title;
  final String location;
  final int hoursWorth;
  final DateTime when;
  final String? topLabel;
  final bool alreadySignedUp;
  final Map<String, dynamic> raw;

  const _VolunteerInboxData({
    required this.docId,
    required this.title,
    required this.location,
    required this.hoursWorth,
    required this.when,
    required this.topLabel,
    required this.alreadySignedUp,
    required this.raw,
  });
}

// ────────────────────────────────────────────────────────────────────────────
// FILTER PILLS
// ────────────────────────────────────────────────────────────────────────────
class _FilterPillsBar extends StatelessWidget {
  final _InboxFilter current;
  final ValueChanged<_InboxFilter> onChanged;

  const _FilterPillsBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pills = <(_InboxFilter, String)>[
      (_InboxFilter.all, l.inboxFilterAll),
      (_InboxFilter.requests, 'Cereri'),
      (_InboxFilter.announcements, 'Anunțuri'),
      (_InboxFilter.volunteer, 'Voluntariate'),
      (_InboxFilter.tutoring, 'Meditații'),
      (_InboxFilter.competition, 'Competiții'),
      (_InboxFilter.camp, 'Tabere'),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        itemCount: pills.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label) = pills[index];
          final selected = current == filter;
          return GestureDetector(
            onTap: () => onChanged(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected ? _primary : _card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? _primary
                      : const Color(0xFFCAD8E3),
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// VOLUNTEER INBOX TILE — opportunity card with inline "Mă înscriu" button
// ────────────────────────────────────────────────────────────────────────────
class _VolunteerInboxTile extends StatelessWidget {
  final _VolunteerInboxData data;
  final VoidCallback? onSignUp;

  const _VolunteerInboxTile({required this.data, required this.onSignUp});

  String _formatDate(DateTime date) {
    const months = <String>[
      'Ianuarie',
      'Februarie',
      'Martie',
      'Aprilie',
      'Mai',
      'Iunie',
      'Iulie',
      'August',
      'Septembrie',
      'Octombrie',
      'Noiembrie',
      'Decembrie',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = const Color(0xFF1F8BE7);

    return Container(
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.volunteer_activism_rounded,
                            color: accent,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l.inboxVolunteerLabel.toUpperCase(),
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      data.topLabel ?? '',
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  data.title,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    if (data.location.isNotEmpty)
                      _MetaChip(
                        icon: Icons.place_outlined,
                        text: data.location,
                      ),
                    _MetaChip(
                      icon: Icons.calendar_month_rounded,
                      text: _formatDate(data.when),
                    ),
                    if (data.hoursWorth > 0)
                      _MetaChip(
                        icon: Icons.schedule_rounded,
                        text: l.inboxVolunteerHours(data.hoursWorth),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onSignUp,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: onSignUp == null
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1F8BE7), Color(0xFF328FDF)],
                            ),
                      color: onSignUp == null
                          ? const Color(0xFFDEE8F0)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          onSignUp == null
                              ? Icons.check_circle_rounded
                              : Icons.add_rounded,
                          color: onSignUp == null
                              ? accent
                              : Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          onSignUp == null
                              ? l.inboxVolunteerSignedUp
                              : l.inboxVolunteerSignUp,
                          style: TextStyle(
                            color: onSignUp == null
                                ? accent
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _textMuted),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: _textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
