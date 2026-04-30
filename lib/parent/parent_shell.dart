import 'package:flutter/material.dart';

import '../common/widgets/maniubara.dart';
import 'parent_home_page.dart';
import 'parent_students_page.dart';

class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int _index = 0;

  static const _items = <BottomNavItemSpec>[
    BottomNavItemSpec(icon: Icons.home_rounded, label: 'Home'),
    BottomNavItemSpec(icon: Icons.group_rounded, label: 'Children'),
    BottomNavItemSpec(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: FixedBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _items,
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          ParentHomePage(),
          ParentStudentsPage(showBack: false),
          ParentProfilePage(showBack: false),
        ],
      ),
    );
  }
}
