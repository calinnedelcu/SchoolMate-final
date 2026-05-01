import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/session.dart';

class LoginPageFirestore extends StatefulWidget {
  const LoginPageFirestore({super.key});

  @override
  State<LoginPageFirestore> createState() => _LoginPageFirestoreState();
}

class _LoginPageFirestoreState extends State<LoginPageFirestore> {
  static const Duration _authTimeout = Duration(seconds: 15);
  final userC = TextEditingController();
  final passC = TextEditingController();
  bool loading = false;
  bool passwordVisible = false; // control password visibility
  DateTime? _blockedUntil;
  Timer? _countdownTimer;
  String _actorKey = '';

  static const _kBlockedUntilMs = 'login_blocked_until_ms';
  static const _kLoginActorKey = 'login_actor_key';

  bool get _isLocallyBlocked {
    if (_blockedUntil == null) return false;
    return DateTime.now().isBefore(_blockedUntil!);
  }

  int get _remainingSeconds {
    if (_blockedUntil == null) return 0;
    final diff = _blockedUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final expired =
          _blockedUntil != null && DateTime.now().isAfter(_blockedUntil!);
      if (expired) {
        _countdownTimer?.cancel();
        _clearLocalBlockState();
      }
      setState(() {});
    });
  }

  Future<void> _setBlockedForSeconds(int sec) async {
    if (sec <= 0) return;
    _blockedUntil = DateTime.now().add(Duration(seconds: sec));
    _startCountdown();
    await _saveLocalBlockState();
    setState(() {});
  }

  Future<void> _saveLocalBlockState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_blockedUntil != null) {
      await prefs.setInt(
        _kBlockedUntilMs,
        _blockedUntil!.millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _clearLocalBlockState() async {
    _blockedUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBlockedUntilMs);
  }

  Future<void> _loadLocalBlockState() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kBlockedUntilMs);
    if (ms == null) return;

    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    if (DateTime.now().isBefore(dt)) {
      _blockedUntil = dt;
      _startCountdown();
      if (mounted) setState(() {});
      return;
    }

    await _clearLocalBlockState();
  }

  String _randomHex(int length) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(length ~/ 2, (_) => rnd.nextInt(256));
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  Future<void> _ensureActorKey() async {
    if (_actorKey.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = (prefs.getString(_kLoginActorKey) ?? '').trim();
    if (RegExp(r'^[a-f0-9]{32,128}$').hasMatch(existing)) {
      _actorKey = existing;
      return;
    }

    final generated = _randomHex(32);
    _actorKey = generated;
    await prefs.setString(_kLoginActorKey, generated);
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));
    userC.addListener(() {
      if (mounted) setState(() {});
    });
    unawaited(_loadLocalBlockState());
    unawaited(_ensureActorKey());
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  Future<T> _withAuthTimeout<T>(Future<T> future, String operationLabel) async {
    try {
      return await future.timeout(_authTimeout);
    } on TimeoutException {
      throw Exception('$operationLabel timeout');
    }
  }

  Future<String> _resolveUsernameFromInput(String input) async {
    final resolveRes = await _withAuthTimeout(
      FirebaseFunctions.instance.httpsCallable('authResolveLoginInput').call({
        'input': input,
      }),
      'authResolveLoginInput',
    );
    final resolveData = Map<String, dynamic>.from(resolveRes.data as Map);
    final username = (resolveData['username'] ?? '').toString().toLowerCase();
    if (username.isEmpty) {
      throw Exception('Invalid credentials');
    }
    return username;
  }

  Future<void> _showResetPasswordCodeDialog(String initialInput) async {
    final inputC = TextEditingController(text: initialInput);
    final codeC = TextEditingController();
    final newPassC = TextEditingController();
    final confirmPassC = TextEditingController();

    bool submitting = false;
    bool showPass = false;
    bool showConfirmPass = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Reset password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: inputC,
                      decoration: const InputDecoration(
                        labelText: 'Username or email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reset code (6 digits)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassC,
                      obscureText: !showPass,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            showPass ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(() => showPass = !showPass);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassC,
                      obscureText: !showConfirmPass,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            showConfirmPass
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(
                              () => showConfirmPass = !showConfirmPass,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final input = inputC.text.trim().toLowerCase();
                          final code = codeC.text.trim();
                          final newPass = newPassC.text.trim();
                          final confirmPass = confirmPassC.text.trim();

                          if (input.isEmpty ||
                              code.isEmpty ||
                              newPass.isEmpty ||
                              confirmPass.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill in all fields.'),
                              ),
                            );
                            return;
                          }
                          if (newPass != confirmPass) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Passwords do not match.'),
                              ),
                            );
                            return;
                          }
                          if (newPass.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Password must be at least 6 characters.',
                                ),
                              ),
                            );
                            return;
                          }

                          var dialogClosed = false;
                          setDialogState(() => submitting = true);
                          try {
                            await FirebaseFunctions.instance
                                .httpsCallable('authConfirmPasswordReset')
                                .call({
                                  'input': input,
                                  'code': code,
                                  'newPassword': newPass,
                                });

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            dialogClosed = true;
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Password reset. You can log in now.',
                                ),
                              ),
                            );
                          } on FirebaseFunctionsException catch (e) {
                            var msg = 'Reset failed. Please try again.';
                            if (e.code == 'invalid-argument') {
                              msg = 'Invalid data or wrong code.';
                            } else if (e.code == 'deadline-exceeded') {
                              msg = 'Code expired. Request a new one.';
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Reset failed. Please try again.',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (!dialogClosed) {
                              setDialogState(() => submitting = false);
                            }
                          }
                        },
                  child: Text(submitting ? 'Saving...' : 'Reset'),
                ),
              ],
            );
          },
        );
      },
    );

    inputC.dispose();
    codeC.dispose();
    newPassC.dispose();
    confirmPassC.dispose();
  }

  Future<void> _openForgotPasswordFlow() async {
    final inputC = TextEditingController(text: userC.text.trim());
    bool sending = false;
    String? nextInput;
    String? postMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: !sending,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Forgot password?'),
              content: TextField(
                controller: inputC,
                decoration: const InputDecoration(
                  labelText: 'Username or email',
                  hintText: 'e.g. student1 or student1@gmail.com',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          final input = inputC.text.trim().toLowerCase();
                          if (input.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a username or email.',
                                ),
                              ),
                            );
                            return;
                          }

                          var dialogClosed = false;
                          setDialogState(() => sending = true);
                          try {
                            final res = await FirebaseFunctions.instance
                                .httpsCallable('authRequestPasswordReset')
                                .call({'input': input});
                            final data = Map<String, dynamic>.from(
                              res.data as Map,
                            );
                            final cooldown = _asInt(
                              data['cooldownSeconds'],
                              fallback: 0,
                            );

                            if (!ctx.mounted) return;
                            nextInput = input;
                            postMessage = cooldown > 0
                                ? 'A code was sent recently. Try again in ${cooldown}s.'
                                : 'If your account exists, we sent a reset code to your email.';
                            Navigator.of(ctx).pop();
                            dialogClosed = true;
                          } on FirebaseFunctionsException catch (e) {
                            var msg =
                                'Could not send the code. Please try again.';
                            if (e.code == 'failed-precondition') {
                              msg = e.message ?? msg;
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not send the code. Please try again.',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (!dialogClosed) {
                              setDialogState(() => sending = false);
                            }
                          }
                        },
                  icon: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.email_outlined, size: 18),
                  label: const Text('Send code'),
                ),
              ],
            );
          },
        );
      },
    );

    inputC.dispose();

    if (!mounted) return;
    if (postMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(postMessage!)));
    }
    if (nextInput != null && nextInput!.isNotEmpty) {
      await _showResetPasswordCodeDialog(nextInput!);
    }
  }

  Future<void> _login() async {
    if (loading) return;

    if (_isLocallyBlocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Account temporarily locked. Try again in ${_remainingSeconds}s.",
            ),
          ),
        );
      }
      return;
    }

    setState(() => loading = true);
    String attemptToken = '';
    try {
      final input = userC.text.trim().toLowerCase();
      final password = passC.text.trim();
      if (input.isEmpty || password.isEmpty) {
        throw Exception("Invalid credentials");
      }

      final username = await _resolveUsernameFromInput(input);

      await _ensureActorKey();
      if (_actorKey.isEmpty) {
        throw Exception("Authentication temporarily unavailable");
      }

      final precheck = await _withAuthTimeout(
        FirebaseFunctions.instance.httpsCallable('authPrecheckLogin').call({
          'username': username,
          'actorKey': _actorKey,
        }),
        'authPrecheckLogin',
      );
      final preData = Map<String, dynamic>.from(precheck.data as Map);
      attemptToken = (preData['attemptToken'] ?? '').toString();
      if (preData['blocked'] == true) {
        final sec = _asInt(preData['remainingSeconds'], fallback: 120);
        await _setBlockedForSeconds(sec);
        throw Exception("Account temporarily locked. Try again in ${sec}s.");
      }

      final email = "$username@school.local";
      final cred = await _withAuthTimeout(
        FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
        'signInWithEmailAndPassword',
      );
      final uid = cred.user!.uid;
      final doc = await _withAuthTimeout(
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server)),
        'users/$uid get',
      );

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Invalid credentials');
      }

      final data = doc.data() as Map<String, dynamic>;
      if ((data["status"] ?? "active") == "disabled") {
        await FirebaseAuth.instance.signOut();
        throw Exception("Authentication unavailable");
      }

      final role = (data["role"] ?? "").toString();
      final usernameFromDb = (data["username"] ?? username).toString();
      // routing is handled by main.dart's StreamBuilder
      assert(role.isNotEmpty || usernameFromDb.isEmpty);

      AppSession.setUser(
        uidValue: uid,
        usernameValue: usernameFromDb,
        roleValue: role,
        fullNameValue: (data['fullName'] ?? '').toString(),
        classIdValue: (data['classId'] ?? '').toString(),
      );
      AppSession.setBootstrapUserData(uidValue: uid, data: data);

      try {
        await _withAuthTimeout(
          FirebaseFunctions.instance
              .httpsCallable('authRegisterLoginSuccess')
              .call({'actorKey': _actorKey}),
          'authRegisterLoginSuccess',
        );
      } on FirebaseFunctionsException {
        // Keep login successful even if this post-login hook fails.
      } on Exception {
        // Keep login successful even if this post-login hook fails.
      } catch (_) {
        // Keep login successful even if this post-login hook fails.
      }

      // Authentication succeeded. The StreamBuilder in main.dart detects the
      // auth-state change and routes to OnboardingPage, TwoFactorVerifyPage,
      // or the role dashboard ÔÇö no Navigator.push needed here.
    } on FirebaseAuthException catch (e) {
      String msg = "Invalid credentials.";
      if (e.code == "wrong-password" ||
          e.code == "invalid-credential" ||
          e.code == "invalid-login-credentials" ||
          e.code == "user-not-found" ||
          e.code == "invalid-email" ||
          e.code == "user-disabled") {
        // Extract username from input - might be email or username
        final input = userC.text.trim().toLowerCase();
        String usernameForFailure = input;
        if (input.contains('@')) {
          // If email was entered, try to resolve it via Cloud Function
          try {
            usernameForFailure = await _resolveUsernameFromInput(input);
          } catch (_) {
            // If lookup fails, use original input
          }
        }

        try {
          if (attemptToken.isNotEmpty) {
            final failRes = await FirebaseFunctions.instance
                .httpsCallable('authReportLoginFailure')
                .call({
                  'username': usernameForFailure,
                  'attemptToken': attemptToken,
                  'actorKey': _actorKey,
                });
            final failData = Map<String, dynamic>.from(failRes.data as Map);
            if (failData['blocked'] == true) {
              final sec = _asInt(failData['remainingSeconds'], fallback: 120);
              await _setBlockedForSeconds(sec);
              msg =
                  "Authentication temporarily unavailable. Please try again later.";
            }
          }
        } on FirebaseFunctionsException catch (fx) {
          if (fx.code == 'resource-exhausted') {
            msg =
                "Authentication temporarily unavailable. Please try again later.";
          } else if (fx.code == 'failed-precondition') {
            msg = "Invalid credentials.";
          }
        }
      }
      if (e.code == "too-many-requests") {
        msg =
            "Authentication temporarily unavailable. Please try again later.";
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Login timed out. Check your connection and try again.',
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[LOGIN ERROR] $e');
      debugPrint('[LOGIN STACK] $st');
      final msg = e.toString().contains('timeout')
          ? 'Login timed out. Check your connection and try again.'
          : 'Login failed. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    userC.dispose();
    passC.dispose();
    super.dispose();
  }

  // Colors (school theme)
  static const _accent = Color(0xFF2848B0);
  static const _cardBg = Color(0xFFF2F4F8);
  static const _inputBorder = Color(0xFFC0C4D8);
  static const _hintColor = Color(0xFF7A7E9A);
  static const _pencilYellow = Color(0xFFF5C518);

  // Math-symbol sparkles (school-themed background flourish)
  Widget _buildMathSparkles({double opacity = 1.0}) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _MathSparklesPainter(opacity: opacity),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildLogo({double size = 92, bool framed = true}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: framed ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: framed
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
        border: framed ? Border.all(color: _pencilYellow, width: 2) : null,
      ),
      padding: EdgeInsets.all(framed ? size * 0.12 : 0),
      child: Image.asset(
        'assets/images/schoolmate_logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
      ),
    );
  }

  // Branding panel (left side on landscape)
  Widget _buildBrandingPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2E80), Color(0xFF2848B0), Color(0xFF3460CC)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _buildMathSparkles(opacity: 1.0)),
          // Decorative book icon in the lower-right corner.
          Positioned(
            right: -32,
            bottom: -36,
            child: Transform.rotate(
              angle: -0.18,
              child: Icon(
                Icons.menu_book_rounded,
                size: 220,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Soft top-left glow.
          Positioned(
            left: -60,
            top: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _pencilYellow.withValues(alpha: 0.18),
                    _pencilYellow.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(52, 56, 52, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Top pill badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _pencilYellow,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'STUDENT APP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                _buildLogo(size: 96, framed: false),
                const SizedBox(height: 32),
                const Text(
                  'SchoolMate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 3,
                  width: 56,
                  decoration: BoxDecoration(
                    color: _pencilYellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'School life, organized.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Schedule, leave requests and announcements — all '
                  'in one place, with real-time parent approvals.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 36),
                const _FeatureBullet(
                  icon: Icons.event_available_rounded,
                  title: 'Live timetable',
                  subtitle: 'Always up to date with your class schedule.',
                ),
                const SizedBox(height: 14),
                const _FeatureBullet(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Dynamic QR check-in',
                  subtitle: 'Fast and secure gate access.',
                ),
                const SizedBox(height: 14),
                const _FeatureBullet(
                  icon: Icons.campaign_rounded,
                  title: 'Announcements & approvals',
                  subtitle: 'Stay in sync with school and parents.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Login form card
  Widget _buildLoginForm({required bool compact}) {
    final radius = BorderRadius.circular(14);

    return Container(
      width: compact ? double.infinity : 420,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 28 : 44,
        vertical: compact ? 36 : 48,
      ),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: AutofillGroup(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sign in',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _accent,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your credentials to access your account',
            style: TextStyle(fontSize: 13, color: _hintColor),
          ),
          const SizedBox(height: 28),

          // Username / Email
          const Text(
            'USERNAME OR EMAIL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _hintColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: userC,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.username],
            decoration: InputDecoration(
              hintText: 'e.g. ion.popescu',
              hintStyle: const TextStyle(color: _inputBorder, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: _accent, width: 1.5),
              ),
              suffixIcon: const Icon(
                Icons.alternate_email,
                color: _hintColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Password label row
          Row(
            children: [
              const Text(
                'PASSWORD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _hintColor,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: loading ? null : _openForgotPasswordFlow,
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 12,
                    color: _accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passC,
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) {
              if (!loading && !_isLocallyBlocked) {
                _login();
              }
            },
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: const TextStyle(color: _inputBorder, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: _accent, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  passwordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _hintColor,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => passwordVisible = !passwordVisible),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Login button
          GestureDetector(
            onTap: (loading || _isLocallyBlocked) ? null : _login,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2848B0), Color(0xFF3460CC)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x352848B0),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLocallyBlocked
                                ? 'Locked (${_remainingSeconds}s)'
                                : 'Sign in',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Footer
          Center(
            child: Column(
              children: const [
                Text(
                  'Don\'t have an account yet?',
                  style: TextStyle(fontSize: 13, color: _hintColor),
                ),
                SizedBox(height: 4),
                Text(
                  'Contact your school administration',
                  style: TextStyle(
                    fontSize: 13,
                    color: _accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 750;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3CA0), Color(0xFF2E58D0), Color(0xFF4070E0)],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: isWide ? _buildLandscape() : _buildPortrait(),
            ),
          ),
        ),
      ),
    );
  }

  // LANDSCAPE: split view
  Widget _buildLandscape() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Material(
          color: Colors.transparent,
          elevation: 32,
          shadowColor: const Color(0x66000000),
          borderRadius: BorderRadius.circular(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 720),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Row(
                children: [
                  Expanded(flex: 6, child: _buildBrandingPanel()),
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: _cardBg,
                      alignment: Alignment.center,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: _buildLoginForm(compact: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // PORTRAIT: card over dark background
  Widget _buildPortrait() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              _buildLogo(size: 104, framed: false),
              const SizedBox(height: 18),
              const Text(
                'SchoolMate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 3,
                width: 44,
                decoration: BoxDecoration(
                  color: _pencilYellow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),
              Material(
                color: Colors.transparent,
                elevation: 20,
                shadowColor: const Color(0x40000000),
                borderRadius: BorderRadius.circular(24),
                child: _buildLoginForm(compact: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Math-symbol sparkles painter (school theme)
class _MathSparklesPainter extends CustomPainter {
  final double opacity;

  const _MathSparklesPainter({this.opacity = 1.0});

  static const _symbols = <({String s, double dx, double dy, double size, bool yellow})>[
    (s: 'π', dx: 0.08, dy: 0.10, size: 26, yellow: true),
    (s: '+', dx: 0.22, dy: 0.18, size: 18, yellow: false),
    (s: '×', dx: 0.34, dy: 0.08, size: 16, yellow: false),
    (s: '√', dx: 0.50, dy: 0.14, size: 22, yellow: false),
    (s: '∞', dx: 0.66, dy: 0.07, size: 24, yellow: true),
    (s: '÷', dx: 0.82, dy: 0.16, size: 18, yellow: false),
    (s: '=', dx: 0.92, dy: 0.32, size: 18, yellow: false),
    (s: '∆', dx: 0.06, dy: 0.36, size: 22, yellow: true),
    (s: '²', dx: 0.18, dy: 0.46, size: 16, yellow: false),
    (s: 'π', dx: 0.78, dy: 0.50, size: 20, yellow: false),
    (s: '+', dx: 0.42, dy: 0.58, size: 16, yellow: false),
    (s: '√', dx: 0.10, dy: 0.66, size: 20, yellow: false),
    (s: '∞', dx: 0.30, dy: 0.74, size: 22, yellow: true),
    (s: '×', dx: 0.58, dy: 0.70, size: 18, yellow: false),
    (s: '÷', dx: 0.74, dy: 0.82, size: 18, yellow: false),
    (s: '∆', dx: 0.88, dy: 0.62, size: 20, yellow: false),
    (s: '=', dx: 0.16, dy: 0.88, size: 16, yellow: false),
    (s: '²', dx: 0.50, dy: 0.92, size: 18, yellow: true),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final whiteStrong = Colors.white.withValues(alpha: 0.30 * opacity);
    final whiteSoft = Colors.white.withValues(alpha: 0.20 * opacity);
    final yellow = const Color(0xFFF5C518).withValues(alpha: 0.42 * opacity);

    for (var i = 0; i < _symbols.length; i++) {
      final sym = _symbols[i];
      final color = sym.yellow ? yellow : (i.isEven ? whiteStrong : whiteSoft);
      final tp = TextPainter(
        text: TextSpan(
          text: sym.s,
          style: TextStyle(
            color: color,
            fontSize: sym.size,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(size.width * sym.dx, size.height * sym.dy),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MathSparklesPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureBullet({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
