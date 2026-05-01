import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';

import 'admin_classes_page.dart';
import 'admin_parents_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_turnstiles_page.dart';

Future<T?> _showBlurDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Duration transitionDuration = const Duration(milliseconds: 220),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel:
        barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: transitionDuration,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return builder(dialogContext);
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );

      return AnimatedBuilder(
        animation: curvedAnimation,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 14 * curvedAnimation.value,
                    sigmaY: 14 * curvedAnimation.value,
                  ),
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: 0.55 * curvedAnimation.value,
                    ),
                  ),
                ),
              ),
              FadeTransition(opacity: curvedAnimation, child: child),
            ],
          );
        },
      );
    },
  );
}

Widget _wrapBlurredPopupBackground(Widget child) {
  return Stack(
    children: [
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(color: Colors.black.withValues(alpha: 0.3)),
        ),
      ),
      child,
    ],
  );
}

class AdminVacantePage extends StatefulWidget {
  const AdminVacantePage({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<AdminVacantePage> createState() => _AdminVacantePageState();
}

class _AdminVacantePageState extends State<AdminVacantePage> {
  bool _sidebarNavigationBusy = false;

  Future<void> _openSidebarPage(Widget page) async {
    if (_sidebarNavigationBusy || !mounted) return;
    _sidebarNavigationBusy = true;
    try {
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) => page,
        ),
      );
    } finally {
      _sidebarNavigationBusy = false;
    }
  }

  Future<void> _showLogoutDialog() async {
    await _showBlurDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access denied (admin only)")),
      );
    }

    final content = Container(
      color: const Color(0xFFF2F4F8),
      child: Column(
        children: [
          if (!widget.embedded) const _TopBar(),
          const Expanded(child: _VacanciesContent()),
        ],
      ),
    );

    if (widget.embedded) return content;

    final displayName = (AppSession.fullName?.trim().isNotEmpty == true)
        ? AppSession.fullName!.trim()
        : ((AppSession.username?.trim().isNotEmpty == true)
              ? AppSession.username!.trim()
              : 'Secretariat');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                _Sidebar(
                  displayName: displayName,
                  onMenuTap: () {},
                  onStudentsTap: () => _openSidebarPage(
                    const AdminStudentsPage(key: ValueKey('students-page-v2')),
                  ),
                  onPersonalTap: () =>
                      _openSidebarPage(const AdminTeachersPage()),
                  onTurnichetiTap: () =>
                      _openSidebarPage(const AdminTurnstilesPage()),
                  onClaseTap: () => _openSidebarPage(const AdminClassesPage()),
                  onParintiTap: () =>
                      _openSidebarPage(const AdminParentsPage()),
                  onLogoutTap: _showLogoutDialog,
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String displayName;
  final VoidCallback onMenuTap;
  final VoidCallback onStudentsTap;
  final VoidCallback onPersonalTap;
  final VoidCallback onTurnichetiTap;
  final VoidCallback onClaseTap;
  final VoidCallback onParintiTap;
  final VoidCallback onLogoutTap;

  const _Sidebar({
    required this.displayName,
    required this.onMenuTap,
    required this.onStudentsTap,
    required this.onPersonalTap,
    required this.onTurnichetiTap,
    required this.onClaseTap,
    required this.onParintiTap,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2040A0), Color(0xFF2848B0), Color(0xFF2E58D0)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'Secretariat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _SidebarTile(
            label: 'Menu',
            icon: Icons.grid_view_rounded,
            selected: false,
            onTap: onMenuTap,
          ),
          _SidebarTile(
            label: 'Students',
            icon: Icons.school_rounded,
            onTap: onStudentsTap,
          ),
          _SidebarTile(
            label: 'Staff',
            icon: Icons.badge_rounded,
            onTap: onPersonalTap,
          ),
          _SidebarTile(
            label: 'Parents',
            icon: Icons.family_restroom_rounded,
            onTap: onParintiTap,
          ),
          _SidebarTile(
            label: 'Classes',
            icon: Icons.table_chart_rounded,
            onTap: onClaseTap,
          ),
          _SidebarTile(
            label: 'Guardians',
            icon: Icons.door_front_door_rounded,
            onTap: onTurnichetiTap,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1988E6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: onLogoutTap,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7E2C5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7A4A10),
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Central High School',
                        style: TextStyle(
                          color: Color(0xFFE8EAF2),
                          fontSize: 11,
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
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.17)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFE8EAF2), size: 18),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFE8EAF2),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3CA0), Color(0xFF2E58D0), Color(0xFF4070E0)],
        ),
      ),
      child: Row(
        children: [
          const Text(
            'School Vacations',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4395DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: Color(0xFFC0C4D8), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search records...',
                          style: TextStyle(
                            color: Color(0xFFC0C4D8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _VacanciesContent extends StatefulWidget {
  const _VacanciesContent();

  @override
  State<_VacanciesContent> createState() => _VacanciesContentState();
}

class _VacanciesContentState extends State<_VacanciesContent> {
  final _nameController = TextEditingController();
  int _currentPage = 0;
  static const int _pageSize = 6;
  bool _monthTransitionForward = true;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime _displayMonth = DateTime.now();
  String? _selectedDocId;
  String? _selectedVacancyName;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _editing = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateLong(DateTime date) {
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _resetForm() {
    _nameController.clear();
    _startDate = null;
    _endDate = null;
    _displayMonth = DateTime.now();
    _selectedDocId = null;
    _selectedVacancyName = null;
    _selectedStartDate = null;
    _selectedEndDate = null;
    _editing = false;
  }

  void _startCreatingVacancy() {
    setState(() {
      _nameController.clear();
      _startDate = null;
      _endDate = null;
      _displayMonth = DateTime.now();
      _selectedDocId = null;
      _selectedVacancyName = null;
      _selectedStartDate = null;
      _selectedEndDate = null;
      _editing = true;
    });
  }

  void _startEditingSelectedVacancy() {
    if (_selectedDocId == null) return;
    setState(() {
      _nameController.text = _selectedVacancyName ?? '';
      _startDate = _selectedStartDate;
      _endDate = _selectedEndDate;
      if (_selectedStartDate != null) {
        _displayMonth = _selectedStartDate!;
      }
      _editing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      if (_selectedDocId != null) {
        _nameController.text = _selectedVacancyName ?? '';
        _startDate = _selectedStartDate;
        _endDate = _selectedEndDate;
        if (_selectedStartDate != null) {
          _displayMonth = _selectedStartDate!;
        }
      } else {
        _nameController.clear();
        _startDate = null;
        _endDate = null;
        _displayMonth = DateTime.now();
      }
      _editing = false;
    });
  }

  Future<void> _saveVacancy() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the vacation name')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start date and end date'),
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final isUpdating = _selectedDocId != null;

    try {
      if (isUpdating) {
        await FirebaseFirestore.instance
            .collection('vacancies')
            .doc(_selectedDocId)
            .update({
              'name': name,
              'startDate': _startDate,
              'endDate': _endDate,
            });
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('vacancies')
            .add({
              'name': name,
              'startDate': _startDate,
              'endDate': _endDate,
              'createdAt': FieldValue.serverTimestamp(),
            });
        _selectedDocId = doc.id;
      }

      if (!mounted) return;

      setState(() {
        _selectedVacancyName = name;
        _selectedStartDate = _startDate;
        _selectedEndDate = _endDate;
        _nameController.text = name;
        if (_startDate != null) {
          _displayMonth = _startDate!;
        }
        _editing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdating
                ? 'Vacation saved successfully'
                : 'Vacation added successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is FirebaseException && e.code == 'permission-denied'
          ? 'You do not have permission to create vacations. Check the account role and published Firestore rules.'
          : 'Error saving vacation';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _confirmDeleteVacancy({required String name}) async {
    final result = await _showBlurDialog<bool>(
      context: context,
      barrierLabel: 'Confirm vacation deletion',
      transitionDuration: const Duration(milliseconds: 180),
      builder: (ctx) {
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0D0D8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFB03040),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delete vacation',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2848B0),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'This action is permanent and will remove the vacation from the saved list.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Color(0xFF7A7E9A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F8),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE8EAF2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selected vacation',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: Color(0xFF7A7E9A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0D0D8),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB03040),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFE8EAF2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFB03040),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Delete vacation'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'School Vacation Settings',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2848B0),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Configure rest periods and manage school vacations.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7A7E9A),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh_rounded),
                color: const Color(0xFF2848B0),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: _buildFormSection()),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: _buildUpcomingVacancies()),
              ],
            ),
          ),
          const SizedBox(height: 112),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    final hasSelectedVacancy = _selectedDocId != null;
    final isCreatingVacancy = _editing && !hasSelectedVacancy;
    final displayedName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_selectedVacancyName ?? 'No vacation selected');
    final displayedStart = _editing ? _startDate : _selectedStartDate;
    final displayedEnd = _editing ? _endDate : _selectedEndDate;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Vacation Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2848B0),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              !_editing
                  ? hasSelectedVacancy
                        ? 'You can edit the selected vacation and save changes quickly.'
                        : 'Create a new vacation and configure the interval from the calendar.'
                  : hasSelectedVacancy
                  ? 'Update the name and period, then save the vacation.'
                  : 'Fill in the fields and save the new vacation.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF87A1B6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Visibility(
            visible: !isCreatingVacancy,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _startCreatingVacancy,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Create vacation'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2848B0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!_editing && !hasSelectedVacancy)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: const Center(
                  child: Text(
                    'Select a vacation from the list on the right or press "Create vacation" to add a new one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF8A9487),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          if (_editing || hasSelectedVacancy) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing
                          ? 'Fill in the vacation period'
                          : 'Selected vacation details',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A7E9A),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Visibility(
                      visible: !_editing && hasSelectedVacancy,
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true,
                      child: OutlinedButton.icon(
                        onPressed: _startEditingSelectedVacancy,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, thickness: 1, color: Color(0xFFE8EAF2)),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'EVENT / VACATION NAME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Color(0xFF2848B0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _nameController,
                            enabled: _editing,
                            onChanged: _editing ? (_) => setState(() {}) : null,
                            decoration: InputDecoration(
                              hintText: 'E.g.: Spring Break',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF2F4F8),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'START DATE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: Color(0xFF2848B0),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: !_editing
                                          ? null
                                          : () async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    _startDate ??
                                                    DateTime.now(),
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime(2030),
                                                builder: (context, child) =>
                                                    _wrapBlurredPopupBackground(
                                                      child ??
                                                          const SizedBox.shrink(),
                                                    ),
                                              );
                                              if (picked != null) {
                                                setState(() {
                                                  _startDate = picked;
                                                  _displayMonth = picked;
                                                  if (_endDate != null &&
                                                      _endDate!.isBefore(
                                                        picked,
                                                      )) {
                                                    _endDate = null;
                                                  }
                                                });
                                              }
                                            },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF2F4F8),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _startDate == null
                                                    ? 'dd/mm/yyyy'
                                                    : _formatDate(_startDate!),
                                                style: TextStyle(
                                                  color: _startDate == null
                                                      ? const Color(0xFF7A7E9A)
                                                      : const Color(0xFF1A2050),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 16,
                                              color: Color(0xFF7A7E9A),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'END DATE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: Color(0xFF2848B0),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: !_editing
                                          ? null
                                          : () async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    _endDate ??
                                                    _startDate ??
                                                    DateTime.now(),
                                                firstDate:
                                                    _startDate ??
                                                    DateTime(2020),
                                                lastDate: DateTime(2030),
                                                builder: (context, child) =>
                                                    _wrapBlurredPopupBackground(
                                                      child ??
                                                          const SizedBox.shrink(),
                                                    ),
                                              );
                                              if (picked != null) {
                                                setState(() {
                                                  _endDate = picked;
                                                });
                                              }
                                            },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF2F4F8),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _endDate == null
                                                    ? 'dd/mm/yyyy'
                                                    : _formatDate(_endDate!),
                                                style: TextStyle(
                                                  color: _endDate == null
                                                      ? const Color(0xFF7A7E9A)
                                                      : const Color(0xFF1A2050),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 16,
                                              color: Color(0xFF7A7E9A),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F7FB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE8EAF2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Summary',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF7A7E9A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  displayedName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2848B0),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  displayedStart != null && displayedEnd != null
                                      ? '${_formatDateLong(displayedStart)} - ${_formatDateLong(displayedEnd)}'
                                      : 'Select the interval from the calendar.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7A7E9A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: SizedBox(
                            height: 48,
                            child: Visibility(
                              visible: _editing,
                              maintainState: true,
                              maintainAnimation: true,
                              maintainSize: true,
                              child: Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: _cancelEditing,
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _saveVacancy,
                                      icon: Icon(
                                        _editing
                                            ? Icons.save_outlined
                                            : Icons.calendar_month_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _editing
                                            ? 'Save vacation'
                                            : 'Create vacation',
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF2848B0,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _buildCalendar()),
                        SizedBox(
                          height: 28,
                          child: Center(
                            child: Visibility(
                              visible:
                                  _selectedVacancyName != null ||
                                  _nameController.text.isNotEmpty,
                              maintainState: true,
                              maintainAnimation: true,
                              maintainSize: true,
                              child: Text(
                                '* Preview: $displayedName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2848B0),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
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
          ],
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final year = _displayMonth.year;
    final month = _displayMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday;

    const monthNames = [
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
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDF3F8),
        border: Border.all(color: const Color(0xFFD3E0EB), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () {
                  setState(() {
                    _monthTransitionForward = false;
                    _displayMonth = DateTime(
                      _displayMonth.year,
                      _displayMonth.month - 1,
                    );
                  });
                },
              ),
              Text(
                '${monthNames[_displayMonth.month - 1]} ${_displayMonth.year}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5E89AF),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () {
                  setState(() {
                    _monthTransitionForward = true;
                    _displayMonth = DateTime(
                      _displayMonth.year,
                      _displayMonth.month + 1,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in dayNames)
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C9EBC),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.center,
                  children: [...previousChildren, ?currentChild],
                );
              },
              transitionBuilder: (child, animation) {
                final beginOffset = _monthTransitionForward
                    ? const Offset(0.08, 0)
                    : const Offset(-0.08, 0);

                return ClipRect(
                  child: FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: beginOffset,
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey('${_displayMonth.year}-${_displayMonth.month}'),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final rows = ((firstWeekday - 1 + daysInMonth) / 7).ceil();
                    const crossSpacing = 8.0;
                    const mainSpacing = 8.0;
                    final squareSize = [
                      (constraints.maxWidth - crossSpacing * 6) / 7,
                      (constraints.maxHeight - mainSpacing * (rows - 1)) / rows,
                    ].reduce((a, b) => a < b ? a : b);
                    final gridWidth = squareSize * 7 + crossSpacing * 6;
                    final gridHeight =
                        squareSize * rows + mainSpacing * (rows - 1);

                    return Center(
                      child: SizedBox(
                        width: gridWidth,
                        height: gridHeight,
                        child: GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: false,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1,
                          mainAxisSpacing: mainSpacing,
                          crossAxisSpacing: crossSpacing,
                          children: [
                            ...List.generate(
                              firstWeekday - 1,
                              (_) => const SizedBox.expand(),
                            ),
                            ...List.generate(daysInMonth, (index) {
                              final day = index + 1;
                              final date = DateTime(year, month, day);
                              final isStart =
                                  _startDate != null &&
                                  _isSameDay(date, _startDate!);
                              final isEnd =
                                  _endDate != null &&
                                  _isSameDay(date, _endDate!);
                              final isBetween =
                                  _startDate != null &&
                                  _endDate != null &&
                                  date.isAfter(_startDate!) &&
                                  date.isBefore(_endDate!);

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_startDate == null) {
                                      _startDate = date;
                                    } else if (_endDate == null) {
                                      if (date.isBefore(_startDate!)) {
                                        _endDate = _startDate;
                                        _startDate = date;
                                      } else {
                                        _endDate = date;
                                      }
                                    } else {
                                      _startDate = date;
                                      _endDate = null;
                                    }
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isStart || isEnd
                                        ? const Color(0xFF2848B0)
                                        : isBetween
                                        ? const Color(0xFFC3D9EB)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    day.toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isStart || isEnd
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingVacancies() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vacancies')
            .orderBy('startDate')
            .snapshots(),
        builder: (context, snapshot) {
          final vacancies = snapshot.hasData
              ? snapshot.data!.docs.toList()
              : <QueryDocumentSnapshot>[];
          final totalPages = vacancies.isEmpty
              ? 0
              : (vacancies.length / _pageSize).ceil();
          final currentPage = totalPages == 0
              ? 0
              : _currentPage.clamp(0, totalPages - 1);
          final visibleVacancies = totalPages == 0
              ? <QueryDocumentSnapshot>[]
              : vacancies
                    .skip(currentPage * _pageSize)
                    .take(_pageSize)
                    .toList();

          Widget listWidget;
          if (snapshot.hasError) {
            listWidget = const Center(
              child: Text(
                'No vacations created',
                style: TextStyle(fontSize: 13, color: Color(0xFF7A7E9A)),
              ),
            );
          } else if (!snapshot.hasData) {
            listWidget = const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            );
          } else if (vacancies.isEmpty) {
            listWidget = const Center(
              child: Text(
                'No vacations created',
                style: TextStyle(fontSize: 13, color: Color(0xFF7A7E9A)),
              ),
            );
          } else {
            listWidget = ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: visibleVacancies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 0),
              itemBuilder: (context, index) {
                final vacancy = visibleVacancies[index];
                return _buildVacancyCard(
                  vacancy,
                  currentPage == 0 && index == 0,
                  vacancy.id == _selectedDocId,
                );
              },
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saved Vacations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5284AF),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${vacancies.length} vacations registered',
                style: const TextStyle(fontSize: 13, color: Color(0xFF7A7E9A)),
              ),
              const SizedBox(height: 20),
              Expanded(child: listWidget),
              if (totalPages > 1) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE8EAF2))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _PaginationButton(
                        icon: Icons.chevron_left_rounded,
                        enabled: currentPage > 0,
                        onTap: () =>
                            setState(() => _currentPage = currentPage - 1),
                      ),
                      const SizedBox(width: 4),
                      ..._buildPageButtons(totalPages, currentPage),
                      const SizedBox(width: 4),
                      _PaginationButton(
                        icon: Icons.chevron_right_rounded,
                        enabled: currentPage < totalPages - 1,
                        onTap: () =>
                            setState(() => _currentPage = currentPage + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPageButtons(int totalPages, int currentPage) {
    final pages = <Widget>[];
    const maxVisible = 5;

    void addPage(int index) {
      pages.add(
        GestureDetector(
          onTap: () => setState(() => _currentPage = index),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: currentPage == index
                  ? const Color(0xFF1A2050)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: currentPage == index
                    ? const Color(0xFF1A2050)
                    : const Color(0xFFE8EAF2),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: currentPage == index
                    ? Colors.white
                    : const Color(0xFF1A2050),
              ),
            ),
          ),
        ),
      );
    }

    void addEllipsis() {
      pages.add(
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          child: const Text(
            '...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7A7E9A),
            ),
          ),
        ),
      );
    }

    if (totalPages <= maxVisible) {
      for (int i = 0; i < totalPages; i++) {
        addPage(i);
      }
    } else {
      addPage(0);

      if (currentPage > 2) {
        addEllipsis();
      }

      final start = (currentPage - 1).clamp(1, totalPages - 2);
      final end = (currentPage + 1).clamp(1, totalPages - 2);
      for (int i = start; i <= end; i++) {
        addPage(i);
      }

      if (currentPage < totalPages - 3) {
        addEllipsis();
      }

      addPage(totalPages - 1);
    }

    return pages;
  }

  Widget _buildVacancyCard(
    QueryDocumentSnapshot doc,
    bool isFirst,
    bool isSelected,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final startDate = (data['startDate'] as Timestamp).toDate();
    final endDate = (data['endDate'] as Timestamp).toDate();
    final name = data['name'] ?? 'Vacation';

    final now = DateTime.now();
    final isFinished = endDate.isBefore(DateTime(now.year, now.month, now.day));

    final Color cardColor;
    final Color nameColor;
    final Color iconColor;
    final Color dateColor;
    final Border? border;

    if (isSelected) {
      cardColor = const Color(0xFF2848B0);
      nameColor = Colors.white;
      iconColor = Colors.white;
      dateColor = Colors.white.withValues(alpha: 0.85);
      border = Border.all(color: const Color(0xFF2848B0), width: 2);
    } else if (isFinished) {
      cardColor = const Color(0xFFF0F0F0);
      nameColor = const Color(0xFF888888);
      iconColor = const Color(0xFFAAAAAA);
      dateColor = const Color(0xFFAAAAAA);
      border = Border.all(color: const Color(0xFFDDDDDD), width: 1);
    } else if (isFirst) {
      cardColor = const Color(0xFF2848B0);
      nameColor = Colors.white;
      iconColor = Colors.white;
      dateColor = Colors.white;
      border = null;
    } else {
      cardColor = const Color(0xFFE8EAF2);
      nameColor = const Color(0xFF2848B0);
      iconColor = const Color(0xFFB03040);
      dateColor = const Color(0xFF666666);
      border = Border.all(color: const Color(0xFFC3D9EB), width: 1);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedDocId == doc.id) {
            _selectedDocId = null;
            _selectedVacancyName = null;
            _selectedStartDate = null;
            _selectedEndDate = null;
            _nameController.clear();
            _startDate = null;
            _endDate = null;
            _displayMonth = DateTime.now();
            _editing = false;
          } else {
            _selectedDocId = doc.id;
            _selectedVacancyName = name;
            _selectedStartDate = startDate;
            _selectedEndDate = endDate;
            _nameController.text = name;
            _startDate = startDate;
            _endDate = endDate;
            _displayMonth = startDate;
            _editing = false;
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFinished ? '$name - Finished' : name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: nameColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: iconColor),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatDateLong(startDate)} - ${_formatDateLong(endDate)}',
                        style: TextStyle(fontSize: 11, color: dateColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                final confirmed = await _confirmDeleteVacancy(name: name);
                if (!confirmed || !mounted) return;

                await FirebaseFirestore.instance
                    .collection('vacancies')
                    .doc(doc.id)
                    .delete();
                if (!mounted) return;

                if (_selectedDocId == doc.id) {
                  setState(() {
                    _resetForm();
                  });
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vacation deleted successfully')),
                );
              },
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Color(0xFFB03040),
              ),
              splashRadius: 18,
              tooltip: 'Delete vacation',
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFFE8EAF2) : const Color(0xFFE8EAF2),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? const Color(0xFF1A2050) : const Color(0xFFC0C4D8),
        ),
      ),
    );
  }
}
