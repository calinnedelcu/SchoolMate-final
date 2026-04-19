import 'package:firster/student/meniu.dart';
import 'package:firster/student/widgets/school_decor.dart';
import 'package:firster/core/session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF2848B0);
const _surface = Color(0xFFF2F4F8);
const _card = Color(0xFFFFFFFF);
const _cardMuted = Color(0xFFE8EAF2);
const _textDark = Color(0xFF1A2050);
const _textMuted = Color(0xFF7A7E9A);

class CereriScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const CereriScreen({super.key, this.onNavigateTab});

  @override
  State<CereriScreen> createState() => _CereriScreenState();
}

class _CereriScreenState extends State<CereriScreen> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _submitting = false;

  // Schedule for the selected day (fetched from Firestore)
  TimeOfDay? _scheduleStart;
  TimeOfDay? _scheduleEnd;
  bool _loadingSchedule = false;
  bool _targetTeacher = true;
  bool _targetParent = false;

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    // Skip weekends when setting the initial date
    DateTime initialDate = _selectedDate ?? now;
    if (initialDate.weekday == DateTime.saturday) {
      initialDate = initialDate.add(const Duration(days: 2));
    } else if (initialDate.weekday == DateTime.sunday) {
      initialDate = initialDate.add(const Duration(days: 1));
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Select date',
      fieldHintText: 'DD/MM/YYYY',
      fieldLabelText: 'Date',
      cancelText: 'Cancel',
      confirmText: 'OK',
      selectableDayPredicate: (day) =>
          day.weekday != DateTime.saturday && day.weekday != DateTime.sunday,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              surface: _card,
              onSurface: _textDark,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _primary),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: _card),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: _cardMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primary, width: 1.4),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: _card,
              headerBackgroundColor: _primary,
              headerForegroundColor: Colors.white,
              headerHeadlineStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              dayStyle: const TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w600,
              ),
              weekdayStyle: const TextStyle(
                color: _textMuted,
                fontWeight: FontWeight.w700,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                if (states.contains(WidgetState.disabled)) {
                  return _textMuted.withValues(alpha: 0.35);
                }
                return _textDark;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return _primary;
                }
                return Colors.transparent;
              }),
              todayBorder: const BorderSide(color: _primary, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
      _dateController.text = _formatDateMmDdYyyy(pickedDate);
      // Reset time and cached schedule when date changes
      _selectedTime = null;
      _timeController.clear();
      _scheduleStart = null;
      _scheduleEnd = null;
    });
  }

  TimeOfDay _parseHHmm(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatDateMmDdYyyy(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }

  String _formatTime12h(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<Map<String, dynamic>> _loadCurrentUserData() async {
    final uid = AppSession.uid ?? '';
    if (uid.isEmpty) {
      return const <String, dynamic>{};
    }

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return userSnap.data() ?? const <String, dynamic>{};
  }

  Future<bool> _fetchDaySchedule(int weekday) async {
    final classId = AppSession.classId;
    if (classId == null || classId.isEmpty) return false;

    setState(() => _loadingSchedule = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data() ?? {};
      final schedule = data['schedule'] as Map<String, dynamic>?;
      if (schedule == null) return false;

      // Firestore key matches Flutter weekday: 1=Mon..5=Fri
      final dayData = schedule[weekday.toString()] as Map<String, dynamic>?;
      if (dayData == null) return false;

      final startStr = dayData['start'] as String?;
      final endStr = dayData['end'] as String?;
      if (startStr == null || endStr == null) return false;

      if (mounted) {
        setState(() {
          _scheduleStart = _parseHHmm(startStr);
          _scheduleEnd = _parseHHmm(endStr);
        });
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _loadingSchedule = false);
    }
  }

  Future<void> _pickTime() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the leave date first.')),
      );
      return;
    }

    // Fetch schedule for this weekday if not already cached
    if (_scheduleStart == null || _scheduleEnd == null) {
      final ok = await _fetchDaySchedule(_selectedDate!.weekday);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your class schedule is not set for the selected day.',
            ),
          ),
        );
        return;
      }
    }

    final rangeStart = _scheduleStart!;
    final rangeEnd = _scheduleEnd!;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? rangeStart,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Select time',
      cancelText: 'Cancel',
      confirmText: 'OK',
      hourLabelText: 'Hour',
      minuteLabelText: 'Minutes',
      builder: (context, child) {
        return Localizations.override(
          context: context,
          delegates: const [_RomanianTimePickerLocalizationsDelegate()],
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: _primary,
                  onPrimary: Colors.white,
                  surface: _card,
                  onSurface: _textDark,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: _primary),
                ),
                timePickerTheme: TimePickerThemeData(
                  backgroundColor: _card,
                  hourMinuteColor: _cardMuted,
                  hourMinuteTextColor: _textDark,
                  dayPeriodColor: _cardMuted,
                  dayPeriodTextColor: _textDark,
                  dialBackgroundColor: _cardMuted,
                  dialHandColor: _primary,
                  dialTextColor: _textDark,
                  entryModeIconColor: _primary,
                  hourMinuteShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(
                      color: Color(0xFFC0C4D8),
                      width: 1.2,
                    ),
                  ),
                  dayPeriodShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: Color(0xFFC0C4D8),
                      width: 1.2,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );

    if (pickedTime == null) {
      return;
    }

    final pickedMin = _toMinutes(pickedTime);
    final startMin = _toMinutes(rangeStart);
    final endMin = _toMinutes(rangeEnd);

    if (pickedMin < startMin || pickedMin > endMin) {
      if (!mounted) return;
      String fmt(TimeOfDay t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Time must be between ${fmt(rangeStart)} and ${fmt(rangeEnd)} (your class schedule).',
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedTime = pickedTime;
      _timeController.text = _formatTime12h(pickedTime);
    });
  }

  Future<Map<String, String>> _resolveTeacher() async {
    final uid = AppSession.uid ?? '';
    if (uid.isEmpty) return const <String, String>{};
    final userData = await _loadCurrentUserData();
    final classId = (userData['classId'] ?? AppSession.classId ?? '')
        .toString()
        .trim();
    if (classId.isEmpty) return const <String, String>{};
    final classSnap = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .get();
    final classData = classSnap.data() ?? const <String, dynamic>{};
    String teacherUid = (classData['teacherUid'] ?? '').toString().trim();
    String teacherUsername = (classData['teacherUsername'] ?? '')
        .toString()
        .trim();
    String teacherName = '';
    if (teacherUid.isNotEmpty) {
      final teacherSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherUid)
          .get();
      final teacherData = teacherSnap.data() ?? const <String, dynamic>{};
      teacherUsername = (teacherData['username'] ?? teacherUsername)
          .toString()
          .trim();
      teacherName = (teacherData['fullName'] ?? teacherUsername)
          .toString()
          .trim();
    }
    return <String, String>{
      'uid': teacherUid,
      'name': teacherName.isNotEmpty ? teacherName : 'Teacher',
      'username': teacherUsername,
    };
  }

  Future<Map<String, String>> _resolveParent() async {
    final uid = AppSession.uid ?? '';
    if (uid.isEmpty) return const <String, String>{};
    final userData = await _loadCurrentUserData();
    final parents = List<String>.from(userData['parents'] ?? const <String>[]);
    if (parents.isEmpty) return const <String, String>{};
    final parentUid = parents.first;
    final parentSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(parentUid)
        .get();
    final parentData = parentSnap.data() ?? const <String, dynamic>{};
    return <String, String>{
      'uid': parentUid,
      'name': (parentData['fullName'] ?? parentData['username'] ?? '')
          .toString()
          .trim(),
      'username': (parentData['username'] ?? '').toString().trim(),
    };
  }

  Future<void> _submitRequest() async {
    final message = _messageController.text.trim();

    if (_selectedDate == null || _selectedTime == null || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in the date, time and reason.'),
        ),
      );
      return;
    }

    if (!_targetTeacher && !_targetParent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one recipient.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final studentUid = AppSession.uid;
    if (studentUid == null || studentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid session. Please log in again.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final userData = await _loadCurrentUserData();
      final classId = (userData['classId'] ?? AppSession.classId ?? '')
          .toString()
          .trim();
      final studentUsername =
          (userData['username'] ?? AppSession.username ?? '').toString().trim();
      final studentName =
          (userData['fullName'] ?? AppSession.fullName ?? studentUsername)
              .toString()
              .trim();

      if (classId.isEmpty) {
        throw Exception('Student does not have a class set in profile.');
      }

      final baseDoc = {
        'studentUid': studentUid,
        'studentUsername': studentUsername,
        'studentName': studentName,
        'classId': classId,
        'dateText': _dateController.text,
        'timeText': _timeController.text,
        'message': message,
        'status': 'pending',
        'requestedAt': Timestamp.now(),
        'requestedForDate': Timestamp.fromDate(
          DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          ),
        ),
        'reviewedAt': null,
        'reviewedByUid': null,
        'reviewedByName': null,
        'viewedByParent': false,
      };

      final futures = <Future>[];

      if (_targetTeacher) {
        final teacher = await _resolveTeacher();
        futures.add(
          FirebaseFirestore.instance.collection('leaveRequests').add({
            ...baseDoc,
            'targetRole': 'teacher',
            'targetUid': (teacher['uid'] ?? '').trim(),
            'targetName': (teacher['name'] ?? 'Teacher').trim(),
            'targetUsername': (teacher['username'] ?? '').trim(),
          }),
        );
      }

      if (_targetParent) {
        final parent = await _resolveParent();
        if (parent['uid']?.isNotEmpty == true) {
          futures.add(
            FirebaseFirestore.instance.collection('leaveRequests').add({
              ...baseDoc,
              'targetRole': 'parent',
              'targetUid': (parent['uid'] ?? '').trim(),
              'targetName': (parent['name'] ?? '').trim(),
              'targetUsername': (parent['username'] ?? '').trim(),
            }),
          );
        }
      }

      await Future.wait(futures);

      await FirebaseFirestore.instance.collection('users').doc(studentUid).set({
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted successfully.')),
      );

      setState(() {
        _selectedDate = null;
        _selectedTime = null;
        _scheduleStart = null;
        _scheduleEnd = null;
        _dateController.clear();
        _timeController.clear();
        _messageController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('Exception:')
                ? e.toString().replaceFirst('Exception: ', '')
                : 'Error submitting the request.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
      _scheduleStart = null;
      _scheduleEnd = null;
      _dateController.clear();
      _timeController.clear();
      _messageController.clear();
    });
  }

  bool get _hasUnsavedData =>
      _selectedDate != null ||
      _selectedTime != null ||
      _messageController.text.trim().isNotEmpty;

  Future<void> _goBack() async {
    if (_hasUnsavedData) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.4),
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDE0EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: _primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Discard request?',
                        style: TextStyle(
                          color: _textDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'The request has not been submitted and data will be cleared.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEAEA),
                          foregroundColor: const Color(0xFFB71C1C),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Discard',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: TextButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Stay',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;

    _resetForm();

    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(0);
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const MeniuScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final compact = MediaQuery.sizeOf(context).width < 390;
    final titleSize = compact ? 29.0 : 33.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E3CA0), Color(0xFF2E58D0), Color(0xFF4070E0)],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x302848B0),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: const HeaderSparklesPainter(variant: 0),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 22),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  onPressed: _goBack,
                                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Leave requests',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 42,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: kPencilYellow,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Description ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: _primary, size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Request permission to leave school during scheduled hours. If approved, your QR access code will be updated automatically.',
                                    style: TextStyle(
                                      color: _textDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ── Recipients ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SEND TO',

                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _RecipientPill(
                                        selected: _targetTeacher,
                                        icon: Icons.school_rounded,
                                        label: 'Teacher',
                                        onTap: () => setState(
                                          () => _targetTeacher = !_targetTeacher,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _RecipientPill(
                                        selected: _targetParent,
                                        icon: Icons.family_restroom,
                                        label: 'Parent',
                                        onTap: () => setState(
                                          () => _targetParent = !_targetParent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ── Date & Time row ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _FieldTile(
                                        label: 'DATE',
                                        value: _dateController.text.isEmpty
                                            ? 'Select date'
                                            : _dateController.text,
                                        icon: Icons.calendar_month_rounded,
                                        isEmpty: _dateController.text.isEmpty,
                                        onTap: _pickDate,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _FieldTile(
                                        label: 'TIME',
                                        value: _timeController.text.isEmpty
                                            ? 'Select time'
                                            : _timeController.text,
                                        icon: Icons.access_time_rounded,
                                        isEmpty: _timeController.text.isEmpty,
                                        onTap: _loadingSchedule ? null : _pickTime,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_loadingSchedule)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: LinearProgressIndicator(color: _primary),
                                  )
                                else if (_scheduleStart != null &&
                                    _scheduleEnd != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline_rounded,
                                            color: _primary, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Schedule: '
                                          '${_scheduleStart!.hour.toString().padLeft(2, '0')}:${_scheduleStart!.minute.toString().padLeft(2, '0')}'
                                          ' – '
                                          '${_scheduleEnd!.hour.toString().padLeft(2, '0')}:${_scheduleEnd!.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                            color: _primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ── Reason ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'REASON',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _messageController,
                                  minLines: 4,
                                  maxLines: 6,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: _textDark,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Why do you need to leave?',
                                    hintStyle: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFA0A4B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    filled: true,
                                    fillColor: _cardMuted,
                                    contentPadding: const EdgeInsets.all(14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: _primary, width: 1.4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // ── Submit ──
                          GestureDetector(
                            onTap: _submitting ? null : _submitRequest,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2848B0), Color(0xFF3460CC)],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x352848B0),
                                    blurRadius: 16,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_submitting)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    const Icon(Icons.send_rounded,
                                        color: Colors.white, size: 18),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Submit request',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ── Info banner ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE0B2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.schedule_rounded,
                                    color: Color(0xFFE65100),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Requests expire automatically at midnight on the selected day.',
                                    style: TextStyle(
                                      color: Color(0xFF5D4037),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_submitting)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.62),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 28),
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x16000000),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: _primary,
                                ),
                              ),
                              SizedBox(width: 14),
                              Flexible(
                                child: Text(
                                  'Submitting request...',
                                  style: TextStyle(
                                    color: _textDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipientPill extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RecipientPill({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _primary : _cardMuted,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: kPencilYellow, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : _textMuted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: kPencilYellow,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isEmpty;
  final VoidCallback? onTap;

  const _FieldTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.isEmpty,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _cardMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: _primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: isEmpty ? const Color(0xFFA0A4B8) : _textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
}




// ---------------------------------------------------------------------------
// Delegate for customizing TimePicker tooltips
// ---------------------------------------------------------------------------
class _RomanianTimePickerLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _RomanianTimePickerLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      const _CustomMaterialLocalizations();

  @override
  bool shouldReload(_RomanianTimePickerLocalizationsDelegate old) => false;
}

class _CustomMaterialLocalizations extends DefaultMaterialLocalizations {
  const _CustomMaterialLocalizations();

  @override
  String get dialModeButtonLabel => 'Switch to dial picker';

  @override
  String get inputTimeModeButtonLabel => 'Switch to text input';
}
