import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../utils/password_hash.dart';
import '../models/user_role.dart';

class AdminStore {
  final _db = FirebaseFirestore.instance;

  Future<void> createUser({
    required String username,
    required String password,
    required String role, // student|teacher|admin|gate
    required String fullName,
    String? classId,
  }) async {
    username = username.trim().toLowerCase();

    if (username.isEmpty || password.isEmpty || fullName.isEmpty) {
      throw Exception("Missing fields");
    }
    final parsedRole = UserRole.fromWire(role);
    if (parsedRole == null) {
      throw Exception("Invalid role");
    }
    if (parsedRole.requiresClassId &&
        (classId == null || classId.trim().isEmpty)) {
      throw Exception("classId required for $role");
    }
    // If student/teacher, the class MUST already exist in /classes
    if (parsedRole.requiresClassId) {
      final cId = classId!.trim().toUpperCase();
      final classSnap = await _db.collection('classes').doc(cId).get();

      if (!classSnap.exists) {
        throw Exception("Class $cId does not exist");
      }
    }
    final ref = _db.collection('users').doc(username);
    final snap = await ref.get();
    if (snap.exists) throw Exception("Username already exists");
    if (parsedRole == UserRole.teacher) {
      await _createTeacherAndAssign(
        username: username,
        password: password,
        fullName: fullName,
        classId: classId!,
      );
      return;
    }
    final hp = await PasswordHash.hashPassword(password);
    await ref.set({
      "username": username,
      "role": parsedRole.wire,
      "fullName": fullName,
      "classId": parsedRole.requiresClassId
          ? classId!.trim().toUpperCase()
          : null,
      "status": "active",
      "passwordAlgo": hp["algo"],
      "passwordSalt": hp["saltB64"],
      "passwordHash": hp["hashB64"],
      "createdAt": FieldValue.serverTimestamp(),
      // Onboarding fields
      "onboardingComplete": false,
      "emailVerified": false,
      "passwordChanged": false,
      "personalEmail": null,
    });
  }

  Future<void> setClassNoExitSchedule({
    required String classId,
    required String startHHmm,
    required String endHHmm,
  }) async {
    classId = classId.trim().toUpperCase();
    if (classId.isEmpty) throw Exception("classId missing");

    // (optional) verify HH:mm format
    bool ok(String s) => RegExp(r'^\d{2}:\d{2}$').hasMatch(s);
    if (!ok(startHHmm) || !ok(endHHmm)) {
      throw Exception("Invalid format. Use HH:mm (e.g. 07:30)");
    }

    // the class must exist (as requested)
    final classRef = _db.collection('classes').doc(classId);
    final snap = await classRef.get();
    if (!snap.exists) throw Exception("Class $classId does not exist");

    await classRef.set({
      "noExitStart": startHHmm,
      "noExitEnd": endHHmm,
      "noExitDays": [1, 2, 3, 4, 5],
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setClassNoExitScheduleForDays({
    required String classId,
    required String startHHmm,
    required String endHHmm,
    required List<String> days,
  }) async {
    classId = classId.trim().toUpperCase();
    if (classId.isEmpty) throw Exception("classId missing");

    // (optional) verify HH:mm format
    bool ok(String s) => RegExp(r'^\d{2}:\d{2}$').hasMatch(s);
    if (!ok(startHHmm) || !ok(endHHmm)) {
      throw Exception("Invalid format. Use HH:mm (e.g. 07:30)");
    }

    // the class must exist
    final classRef = _db.collection('classes').doc(classId);
    final snap = await classRef.get();
    if (!snap.exists) throw Exception("Class $classId does not exist");

    // convert day names to numbers (1-5)
    final dayMapping = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
    };

    final dayNumbers = days
        .map((day) => dayMapping[day])
        .whereType<int>()
        .toList();

    await classRef.set({
      "noExitStart": startHHmm,
      "noExitEnd": endHHmm,
      "noExitDays": dayNumbers,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteClassCascade(String classId) async {
    classId = classId.trim().toUpperCase();
    if (classId.isEmpty) throw Exception("classId missing");

    final classRef = _db.collection('classes').doc(classId);

    // get teacherUsername first
    final classSnap = await classRef.get();
    final teacherUsername = (classSnap.data()?['teacherUsername'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    // 1) delete all students from this class
    final studentsSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('classId', isEqualTo: classId)
        .get();

    final batch = _db.batch();
    for (final d in studentsSnap.docs) {
      batch.delete(d.reference);
    }

    // 2) if a teacher exists -> unassign them from this class (do NOT delete the user)
    if (teacherUsername.isNotEmpty) {
      final tRef = _db.collection('users').doc(teacherUsername);
      batch.update(tRef, {
        "classId": FieldValue.delete(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    // 3) delete the class
    batch.delete(classRef);

    await batch.commit();
  }

  Future<void> _createTeacherAndAssign({
    required String username,
    required String password,
    required String fullName,
    required String classId,
  }) async {
    username = username.trim().toLowerCase();
    classId = classId.trim().toUpperCase();

    final userRef = _db.collection('users').doc(username);
    final classRef = _db.collection('classes').doc(classId);

    final hp = await PasswordHash.hashPassword(password);

    await _db.runTransaction((tx) async {
      final uSnap = await tx.get(userRef);
      if (uSnap.exists) throw Exception("Username already exists");

      final cSnap = await tx.get(classRef);
      final existingTeacher = cSnap.exists
          ? ((cSnap.data() as Map<String, dynamic>)['teacherUsername'] ?? '')
                .toString()
                .trim()
                .toLowerCase()
          : '';
      if (existingTeacher.isNotEmpty) {
        throw Exception("Class $classId already has a head teacher: $existingTeacher");
      }

      // 1) create teacher user
      tx.set(userRef, {
        "username": username,
        "role": UserRole.teacher.wire,
        "fullName": fullName,
        "classId": classId,
        "status": "active",
        "passwordAlgo": hp["algo"],
        "passwordSalt": hp["saltB64"],
        "passwordHash": hp["hashB64"],
        "createdAt": FieldValue.serverTimestamp(),
        // Onboarding fields
        "onboardingComplete": false,
        "emailVerified": false,
        "passwordChanged": false,
        "personalEmail": null,
      });

      // 2) set teacher on the class
      tx.set(classRef, {
        "name": classId,
        "teacherUsername": username,
        "updatedAt": FieldValue.serverTimestamp(),
        "createdAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<String> resetPassword(String username) async {
    username = username.trim().toLowerCase();
    final newPass = _randomPass(10);
    final hp = await PasswordHash.hashPassword(newPass);
    await _db.collection('users').doc(username).update({
      "passwordAlgo": hp["algo"],
      "passwordSalt": hp["saltB64"],
      "passwordHash": hp["hashB64"],
    });
    return newPass; // secretariat copies it
  }

  Future<void> deleteUser(String username) async {
    username = username.trim().toLowerCase();
    if (username.isEmpty) throw Exception("username missing");

    Future<void> clearTeacherFromClasses() async {
      final classesSnap = await _db
          .collection('classes')
          .where('teacherUsername', isEqualTo: username)
          .get();
      if (classesSnap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final classDoc in classesSnap.docs) {
        batch.set(classDoc.reference, {
          "teacherUsername": FieldValue.delete(),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }

    Future<void> clearTeacherFromTimetables() async {
      final timetablesSnap = await _db.collection('timetables').get();
      final batch = _db.batch();
      bool hasUpdates = false;
      for (final doc in timetablesSnap.docs) {
        final days = (doc.data()['days'] as Map<String, dynamic>?);
        if (days == null) continue;
        final updates = <String, dynamic>{};
        for (final dayEntry in days.entries) {
          final lessons = dayEntry.value as Map<String, dynamic>?;
          if (lessons == null) continue;
          for (final lessonEntry in lessons.entries) {
            final lesson = lessonEntry.value as Map<String, dynamic>?;
            if (lesson?['teacherUsername'] == username) {
              updates['days.${dayEntry.key}.${lessonEntry.key}'] =
                  FieldValue.delete();
            }
          }
        }
        if (updates.isNotEmpty) {
          updates['updatedAt'] = FieldValue.serverTimestamp();
          batch.update(doc.reference, updates);
          hasUpdates = true;
        }
      }
      if (hasUpdates) await batch.commit();
    }

    // Backend function is the only path: it deletes both the Firebase Auth
    // account and the Firestore user document (the client cannot do the former
    // and is not authorized to do the latter once write rules are tightened).
    final callable = FirebaseFunctions.instance.httpsCallable(
      'adminDeleteUser',
    );
    await callable.call(<String, dynamic>{'username': username});

    // Best-effort cleanup of stale references (head-teacher pointers on classes
    // and lessons in timetables). Surfaced as errors if they fail.
    await clearTeacherFromClasses();
    await clearTeacherFromTimetables();
  }

  Future<void> setDisabled(String username, bool disabled) async {
    username = username.trim().toLowerCase();
    if (username.isEmpty) throw Exception("username missing");

    final callable = FirebaseFunctions.instance.httpsCallable(
      'adminSetDisabled',
    );
    await callable.call(<String, dynamic>{
      'username': username,
      'disabled': disabled,
    });
  }

  Future<void> moveStudent(String userIdentifier, String newClassId) async {
    userIdentifier = userIdentifier.trim();
    newClassId = newClassId.trim().toUpperCase();

    if (userIdentifier.isEmpty) throw Exception("user identifier missing");
    if (newClassId.isEmpty) throw Exception("classId missing");

    // Accept both user document id (uid/username) and username field.
    DocumentReference<Map<String, dynamic>>? userRef;
    final directRef = _db.collection('users').doc(userIdentifier);
    final directSnap = await directRef.get();
    if (directSnap.exists) {
      userRef = directRef;
    } else {
      final byUsername = await _db
          .collection('users')
          .where('username', isEqualTo: userIdentifier.toLowerCase())
          .limit(1)
          .get();
      if (byUsername.docs.isNotEmpty) {
        userRef = byUsername.docs.first.reference;
      }
    }

    if (userRef == null) {
      throw Exception(
        "User does not exist (check uid/username): $userIdentifier",
      );
    }
    final resolvedUserRef = userRef;

    final newClassRef = _db.collection('classes').doc(newClassId);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(resolvedUserRef);
      if (!userSnap.exists) throw Exception("User does not exist");

      final userData = userSnap.data() as Map<String, dynamic>;
      final role = UserRole.fromWire((userData["role"] ?? "").toString());
      final userUsername = (userData["username"] ?? "")
          .toString()
          .trim()
          .toLowerCase();
      final oldClassId = (userData["classId"] ?? "")
          .toString()
          .trim()
          .toUpperCase();

      if (role == null || !role.requiresClassId) {
        throw Exception("Only student/teacher can be moved");
      }

      // ensure the class exists
      final newClassSnap = await tx.get(newClassRef);
      if (!newClassSnap.exists) {
        tx.set(newClassRef, {
          "name": newClassId,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // STUDENT: just update classId
      if (role == UserRole.student) {
        tx.update(resolvedUserRef, {
          "classId": newClassId,
          "updatedAt": FieldValue.serverTimestamp(),
        });
        return;
      }

      // TEACHER: check whether the new class already has a head teacher
      final newClassData = newClassSnap.exists
          ? (newClassSnap.data() as Map<String, dynamic>)
          : <String, dynamic>{};

      final existingTeacher = (newClassData["teacherUsername"] ?? "")
          .toString()
          .trim()
          .toLowerCase();

      if (existingTeacher.isNotEmpty && existingTeacher != userUsername) {
        throw Exception(
          "Class $newClassId already has a head teacher: $existingTeacher",
        );
      }

      // if the teacher was head teacher of the old class, remove them from there
      if (oldClassId.isNotEmpty && oldClassId != newClassId) {
        final oldClassRef = _db.collection('classes').doc(oldClassId);
        final oldClassSnap = await tx.get(oldClassRef);
        if (oldClassSnap.exists) {
          final oldClassData = oldClassSnap.data() as Map<String, dynamic>;
          final oldTeacher = (oldClassData["teacherUsername"] ?? "")
              .toString()
              .trim()
              .toLowerCase();

          if (oldTeacher == userUsername) {
            // remove teacherUsername completely
            tx.set(oldClassRef, {
              "teacherUsername": FieldValue.delete(),
              "updatedAt": FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      }

      // set teacher as head teacher of the new class
      tx.set(newClassRef, {
        "name": newClassId,
        "teacherUsername": userUsername,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // update user.classId
      tx.update(resolvedUserRef, {
        "classId": newClassId,
        "updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> changeClassTeacher({
    required String classId,
    required String teacherUsername, // can be "" to remove the teacher
  }) async {
    classId = classId.trim().toUpperCase();
    teacherUsername = teacherUsername.trim().toLowerCase();

    final classRef = _db.collection('classes').doc(classId);

    await _db.runTransaction((tx) async {
      // ALL READS FIRST (Firestore client SDK requires reads before writes)
      final classSnap = await tx.get(classRef);
      if (!classSnap.exists) {
        throw Exception("Class $classId does not exist");
      }

      String? oldTeacher;
      final classData = classSnap.data() as Map<String, dynamic>;
      oldTeacher = (classData['teacherUsername'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (oldTeacher.isEmpty) oldTeacher = null;

      DocumentReference? oldTeacherRef;
      DocumentSnapshot? oldSnap;
      if (oldTeacher != null && oldTeacher != teacherUsername) {
        oldTeacherRef = _db.collection('users').doc(oldTeacher);
        oldSnap = await tx.get(oldTeacherRef);
      }

      DocumentReference? newTeacherRef;
      DocumentSnapshot? newSnap;
      if (teacherUsername.isNotEmpty) {
        newTeacherRef = _db.collection('users').doc(teacherUsername);
        newSnap = await tx.get(newTeacherRef);
      }

      // VALIDATIONS
      if (teacherUsername.isNotEmpty &&
          oldTeacher != null &&
          oldTeacher != teacherUsername) {
        throw Exception("Class $classId already has a head teacher: $oldTeacher");
      }

      if (teacherUsername.isNotEmpty) {
        if (newSnap == null || !newSnap.exists) {
          throw Exception("Teacher '$teacherUsername' does not exist in users");
        }
        final newData = newSnap.data() as Map<String, dynamic>;
        final newRole = UserRole.fromWire((newData["role"] ?? "").toString());
        if (newRole != UserRole.teacher) {
          throw Exception("User '$teacherUsername' does not have role=teacher");
        }
        final teacherClass = (newData["classId"] ?? "")
            .toString()
            .toUpperCase();
        if (teacherClass.isNotEmpty && teacherClass != classId) {
          throw Exception(
            "Teacher '$teacherUsername' is already head teacher of $teacherClass",
          );
        }
      }

      // ALL WRITES AFTER ALL READS
      if (teacherUsername.isEmpty) {
        tx.set(classRef, {
          "name": classId,
          "updatedAt": FieldValue.serverTimestamp(),
          "teacherUsername": FieldValue.delete(),
        }, SetOptions(merge: true));
      } else {
        tx.set(classRef, {
          "name": classId,
          "teacherUsername": teacherUsername,
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (newTeacherRef != null) {
        tx.update(newTeacherRef, {
          "classId": classId,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }

      if (oldTeacherRef != null && oldSnap != null && oldSnap.exists) {
        final oldData = oldSnap.data() as Map<String, dynamic>;
        final oldClassId = (oldData['classId'] ?? '')
            .toString()
            .toUpperCase();
        if (oldClassId == classId) {
          tx.update(oldTeacherRef, {"classId": FieldValue.delete()});
        }
      }
    });
  }

  Future<void> createClass({
    required String classId,
    String? teacherUsername, // null = don't change, "" = remove, "abc" = set
  }) async {
    classId = classId.trim().toUpperCase();
    if (classId.isEmpty) throw Exception("classId missing");

    // just ensure the class exists
    await _db.collection('classes').doc(classId).set({
      "name": classId,
      "updatedAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // if null -> don't change the head teacher
    if (teacherUsername == null) return;

    // IMPORTANT: call changeClassTeacher also for "" (remove)
    await changeClassTeacher(
      classId: classId,
      teacherUsername: teacherUsername,
    );
  }

  String _randomPass(int len) {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
    final r = Random();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
