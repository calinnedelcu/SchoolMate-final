import 'dart:async';

import 'package:school_mate/auth/login_page_firestore.dart';
import 'package:school_mate/auth/two_factor_verify_page.dart';
import 'package:school_mate/student/mainnavigation.dart';
import 'package:school_mate/admin/secretariat_raw_page.dart'
    show SecretariatRawPage;
import 'package:school_mate/gate/gate_scan_page.dart';
import 'package:school_mate/gate/gate_menu_page.dart';
import 'package:school_mate/gate/gate_scan_result_page.dart';
import 'package:school_mate/teacher/teacher_shell.dart';
import 'package:school_mate/parent/parent_shell.dart';
import 'package:school_mate/services/security_flags_service.dart';
import 'package:school_mate/core/session.dart';
import 'package:school_mate/auth/onboarding_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/firebase_options.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();
StreamSubscription<String>? _tokenRefreshSub;
String? _tokenBoundUid;
String? _tokenInitUid;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      webExperimentalForceLongPolling: true,
    );
  }

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (kIsWeb) return; // handled by the Firebase service worker on web
    final n = message.notification;
    if (n == null) return;
    _localNotifications.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'student_channel',
          'Student notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  });

  runApp(const MyApp());
}

Future<void> _saveFcmToken(String uid) async {
  if (_tokenBoundUid == uid && _tokenRefreshSub != null) return;
  if (_tokenInitUid == uid) return;
  _tokenInitUid = uid;
  try {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    // The user may have signed out (or switched) while the async work above
    // was in flight; in that case skip the writes for the now-stale uid.
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) {
      // Guard against late refreshes after sign-out / user switch: the
      // current-user check below short-circuits writes destined for a uid
      // that is no longer authenticated on this device.
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': newToken,
      }, SetOptions(merge: true));
    });
    _tokenBoundUid = uid;
  } catch (e, st) {
    debugPrint('main.dart: _saveFcmToken failed: $e\n$st');
  } finally {
    if (_tokenInitUid == uid) {
      _tokenInitUid = null;
    }
  }
}

Future<void> _cleanupAuthState({bool clearPersistedTwoFactor = true}) async {
  await _tokenRefreshSub?.cancel();
  _tokenRefreshSub = null;
  _tokenBoundUid = null;
  _tokenInitUid = null;
  if (clearPersistedTwoFactor) {
    // Clear the persisted 2FA verified flag so the next login (or a different
    // user on the same machine) must verify again. twoFactorVerifiedUntil on
    // the user doc is server-only (rules deny client writes) and expires
    // after TWO_FA_SESSION_DURATION_MS.
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = prefs
          .getKeys()
          .where((k) => k.startsWith('tf_verified_'))
          .toList();
      for (final k in keysToRemove) {
        await prefs.remove(k);
      }
    } catch (e, st) {
      debugPrint('main.dart: clearing tf_verified_* prefs failed: $e\n$st');
    }
  }
  AppSession.clear();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Streams cached so rebuilds do not recreate Firestore listeners.
  // Recreating in build() caused rapid widget-type swaps and the
  // "Cannot hit test a render box that has never been laid out" loop.
  late final Stream<SecurityFlags> _flagsStream;
  String? _cachedUid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;
  bool _hadAuthenticatedUser = false;
  final Set<String> _authEmailMirroredUids = {};

  // Cached so that StreamBuilder rebuilds do not recreate the Future,
  // which would reset the FutureBuilder to ConnectionState.waiting.
  String? _twoFactorPersistedUid;
  Future<bool>? _twoFactorPersistedFuture;

  Future<bool> _getOrCreateTwoFactorFuture(String uid) {
    if (_twoFactorPersistedUid != uid || _twoFactorPersistedFuture == null) {
      _twoFactorPersistedUid = uid;
      _twoFactorPersistedFuture = _loadPersistedTwoFactorState(uid);
    }
    return _twoFactorPersistedFuture!;
  }

  Future<bool> _loadPersistedTwoFactorState(String uid) async {
    if (AppSession.twoFactorVerified) {
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'tf_verified_$uid';
      final expiry = prefs.getInt(key);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (expiry != null && now < expiry) {
        AppSession.twoFactorVerified = true;
        return true;
      }
      if (expiry != null) {
        await prefs.remove(key);
      }
    } catch (e, st) {
      debugPrint('main.dart: _loadPersistedTwoFactorState failed: $e\n$st');
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _flagsStream = SecurityFlagsService.watch();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getUserDocStream(String uid) {
    if (uid != _cachedUid) {
      _cachedUid = uid;
      _userDocStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
    }
    return _userDocStream!;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SchoolMate',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF84B0D2),
            ).copyWith(
              primary: const Color(0xFF2848B0),
              outlineVariant: const Color(0xFFE8EAF2),
              onSurface: const Color(0xFF1A2050),
              onSurfaceVariant: const Color(0xFF7A7E9A),
              surface: Colors.white,
              surfaceContainerHighest: const Color(0xFFF2F4F8),
            ),
          ),
          routes: {
            '/gateScan': (context) => const GateScanPage(),
            '/gateScanResult': (context) => const GateScanResultPage(),
          },
          home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            unawaited(
              _cleanupAuthState(clearPersistedTwoFactor: _hadAuthenticatedUser),
            );
            return const LoginPageFirestore();
          }

          _hadAuthenticatedUser = true;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _getUserDocStream(user.uid),
            builder: (context, userDocSnap) {
              final bootstrapData = AppSession.uid == user.uid
                  ? AppSession.bootstrapUserData
                  : null;
              final userDoc = userDocSnap.data;
              final resolvedData = userDoc?.data() ?? bootstrapData;

              if (userDocSnap.connectionState == ConnectionState.waiting &&
                  resolvedData == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userDocSnap.hasError && resolvedData == null) {
                unawaited(_cleanupAuthState());
                unawaited(FirebaseAuth.instance.signOut());
                return const LoginPageFirestore();
              }

              if (userDoc != null && !userDoc.exists) {
                unawaited(_cleanupAuthState());
                unawaited(FirebaseAuth.instance.signOut());
                return const LoginPageFirestore();
              }

              if (resolvedData == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final data = resolvedData;
              final status = (data['status'] ?? 'active').toString();
              if (status == 'disabled') {
                // A cached snapshot may still contain the previous disabled
                // state right after an admin re-enables the account.
                if (userDoc != null && userDoc.metadata.isFromCache) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                unawaited(_cleanupAuthState());
                unawaited(FirebaseAuth.instance.signOut());
                return const LoginPageFirestore();
              }

              final effectivelyOnboarded =
                  data['onboardingComplete'] == true;
              final role = (data['role'] ?? '').toString();
              final twoFactorVerifiedUntil =
                  (data['twoFactorVerifiedUntil'] as Timestamp?)?.toDate();
              final hasRemoteTwoFactorSession =
                  twoFactorVerifiedUntil != null &&
                  twoFactorVerifiedUntil.isAfter(DateTime.now());
              if (hasRemoteTwoFactorSession && !AppSession.twoFactorVerified) {
                AppSession.twoFactorVerified = true;
              }

              // Mirror auth email into the Firestore user profile once per uid
              // to avoid write loops on rebuilds.
              if (!_authEmailMirroredUids.contains(user.uid) &&
                  (data['authEmail'] ?? '').toString().trim().isEmpty &&
                  (user.email ?? '').trim().isNotEmpty) {
                _authEmailMirroredUids.add(user.uid);
                unawaited(
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({
                        'authEmail': user.email,
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true)),
                );
              }

              return StreamBuilder<SecurityFlags>(
                stream: _flagsStream,
                initialData: SecurityFlags.defaults,
                builder: (context, settingsSnap) {
                  final flags = settingsSnap.data ?? SecurityFlags.defaults;

                  if (role != 'gate' &&
                      flags.onboardingEnabled &&
                      !effectivelyOnboarded) {
                    return OnboardingPage(user: user, userData: data);
                  }

                  final requiresTwoFactor =
                      role != 'gate' &&
                      flags.twoFactorEnabled &&
                      effectivelyOnboarded &&
                      !hasRemoteTwoFactorSession;

                  return FutureBuilder<bool>(
                    future: requiresTwoFactor
                        ? _getOrCreateTwoFactorFuture(user.uid)
                        : Future<bool>.value(false),
                    builder: (context, persistedTwoFaSnap) {
                      if (requiresTwoFactor &&
                          !AppSession.twoFactorVerified &&
                          persistedTwoFaSnap.connectionState ==
                              ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      return ValueListenableBuilder<bool>(
                        valueListenable: AppSession.twoFactorNotifier,
                        builder: (context, twoFaVerified, _) {
                          if (requiresTwoFactor && !twoFaVerified) {
                            final username = (data['username'] ?? '')
                                .toString();
                            return TwoFactorVerifyPage(
                              uid: user.uid,
                              role: role,
                              username: username,
                              fullName: (data['fullName'] ?? '').toString(),
                              classId: (data['classId'] ?? '').toString(),
                            );
                          }

                          final username = (data['username'] ?? '').toString();

                          AppSession.setUser(
                            uidValue: user.uid,
                            usernameValue: username,
                            roleValue: role,
                            fullNameValue: (data['fullName'] ?? '').toString(),
                            classIdValue: (data['classId'] ?? '').toString(),
                          );

                          unawaited(_saveFcmToken(user.uid));

                          if (role == 'student') {
                            return const AppShell();
                          } else if (role == 'gate') {
                            return const GateMenuPage();
                          } else if (role == 'admin') {
                            return const SecretariatRawPage();
                          } else if (role == 'teacher') {
                            return const TeacherShell();
                          } else if (role == 'parent') {
                            return const ParentShell();
                          }

                          unawaited(_cleanupAuthState());
                          unawaited(FirebaseAuth.instance.signOut());
                          return const LoginPageFirestore();
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
