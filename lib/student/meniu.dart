import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/core/session.dart';
import 'package:firster/l10n/app_localizations.dart';
import 'package:firster/student/cereri.dart';
import 'package:firster/student/inbox.dart';
import 'package:firster/student/widgets/qr_bottom_sheet.dart';
import 'package:flutter/material.dart';

class _DampedScrollPhysics extends ScrollPhysics {
  const _DampedScrollPhysics({super.parent});
  @override
  _DampedScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _DampedScrollPhysics(parent: buildParent(ancestor));
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, offset) * 0.55;
}

const _primary = Color(0xFF1F8BE7);
const _surface = Color(0xFFEFF5FA);
const _surfaceContainerLow = Color(0xFFE7F0F6);
const _surfaceContainerHigh = Color(0xFFDEE8F0);
const _surfaceLowest = Color(0xFFFFFFFF);
const _outline = Color(0xFF717B6E);
const _outlineVariant = Color(0xFFBACCD9);
const _onSurface = Color(0xFF587F9E);

class MeniuScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final void Function(String docId)? onNavigateToActiveLeave;

  const MeniuScreen({
    super.key,
    this.onNavigateTab,
    this.onNavigateToActiveLeave,
  });

  @override
  State<MeniuScreen> createState() => _MeniuScreenState();
}

class _MeniuScreenState extends State<MeniuScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _leaveActiveStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _classDocStream;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots();

    _leaveActiveStream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', isEqualTo: currentUser.uid)
        .where('status', whereIn: ['approved', 'active', 'pending'])
        .snapshots();

    final classId = AppSession.classId;
    if (classId != null && classId.isNotEmpty) {
      _classDocStream = FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .snapshots();
    }
  }

  /// Returns parsed schedule for today: {start, end} as minutes-of-day, or null.
  ({int startMin, int endMin, String startText, String endText})?
  _todaySchedule(Map<String, dynamic> classData) {
    final now = DateTime.now();
    final weekday = now.weekday;
    if (weekday > 5) return null;

    final schedule = (classData['schedule'] as Map?) ?? {};
    final daySchedule = schedule[weekday.toString()] as Map?;
    if (daySchedule == null) return null;

    int parseMinutes(String value) {
      final parts = value.split(':');
      if (parts.length != 2) return -1;
      final hour = int.tryParse(parts[0]) ?? -1;
      final minute = int.tryParse(parts[1]) ?? -1;
      if (hour < 0 || minute < 0) return -1;
      return hour * 60 + minute;
    }

    final startText = (daySchedule['start'] ?? '').toString();
    final endText = (daySchedule['end'] ?? '').toString();
    final startMin = parseMinutes(startText);
    final endMin = parseMinutes(endText);
    if (startMin < 0 || endMin < 0) return null;
    return (
      startMin: startMin,
      endMin: endMin,
      startText: startText,
      endText: endText,
    );
  }

  String _formatClassLabel(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return 'Clasa nealocata';
    }

    final normalized = trimmed
        .replaceFirst(RegExp(r'^clasa\s+', caseSensitive: false), '')
        .trim();
    final compact = normalized.replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(r'^(\d{1,2})([A-Za-z])$').firstMatch(compact);
    if (match == null) {
      return trimmed;
    }

    final grade = match.group(1)!;
    final letter = match.group(2)!.toUpperCase();
    return 'Clasa a $grade-a $letter';
  }

  void _openCereri() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(2);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CereriScreen()));
  }

  Future<void> _openInbox() async {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(3);
      return;
    }

    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'inboxLastOpenedAt': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      }, SetOptions(merge: true));
    }

    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const InboxScreen()));
  }

  void _openSchedule() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
    }
  }

  Future<void> _showQrSheet(BuildContext context) async {
    await showQrSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final fallbackName = (AppSession.username?.trim().isNotEmpty ?? false)
        ? AppSession.username!.trim()
        : 'Elev';

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userDocStream,
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final fullName = (data['fullName'] ?? '').toString().trim();
            final resolvedName = fullName.isNotEmpty ? fullName : fallbackName;
            final classId = (data['classId'] ?? AppSession.classId ?? '')
                .toString()
                .trim();
            final className = (data['className'] ?? '').toString().trim();
            final inboxLastOpenedAt = (data['inboxLastOpenedAt'] as Timestamp?)
                ?.toDate();
            final classStream = classId.isNotEmpty
                ? FirebaseFirestore.instance
                      .collection('classes')
                      .doc(classId)
                      .snapshots()
                : _classDocStream;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: classStream,
              builder: (context, classSnapshot) {
                final classData =
                    classSnapshot.data?.data() ?? const <String, dynamic>{};
                final classDocName = (classData['name'] ?? '')
                    .toString()
                    .trim();
                final rawClassName = className.isNotEmpty
                    ? className
                    : (classDocName.isNotEmpty
                          ? classDocName
                          : (classId.isNotEmpty ? classId : 'Clasa nealocata'));
                final resolvedClassName = _formatClassLabel(rawClassName);
                final todaySchedule = _todaySchedule(classData);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: _surface),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _TopHeroHeader(
                        displayName: resolvedName,
                        className: resolvedClassName,
                      ),
                    ),
                    Positioned(
                      top: 190.0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SingleChildScrollView(
                        physics: const _DampedScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          children: [
                            _AziCard(
                              schedule: todaySchedule,
                              onViewSchedule: _openSchedule,
                            ),
                            const SizedBox(height: 14),
                            _CerereInvoireCard(
                              leaveStream: _leaveActiveStream,
                              onCreateNew: _openCereri,
                              onShowQr: () => _showQrSheet(context),
                              onPendingTap: widget.onNavigateToActiveLeave,
                            ),
                            const SizedBox(height: 14),
                            _InboxPreviewCard(
                              studentUid:
                                  FirebaseAuth.instance.currentUser?.uid ?? '',
                              inboxLastOpenedAt: inboxLastOpenedAt,
                              onTap: _openInbox,
                            ),
                            const SizedBox(height: 14),
                            _QuickActionsRow(
                              onSchedule: _openSchedule,
                              onMessages: _openInbox,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HEADER
// ────────────────────────────────────────────────────────────────────────────
class _TopHeroHeader extends StatelessWidget {
  final String displayName;
  final String className;

  const _TopHeroHeader({required this.displayName, required this.className});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final l = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(52),
        bottomRight: Radius.circular(52),
      ),
      child: Container(
        height: 220 + topPadding,
        color: _primary,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -80,
              top: -90,
              child: _Circle(size: 290, opacity: 0.08),
            ),
            Positioned(
              right: 38,
              top: 54,
              child: _Circle(size: 78, opacity: 0.07),
            ),
            Positioned(
              left: -60,
              bottom: -44,
              child: _Circle(size: 186, opacity: 0.08),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(28, 8 + topPadding, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.homeGreeting(displayName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            height: 1.20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          className,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
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

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Circle({required this.size, required this.opacity});

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

// ────────────────────────────────────────────────────────────────────────────
// AZI CARD
// ────────────────────────────────────────────────────────────────────────────
class _AziCard extends StatelessWidget {
  final ({int startMin, int endMin, String startText, String endText})?
  schedule;
  final VoidCallback onViewSchedule;

  const _AziCard({required this.schedule, required this.onViewSchedule});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final dateText = MaterialLocalizations.of(
      context,
    ).formatFullDate(now).replaceAll(', ${now.year}', '');

    String statusText;
    Color statusColor;
    IconData statusIcon;
    String? intervalText;

    if (schedule == null) {
      statusText = l.homeTodayNoSchedule;
      statusColor = _outline;
      statusIcon = Icons.event_busy_rounded;
    } else {
      final nowMin = now.hour * 60 + now.minute;
      intervalText = l.homeTodayInterval(schedule!.startText, schedule!.endText);
      if (nowMin < schedule!.startMin) {
        statusText = l.homeTodayUpcoming(schedule!.startText);
        statusColor = _primary;
        statusIcon = Icons.access_time_rounded;
      } else if (nowMin <= schedule!.endMin) {
        statusText = l.homeTodayInProgress;
        statusColor = _primary;
        statusIcon = Icons.school_rounded;
      } else {
        statusText = l.homeTodayFinished;
        statusColor = _outline;
        statusIcon = Icons.check_circle_outline_rounded;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141F8BE7),
            blurRadius: 22,
            offset: Offset(0, 10),
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
                  color: _primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.today_rounded,
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
                      l.homeTodayCardTitle,
                      style: const TextStyle(
                        color: _outline,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _capitalize(dateText),
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (intervalText != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                intervalText,
                style: TextStyle(
                  color: _outline.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onViewSchedule,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_view_week_rounded,
                    color: _primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.homeTodayViewFull,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _outline,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// CERERE DE ÎNVOIRE CARD
// ────────────────────────────────────────────────────────────────────────────
class _CerereInvoireCard extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? leaveStream;
  final VoidCallback onCreateNew;
  final VoidCallback onShowQr;
  final void Function(String docId)? onPendingTap;

  const _CerereInvoireCard({
    required this.leaveStream,
    required this.onCreateNew,
    required this.onShowQr,
    required this.onPendingTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: leaveStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);

        bool isExpired(Map<String, dynamic> data) {
          final forDate = (data['requestedForDate'] as Timestamp?)?.toDate();
          if (forDate == null) return false;
          return forDate.isBefore(todayMidnight);
        }

        QueryDocumentSnapshot<Map<String, dynamic>>? activeDoc;
        QueryDocumentSnapshot<Map<String, dynamic>>? pendingDoc;
        for (final d in docs) {
          final data = d.data();
          if (isExpired(data)) continue;
          final status = data['status'];
          if (status == 'approved' || status == 'active') {
            activeDoc ??= d;
          } else if (status == 'pending') {
            pendingDoc ??= d;
          }
        }

        if (activeDoc != null) {
          return _LeaveCardShell(
            chipText: l.homeRequestActiveChip,
            chipColor: _primary,
            iconColor: _primary,
            backgroundColor: _surfaceLowest,
            iconBackground: _primary.withValues(alpha: 0.10),
            title: l.homeRequestCardTitle,
            subtitle: l.homeRequestActiveSubtitle,
            buttonLabel: l.homeRequestActiveCta,
            buttonIcon: Icons.qr_code_2_rounded,
            buttonGradient: const [Color(0xFF1F8BE7), Color(0xFF328FDF)],
            buttonForeground: Colors.white,
            onButton: onShowQr,
            onCardTap: onPendingTap == null
                ? null
                : () => onPendingTap!(activeDoc!.id),
          );
        }

        if (pendingDoc != null) {
          return _LeaveCardShell(
            chipText: l.homeRequestPendingChip,
            chipColor: const Color(0xFF8A6A1D),
            iconColor: const Color(0xFF8A6A1D),
            backgroundColor: _surfaceLowest,
            iconBackground: const Color(0xFFF6F0D9),
            title: l.homeRequestCardTitle,
            subtitle: l.homeRequestPendingSubtitle,
            buttonLabel: null,
            buttonIcon: null,
            buttonGradient: null,
            buttonForeground: null,
            onButton: null,
            onCardTap: onPendingTap == null
                ? null
                : () => onPendingTap!(pendingDoc!.id),
          );
        }

        return _LeaveCardShell(
          chipText: null,
          chipColor: _outline,
          iconColor: _primary,
          backgroundColor: _surfaceLowest,
          iconBackground: _primary.withValues(alpha: 0.10),
          title: l.homeRequestCardTitle,
          subtitle: l.homeRequestNoneSubtitle,
          buttonLabel: l.homeRequestNoneCta,
          buttonIcon: Icons.add_rounded,
          buttonGradient: const [Color(0xFF1F8BE7), Color(0xFF328FDF)],
          buttonForeground: Colors.white,
          onButton: onCreateNew,
          onCardTap: null,
        );
      },
    );
  }
}

class _LeaveCardShell extends StatelessWidget {
  final String? chipText;
  final Color chipColor;
  final Color iconColor;
  final Color iconBackground;
  final Color backgroundColor;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final IconData? buttonIcon;
  final List<Color>? buttonGradient;
  final Color? buttonForeground;
  final VoidCallback? onButton;
  final VoidCallback? onCardTap;

  const _LeaveCardShell({
    required this.chipText,
    required this.chipColor,
    required this.iconColor,
    required this.iconBackground,
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.buttonGradient,
    required this.buttonForeground,
    required this.onButton,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.36)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: iconColor,
                  size: 24,
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _outline.withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (chipText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chipText!.toUpperCase(),
                    style: TextStyle(
                      color: chipColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          if (buttonLabel != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onButton,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: buttonGradient == null
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: buttonGradient!,
                        ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x351F8BE7),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (buttonIcon != null) ...[
                      Icon(buttonIcon, color: buttonForeground, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      buttonLabel!,
                      style: TextStyle(
                        color: buttonForeground,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onCardTap != null && buttonLabel == null) {
      return GestureDetector(onTap: onCardTap, child: card);
    }
    return card;
  }
}



// ────────────────────────────────────────────────────────────────────────────
// INBOX PREVIEW CARD
// ────────────────────────────────────────────────────────────────────────────
class _InboxPreviewCard extends StatelessWidget {
  final String studentUid;
  final DateTime? inboxLastOpenedAt;
  final VoidCallback onTap;

  const _InboxPreviewCard({
    required this.studentUid,
    required this.inboxLastOpenedAt,
    required this.onTap,
  });

  DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isVisibleLeaveMessage(Map<String, dynamic> data) {
    final source = (data['source'] ?? '').toString().trim();
    return source != 'secretariat';
  }

  DateTime? _leaveMessageTime(Map<String, dynamic> data) {
    return _readDateTime(data['reviewedAt']) ??
        _readDateTime(data['requestedAt']);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: studentUid.isEmpty
            ? null
            : FirebaseFirestore.instance
                  .collection('leaveRequests')
                  .where('studentUid', isEqualTo: studentUid)
                  .orderBy('requestedAt', descending: true)
                  .limit(20)
                  .snapshots(),
        builder: (context, leaveSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: studentUid.isEmpty
                ? null
                : FirebaseFirestore.instance
                      .collection('secretariatMessages')
                      .where('recipientUid', isEqualTo: studentUid)
                      .where('recipientRole', isEqualTo: 'student')
                      .limit(20)
                      .snapshots(),
            builder: (context, secretariatSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: studentUid.isEmpty
                    ? null
                    : FirebaseFirestore.instance
                          .collection('secretariatMessages')
                          .where('recipientUid', isEqualTo: '')
                          .where('recipientRole', isEqualTo: 'student')
                          .limit(20)
                          .snapshots(),
                builder: (context, globalSnapshot) {
                  final leaveDocs = leaveSnapshot.data?.docs ?? const [];
                  final secretariatDocs =
                      secretariatSnapshot.data?.docs ?? const [];
                  final globalDocs = globalSnapshot.data?.docs ?? const [];

                  // Build a unified list of preview entries
                  final entries = <_PreviewEntry>[];
                  for (final doc in leaveDocs) {
                    final data = doc.data();
                    if (!_isVisibleLeaveMessage(data)) continue;
                    final when = _leaveMessageTime(data);
                    if (when == null) continue;
                    final status = (data['status'] ?? 'pending').toString();
                    final message = (data['message'] ?? '').toString().trim();
                    entries.add(
                      _PreviewEntry(
                        when: when,
                        title: 'Cerere învoire',
                        snippet: message.isEmpty
                            ? _leaveStatusSnippet(status)
                            : message,
                        icon: Icons.description_rounded,
                      ),
                    );
                  }
                  for (final doc in [...secretariatDocs, ...globalDocs]) {
                    final data = doc.data();
                    final when = _readDateTime(data['createdAt']);
                    if (when == null) continue;
                    final message = (data['message'] ?? '').toString().trim();
                    final senderName =
                        (data['senderName'] ?? 'Secretariat')
                            .toString()
                            .trim();
                    entries.add(
                      _PreviewEntry(
                        when: when,
                        title: senderName.isEmpty ? 'Secretariat' : senderName,
                        snippet: message,
                        icon: Icons.campaign_rounded,
                      ),
                    );
                  }

                  entries.sort((a, b) => b.when.compareTo(a.when));

                  int unread;
                  if (inboxLastOpenedAt == null) {
                    unread = entries.length;
                  } else {
                    unread = entries
                        .where((e) => e.when.isAfter(inboxLastOpenedAt!))
                        .length;
                  }

                  final preview = entries.take(2).toList();

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      color: _surfaceLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _outlineVariant.withValues(alpha: 0.36),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F000000),
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
                                color: _primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.forum_rounded,
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
                                    l.homeInboxPreviewTitle,
                                    style: const TextStyle(
                                      color: _onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    unread == 0
                                        ? l.homeInboxNoMessages
                                        : l.homeInboxUnreadCount(unread),
                                    style: TextStyle(
                                      color: unread > 0
                                          ? _primary
                                          : _outline.withValues(alpha: 0.95),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
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
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          for (var i = 0; i < preview.length; i++) ...[
                            _PreviewLine(entry: preview[i]),
                            if (i < preview.length - 1)
                              const SizedBox(height: 8),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _leaveStatusSnippet(String status) {
    switch (status) {
      case 'approved':
        return 'Cererea ta a fost aprobată.';
      case 'rejected':
        return 'Cererea ta a fost respinsă.';
      case 'expired':
        return 'Cererea a expirat.';
      default:
        return 'Cererea este în așteptare.';
    }
  }
}

class _PreviewEntry {
  final DateTime when;
  final String title;
  final String snippet;
  final IconData icon;

  const _PreviewEntry({
    required this.when,
    required this.title,
    required this.snippet,
    required this.icon,
  });
}

class _PreviewLine extends StatelessWidget {
  final _PreviewEntry entry;
  const _PreviewLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          entry.icon,
          color: _outline.withValues(alpha: 0.7),
          size: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(
                color: _onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(
                  text: '${entry.title}: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: entry.snippet.isEmpty
                      ? '—'
                      : entry.snippet,
                  style: TextStyle(
                    color: _outline.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS ROW
// ────────────────────────────────────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onSchedule;
  final VoidCallback onMessages;

  const _QuickActionsRow({
    required this.onSchedule,
    required this.onMessages,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            l.homeQuickActionsTitle.toUpperCase(),
            style: TextStyle(
              color: _outline.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _QuickActionTile(
                icon: Icons.calendar_view_week_rounded,
                label: l.homeQuickActionSchedule,
                onTap: onSchedule,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.forum_rounded,
                label: l.homeQuickActionMessages,
                onTap: onMessages,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outlineVariant.withValues(alpha: 0.36)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _primary, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
