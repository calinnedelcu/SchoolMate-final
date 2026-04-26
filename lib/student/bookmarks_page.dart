import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firster/core/session.dart';
import 'package:firster/student/bookmarks_service.dart';
import 'package:firster/student/widgets/school_decor.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _card = Color(0xFFFFFFFF);
const _textDark = Color(0xFF1A2050);
const _textMuted = Color(0xFF7A7E9A);

enum _BookmarkFilter { all, competition, camp, volunteer, announcement }

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  _BookmarkFilter _filter = _BookmarkFilter.all;

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid ?? '';

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _Header(
              filter: _filter,
              onFilterChanged: (f) => setState(() => _filter = f),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(child: _buildBody(uid)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String uid) {
    if (uid.isEmpty) {
      return const Center(child: Text('Invalid session.'));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: BookmarksService.stream(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }
        final allItems =
            snap.data!.docs.map(BookmarkItem.fromDoc).toList();

        final items = _filter == _BookmarkFilter.all
            ? allItems
            : allItems.where((e) => e.category == _filterKey(_filter)).toList();

        if (items.isEmpty) {
          return _EmptyState(filter: _filter);
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _BookmarkTile(
            item: items[i],
            onRemove: () => BookmarksService.remove(
              uid: uid,
              itemId: items[i].itemId,
            ),
          ),
        );
      },
    );
  }

  static String _filterKey(_BookmarkFilter f) {
    switch (f) {
      case _BookmarkFilter.competition:
        return 'competition';
      case _BookmarkFilter.camp:
        return 'camp';
      case _BookmarkFilter.volunteer:
        return 'volunteer';
      case _BookmarkFilter.announcement:
        return 'announcement';
      case _BookmarkFilter.all:
        return '';
    }
  }
}

class _Header extends StatelessWidget {
  final _BookmarkFilter filter;
  final ValueChanged<_BookmarkFilter> onFilterChanged;
  final VoidCallback onBack;

  const _Header({
    required this.filter,
    required this.onFilterChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    final pills = <(_BookmarkFilter, String)>[
      (_BookmarkFilter.all, 'All'),
      (_BookmarkFilter.competition, 'Competitions'),
      (_BookmarkFilter.camp, 'Camps'),
      (_BookmarkFilter.volunteer, 'Volunteering'),
      (_BookmarkFilter.announcement, 'Announcements'),
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
                  painter: const HeaderSparklesPainter(variant: 3),
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
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bookmarks',
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
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text(
            'Saved competitions, camps, volunteering and announcements.',
            style: TextStyle(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              for (int i = 0; i < pills.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => onFilterChanged(pills[i].$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: filter == pills[i].$1 ? _primary : _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: filter == pills[i].$1
                            ? _primary
                            : const Color(0xFFCDD1DE),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      pills[i].$2,
                      style: TextStyle(
                        color: filter == pills[i].$1 ? Colors.white : _textDark,
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
      ],
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final BookmarkItem item;
  final VoidCallback onRemove;

  const _BookmarkTile({required this.item, required this.onRemove});

  ({IconData icon, Color fg, Color bg, String label}) _categoryStyle() {
    switch (item.category) {
      case 'competition':
        return (
          icon: Icons.emoji_events_rounded,
          fg: const Color(0xFFCC8A1A),
          bg: const Color(0xFFFFF3D6),
          label: 'COMPETITION',
        );
      case 'camp':
        return (
          icon: Icons.forest_rounded,
          fg: const Color(0xFF3F8B3A),
          bg: const Color(0xFFD9EFD8),
          label: 'CAMP',
        );
      case 'volunteer':
        return (
          icon: Icons.volunteer_activism_rounded,
          fg: const Color(0xFF7B1FA2),
          bg: const Color(0xFFEDE0F4),
          label: 'VOLUNTEERING',
        );
      case 'announcement':
      default:
        return (
          icon: Icons.campaign_rounded,
          fg: const Color(0xFF3460CC),
          bg: const Color(0xFFDDE0EC),
          label: 'ANNOUNCEMENT',
        );
    }
  }

  String _formatDate(DateTime d) {
    const months = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final style = _categoryStyle();
    return Container(
      decoration: BoxDecoration(
        color: style.fg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetail(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: WhiteCardSparklesPainter(
                      primary: style.fg,
                      variant: item.itemId.hashCode % 5,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
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
                              color: style.bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(style.icon, color: style.fg, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  style.label,
                                  style: TextStyle(
                                    color: style.fg,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: onRemove,
                            tooltip: 'Remove bookmark',
                            splashRadius: 20,
                            icon: const Icon(
                              Icons.bookmark_rounded,
                              color: Color(0xFFCC8A1A),
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          item.title.isEmpty ? 'Saved item' : item.title,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
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
                      if (item.message.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            item.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (item.eventDate != null)
                            _MetaChip(
                              icon: Icons.calendar_month_rounded,
                              text: _formatDate(item.eventDate!),
                            ),
                          if (item.location.isNotEmpty)
                            _MetaChip(
                              icon: Icons.place_outlined,
                              text: item.location,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC0A0F2A),
      builder: (_) => _BookmarkDetailDialog(item: item),
    );
  }
}

class _BookmarkDetailDialog extends StatelessWidget {
  final BookmarkItem item;

  const _BookmarkDetailDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = size.width < 460 ? size.width - 32 : 420.0;
    final maxH = size.height * 0.82;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailHeader(item: item),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.eventDate != null || item.location.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 8,
                              children: [
                                if (item.eventDate != null)
                                  _MetaChip(
                                    icon: Icons.calendar_month_rounded,
                                    text: _formatLong(item.eventDate!),
                                  ),
                                if (item.location.isNotEmpty)
                                  _MetaChip(
                                    icon: Icons.place_outlined,
                                    text: item.location,
                                  ),
                              ],
                            ),
                          ),
                        Text(
                          item.message.isEmpty
                              ? 'No additional details.'
                              : item.message,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                        if (item.link.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.link_rounded,
                                  size: 18,
                                  color: _primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SelectableText(
                                    item.link,
                                    style: const TextStyle(
                                      color: _primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (item.senderName.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 16,
                                color: _textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.senderName,
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: GestureDetector(
                    onTap: () async {
                      final uid = AppSession.uid ?? '';
                      await BookmarksService.remove(
                        uid: uid,
                        itemId: item.itemId,
                      );
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0D0D8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_remove_rounded,
                            color: Color(0xFFB03040),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Remove bookmark',
                            style: TextStyle(
                              color: Color(0xFFB03040),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
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

  static String _formatLong(DateTime d) {
    const months = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _DetailHeader extends StatelessWidget {
  final BookmarkItem item;

  const _DetailHeader({required this.item});

  Color _accent() {
    switch (item.category) {
      case 'competition':
        return const Color(0xFFCC8A1A);
      case 'camp':
        return const Color(0xFF3F8B3A);
      case 'volunteer':
        return const Color(0xFF7B1FA2);
      case 'announcement':
      default:
        return const Color(0xFF3460CC);
    }
  }

  IconData _icon() {
    switch (item.category) {
      case 'competition':
        return Icons.emoji_events_rounded;
      case 'camp':
        return Icons.forest_rounded;
      case 'volunteer':
        return Icons.volunteer_activism_rounded;
      case 'announcement':
      default:
        return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    return Container(
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
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icon(), size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            item.category.toUpperCase(),
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
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      splashRadius: 22,
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
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
                    item.title.isEmpty ? 'Saved item' : item.title,
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
    );
  }

  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
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

class _EmptyState extends StatelessWidget {
  final _BookmarkFilter filter;

  const _EmptyState({required this.filter});

  String _label() {
    switch (filter) {
      case _BookmarkFilter.competition:
        return 'No bookmarked competitions yet.';
      case _BookmarkFilter.camp:
        return 'No bookmarked camps yet.';
      case _BookmarkFilter.volunteer:
        return 'No bookmarked volunteering opportunities yet.';
      case _BookmarkFilter.announcement:
        return 'No bookmarked announcements yet.';
      case _BookmarkFilter.all:
        return 'You haven\'t bookmarked anything yet.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF2),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.bookmark_border_rounded,
              color: _primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _label(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Open a post in Messages and tap the bookmark icon to save it here.',
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
