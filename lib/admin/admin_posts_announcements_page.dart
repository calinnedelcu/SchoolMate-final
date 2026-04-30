import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../common/link_utils.dart';
import '../common/storage_image.dart';
import 'admin_post_composer_page.dart';

const _bg = Color(0xFFF2F4F8);
const _cardBg = Color(0xFFFFFFFF);
const _primary = Color(0xFF2848B0);
const _textDark = Color(0xFF1A2050);
const _textMid = Color(0xFF3A4A80);
const _textMuted = Color(0xFF7A7E9A);
const _pinColor = Color(0xFFB07A00);

// Category colors
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

// Unified post item

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
  final String imageUrl;

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
    this.imageUrl = '',
  });
}

// Page

class AdminPostsAnnouncementsPage extends StatelessWidget {
  final bool embedded;
  final PostComposerMode mode;
  const AdminPostsAnnouncementsPage({
    super.key,
    this.embedded = false,
    this.mode = PostComposerMode.secretariat,
  });

  void _openComposer(BuildContext context) {
    showPostComposerDialog(context, mode: mode);
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

// Stats Row

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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
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

// Posts List

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
    final cs = Theme.of(context).colorScheme;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
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
        Divider(height: 1, color: cs.outlineVariant),
        const SizedBox(height: 14),
        // Filter chips
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
                imageUrl: (data['imageUrl'] ?? '').toString(),
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
                imageUrl: (data['imageUrl'] ?? '').toString(),
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

// Post Card

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
            // Image preview (right of text)
            if (item.imageUrl.isNotEmpty) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: StorageImage(
                    url: item.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (_) => Container(
                      color: color.withValues(alpha: 0.08),
                    ),
                    errorBuilder: (_, _) => Container(
                      color: color.withValues(alpha: 0.08),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: _textMuted,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // Actions
            const SizedBox(width: 6),
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
    final cs = Theme.of(context).colorScheme;
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
                    : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected || _hovered
                  ? widget.chipColor
                  : cs.outlineVariant,
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

// Post Detail / Edit Dialog

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
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _maxCtrl;

  DateTime? _eventDate;
  DateTime? _eventEndDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _messageCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _linkCtrl = TextEditingController();
    _hoursCtrl = TextEditingController();
    _maxCtrl = TextEditingController();
    _loadDoc();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _locationCtrl.dispose();
    _linkCtrl.dispose();
    _hoursCtrl.dispose();
    _maxCtrl.dispose();
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
    _hoursCtrl.text = (data['hoursWorth'] ?? '').toString();
    _maxCtrl.text = (data['maxParticipants'] ?? '').toString();
    final eventKey = isVol ? 'date' : 'eventDate';
    final eventTs = data[eventKey] as Timestamp?;
    final endTs = data['eventEndDate'] as Timestamp?;
    setState(() {
      _fullDoc = data;
      _loading = false;
      _eventDate = eventTs?.toDate();
      _eventEndDate = endTs?.toDate();
    });
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final initial = isEnd
        ? (_eventEndDate ?? _eventDate ?? DateTime.now().add(const Duration(days: 1)))
        : (_eventDate ?? DateTime.now().add(const Duration(days: 1)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _eventEndDate = picked;
      } else {
        _eventDate = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final isVol = widget.item.collection == 'volunteerOpportunities';
    final cat = widget.item.category;
    final hasEndDate = cat == 'camp' || cat == 'vacation';
    final eventKey = isVol ? 'date' : 'eventDate';

    final updates = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      if (isVol) 'description': _messageCtrl.text.trim()
      else 'message': _messageCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'link': _linkCtrl.text.trim(),
      if (_eventDate != null) eventKey: Timestamp.fromDate(_eventDate!),
      if (hasEndDate && _eventEndDate != null)
        'eventEndDate': Timestamp.fromDate(_eventEndDate!),
      if (isVol) 'hoursWorth': _hoursCtrl.text.trim(),
      if (isVol) 'maxParticipants': _maxCtrl.text.trim(),
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
    final cs = Theme.of(context).colorScheme;
    final catColor = _categoryColor(widget.item.category);
    final catIcon = _categoryIcon(widget.item.category);
    final isVol = widget.item.collection == 'volunteerOpportunities';
    final title = _fullDoc?['title']?.toString() ?? widget.item.title;
    final doc = _fullDoc;
    final senderName = doc == null
        ? widget.item.senderName
        : ((isVol ? doc['createdByName'] : doc['senderName'])?.toString() ?? widget.item.senderName);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 580),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          color: cs.surfaceContainerHighest,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Blue gradient header
              Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3CA0), Color(0xFF2848B0), Color(0xFF3060D0)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category icon circle
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(catIcon, size: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category badge pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Text(
                              _categoryLabel(widget.item.category),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _loading
                                ? 'Loading…'
                                : (title.isEmpty ? '(no title)' : title),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (senderName.isNotEmpty && !_loading) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded,
                                    size: 12, color: Colors.white70),
                                const SizedBox(width: 4),
                                Text(
                                  senderName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Header action buttons
                    Column(
                      children: [
                        _HeaderBtn(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        if (!_loading) ...[
                          const SizedBox(height: 6),
                          _HeaderBtn(
                            icon: _editing
                                ? Icons.undo_rounded
                                : Icons.edit_rounded,
                            onTap: () {
                              if (_editing) {
                                _loadDoc();
                                setState(() => _editing = false);
                              } else {
                                setState(() => _editing = true);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: CircularProgressIndicator(color: _primary),
                          ),
                        )
                      : _editing
                          ? _buildEditBody(context, isVol)
                          : _buildViewBody(context, isVol, catColor),
                ),
              ),

              // Footer
              if (_editing)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    border: Border(top: BorderSide(color: Color(0xFFE4E8F4))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  _loadDoc();
                                  setState(() => _editing = false);
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textMuted,
                            side: const BorderSide(color: Color(0xFFD2D8F0)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            padding: const EdgeInsets.symmetric(vertical: 13),
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

  Widget _buildViewBody(BuildContext context, bool isVol, Color catColor) {
    final cs = Theme.of(context).colorScheme;
    final message = (isVol
            ? _fullDoc!['description']
            : _fullDoc!['message'])
        ?.toString() ?? '';
    final location = _fullDoc!['location']?.toString() ?? '';
    final link = _fullDoc!['link']?.toString() ?? '';
    final eventDateTs = isVol
        ? _fullDoc!['date'] as Timestamp?
        : _fullDoc!['eventDate'] as Timestamp?;
    final eventEndDateTs = _fullDoc!['eventEndDate'] as Timestamp?;
    final publishedTs = _fullDoc!['createdAt'] as Timestamp?;
    final hoursWorth = _fullDoc!['hoursWorth']?.toString() ?? '';
    final maxPart = _fullDoc!['maxParticipants']?.toString() ?? '';
    final imageUrl = _fullDoc!['imageUrl']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl.isNotEmpty) ...[
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
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
                  errorBuilder: (_, error) => Container(
                    width: 320,
                    color: cs.outlineVariant,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.broken_image_rounded,
                          color: _textMuted,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Could not load image',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$error',
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Meta chips row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _MetaChip(
              icon: Icons.groups_rounded,
              label: widget.item.audienceLabel.isEmpty
                  ? 'All students'
                  : widget.item.audienceLabel,
              color: _primary,
            ),
            if (publishedTs != null)
              _MetaChip(
                icon: Icons.calendar_today_rounded,
                label: _formatDate(publishedTs),
                color: _textMid,
              ),
            if (widget.item.pinned)
              _MetaChip(
                icon: Icons.push_pin_rounded,
                label: 'Pinned',
                color: _pinColor,
              ),
          ],
        ),

        const SizedBox(height: 18),

        // Message / description
        if (message.isNotEmpty) ...[
          _SectionLabel('Message'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: _textDark,
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Info rows
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              if (location.isNotEmpty)
                _InfoRow(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  value: location,
                  iconColor: const Color(0xFF2E7D32),
                  isFirst: true,
                ),
              if (eventDateTs != null)
                _InfoRow(
                  icon: Icons.event_rounded,
                  label: eventEndDateTs != null ? 'Start date' : 'Event date',
                  value: _formatDate(eventDateTs),
                  iconColor: const Color(0xFF0277BD),
                  isFirst: location.isEmpty,
                ),
              if (eventEndDateTs != null)
                _InfoRow(
                  icon: Icons.event_available_rounded,
                  label: 'End date',
                  value: _formatDate(eventEndDateTs),
                  iconColor: const Color(0xFF0277BD),
                  isFirst: location.isEmpty && eventDateTs == null,
                ),
              if (isVol && hoursWorth.isNotEmpty)
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  label: 'Hours / Max participants',
                  value: '$hoursWorth h  ·  max $maxPart',
                  iconColor: const Color(0xFF7B1FA2),
                  isFirst: location.isEmpty && eventDateTs == null,
                ),
              if (link.isNotEmpty)
                _InfoRow(
                  icon: Icons.link_rounded,
                  label: 'Link',
                  value: link,
                  iconColor: _primary,
                  isFirst: location.isEmpty &&
                      eventDateTs == null &&
                      !(isVol && hoursWorth.isNotEmpty),
                  onTap: () => launchExternalUrl(context, link),
                ),
              if (location.isEmpty &&
                  eventDateTs == null &&
                  link.isEmpty &&
                  !(isVol && hoursWorth.isNotEmpty))
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Text(
                    'No additional details.',
                    style: TextStyle(color: _textMuted, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditBody(BuildContext context, bool isVol) {
    final cat = widget.item.category;
    final hasEventDate = cat == 'competition' || cat == 'camp' ||
        cat == 'volunteer' || cat == 'vacation';
    final hasEndDate = cat == 'camp' || cat == 'vacation';
    final startLabel = cat == 'vacation' ? 'Start date *' : 'Event date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Title'),
        const SizedBox(height: 6),
        _Field(label: '', controller: _titleCtrl),
        if (cat != 'vacation') ...[
          const SizedBox(height: 14),
          _SectionLabel(isVol ? 'Description' : 'Message'),
          const SizedBox(height: 6),
          _Field(label: '', controller: _messageCtrl, maxLines: 5),
        ],
        if (cat != 'announcement' && cat != 'vacation') ...[
          const SizedBox(height: 14),
          _SectionLabel('Location'),
          const SizedBox(height: 6),
          _Field(label: '', controller: _locationCtrl),
        ],
        if (hasEventDate) ...[
          const SizedBox(height: 14),
          _SectionLabel(hasEndDate ? 'Dates' : startLabel),
          const SizedBox(height: 6),
          if (hasEndDate)
            Row(
              children: [
                Expanded(child: _EditDateField(label: 'Start', date: _eventDate, onTap: () => _pickDate(isEnd: false))),
                const SizedBox(width: 10),
                Expanded(child: _EditDateField(label: 'End', date: _eventEndDate, onTap: () => _pickDate(isEnd: true))),
              ],
            )
          else
            _EditDateField(label: startLabel, date: _eventDate, onTap: () => _pickDate(isEnd: false)),
        ],
        if (isVol) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Hours'),
                    const SizedBox(height: 6),
                    _Field(label: '', controller: _hoursCtrl, keyboardType: TextInputType.number),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Max participants'),
                    const SizedBox(height: 6),
                    _Field(label: '', controller: _maxCtrl, keyboardType: TextInputType.number),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _SectionLabel('Link'),
        const SizedBox(height: 6),
        _Field(label: '', controller: _linkCtrl),
        const SizedBox(height: 4),
      ],
    );
  }
}

// Detail helper widgets

class _HeaderBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  State<_HeaderBtn> createState() => _HeaderBtnState();
}

class _HeaderBtnState extends State<_HeaderBtn> {
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: Icon(widget.icon, size: 17, color: Colors.white),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool isFirst;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.isFirst = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLink = onTap != null;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isLink ? iconColor : _textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    decoration: isLink ? TextDecoration.underline : null,
                    decorationColor: isLink ? iconColor : null,
                  ),
                ),
              ],
            ),
          ),
          if (isLink) ...[
            const SizedBox(width: 6),
            Icon(Icons.open_in_new_rounded, size: 14, color: iconColor),
          ],
        ],
      ),
    );

    return Column(
      children: [
        if (!isFirst)
          const Divider(
            height: 1,
            color: Color(0xFFEEF0F8),
            indent: 14,
            endIndent: 14,
          ),
        if (isLink)
          InkWell(onTap: onTap, child: content)
        else
          content,
      ],
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

// (vacation posts are created via the post composer as PostKind.vacation)


class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
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
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: _textDark, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: cs.outlineVariant,
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

class _EditDateField extends StatefulWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _EditDateField({required this.label, required this.date, required this.onTap});

  @override
  State<_EditDateField> createState() => _EditDateFieldState();
}

class _EditDateFieldState extends State<_EditDateField> {
  bool _hovered = false;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDate = widget.date != null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFFDDE0EE)
                : cs.outlineVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasDate
                  ? _primary.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: hasDate ? _primary : _textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasDate ? _fmt(widget.date!) : widget.label,
                  style: TextStyle(
                    color: hasDate ? _textDark : _textMuted,
                    fontSize: 13,
                    fontWeight: hasDate ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.edit_calendar_rounded, size: 14, color: _textMuted.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
