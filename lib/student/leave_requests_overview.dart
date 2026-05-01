import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';
import 'cereri.dart';
import 'meniu.dart';
import 'widgets/no_anim_route.dart';
import 'widgets/school_decor.dart';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _card = Color(0xFFFFFFFF);
const _cardMuted = Color(0xFFE8EAF2);
const _textDark = Color(0xFF1A2050);
const _textMid = Color(0xFF3A4A80);
const _textMuted = Color(0xFF7A7E9A);

class LeaveRequestsOverviewScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const LeaveRequestsOverviewScreen({super.key, this.onNavigateTab});

  @override
  State<LeaveRequestsOverviewScreen> createState() =>
      _LeaveRequestsOverviewScreenState();
}

class _LeaveRequestsOverviewScreenState
    extends State<LeaveRequestsOverviewScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _requestsStream;

  @override
  void initState() {
    super.initState();
    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      _requestsStream = FirebaseFirestore.instance
          .collection('leaveRequests')
          .where('studentUid', isEqualTo: uid)
          .orderBy('requestedAt', descending: true)
          .limit(60)
          .snapshots();
    }
  }

  void _goBack() {
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

  void _openCreateForm() {
    Navigator.of(context).push(noAnimRoute((_) => const CereriScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          top: false,
          bottom: false,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _requestsStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              final items = _dedupeAndSort(docs);

              int approved = 0, pending = 0, rejected = 0;
              for (final it in items) {
                switch (it.status) {
                  case 'approved':
                  case 'active':
                    approved++;
                    break;
                  case 'rejected':
                    rejected++;
                    break;
                  case 'pending':
                    pending++;
                    break;
                }
              }
              final total = items.length;

              return Column(
                children: [
                  _Header(
                    total: total,
                    pending: pending,
                    onBack: _goBack,
                    onCreate: _openCreateForm,
                  ),
                  Expanded(
                    child: _requestsStream == null
                        ? const Center(
                            child: Text(
                              'You need to be logged in to view your requests.',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : !snapshot.hasData
                            ? const Center(
                                child: CircularProgressIndicator(color: _primary),
                              )
                            : ListView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                                children: [
                                  _CreateButton(onTap: _openCreateForm),
                                  const SizedBox(height: 18),
                                  _StatsRow(
                                    approved: approved,
                                    pending: pending,
                                    rejected: rejected,
                                  ),
                                  const SizedBox(height: 22),
                                  if (items.isNotEmpty) ...[
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4, bottom: 12),
                                      child: Text(
                                        'HISTORY',
                                        style: TextStyle(
                                          color: _textMuted,
                                          fontSize: 12,
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    for (int i = 0; i < items.length; i++) ...[
                                      _RequestCard(item: items[i]),
                                      if (i != items.length - 1)
                                        const SizedBox(height: 12),
                                    ],
                                  ] else
                                    _EmptyState(onCreate: _openCreateForm),
                                ],
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_RequestItem> _dedupeAndSort(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final byKey = <String, _RequestItem>{};
    for (final d in docs) {
      final data = d.data();
      final dateText = (data['dateText'] ?? '').toString();
      final timeText = (data['timeText'] ?? '').toString();
      final message = (data['message'] ?? '').toString();
      final ts = (data['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final key = '$dateText|$timeText|$message|$ts';

      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = _RequestItem.fromData(d.id, data);
      } else {
        byKey[key] = existing.merge(_RequestItem.fromData(d.id, data));
      }
    }
    final list = byKey.values.toList()
      ..sort((a, b) => b.requestedAtMs.compareTo(a.requestedAtMs));
    return list;
  }
}

class _RequestItem {
  final String id;
  final String dateText;
  final String timeText;
  final String message;
  final String status;
  final String reviewedByName;
  final String reviewedByRole;
  final DateTime? requestedForDate;
  final int requestedAtMs;

  const _RequestItem({
    required this.id,
    required this.dateText,
    required this.timeText,
    required this.message,
    required this.status,
    required this.reviewedByName,
    required this.reviewedByRole,
    required this.requestedForDate,
    required this.requestedAtMs,
  });

  factory _RequestItem.fromData(String id, Map<String, dynamic> data) {
    final reviewedByUid = (data['reviewedByUid'] ?? '').toString().trim();
    final teacherUid = (data['targetTeacherUid'] ?? '').toString().trim();
    final parentUid = (data['targetParentUid'] ?? '').toString().trim();
    String role = '';
    if (reviewedByUid.isNotEmpty) {
      if (reviewedByUid == teacherUid) {
        role = 'teacher';
      } else if (reviewedByUid == parentUid) {
        role = 'parent';
      }
    }
    if (role.isEmpty) {
      // Legacy single-recipient docs: derive from targetRole.
      role = (data['targetRole'] ?? '').toString().trim();
    }
    return _RequestItem(
      id: id,
      dateText: (data['dateText'] ?? '').toString(),
      timeText: (data['timeText'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      reviewedByName: (data['reviewedByName'] ?? '').toString(),
      reviewedByRole: role,
      requestedForDate: (data['requestedForDate'] as Timestamp?)?.toDate(),
      requestedAtMs:
          (data['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
    );
  }

  // Prefer the most informative status when merging duplicate target rows
  // (one request might be sent to both teacher and parent).
  _RequestItem merge(_RequestItem other) {
    const priority = {
      'approved': 4,
      'active': 4,
      'rejected': 3,
      'pending': 2,
      '': 1,
    };
    final mineP = priority[status] ?? 0;
    final otherP = priority[other.status] ?? 0;
    final winner = otherP > mineP ? other : this;
    return _RequestItem(
      id: winner.id,
      dateText: dateText.isNotEmpty ? dateText : other.dateText,
      timeText: timeText.isNotEmpty ? timeText : other.timeText,
      message: message.isNotEmpty ? message : other.message,
      status: winner.status,
      reviewedByName: winner.reviewedByName.isNotEmpty
          ? winner.reviewedByName
          : (reviewedByName.isNotEmpty ? reviewedByName : other.reviewedByName),
      reviewedByRole: winner.reviewedByRole.isNotEmpty
          ? winner.reviewedByRole
          : (reviewedByRole.isNotEmpty ? reviewedByRole : other.reviewedByRole),
      requestedForDate: requestedForDate ?? other.requestedForDate,
      requestedAtMs: requestedAtMs > other.requestedAtMs
          ? requestedAtMs
          : other.requestedAtMs,
    );
  }
}

String _roleLabel(String role) {
  switch (role.toLowerCase()) {
    case 'teacher':
      return 'Homeroom teacher';
    case 'parent':
      return 'Parent';
    default:
      return '';
  }
}

class _Header extends StatelessWidget {
  final int total;
  final int pending;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  const _Header({
    required this.total,
    required this.pending,
    required this.onBack,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
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
              painter: const HeaderSparklesPainter(variant: 1),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
            child: Row(
              children: [
                _GlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave requests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.05,
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
                      const SizedBox(height: 6),
                      Text(
                        '$total total · $pending pending',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _GlassIconButton(
                  icon: Icons.edit_rounded,
                  onTap: onCreate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(13),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _CreateButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CreateButton({required this.onTap});

  @override
  State<_CreateButton> createState() => _CreateButtonState();
}

class _CreateButtonState extends State<_CreateButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2848B0), Color(0xFF3460CC)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x352848B0),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Create new request',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int approved;
  final int pending;
  final int rejected;

  const _StatsRow({
    required this.approved,
    required this.pending,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.check_circle_rounded,
            iconColor: _primary,
            iconBg: _primary.withValues(alpha: 0.12),
            count: approved,
            label: 'APPROVED',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.hourglass_top_rounded,
            iconColor: const Color(0xFFC58A00),
            iconBg: const Color(0xFFFFF1C4),
            count: pending,
            label: 'PENDING',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.cancel_rounded,
            iconColor: const Color(0xFFB03040),
            iconBg: const Color(0xFFFADBE0),
            count: rejected,
            label: 'REJECTED',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final int count;
  final String label;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              color: _textDark,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final _RequestItem item;

  const _RequestCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(item.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _cardMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Leave request',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(),
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(info: statusInfo),
            ],
          ),
          if (item.message.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              item.message.trim(),
              style: const TextStyle(
                color: _textMid,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (item.reviewedByName.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: const Color(0xFFEDEEF4),
            ),
            const SizedBox(height: 10),
            Text(
              _reviewedByLabel(item),
              style: const TextStyle(
                color: _textMuted,
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _subtitle() {
    final date = item.dateText.trim();
    final time = item.timeText.trim();
    if (date.isEmpty && time.isEmpty) return '—';
    if (date.isEmpty) return time;
    if (time.isEmpty) return date;
    return '$date · $time';
  }
}

String _reviewedByLabel(_RequestItem item) {
  final name = item.reviewedByName.trim();
  final role = _roleLabel(item.reviewedByRole);
  if (role.isEmpty) {
    return 'REVIEWED BY ${name.toUpperCase()}';
  }
  return 'REVIEWED BY ${name.toUpperCase()} · ${role.toUpperCase()}';
}

class _StatusInfo {
  final String label;
  final Color bg;
  final Color fg;
  const _StatusInfo(this.label, this.bg, this.fg);
}

_StatusInfo _statusInfo(String status) {
  switch (status) {
    case 'approved':
    case 'active':
      return const _StatusInfo(
        'Approved',
        Color(0xFFE2E7FA),
        Color(0xFF2848B0),
      );
    case 'rejected':
      return const _StatusInfo(
        'Rejected',
        Color(0xFFFADBE0),
        Color(0xFFB03040),
      );
    case 'pending':
    default:
      return const _StatusInfo(
        'Pending',
        Color(0xFFFFF1C4),
        Color(0xFFB07A00),
      );
  }
}

class _StatusPill extends StatelessWidget {
  final _StatusInfo info;

  const _StatusPill({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: info.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: info.fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            info.label,
            style: TextStyle(
              color: info.fg,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: _primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No requests yet',
            style: TextStyle(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Submit your first leave request and track it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
