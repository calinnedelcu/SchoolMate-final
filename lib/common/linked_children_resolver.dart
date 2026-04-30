import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Returns the union of child UIDs linked to [parentUid] across the three
/// legacy schemas: `users.parents` (array), `users.parentUid`, `users.parentId`.
/// A failure on any single query is logged but does not abort the others.
/// [parentUid] itself is excluded from the result.
Future<Set<String>> resolveLinkedChildIds(
  String parentUid, {
  FirebaseFirestore? firestore,
  String tag = 'linked_children_resolver',
}) async {
  if (parentUid.isEmpty) return <String>{};

  final fs = firestore ?? FirebaseFirestore.instance;
  final users = fs.collection('users');
  final ids = <String>{};

  try {
    final byParents =
        await users.where('parents', arrayContains: parentUid).get();
    ids.addAll(byParents.docs.map((doc) => doc.id));
  } catch (e, st) {
    debugPrint('$tag: query children by parents array: $e\n$st');
  }

  try {
    final byParentUid =
        await users.where('parentUid', isEqualTo: parentUid).get();
    ids.addAll(byParentUid.docs.map((doc) => doc.id));
  } catch (e, st) {
    debugPrint('$tag: query children by parentUid: $e\n$st');
  }

  try {
    final byParentId =
        await users.where('parentId', isEqualTo: parentUid).get();
    ids.addAll(byParentId.docs.map((doc) => doc.id));
  } catch (e, st) {
    debugPrint('$tag: query children by parentId: $e\n$st');
  }

  ids.remove(parentUid);
  return ids;
}
