import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_post_composer_page.dart';

const _bg = Color(0xFFF2F4F8);
const _cardBg = Color(0xFFFFFFFF);
const _primary = Color(0xFF2848B0);
const _textDark = Color(0xFF1A2050);
const _textMid = Color(0xFF3A4A80);
const _textMuted = Color(0xFF7A7E9A);
const _pinColor = Color(0xFFB07A00);

// ─── Category colors ──────────────────────────────────────────────────────────
Color _categoryColor(String cat) {
  switch (cat) {
    case 'competition':
      return const Color(0xFFC07800);
    case 'camp':
      return const Color(0xFF2E7D32);
    case 'volunteer':
      return const Color(0xFF7B1FA2);
    case 'vacation':
      return const Color(0xFF0277BD);
    default:
      return _primary;
  }
}

Color _categoryBg(String cat) {
  switch (cat) {
    case 'competition':
      return const Color(0xFFFFF8E1);
    case 'camp':
      return const Color(0xFFF1F8F1);
    case 'volunteer':
      return const Color(0xFFF8F0FF);
    case 'vacation':
      return const Color(0xFFE3F2FD);
    default:
      return _cardBg;
  }
}

IconData _categoryIcon(String cat) {
  switch (cat) {
    case 'competition':
      return Icons.emoji_events_rounded;
    case 'camp':
      return Icons.forest_rounded;
    case 'volunteer':
      return Icons.volunteer_activism_rounded;
    case 'vacation':
      return Icons.beach_access_rounded;
    default:
      return Icons.campaign_rounded;
  }
}

// ─── Unified post item ────────────────────────────────────────────────────────

class _PostItem {
  final String docId;
  final String collection;
  final String title;
  final String message;
  final String category;
  final DateTime? createdAt;
  final String audienceLabel;
  final String senderName;
  final bool pinned;

  const _PostItem({
    required this.docId,
    required this.collection,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    required this.audienceLabel,
    required this.senderName,
    required this.pinned,
  });
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class AdminPostsAnnouncementsPage extends StatelessWidget {
  final bool embedded;
  const AdminPostsAnnouncementsPage({super.key, this.embedded = false});

  void _openComposer(BuildContext context) {
    showPostComposerDialog(context, mode: PostComposerMode.secretariat);
  }

  @override
  Widget build(BuildContext context) {
    final body = Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatsRow(),
            const SizedBox(height: 28),
            _PostsList(onNewPost: () => _openComposer(context)),
          ],
        ),
      ),
    );
    if (embedded) return body;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text('Posts & Announcements'),
      ),
      body: body,
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final yearStart = DateTime(
        DateTime.now().month >= 9 ? DateTime.now().year : DateTime.now().year - 1,
        9,
        1);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('secretariatMessages')
          .where('messageType', isEqualTo: 'secretariatGlobal')
          .where('recipientRole', isEqualTo: 'student')
          .where('recipientUid', isEqualTo: '')
          .snapshots(),
      builder: (context, snap) {
        final allDocs = snap.data?.docs ?? [];
        final publishedCount = allDocs
            .where((d) {
              final status = (d.data()['status'] ?? 'active').toString();
              final ts = d.data()['createdAt'] as Timestamp?;
              final dt = ts?.toDate();
              return status == 'active' && dt != null && dt.isAfter(yearStart);
            })
            .length;

        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final recentCount = allDocs
            .where((d) {
              final ts = d.data()['createdAt'] as Timestamp?;
              final dt = ts?.toDate();
              return dt != null && dt.isAfter(weekAgo);
            })
            .length;

        return LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final cards = [
            _StatCard(
              icon: Icons.campaign_rounded,
              iconBg: const Color(0xFFEEF1FB),
              iconColor: _primary,
              label: 'PUBLISHED',
              value: snap.hasData ? '$publishedCount' : '—',
              sub: 'This school year',
            ),
            _StatCard(
              icon: Icons.drafts_outlined,
              iconBg: const Color(0xFFEDF7F0),
              iconColor: const Color(0xFF2E8B57),
              label: 'DRAFTS',
              value: '0',
              sub: 'Unpublished',
            ),
            _StatCard(
              icon: Icons.bar_chart_rounded,
              iconBg: const Color(0xFFF3EDFB),
              iconColor: const Color(0xFF7B4FCC),
              label: 'AVG READ RATE',
              value: '—',
              sub: 'Not tracked',
            ),
            _StatCard(
              icon: Icons.access_time_rounded,
              iconBg: const Color(0xFFFFF8E8),
              iconColor: const Color(0xFFF5A623),
              label: 'THIS WEEK',
              value: snap.hasData ? '$recentCount' : '—',
              sub: 'New posts',
            ),
          ];

          if (isNarrow) {
            return Column(
              children: [
                Row(children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ]),
              ],
            );
          }

          return Row(
            children: cards
                .expand((c) => [Expanded(child: c), const SizedBox(width: 14)])
                .toList()
              ..removeLast(),
          );
        });
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;
  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9BA3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    color: Color(0xFF9BA3B8),
                    fontSize: 11,
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

// ─── Posts List ───────────────────────────────────────────────────────────────

const _kFilterAll = 'all';

class _PostsList extends StatefulWidget {
  final VoidCallback onNewPost;
  const _PostsList({required this.onNewPost});

  @override
  State<_PostsList> createState() => _PostsListState();
}

class _PostsListState extends State<_PostsList> {
  String _filter = _kFilterAll;

  static const _filters = [
    (_kFilterAll, 'All', Icons.apps_rounded),
    ('announcement', 'Announcements', Icons.campaign_rounded),
    ('competition', 'Competition', Icons.emoji_events_rounded),
    ('camp', 'Camp', Icons.forest_rounded),
    ('volunteer', 'Volunteer', Icons.volunteer_activism_rounded),
    ('vacation', 'Vacation', Icons.beach_access_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Published posts',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage announcements and opportunities.',
                  style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Spacer(),
            TextButton(
              onPressed: widget.onNewPost,
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                overlayColor: _primary.withValues(alpha: 0.10),
              ).copyWith(
                mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              ),
              child: const Text(
                '+ New post',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFE8EAF2)),
        const SizedBox(height: 14),
        // ── Filter chips ─────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) {
              final (key, label, icon) = f;
              final selected = _filter == key;
              final chipColor = key == _kFilterAll ? _primary : _categoryColor(key);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChipWidget(
                  label: label,
                  icon: icon,
                  selected: selected,
                  chipColor: chipColor,
                  onTap: () => setState(() => _filter = key),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('secretariatMessages')
              .where('messageType', isEqualTo: 'secretariatGlobal')
              .where('recipientRole', isEqualTo: 'student')
              .where('recipientUid', isEqualTo: '')
              .limit(80)
              .snapshots(),
          builder: (context, msgSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('volunteerOpportunities')
                  .orderBy('createdAt', descending: true)
                  .limit(80)
                  .snapshots(),
              builder: (context, volSnap) {
                if (!msgSnap.hasData || !volSnap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final msgDocs = msgSnap.data!.docs;
                final volDocs = volSnap.data!.docs;

            final List<_PostItem> items = [];

            for (final d in msgDocs) {
              final data = d.data();
              final status = (data['status'] ?? 'active').toString();
              if (status != 'active') continue;
              final ts = data['createdAt'] as Timestamp?;
              final dt = ts?.toDate();
              if (dt == null || !dt.isAfter(cutoff)) continue;

              final audienceLabel = (data['audienceLabel'] ?? '').toString();
              final ids = (data['audienceClassIds'] as List?) ?? [];
              final audience = audienceLabel.isNotEmpty
                  ? audienceLabel
                  : (ids.isEmpty || ids.contains(kAudienceAll))
                      ? 'All students'
                      : ids.length == 1
                          ? 'Class ${ids.first}'
                          : '${ids.length} classes';

              items.add(_PostItem(
                docId: d.id,
                collection: 'secretariatMessages',
                title: (data['title'] ?? '').toString(),
                message: (data['message'] ?? '').toString(),
                category: (data['category'] ?? 'announcement').toString(),
                createdAt: dt,
                audienceLabel: audience,
                senderName: (data['senderName'] ?? '').toString(),
                pinned: data['pinned'] == true,
              ));
            }

            for (final d in volDocs) {
              final data = d.data();
              final status = (data['status'] ?? 'active').toString();
              if (status != 'active') continue;
              final ts = data['createdAt'] as Timestamp?;
              final dt = ts?.toDate();
              if (dt == null || !dt.isAfter(cutoff)) continue;

              final ids = (data['audienceClassIds'] as List?) ?? [];
              final audience = ids.isEmpty || ids.contains(kAudienceAll)
                  ? 'All students'
                  : ids.length == 1
                      ? 'Class ${ids.first}'
                      : '${ids.length} classes';

              items.add(_PostItem(
                docId: d.id,
                collection: 'volunteerOpportunities',
                title: (data['title'] ?? '').toString(),
                message: (data['description'] ?? '').toString(),
                category: 'volunteer',
                createdAt: dt,
                audienceLabel: audience,
                senderName: (data['createdByName'] ?? '').toString(),
                pinned: data['pinned'] == true,
              ));
            }

            // Pinned first, then newest
            items.sort((a, b) {
              if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
              return (b.createdAt ?? DateTime(0))
                  .compareTo(a.createdAt ?? DateTime(0));
            });

            // Apply filter
            final filtered = _filter == _kFilterAll
                ? items
                : items.where((i) {
                    if (_filter == 'announcement') {
                      return i.category != 'competition' &&
                          i.category != 'camp' &&
                          i.category != 'volunteer' &&
                          i.category != 'vacation';
                    }
                    return i.category == _filter;
                  }).toList();

            if (filtered.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _filter == _kFilterAll
                      ? 'No posts in the last 30 days.'
                      : 'No posts for this category.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _textMuted, fontSize: 13),
                ),
              );
            }

            return Column(
              children: filtered
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PostCard(item: item),
                      ))
                  .toList(),
            );
          },
            );
          },
        ),
      ],
      ),
    );
  }
}

// ─── Post Card ────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final _PostItem item;
  const _PostCard({required this.item});

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _senderInitials(String name) {
    final n = name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return n[0].toUpperCase();
  }

  Future<void> _togglePin(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection(item.collection)
        .doc(item.docId)
        .update({'pinned': !item.pinned});
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post'),
        content: const Text('This will permanently delete the post. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection(item.collection)
          .doc(item.docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = item.pinned ? const Color(0xFFE8A800) : _categoryColor(item.category);
    final bg = item.pinned ? const Color(0xFFFFFDF5) : _categoryBg(item.category);
    final icon = _categoryIcon(item.category);
    final timeAgo = _timeAgo(item.createdAt);
    final initials = _senderInitials(item.senderName);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 3.5),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Category icon
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title.isEmpty ? '(no title)' : item.title,
                          style: TextStyle(
                            color: _textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.pinned) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0C2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'PINNED',
                            style: TextStyle(
                              color: _pinColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.message.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        item.audienceLabel,
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const _Dot(),
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: color,
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        item.senderName.isEmpty
                            ? '—'
                            : item.senderName.split(' ').first,
                        style: const TextStyle(color: _textMuted, fontSize: 11),
                      ),
                      const _Dot(),
                      Text(
                        timeAgo,
                        style: const TextStyle(color: _textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionBtn(
                  icon: item.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: item.pinned ? _pinColor : _textMuted,
                  tooltip: item.pinned ? 'Unpin' : 'Pin',
                  onTap: () => _togglePin(context),
                ),
                const SizedBox(height: 2),
                _ActionBtn(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFB03040),
                  tooltip: 'Delete',
                  onTap: () => _delete(context),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: _PostDetailDialog(item: item),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _FilterChipWidget extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color chipColor;
  final VoidCallback onTap;

  const _FilterChipWidget({
    required this.label,
    required this.icon,
    required this.selected,
    required this.chipColor,
    required this.onTap,
  });

  @override
  State<_FilterChipWidget> createState() => _FilterChipWidgetState();
}

class _FilterChipWidgetState extends State<_FilterChipWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.chipColor
                : _hovered
                    ? widget.chipColor.withValues(alpha: 0.10)
                    : const Color(0xFFF2F4F8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected || _hovered
                  ? widget.chipColor
                  : const Color(0xFFE8EAF2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 13,
                color: widget.selected
                    ? Colors.white
                    : _hovered
                        ? widget.chipColor
                        : _textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.selected
                      ? Colors.white
                      : _hovered
                          ? widget.chipColor
                          : _textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        '·',
        style: TextStyle(color: _textMuted, fontSize: 12),
      ),
    );
  }
}

// ─── Post Detail / Edit Dialog ────────────────────────────────────────────────

class _PostDetailDialog extends StatefulWidget {
  final _PostItem item;
  const _PostDetailDialog({required this.item});

  @override
  State<_PostDetailDialog> createState() => _PostDetailDialogState();
}

class _PostDetailDialogState extends State<_PostDetailDialog> {
  Map<String, dynamic>? _fullDoc;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _messageCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _linkCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _messageCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _linkCtrl = TextEditingController();
    _loadDoc();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _locationCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDoc() async {
    final snap = await FirebaseFirestore.instance
        .collection(widget.item.collection)
        .doc(widget.item.docId)
        .get();
    if (!mounted) return;
    final data = snap.data() ?? {};
    final isVol = widget.item.collection == 'volunteerOpportunities';
    _titleCtrl.text = (data['title'] ?? '').toString();
    _messageCtrl.text =
        (isVol ? data['description'] : data['message'] ?? '').toString();
    _locationCtrl.text = (data['location'] ?? '').toString();
    _linkCtrl.text = (data['link'] ?? '').toString();
    setState(() {
      _fullDoc = data;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final isVol = widget.item.collection == 'volunteerOpportunities';
    final updates = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      if (isVol) 'description': _messageCtrl.text.trim()
      else 'message': _messageCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'link': _linkCtrl.text.trim(),
    };
    await FirebaseFirestore.instance
        .collection(widget.item.collection)
        .doc(widget.item.docId)
        .update(updates);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
      _fullDoc = {...?_fullDoc, ...updates};
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Post updated.')));
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(widget.item.category);
    final icon = _categoryIcon(widget.item.category);
    final isVol = widget.item.collection == 'volunteerOpportunities';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          color: const Color(0xFFFAFBFF),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Accent bar ───────────────────────────────────────────
              Container(height: 4, color: color),

              // ── Top bar: category badge + close ──────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 14, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 13, color: color),
                          const SizedBox(width: 6),
                          Text(
                            _categoryLabel(widget.item.category),
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!_loading && !_editing)
                      _IconChip(
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        color: _textMid,
                        onTap: () => setState(() => _editing = true),
                      ),
                    if (!_loading && _editing)
                      _IconChip(
                        icon: Icons.undo_rounded,
                        label: 'Cancel',
                        color: _textMuted,
                        onTap: () { _loadDoc(); setState(() => _editing = false); },
                      ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      mouseCursor: SystemMouseCursors.click,
                      hoverColor: _textMuted.withValues(alpha: 0.10),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.close_rounded, size: 20, color: _textMuted),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable body ───────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                  child: _loading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            if (_editing)
                              _Field(label: 'Title', controller: _titleCtrl)
                            else ...[
                              Text(
                                _fullDoc!['title']?.toString().isEmpty ?? true
                                    ? '(no title)'
                                    : _fullDoc!['title'].toString(),
                                style: const TextStyle(
                                  color: _textDark,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.item.audienceLabel,
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),
                            _divider(),
                            const SizedBox(height: 18),

                            // Message / Description
                            if (_editing)
                              _Field(
                                label: isVol ? 'Description' : 'Message',
                                controller: _messageCtrl,
                                maxLines: 6,
                              )
                            else
                              _DetailRow(
                                label: isVol ? 'Description' : 'Message',
                                value: (isVol
                                        ? _fullDoc!['description']
                                        : _fullDoc!['message'])
                                    ?.toString() ?? '',
                              ),

                            const SizedBox(height: 18),

                            // Two-column metadata row
                            if (_editing) ...[
                              _Field(label: 'Location', controller: _locationCtrl),
                              const SizedBox(height: 12),
                              _Field(label: 'Link', controller: _linkCtrl),
                            ] else ...[
                              _TwoCol(
                                left: _DetailRow(
                                  label: 'Location',
                                  value: _fullDoc!['location']?.toString() ?? '',
                                ),
                                right: isVol
                                    ? _DetailRow(
                                        label: 'Event date',
                                        value: _formatDate(_fullDoc!['date'] as Timestamp?),
                                      )
                                    : _DetailRow(
                                        label: 'Event date',
                                        value: _formatDate(_fullDoc!['eventDate'] as Timestamp?),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              _TwoCol(
                                left: _DetailRow(
                                  label: 'Link',
                                  value: _fullDoc!['link']?.toString() ?? '',
                                ),
                                right: isVol
                                    ? _DetailRow(
                                        label: 'Hours / Max',
                                        value:
                                            '${_fullDoc!['hoursWorth'] ?? '—'} h  ·  max ${_fullDoc!['maxParticipants'] ?? '—'}',
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 18),
                              _divider(),
                              const SizedBox(height: 16),
                              _TwoCol(
                                left: _DetailRow(
                                  label: 'Published by',
                                  value: (isVol
                                          ? _fullDoc!['createdByName']
                                          : _fullDoc!['senderName'])
                                      ?.toString() ?? '',
                                ),
                                right: _DetailRow(
                                  label: 'Published on',
                                  value: _formatDate(_fullDoc!['createdAt'] as Timestamp?),
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),
                          ],
                        ),
                ),
              ),

              // ── Footer (edit mode) ────────────────────────────────────
              if (_editing)
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE4E8F4)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text(
                                  'Save changes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _categoryLabel(String cat) {
  switch (cat) {
    case 'competition':
      return 'COMPETITION';
    case 'camp':
      return 'CAMP';
    case 'volunteer':
      return 'VOLUNTEERING';
    case 'vacation':
      return 'VACATION';
    default:
      return 'ANNOUNCEMENT';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: _textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(
            color: _textDark,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _TwoCol extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _TwoCol({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 20),
        Expanded(child: right),
      ],
    );
  }
}

class _IconChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _IconChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_IconChip> createState() => _IconChipState();
}

class _IconChipState extends State<_IconChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _hovered ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _divider() => const Divider(color: Color(0xFFE4E8F4), height: 1);

// (vacation posts are created via the post composer as PostKind.vacation)


class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  const _Field({required this.label, required this.controller, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: _textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: _textDark, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFE8EAF2),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
