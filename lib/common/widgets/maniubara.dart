import 'package:flutter/material.dart';

const _primary = Color(0xFF2848B0);
const _activeBg = Color(0xFFE3E8F8);
const _inactive = Color(0xFF7A7E9A);
const _surface = Color(0xFFFFFFFF);

class BottomNavItemSpec {
  final IconData icon;
  final String label;
  const BottomNavItemSpec({required this.icon, required this.label});
}

const _studentNavItems = <BottomNavItemSpec>[
  BottomNavItemSpec(icon: Icons.home_rounded, label: 'Home'),
  BottomNavItemSpec(icon: Icons.calendar_month_rounded, label: 'Schedule'),
  BottomNavItemSpec(icon: Icons.person_rounded, label: 'Profile'),
];

class FixedBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItemSpec> items;

  const FixedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = _studentNavItems,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++)
              _NavItem(
                icon: items[i].icon,
                label: items[i].label,
                selected: currentIndex == i,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? _primary : _inactive;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? _activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
