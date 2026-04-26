import 'package:cloud_firestore/cloud_firestore.dart';

class BookmarkItem {
  final String itemId;
  final String itemType;
  final String category;
  final String title;
  final String message;
  final String link;
  final String senderName;
  final String location;
  final DateTime? eventDate;
  final DateTime? eventEndDate;
  final int hoursWorth;
  final DateTime? savedAt;
  final Map<String, dynamic> raw;

  const BookmarkItem({
    required this.itemId,
    required this.itemType,
    required this.category,
    required this.title,
    required this.message,
    required this.link,
    required this.senderName,
    required this.location,
    required this.eventDate,
    required this.eventEndDate,
    required this.hoursWorth,
    required this.savedAt,
    required this.raw,
  });

  factory BookmarkItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return BookmarkItem(
      itemId: doc.id,
      itemType: (data['itemType'] ?? 'post').toString(),
      category: (data['category'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      link: (data['link'] ?? '').toString(),
      senderName: (data['senderName'] ?? '').toString(),
      location: (data['location'] ?? '').toString(),
      eventDate: (data['eventDate'] as Timestamp?)?.toDate(),
      eventEndDate: (data['eventEndDate'] as Timestamp?)?.toDate(),
      hoursWorth: ((data['hoursWorth'] as num?) ?? 0).toInt(),
      savedAt: (data['savedAt'] as Timestamp?)?.toDate(),
      raw: data,
    );
  }
}

class BookmarksService {
  static CollectionReference<Map<String, dynamic>> _ref(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('bookmarks');

  static Stream<bool> isBookmarked(String uid, String itemId) {
    if (uid.isEmpty || itemId.isEmpty) return Stream.value(false);
    return _ref(uid).doc(itemId).snapshots().map((s) => s.exists);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> stream(String uid) {
    return _ref(uid).orderBy('savedAt', descending: true).snapshots();
  }

  static Future<void> add({
    required String uid,
    required String itemId,
    required String itemType,
    required String category,
    required String title,
    String message = '',
    String link = '',
    String senderName = '',
    String location = '',
    DateTime? eventDate,
    DateTime? eventEndDate,
    int hoursWorth = 0,
  }) {
    if (uid.isEmpty || itemId.isEmpty) return Future.value();
    return _ref(uid).doc(itemId).set({
      'itemType': itemType,
      'category': category,
      'title': title,
      'message': message,
      'link': link,
      'senderName': senderName,
      'location': location,
      'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate),
      'eventEndDate':
          eventEndDate == null ? null : Timestamp.fromDate(eventEndDate),
      'hoursWorth': hoursWorth,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> remove({
    required String uid,
    required String itemId,
  }) {
    if (uid.isEmpty || itemId.isEmpty) return Future.value();
    return _ref(uid).doc(itemId).delete();
  }
}
