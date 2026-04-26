import 'package:flutter/material.dart';

import '../admin/admin_post_composer_page.dart';
import '../common/unified_messages_page.dart';
import '../student/widgets/no_anim_route.dart';

class MesajeDirPage extends StatelessWidget {
  const MesajeDirPage({super.key});

  @override
  Widget build(BuildContext context) {
    return UnifiedMessagesPage(
      role: UnifiedInboxRole.teacher,
      onCreatePost: () => Navigator.push(
        context,
        noAnimRoute(
          (_) => const AdminPostComposerPage(mode: PostComposerMode.teacher),
        ),
      ),
    );
  }
}
