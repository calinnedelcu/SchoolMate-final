import 'package:flutter/material.dart';
import 'package:school_mate/common/unified_messages_page.dart';

class ParentInboxPage extends StatelessWidget {
  const ParentInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedMessagesPage(role: UnifiedInboxRole.parent);
  }
}
