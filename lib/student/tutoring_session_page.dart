import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firster/core/session.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF1F8BE7);
const _surface = Color(0xFFEFF5FA);
const _surfaceLowest = Color(0xFFFFFFFF);
const _surfaceContainerLow = Color(0xFFE7F0F6);
const _outline = Color(0xFF717B6E);
const _onSurface = Color(0xFF587F9E);

class TutoringSessionPage extends StatefulWidget {
  final String sessionId;

  const TutoringSessionPage({super.key, required this.sessionId});

  @override
  State<TutoringSessionPage> createState() => _TutoringSessionPageState();
}

class _TutoringSessionPageState extends State<TutoringSessionPage> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _sessionStream;

  @override
  void initState() {
    super.initState();
    _sessionStream = FirebaseFirestore.instance
        .collection('tutoringSessions')
        .doc(widget.sessionId)
        .snapshots();
  }

  Future<void> _confirmSession() async {
    await FirebaseFirestore.instance
        .collection('tutoringSessions')
        .doc(widget.sessionId)
        .update({'status': 'confirmed'});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesiune confirmata')),
    );
  }

  Future<void> _cancelSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anuleaza sesiune'),
        content: const Text('Esti sigur ca vrei sa anulezi aceasta sesiune?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Inapoi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Anuleaza',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await FirebaseFirestore.instance
        .collection('tutoringSessions')
        .doc(widget.sessionId)
        .update({'status': 'cancelled'});

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final myUid = AppSession.uid ?? '';

    return Scaffold(
      backgroundColor: _surface,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _sessionStream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data() ?? {};
          if (data.isEmpty) {
            return Column(
              children: [
                _Header(topPadding: topPadding, title: 'Sesiune'),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Sesiunea nu mai exista',
                      style: TextStyle(color: _outline),
                    ),
                  ),
                ),
              ],
            );
          }

          final tutorUid = (data['tutorUid'] ?? '').toString();
          final tutorName = (data['tutorName'] ?? '').toString();
          final learnerName = (data['learnerName'] ?? '').toString();
          final subject = (data['subject'] ?? '').toString();
          final notes = (data['notes'] ?? '').toString();
          final availability = (data['availability'] ?? '').toString();
          final status = (data['status'] ?? '').toString();
          final hoursLogged = (data['hoursLogged'] as num?)?.toInt() ?? 0;
          final isTutor = tutorUid == myUid;

          return Column(
            children: [
              _Header(topPadding: topPadding, title: subject),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusBanner(status: status, hoursLogged: hoursLogged),
                      const SizedBox(height: 18),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
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
                            _PeerRow(
                              role: 'Tutor',
                              name: tutorName,
                              isMe: isTutor,
                            ),
                            const SizedBox(height: 12),
                            _PeerRow(
                              role: 'Elev',
                              name: learnerName,
                              isMe: !isTutor,
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            _InfoRow(
                              icon: Icons.menu_book_rounded,
                              label: 'Materie',
                              value: subject,
                            ),
                            if (availability.isNotEmpty)
                              _InfoRow(
                                icon: Icons.schedule_rounded,
                                label: 'Disponibilitate',
                                value: availability,
                              ),
                            if (notes.isNotEmpty)
                              _InfoRow(
                                icon: Icons.notes_rounded,
                                label: 'Detalii',
                                value: notes,
                              ),
                            if (status == 'completed')
                              _InfoRow(
                                icon: Icons.access_time_rounded,
                                label: 'Ore validate',
                                value: '$hoursLogged ore',
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (status == 'pending') ...[
                        _ActionButton(
                          label: 'Confirma sesiune',
                          icon: Icons.check_rounded,
                          onTap: _confirmSession,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (status == 'pending' || status == 'confirmed') ...[
                        _ActionButton(
                          label: 'Anuleaza',
                          icon: Icons.close_rounded,
                          onTap: _cancelSession,
                          danger: true,
                        ),
                      ],
                      if (status == 'confirmed')
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'Dirigintele va valida sesiunea si va confirma orele dupa intalnire.',
                              style: TextStyle(
                                color: _outline,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HEADER
// ────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final double topPadding;
  final String title;
  const _Header({required this.topPadding, required this.title});

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// STATUS BANNER
// ────────────────────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String status;
  final int hoursLogged;
  const _StatusBanner({required this.status, required this.hoursLogged});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;
    switch (status) {
      case 'pending':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        icon = Icons.hourglass_top_rounded;
        label = 'In asteptarea confirmarii';
        break;
      case 'confirmed':
        bg = _primary.withValues(alpha: 0.1);
        fg = _primary;
        icon = Icons.check_circle_outline_rounded;
        label = 'Sesiune confirmata';
        break;
      case 'completed':
        bg = _primary.withValues(alpha: 0.12);
        fg = _primary;
        icon = Icons.verified_rounded;
        label = '$hoursLogged ore validate';
        break;
      default:
        bg = const Color(0xFFFCE4EC);
        fg = const Color(0xFFC62828);
        icon = Icons.cancel_rounded;
        label = 'Sesiune anulata';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// PEER ROW
// ────────────────────────────────────────────────────────────────────────────
class _PeerRow extends StatelessWidget {
  final String role;
  final String name;
  final bool isMe;
  const _PeerRow({
    required this.role,
    required this.name,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _primary.withValues(alpha: 0.12),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: _primary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: const TextStyle(
                  color: _outline,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                name.isEmpty ? 'Necunoscut' : name,
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (isMe)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Tu',
              style: TextStyle(
                color: _primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _outline, size: 18),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
              color: _outline,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: danger
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF1F8BE7), Color(0xFF328FDF)],
                ),
          color: danger ? const Color(0xFFFCE4EC) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: danger ? const Color(0xFFC62828) : Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: danger ? const Color(0xFFC62828) : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
