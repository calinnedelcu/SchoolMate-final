import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firster/l10n/app_localizations.dart';
import 'package:firster/student/meniu.dart';
import 'package:firster/core/session.dart';
import 'package:flutter/material.dart';

enum _InboxFilter {
  all,
  requests,
  announcements,
  volunteer,
  competition,
  camp,
}

const String _kAudienceAll = '__ALL__';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _card = Color(0xFFFFFFFF);
const _textDark = Color(0xFF1A2050);
const _textMuted = Color(0xFF7A7E9A);

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

  String _formatRequestDate(DateTime? date) {
    if (date == null) return '--';
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatRequestTitle(DateTime? date) {
    if (date == null) return 'Leave request';
    final dateStr = _formatRequestDate(date);
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return 'Leave request - $dateStr, $hh:$mm';
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
    if (diff == 1) return 'Yesterday';
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
          message: message.isEmpty ? 'Request has been approved.' : message,
          leadingIcon: Icons.description_rounded,
          leadingBackground: const Color(0xFFDDE0EC),
          leadingForeground: _primary,
          statusIcon: Icons.check_circle_rounded,
          statusLabel: 'Approved',
          statusBackground: const Color(0xFFDDE0EC),
          statusForeground: _primary,
          sortAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      case 'rejected':
        return _InboxCardData(
          docId: doc.id,
          category: _InboxFilter.requests,
          title: _formatRequestTitle(requestedForDate),
          topLabel: _formatSentLabel(requestedAt),
          message: message.isEmpty ? 'Request has been rejected.' : message,
          leadingIcon: Icons.description_rounded,
          leadingBackground: const Color(0xFFF0D0D8),
          leadingForeground: const Color(0xFFB03040),
          statusIcon: Icons.cancel_rounded,
          statusLabel: 'Rejected',
          statusBackground: const Color(0xFFF0D0D8),
          statusForeground: const Color(0xFFB03040),
          sortAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      case 'expired':
        return _InboxCardData(
          docId: doc.id,
          category: _InboxFilter.requests,
          title: _formatRequestTitle(requestedForDate),
          topLabel: _formatSentLabel(requestedAt),
          message: message.isEmpty ? 'Request has expired automatically.' : message,
          leadingIcon: Icons.history_toggle_off_rounded,
          leadingBackground: const Color(0xFFF2EEDC),
          leadingForeground: const Color(0xFF8A6A1D),
          statusIcon: Icons.hourglass_bottom_rounded,
          statusLabel: 'Expired',
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
              ? 'Request is pending approval.'
              : message,
          leadingIcon: Icons.history_rounded,
          leadingBackground: const Color(0xFFDDE0EC),
          leadingForeground: const Color(0xFF7A7E9A),
          statusIcon: Icons.watch_later_rounded,
          statusLabel: 'Pending',
          statusBackground: const Color(0xFFDDE0EC),
          statusForeground: const Color(0xFF7A7E9A),
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
        fallbackTitle = 'Competition';
        icon = Icons.emoji_events_rounded;
        iconBg = const Color(0xFFFFF3D6);
        iconFg = const Color(0xFFCC8A1A);
        break;
      case 'camp':
        category = _InboxFilter.camp;
        fallbackTitle = 'Camp';
        icon = Icons.forest_rounded;
        iconBg = const Color(0xFFD9EFD8);
        iconFg = const Color(0xFF3F8B3A);
        break;
      case 'announcement':
        category = _InboxFilter.announcements;
        fallbackTitle = 'School announcement';
        icon = Icons.campaign_rounded;
        iconBg = const Color(0xFFDDE0EC);
        iconFg = const Color(0xFF3460CC);
        break;
      default:
        category = fallbackCategory;
        fallbackTitle = 'Office message';
        icon = Icons.campaign_rounded;
        iconBg = const Color(0xFFDDE0EC);
        iconFg = const Color(0xFF3460CC);
    }

    return _InboxCardData(
      docId: doc.id,
      category: category,
      title: docTitle.isEmpty ? fallbackTitle : docTitle,
      topLabel: _formatSentLabel(createdAt),
      message: message.isEmpty ? 'You have a new message.' : message,
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
              filter: _filter,
              onFilterChanged: (f) => setState(() => _filter = f),
            ),
            Expanded(child: _buildInboxBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxBody() {
    if (_leaveStream == null) {
      return const Center(child: Text('Invalid session.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _leaveStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
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
              return Center(child: Text('Error: ${secretariatSnap.error}'));
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _secretariatGlobalStream,
              builder: (context, globalSnap) {
                if (globalSnap.hasError) {
                  return Center(child: Text('Error: ${globalSnap.error}'));
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
    }

    // Combine into a single chronologically sorted list
    final combined = <_InboxRow>[
      ...filteredCards.map((c) => _InboxRow.card(c)),
      ...filteredVolunteer.map((v) => _InboxRow.volunteer(v)),
    ]..sort((a, b) => b.sortAt.compareTo(a.sortAt));

    final horizontalPadding =
        MediaQuery.sizeOf(context).width < 390 ? 14.0 : 18.0;

    return ListView(
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
                    l.inboxEmpty,
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

class _InboxHeader extends StatefulWidget {
  final VoidCallback onBack;
  final _InboxFilter filter;
  final ValueChanged<_InboxFilter> onFilterChanged;

  const _InboxHeader({
    required this.onBack,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  State<_InboxHeader> createState() => _InboxHeaderState();
}

class _InboxHeaderState extends State<_InboxHeader> {
  final ScrollController _pillsScroll = ScrollController();
  double _scrollFraction = 0;

  @override
  void initState() {
    super.initState();
    _pillsScroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pillsScroll.removeListener(_onScroll);
    _pillsScroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final sc = _pillsScroll;
    if (!sc.hasClients || sc.position.maxScrollExtent <= 0) return;
    final f = (sc.offset / sc.position.maxScrollExtent).clamp(0.0, 1.0);
    if ((f - _scrollFraction).abs() > 0.005) {
      setState(() => _scrollFraction = f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    final pills = <(_InboxFilter, String)>[
      (_InboxFilter.all, l.inboxFilterAll),
      (_InboxFilter.requests, 'Requests'),
      (_InboxFilter.announcements, 'Announcements'),
      (_InboxFilter.volunteer, 'Volunteering'),
      (_InboxFilter.competition, 'Competitions'),
      (_InboxFilter.camp, 'Camps'),
    ];

    return Column(
      children: [
        // Gradient header — same as other pages
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 22),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3CA0), Color(0xFF2E58D0), Color(0xFF4070E0)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x302848B0),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                l.inboxTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        // Description on background
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text(
            'Manage your activities, requests and announcements.',
            style: TextStyle(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
        // Filter pills
        SingleChildScrollView(
          controller: _pillsScroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              for (int i = 0; i < pills.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => widget.onFilterChanged(pills[i].$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.filter == pills[i].$1 ? _primary : _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: widget.filter == pills[i].$1 ? _primary : const Color(0xFFCDD1DE),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      pills[i].$2,
                      style: TextStyle(
                        color: widget.filter == pills[i].$1 ? Colors.white : _textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Scroll position indicator
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 2, 24, 6),
          child: Row(
            children: [
              Icon(Icons.chevron_left_rounded, color: _textMuted.withValues(alpha: 0.35), size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const thumbRatio = 0.35;
                    final trackW = constraints.maxWidth;
                    final thumbW = trackW * thumbRatio;
                    final travel = trackW - thumbW;
                    final offset = travel * _scrollFraction;
                    return Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8DAE2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: offset,
                            child: Container(
                              width: thumbW,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9498AA),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: _textMuted.withValues(alpha: 0.35), size: 16),
            ],
          ),
        ),
      ],
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
                                          ? 'Leave request'
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
// VOLUNTEER INBOX TILE — opportunity card with inline "Mă înscriu" button
// ────────────────────────────────────────────────────────────────────────────
class _VolunteerInboxTile extends StatelessWidget {
  final _VolunteerInboxData data;
  final VoidCallback? onSignUp;

  const _VolunteerInboxTile({required this.data, required this.onSignUp});

  String _formatDate(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = const Color(0xFF2848B0);

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
                              colors: [Color(0xFF2848B0), Color(0xFF3460CC)],
                            ),
                      color: onSignUp == null
                          ? const Color(0xFFDDE0EC)
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
