import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_mate/common/link_utils.dart';
import 'package:school_mate/common/storage_image.dart';
import 'package:school_mate/student/bookmarks_service.dart';
import 'package:school_mate/student/meniu.dart';
import 'package:school_mate/student/widgets/no_anim_route.dart';
import 'package:school_mate/student/widgets/school_decor.dart';
import 'package:school_mate/core/session.dart';
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
      // List may not be rendered yet; retry after one frame.
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

    navigator.pushReplacement(noAnimRoute((_) => const MeniuScreen()));
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
          raw: data,
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
          raw: data,
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
          raw: data,
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
          raw: data,
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
      case 'volunteer':
        category = _InboxFilter.volunteer;
        fallbackTitle = 'Volunteering';
        icon = Icons.volunteer_activism_rounded;
        iconBg = const Color(0xFFEDE0F4);
        iconFg = const Color(0xFF7B1FA2);
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
      raw: data,
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

  void _showCardDetailSheet(BuildContext context, _InboxCardData data) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0xCC0A0F2A),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => _InboxCardDetailDialog(data: data),
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
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
          return const _InboxErrorView();
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
              return const _InboxErrorView();
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _secretariatGlobalStream,
              builder: (context, globalSnap) {
                if (globalSnap.hasError) {
                  return const _InboxErrorView();
                }

                return _buildLoadedBody(
                  leaveDocs: snapshot.data!.docs,
                  secretariatDocs:
                      secretariatSnap.data?.docs ?? const [],
                  globalDocs: globalSnap.data?.docs ?? const [],
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
  }) {
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

    // Apply filter
    final List<_InboxCardData> filteredCards = switch (_filter) {
      _InboxFilter.all => cards,
      _InboxFilter.requests =>
          cards.where((c) => c.category == _InboxFilter.requests).toList(),
      _InboxFilter.announcements => cards
          .where((c) => c.category == _InboxFilter.announcements)
          .toList(),
      _InboxFilter.volunteer =>
          cards.where((c) => c.category == _InboxFilter.volunteer).toList(),
      _InboxFilter.competition =>
          cards.where((c) => c.category == _InboxFilter.competition).toList(),
      _InboxFilter.camp =>
          cards.where((c) => c.category == _InboxFilter.camp).toList(),
    };

    final combined = filteredCards
        .map((c) => _InboxRow.card(c))
        .toList()
      ..sort((a, b) => b.sortAt.compareTo(a.sortAt));

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
                  child: const Text(
                    'No messages in this category.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                    onTap: () => _showCardDetailSheet(context, row.card!),
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
  final DateTime sortAt;

  _InboxRow.card(_InboxCardData c)
      : card = c,
        sortAt = c.sortAt;
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
    final topPadding = MediaQuery.of(context).padding.top;

    final pills = <(_InboxFilter, String)>[
      (_InboxFilter.all, 'All'),
      (_InboxFilter.requests, 'Requests'),
      (_InboxFilter.announcements, 'Announcements'),
      (_InboxFilter.volunteer, 'Volunteering'),
      (_InboxFilter.competition, 'Competitions'),
      (_InboxFilter.camp, 'Camps'),
    ];

    return Column(
      children: [
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
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
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: const HeaderSparklesPainter(variant: 2),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 22),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Messages',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 42,
                          height: 3,
                          decoration: BoxDecoration(
                            color: kPencilYellow,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
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
  final VoidCallback? onTap;

  const _InboxRequestTile({
    super.key,
    required this.data,
    this.highlighted = false,
    this.onTap,
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
        if (mounted) {
          _bounceCtrl.forward().then((_) {
            if (mounted) _bounceCtrl.reverse();
          });
        }
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
    final imageUrl =
        (widget.data.raw['imageUrl'] ?? '').toString().trim();
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
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: WhiteCardSparklesPainter(
                              primary: widget.data.leadingForeground,
                              variant: widget.data.docId.hashCode % 5,
                            ),
                          ),
                        ),
                        Padding(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        20,
                        imageUrl.isEmpty ? 18 : 12,
                        20,
                      ),
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
                                    const SizedBox(height: 6),
                                    Container(
                                      width: 36,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: kPencilYellow,
                                        borderRadius: BorderRadius.circular(2),
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
                      ],
                    ),
                  ),
                  if (imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: StorageImage(
                            url: imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (_) => Container(
                              color: widget.data.leadingBackground,
                            ),
                            errorBuilder: (_, _) => Container(
                              color: widget.data.leadingBackground,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: widget.data.leadingForeground,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
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
  final Map<String, dynamic> raw;

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
    this.raw = const <String, dynamic>{},
  });
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


String _formatLongDate(DateTime d) {
  const months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _formatLongDateTime(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${_formatLongDate(d)} · $hh:$mm';
}

String _categoryLabel(_InboxFilter f) {
  switch (f) {
    case _InboxFilter.requests:
      return 'REQUEST';
    case _InboxFilter.announcements:
      return 'ANNOUNCEMENT';
    case _InboxFilter.competition:
      return 'COMPETITION';
    case _InboxFilter.camp:
      return 'CAMP';
    case _InboxFilter.volunteer:
      return 'VOLUNTEERING';
    case _InboxFilter.all:
      return '';
  }
}

Widget _dialogShell({
  required BuildContext context,
  required Color accent,
  required Color accentBg,
  required IconData icon,
  required String categoryText,
  required String title,
  required Widget body,
  Widget? footer,
  Widget? headerAction,
}) {
  final size = MediaQuery.sizeOf(context);
  final maxW = size.width < 460 ? size.width - 32 : 420.0;
  final maxH = size.height * 0.82;

  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 40,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Colored top header
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, _lighten(accent, 0.12)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: const HeaderSparklesPainter(variant: 2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.20,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          icon,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          categoryText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (headerAction != null) ...[
                                    headerAction,
                                    const SizedBox(width: 6),
                                  ],
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
                                    splashRadius: 22,
                                    icon: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 40,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: kPencilYellow,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: body,
                    ),
                  ),
                  if (footer != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: footer,
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

Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final l = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(l).toColor();
}

class _InboxCardDetailDialog extends StatelessWidget {
  final _InboxCardData data;

  const _InboxCardDetailDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final raw = data.raw;
    final eventDate = (raw['eventDate'] as Timestamp?)?.toDate();
    final eventEndDate = (raw['eventEndDate'] as Timestamp?)?.toDate();
    final requestedForDate =
        (raw['requestedForDate'] as Timestamp?)?.toDate();
    final createdAt = (raw['createdAt'] as Timestamp?)?.toDate();
    final requestedAt = (raw['requestedAt'] as Timestamp?)?.toDate();
    final location = (raw['location'] ?? '').toString().trim();
    final link = (raw['link'] ?? '').toString().trim();
    final senderName = (raw['senderName'] ?? '').toString().trim();
    final audienceLabel = (raw['audienceLabel'] ?? '').toString().trim();

    final accent = data.leadingForeground;
    final imageUrl = (raw['imageUrl'] ?? '').toString().trim();
    final isRequest = data.category == _InboxFilter.requests;
    final bookmarkCategory = switch (data.category) {
      _InboxFilter.competition => 'competition',
      _InboxFilter.camp => 'camp',
      _InboxFilter.volunteer => 'volunteer',
      _InboxFilter.announcements => 'announcement',
      _ => '',
    };

    return _dialogShell(
      context: context,
      accent: accent,
      accentBg: data.leadingBackground,
      icon: data.leadingIcon,
      categoryText: _categoryLabel(data.category),
      title: data.title,
      headerAction: (isRequest || bookmarkCategory.isEmpty)
          ? null
          : _BookmarkToggleButton(
              itemId: data.docId,
              itemType: 'post',
              category: bookmarkCategory,
              title: data.title,
              message: data.message,
              link: link,
              senderName: senderName,
              location: location,
              imageUrl: imageUrl,
              eventDate: eventDate,
              eventEndDate: eventEndDate,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: StorageImage(
                    url: imageUrl,
                    fit: BoxFit.scaleDown,
                    loadingBuilder: (_) => Container(
                      width: 280,
                      height: 180,
                      color: cs.outlineVariant,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                    errorBuilder: (_, _) => Container(
                      width: 280,
                      height: 160,
                      color: cs.outlineVariant,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: _textMuted,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (eventDate != null ||
              requestedForDate != null ||
              location.isNotEmpty) ...[
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                if (eventDate != null)
                  _MetaChip(
                    icon: Icons.calendar_month_rounded,
                    text: eventEndDate != null
                        ? '${_formatLongDate(eventDate)} → ${_formatLongDate(eventEndDate)}'
                        : _formatLongDate(eventDate),
                  ),
                if (requestedForDate != null)
                  _MetaChip(
                    icon: Icons.event_rounded,
                    text: _formatLongDate(requestedForDate),
                  ),
                if (location.isNotEmpty)
                  _MetaChip(
                    icon: Icons.place_outlined,
                    text: location,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Text(
            data.message,
            style: const TextStyle(
              color: _textDark,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
          if (link.isNotEmpty) ...[
            const SizedBox(height: 14),
            _DetailLinkBlock(link: link, accent: accent),
          ],
          const SizedBox(height: 14),
          _DetailFooterMeta(
            senderName: senderName,
            audienceLabel: audienceLabel,
            sentAt: createdAt ?? requestedAt,
            statusLabel: data.statusLabel,
            statusIcon: data.statusIcon,
            statusBackground: data.statusBackground,
            statusForeground: data.statusForeground,
            isRequest: data.category == _InboxFilter.requests,
          ),
        ],
      ),
    );
  }
}

class _DetailLinkBlock extends StatelessWidget {
  final String link;
  final Color accent;

  const _DetailLinkBlock({required this.link, required this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => launchExternalUrl(context, link),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.link_rounded, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  link,
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    decoration: TextDecoration.underline,
                    decorationColor: accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new_rounded, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailFooterMeta extends StatelessWidget {
  final String senderName;
  final String audienceLabel;
  final DateTime? sentAt;
  final String? statusLabel;
  final IconData? statusIcon;
  final Color? statusBackground;
  final Color? statusForeground;
  final bool isRequest;

  const _DetailFooterMeta({
    required this.senderName,
    required this.audienceLabel,
    required this.sentAt,
    required this.statusLabel,
    required this.statusIcon,
    required this.statusBackground,
    required this.statusForeground,
    required this.isRequest,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = <Widget>[];

    if (senderName.isNotEmpty) {
      rows.add(
        _FooterRow(
          icon: Icons.person_outline_rounded,
          text: senderName,
        ),
      );
    }
    if (audienceLabel.isNotEmpty) {
      rows.add(
        _FooterRow(
          icon: Icons.groups_2_outlined,
          text: audienceLabel,
        ),
      );
    }
    if (sentAt != null) {
      rows.add(
        _FooterRow(
          icon: Icons.access_time_rounded,
          text: _formatLongDateTime(sentAt!),
        ),
      );
    }
    if (isRequest && statusLabel != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusBackground ?? const Color(0xFFDDE0EC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (statusIcon != null)
                  Icon(
                    statusIcon,
                    size: 15,
                    color: statusForeground ?? _primary,
                  ),
                const SizedBox(width: 6),
                Text(
                  statusLabel!,
                  style: TextStyle(
                    color: statusForeground ?? _primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _BookmarkToggleButton extends StatelessWidget {
  final String itemId;
  final String itemType;
  final String category;
  final String title;
  final String message;
  final String link;
  final String senderName;
  final String location;
  final String imageUrl;
  final DateTime? eventDate;
  final DateTime? eventEndDate;

  const _BookmarkToggleButton({
    required this.itemId,
    required this.itemType,
    required this.category,
    required this.title,
    this.message = '',
    this.link = '',
    this.senderName = '',
    this.location = '',
    this.imageUrl = '',
    this.eventDate,
    this.eventEndDate,
  });

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: BookmarksService.isBookmarked(uid, itemId),
      builder: (context, snap) {
        final bookmarked = snap.data ?? false;
        return IconButton(
          onPressed: () async {
            if (bookmarked) {
              await BookmarksService.remove(uid: uid, itemId: itemId);
            } else {
              await BookmarksService.add(
                uid: uid,
                itemId: itemId,
                itemType: itemType,
                category: category,
                title: title,
                message: message,
                link: link,
                senderName: senderName,
                location: location,
                imageUrl: imageUrl,
                eventDate: eventDate,
                eventEndDate: eventEndDate,
              );
            }
          },
          splashRadius: 22,
          tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: bookmarked ? kPencilYellow : Colors.white,
              size: 18,
            ),
          ),
        );
      },
    );
  }
}

class _FooterRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FooterRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _textDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _InboxErrorView extends StatelessWidget {
  const _InboxErrorView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.cloud_off_rounded, size: 48, color: _textMuted),
            SizedBox(height: 12),
            Text(
              'Could not load messages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
