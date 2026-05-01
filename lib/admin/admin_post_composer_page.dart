import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/session.dart';
import '../student/widgets/school_decor.dart';

const _primary = Color(0xFF2848B0);
const _surfaceColor = Color(0xFFF2F4F8);
const _cardBg = Color(0xFFFFFFFF);
const _outline = Color(0xFF7A7E9A);
const _onSurface = Color(0xFF3A4A80);
const _fieldBg = Color(0xFFE8EAF2);
const _danger = Color(0xFFB03040);

/// Audience sentinel for school-wide broadcasts.
const String kAudienceAll = '__ALL__';

enum PostKind { announcement, competition, camp, volunteer, vacation }

extension PostKindLabel on PostKind {
  String get label {
    switch (this) {
      case PostKind.announcement:
        return 'School announcement';
      case PostKind.competition:
        return 'Competition';
      case PostKind.camp:
        return 'Camp';
      case PostKind.volunteer:
        return 'Volunteering';
      case PostKind.vacation:
        return 'Vacation';
    }
  }

  IconData get icon {
    switch (this) {
      case PostKind.announcement:
        return Icons.campaign_rounded;
      case PostKind.competition:
        return Icons.emoji_events_rounded;
      case PostKind.camp:
        return Icons.forest_rounded;
      case PostKind.volunteer:
        return Icons.volunteer_activism_rounded;
      case PostKind.vacation:
        return Icons.beach_access_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case PostKind.announcement:
        return const Color(0xFF2848B0);
      case PostKind.competition:
        return const Color(0xFFC07800);
      case PostKind.camp:
        return const Color(0xFF2E7D32);
      case PostKind.volunteer:
        return const Color(0xFF7B1FA2);
      case PostKind.vacation:
        return const Color(0xFF0277BD);
    }
  }

  List<Color> get headerGradient {
    switch (this) {
      case PostKind.announcement:
        return const [Color(0xFF1E3CA0), Color(0xFF2848B0), Color(0xFF3060D0)];
      case PostKind.competition:
        return const [Color(0xFF8A5000), Color(0xFFC07800), Color(0xFFD89020)];
      case PostKind.camp:
        return const [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF3E9142)];
      case PostKind.volunteer:
        return const [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFF9C27B0)];
      case PostKind.vacation:
        return const [Color(0xFF01579B), Color(0xFF0277BD), Color(0xFF0288D1)];
    }
  }

  String get categoryKey {
    switch (this) {
      case PostKind.announcement:
        return 'announcement';
      case PostKind.competition:
        return 'competition';
      case PostKind.camp:
        return 'camp';
      case PostKind.volunteer:
        return 'volunteer';
      case PostKind.vacation:
        return 'vacation';
    }
  }
}

Future<void> showPostComposerDialog(
  BuildContext context, {
  PostComposerMode mode = PostComposerMode.secretariat,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AdminPostComposerPage(
              embedded: true,
              formOnly: true,
              mode: mode,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Post composer page.
///
/// - In `mode = secretariat`, the user can target the whole school OR pick
///   any combination of classes, and can post all 4 categories.
/// - In `mode = teacher`, the audience is locked to the homeroom teacher's own
///   classId, and only Announcement / Competition / Camp / Volunteering for that
///   class are available.
class AdminPostComposerPage extends StatefulWidget {
  /// Whether the composer is rendered embedded inside the secretariat shell
  /// (no AppBar / Scaffold) or as a full-screen page.
  final bool embedded;

  /// When true, renders only the kind chips + form card (no page header or recent-posts list).
  /// Used inside the popup dialog.
  final bool formOnly;

  /// `secretariat` (full audience picker) or `teacher` (locked to own class).
  final PostComposerMode mode;

  const AdminPostComposerPage({
    super.key,
    this.embedded = false,
    this.formOnly = false,
    this.mode = PostComposerMode.secretariat,
  });

  @override
  State<AdminPostComposerPage> createState() => _AdminPostComposerPageState();
}

enum PostComposerMode { secretariat, teacher }

class _AdminPostComposerPageState extends State<AdminPostComposerPage> {
  PostKind _kind = PostKind.announcement;

  // Picks copy based on the composer mode (teacher vs. secretariat).
  String _modeText(String forTeacher, String forSecretariat) =>
      widget.mode == PostComposerMode.teacher ? forTeacher : forSecretariat;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();

  DateTime? _eventDate;
  DateTime? _eventEndDate;
  bool _submitting = false;

  Uint8List? _imageBytes;
  String? _imagePath;

  String? _flashError;

  /// `null` = school-wide; otherwise an explicit list of classIds.
  Set<String>? _selectedClassIds;

  @override
  void initState() {
    super.initState();
    if (widget.mode == PostComposerMode.teacher) {
      final classId = (AppSession.classId ?? '').trim();
      _selectedClassIds = classId.isEmpty ? <String>{} : {classId};
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imagePath = picked.path;
    });
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _imagePath = null;
    });
  }

  Future<String?> _uploadImageIfAny(String broadcastId) async {
    if (_imageBytes == null) return null;
    final ref = FirebaseStorage.instance.ref(
      'secretariat_posts/$broadcastId.jpg',
    );
    final meta = SettableMetadata(contentType: 'image/jpeg');
    if (kIsWeb || _imagePath == null) {
      final snap = await ref.putData(_imageBytes!, meta);
      return snap.ref.getDownloadURL();
    }
    final snap = await ref.putFile(File(_imagePath!), meta);
    return snap.ref.getDownloadURL();
  }

  Future<void> _pickEventDate({required bool isEnd}) async {
    final initial = isEnd
        ? (_eventEndDate ??
              _eventDate ??
              DateTime.now().add(const Duration(days: 1)))
        : (_eventDate ?? DateTime.now().add(const Duration(days: 1)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _eventEndDate = picked;
      } else {
        _eventDate = picked;
      }
    });
  }

  String? _validate() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return _modeText('Add a title.', 'Add a title.');

    if (_kind == PostKind.vacation) {
      if (_eventDate == null) {
        return _modeText(
          'Pick the vacation start date.',
          'Pick the vacation start date.',
        );
      }
      if (_eventEndDate == null) {
        return _modeText(
          'Pick the vacation end date.',
          'Pick the vacation end date.',
        );
      }
      if (_eventEndDate!.isBefore(_eventDate!)) {
        return _modeText(
          'End date must be after start date.',
          'End date must be after start date.',
        );
      }
      return null;
    }

    final desc = _descCtrl.text.trim();
    if (desc.length < 20) {
      return _modeText(
        'Description must be at least 20 characters.',
        'Description must be at least 20 characters.',
      );
    }
    if (widget.mode == PostComposerMode.secretariat) {
      if (_selectedClassIds != null && _selectedClassIds!.isEmpty) {
        return 'Select at least one class or "Whole school".';
      }
    }
    switch (_kind) {
      case PostKind.competition:
      case PostKind.camp:
      case PostKind.volunteer:
        if (_eventDate == null) {
          return _modeText('Pick the event date.', 'Pick the event date.');
        }
        break;
      case PostKind.announcement:
      case PostKind.vacation:
        break;
    }
    final link = _linkCtrl.text.trim();
    if (link.isNotEmpty &&
        !link.startsWith('http://') &&
        !link.startsWith('https://')) {
      return _modeText(
        'Link must start with http:// or https://.',
        'Link must start with http:// or https://.',
      );
    }
    return null;
  }

  List<String> _audienceClassIds() {
    if (_selectedClassIds == null) return const [kAudienceAll];
    return _selectedClassIds!.toList()..sort();
  }

  String _audienceLabel(List<String> ids) {
    if (ids.contains(kAudienceAll)) return 'Whole school';
    if (ids.length == 1) return 'Class ${ids.first}';
    return '${ids.length} classes';
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _flashError = err);
      return;
    }
    setState(() {
      _submitting = true;
      _flashError = null;
    });
    final messenger = ScaffoldMessenger.of(context);

    try {
      final audience = _audienceClassIds();
      final senderUid = AppSession.uid ?? '';
      final senderName = AppSession.fullName ?? AppSession.username ?? '';
      final senderRole = AppSession.role ?? 'admin';
      final title = _titleCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      final location = _locationCtrl.text.trim();
      final link = _linkCtrl.text.trim();

      final broadcastId =
          '${DateTime.now().millisecondsSinceEpoch}_${_kind.categoryKey}';
      final imageUrl = await _uploadImageIfAny(broadcastId);

      if (_kind == PostKind.vacation) {
        final vacationName = title;
        // Save to vacancies for the school calendar
        await FirebaseFirestore.instance.collection('vacancies').add({
          'name': vacationName,
          'startDate': Timestamp.fromDate(_eventDate!),
          'endDate': Timestamp.fromDate(_eventEndDate!),
          'createdAt': FieldValue.serverTimestamp(),
          'imageUrl': ?imageUrl,
        });
        // Broadcast to students; parents see student-targeted broadcasts via
        // Firestore rules.
        await FirebaseFirestore.instance.collection('secretariatMessages').add({
          'recipientRole': 'student',
          'recipientUid': '',
          'studentUid': '',
          'studentUsername': '',
          'studentName': '',
          'classId': '',
          'recipientName': '',
          'recipientUsername': '',
          'message':
              'Vacation: $vacationName\n'
              '${_fmtDate(_eventDate!)} – ${_fmtDate(_eventEndDate!)}',
          'title': vacationName,
          'category': 'vacation',
          'audienceClassIds': const [kAudienceAll],
          'audienceLabel': 'Whole school',
          'location': '',
          'link': '',
          'eventDate': Timestamp.fromDate(_eventDate!),
          'eventEndDate': Timestamp.fromDate(_eventEndDate!),
          'createdAt': FieldValue.serverTimestamp(),
          'senderUid': senderUid,
          'senderName': senderName,
          'senderRole': senderRole,
          'broadcastId': broadcastId,
          'messageType': 'secretariatGlobal',
          'source': 'secretariat',
          'status': 'active',
          'imageUrl': ?imageUrl,
        });
      } else {
        // Announcement / Competition / Camp → secretariatMessages broadcast.
        // Parents see student-targeted broadcasts via Firestore rules.
        await FirebaseFirestore.instance.collection('secretariatMessages').add({
          'recipientRole': 'student',
          'recipientUid': '',
          'studentUid': '',
          'studentUsername': '',
          'studentName': '',
          'classId': '',
          'recipientName': '',
          'recipientUsername': '',
          'message': desc,
          'title': title,
          'category': _kind.categoryKey,
          'audienceClassIds': audience,
          'audienceLabel': _audienceLabel(audience),
          'location': location,
          'link': link,
          'eventDate': _eventDate != null
              ? Timestamp.fromDate(_eventDate!)
              : null,
          'eventEndDate': _eventEndDate != null
              ? Timestamp.fromDate(_eventEndDate!)
              : null,
          'createdAt': FieldValue.serverTimestamp(),
          'senderUid': senderUid,
          'senderName': senderName,
          'senderRole': senderRole,
          'broadcastId': broadcastId,
          'messageType': 'secretariatGlobal',
          'source': senderRole == 'teacher' ? 'teacher' : 'secretariat',
          'status': 'active',
          'imageUrl': ?imageUrl,
        });
      }

      if (!mounted) return;
      final successMsg = '${_kindLabel(_kind)} published!';
      if (widget.formOnly) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMsg),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMsg),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      setState(() => _flashError = 'Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  void _resetForm() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _locationCtrl.clear();
    _linkCtrl.clear();
    setState(() {
      _eventDate = null;
      _eventEndDate = null;
      _imageBytes = null;
      _imagePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.formOnly) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 12, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3CA0), Color(0xFF2848B0), Color(0xFF3060D0)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'New post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
          Flexible(
            child: Container(
              color: _surfaceColor,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildKindChips(),
                      const SizedBox(height: 14),
                      _buildComposerCard(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final subtitle = _modeText(
      'Send announcements, competitions, camps and volunteering for your class.',
      widget.mode == PostComposerMode.teacher
          ? 'Send announcements, competitions, camps and volunteering for your class.'
          : 'Compose announcements, competitions, camps and volunteering for the whole school or selected classes.',
    );
    final pageTitle = _modeText('Posts', 'Posts');
    final recentLabel = _modeText('Recent posts', 'Recent posts');

    if (widget.embedded) {
      return Container(
        color: _surfaceColor,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pageTitle,
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: _outline, fontSize: 13),
              ),
              const SizedBox(height: 20),
              _buildKindChips(),
              const SizedBox(height: 16),
              _buildComposerCard(),
              const SizedBox(height: 24),
              Text(
                recentLabel,
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _PostsManagementList(
                mode: widget.mode,
                ownerUid: AppSession.uid ?? '',
                ownerClassId: (AppSession.classId ?? '').trim(),
              ),
            ],
          ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PageBlueHeader(
              title: pageTitle,
              subtitle: _modeText(
                'For your class',
                widget.mode == PostComposerMode.teacher
                    ? 'For your class'
                    : 'For the school',
              ),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _outline,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildKindChips(),
                      const SizedBox(height: 16),
                      _buildComposerCard(),
                      const SizedBox(height: 24),
                      Text(
                        recentLabel,
                        style: const TextStyle(
                          color: _onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PostsManagementList(
                        mode: widget.mode,
                        ownerUid: AppSession.uid ?? '',
                        ownerClassId: (AppSession.classId ?? '').trim(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(PostKind k) {
    if (widget.mode == PostComposerMode.teacher) {
      switch (k) {
        case PostKind.announcement:
          return 'Announcement';
        case PostKind.competition:
          return 'Competition';
        case PostKind.camp:
          return 'Camp';
        case PostKind.volunteer:
          return 'Volunteer';
        case PostKind.vacation:
          return 'Vacation';
      }
    }
    return k.label;
  }

  List<PostKind> get _visibleKinds {
    if (widget.mode == PostComposerMode.teacher) {
      // Teachers can't create vacancies (school-wide calendar entries).
      return PostKind.values
          .where((k) => k != PostKind.vacation)
          .toList();
    }
    return PostKind.values;
  }

  Widget _buildKindChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _visibleKinds.map((k) {
        final selected = _kind == k;
        final chipColor = selected ? k.accentColor : _cardBg;
        final borderColor = selected ? k.accentColor : const Color(0xFFD2DEE7);
        return GestureDetector(
          onTap: () => setState(() => _kind = k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  k.icon,
                  size: 16,
                  color: selected ? Colors.white : k.accentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  _kindLabel(k),
                  style: TextStyle(
                    color: selected ? Colors.white : _onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildComposerCard() {
    final color = _primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_kind.icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_modeText('New post', 'New post')} · ${_kindLabel(_kind)}',
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (_flashError != null) ...[
            const SizedBox(height: 12),
            _buildErrorBanner(_flashError!),
          ],
          const SizedBox(height: 14),
          _ComposerInput(
            controller: _titleCtrl,
            hint: _kind == PostKind.vacation
                ? _modeText(
                    'Vacation name * (e.g. Winter break)',
                    'Vacation name * (e.g. Winter break)',
                  )
                : _modeText('Title *', 'Title *'),
            maxLength: 90,
          ),
          if (_kind == PostKind.vacation) ...[
            const SizedBox(height: 10),
            _buildDatePickers(),
          ] else ...[
            const SizedBox(height: 10),
            _ComposerInput(
              controller: _descCtrl,
              hint: _modeText(
                'Description * (min. 20 characters)',
                'Description * (min. 20 characters)',
              ),
              maxLines: 4,
              maxLength: 800,
            ),
            const SizedBox(height: 10),
            if (_kind != PostKind.announcement) ...[
              _ComposerInput(
                controller: _locationCtrl,
                hint: _modeText('Location', 'Location'),
              ),
              const SizedBox(height: 10),
            ],
            _ComposerInput(
              controller: _linkCtrl,
              hint: _modeText(
                'External link (optional, https://...)',
                'External link (optional, https://...)',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            if (_kind != PostKind.announcement) _buildDatePickers(),
          ],
          const SizedBox(height: 14),
          _buildImagePicker(),
          const SizedBox(height: 14),
          if (_kind != PostKind.vacation) _buildAudienceSelector(),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _submitting ? null : _submit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: _submitting ? color.withValues(alpha: 0.45) : color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _modeText('Publish', 'Publish'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickers() {
    final showRange = _kind == PostKind.camp || _kind == PostKind.vacation;
    final startLabel = _kind == PostKind.vacation
        ? _modeText('Start *', 'Start *')
        : (showRange
            ? _modeText('Start', 'Start')
            : _modeText('Date *', 'Date *'));
    final endLabel = _kind == PostKind.vacation
        ? _modeText('End *', 'End *')
        : _modeText('End', 'End');
    return Row(
      children: [
        Expanded(
          child: _DateField(
            label: startLabel,
            date: _eventDate,
            onTap: () => _pickEventDate(isEnd: false),
          ),
        ),
        if (showRange) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _DateField(
              label: endLabel,
              date: _eventEndDate,
              onTap: () => _pickEventDate(isEnd: true),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _flashError = null),
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.close_rounded, color: _danger, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasImage = _imageBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PHOTO',
          style: TextStyle(
            color: _outline,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        if (hasImage)
          Container(
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.memory(
                    _imageBytes!,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _submitting ? null : _pickImage,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text('Replace'),
                        style: TextButton.styleFrom(
                          foregroundColor: _primary,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _submitting ? null : _clearImage,
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(
                          foregroundColor: _danger,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: _submitting ? null : _pickImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: _fieldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFC0C4D8),
                  style: BorderStyle.solid,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_photo_alternate_rounded,
                    color: _outline,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _modeText('Add a photo (optional)', 'Add a photo (optional)'),
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudienceSelector() {
    if (widget.mode == PostComposerMode.teacher) {
      final classId = (AppSession.classId ?? '').trim();
      if (classId.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _fieldBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_rounded, size: 16, color: _outline),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Audience: your class (not configured)',
                  style: TextStyle(
                    color: _onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      final wholeSchool = _selectedClassIds == null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AUDIENCE',
            style: TextStyle(
              color: _outline,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          _TeacherAudienceOption(
            icon: Icons.groups_rounded,
            label: 'My class · $classId',
            selected: !wholeSchool,
            onTap: () => setState(() => _selectedClassIds = {classId}),
          ),
          const SizedBox(height: 8),
          _TeacherAudienceOption(
            icon: Icons.public_rounded,
            label: 'Whole school',
            selected: wholeSchool,
            onTap: () => setState(() => _selectedClassIds = null),
          ),
        ],
      );
    }

    final allSelected = _selectedClassIds == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AUDIENCE',
          style: TextStyle(
            color: _outline,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _selectedClassIds = null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: allSelected ? _primary : _fieldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  allSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: allSelected ? Colors.white : _outline,
                ),
                const SizedBox(width: 10),
                Text(
                  'Whole school',
                  style: TextStyle(
                    color: allSelected ? Colors.white : _onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('classes').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 30,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final classes = snap.data!.docs.map((d) {
              final m = d.data();
              return _ClassOption(
                id: d.id,
                name: (m['name'] ?? d.id).toString(),
              );
            }).toList()..sort((a, b) => a.name.compareTo(b.name));
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: classes.map((c) {
                final selected =
                    _selectedClassIds != null &&
                    _selectedClassIds!.contains(c.id);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedClassIds ??= <String>{};
                      if (_selectedClassIds!.contains(c.id)) {
                        _selectedClassIds!.remove(c.id);
                      } else {
                        _selectedClassIds!.add(c.id);
                      }
                      if (_selectedClassIds!.isEmpty) {
                        _selectedClassIds = null;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? _primary : _fieldBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      c.name,
                      style: TextStyle(
                        color: selected ? Colors.white : _onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ClassOption {
  final String id;
  final String name;
  const _ClassOption({required this.id, required this.name});
}

class _TeacherAudienceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TeacherAudienceOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _primary : _fieldBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? Colors.white : _outline,
            ),
            const SizedBox(width: 10),
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : _onSurface,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// COMPOSER INPUT
class _ComposerInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;

  const _ComposerInput({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType ?? TextInputType.text,
      style: const TextStyle(
        color: _onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _outline, fontSize: 13),
        filled: true,
        fillColor: _fieldBg,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// DATE FIELD
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final txt = date == null
        ? label
        : '${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 15, color: _outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                txt,
                style: TextStyle(
                  color: date == null ? _outline : _onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// POSTS MANAGEMENT LIST
class _PostsManagementList extends StatelessWidget {
  final PostComposerMode mode;
  final String ownerUid;
  final String ownerClassId;

  const _PostsManagementList({
    required this.mode,
    required this.ownerUid,
    required this.ownerClassId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('secretariatMessages')
              .where('messageType', isEqualTo: 'secretariatGlobal')
              .where('recipientRole', isEqualTo: 'student')
              .where('recipientUid', isEqualTo: '')
              .limit(80)
              .snapshots(),
          builder: (context, msgSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('volunteerOpportunities')
                  .limit(80)
                  .snapshots(),
              builder: (context, volSnap) {
                if (!msgSnap.hasData || !volSnap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final items = <_PostItem>[];

                for (final doc in msgSnap.data!.docs) {
                  final d = doc.data();
                  if (!_canSee(d)) continue;
                  final created = (d['createdAt'] as Timestamp?)?.toDate();
                  items.add(
                    _PostItem(
                      id: doc.id,
                      collection: 'secretariatMessages',
                      title: (d['title'] ?? '').toString(),
                      message: (d['message'] ?? '').toString(),
                      category: (d['category'] ?? 'announcement').toString(),
                      audienceLabel: (d['audienceLabel'] ?? '').toString(),
                      audienceClassIds: List<String>.from(
                        (d['audienceClassIds'] ?? const []) as List,
                      ),
                      createdAt: created,
                      archived:
                          (d['status'] ?? 'active').toString() == 'archived',
                      senderName: (d['senderName'] ?? '').toString(),
                    ),
                  );
                }

                for (final doc in volSnap.data!.docs) {
                  final d = doc.data();
                  if (!_canSee(d)) continue;
                  final created = (d['createdAt'] as Timestamp?)?.toDate();
                  items.add(
                    _PostItem(
                      id: doc.id,
                      collection: 'volunteerOpportunities',
                      title: (d['title'] ?? '').toString(),
                      message: (d['description'] ?? '').toString(),
                      category: 'volunteer',
                      audienceLabel: _legacyAudienceLabel(d),
                      audienceClassIds: List<String>.from(
                        (d['audienceClassIds'] ?? const []) as List,
                      ),
                      createdAt: created,
                      archived:
                          (d['status'] ?? 'active').toString() == 'archived',
                      senderName: (d['createdByName'] ?? '').toString(),
                    ),
                  );
                }

                items.sort((a, b) {
                  final ad =
                      a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bd =
                      b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bd.compareTo(ad);
                });

                if (items.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      mode == PostComposerMode.teacher
                          ? 'No posts yet.'
                          : 'No posts yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _outline, fontSize: 13),
                    ),
                  );
                }

                return Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PostCard(item: item, mode: mode),
                        ),
                      )
                      .toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  bool _canSee(Map<String, dynamic> d) {
    if (mode == PostComposerMode.secretariat) return true;
    // Teacher: only posts they created themselves. Secretariat broadcasts that
    // happen to target their class are not theirs to archive or delete.
    final senderUid = (d['createdBy'] ?? d['senderUid'] ?? '').toString();
    return senderUid == ownerUid;
  }

  String _legacyAudienceLabel(Map<String, dynamic> d) {
    final isTeacher = mode == PostComposerMode.teacher;
    final audience = (d['audienceClassIds'] as List?) ?? const [];
    if (audience.isNotEmpty) {
      if (audience.contains(kAudienceAll)) {
        return isTeacher ? 'Whole school' : 'Whole school';
      }
      if (audience.length == 1) {
        return isTeacher ? 'Class ${audience.first}' : 'Class ${audience.first}';
      }
      return isTeacher
          ? '${audience.length} classes'
          : '${audience.length} classes';
    }
    final classId = d['classId'];
    if (classId == null) return isTeacher ? 'Whole school' : 'Whole school';
    return isTeacher ? 'Class $classId' : 'Class $classId';
  }
}

class _PostItem {
  final String id;
  final String collection;
  final String title;
  final String message;
  final String category;
  final String audienceLabel;
  final List<String> audienceClassIds;
  final DateTime? createdAt;
  final bool archived;
  final String senderName;

  const _PostItem({
    required this.id,
    required this.collection,
    required this.title,
    required this.message,
    required this.category,
    required this.audienceLabel,
    required this.audienceClassIds,
    required this.createdAt,
    required this.archived,
    required this.senderName,
  });
}

class _PostCard extends StatelessWidget {
  final _PostItem item;
  final PostComposerMode mode;
  const _PostCard({required this.item, required this.mode});

  bool get _isTeacher => mode == PostComposerMode.teacher;

  IconData get _icon {
    switch (item.category) {
      case 'competition':
        return Icons.emoji_events_rounded;
      case 'camp':
        return Icons.forest_rounded;
      case 'volunteer':
        return Icons.volunteer_activism_rounded;
      case 'vacation':
        return Icons.beach_access_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  String get _label {
    if (_isTeacher) {
      switch (item.category) {
        case 'competition':
          return 'Competition';
        case 'camp':
          return 'Camp';
        case 'volunteer':
          return 'Volunteer';
        case 'vacation':
          return 'Vacation';
        default:
          return 'Announcement';
      }
    }
    switch (item.category) {
      case 'competition':
        return 'Competition';
      case 'camp':
        return 'Camp';
      case 'volunteer':
        return 'Volunteering';
      case 'vacation':
        return 'Vacation';
      default:
        return 'Announcement';
    }
  }

  Future<void> _archive(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection(item.collection)
        .doc(item.id)
        .update({'status': item.archived ? 'active' : 'archived'});
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _isTeacher ? 'Delete post?' : 'Delete post?',
        ),
        content: Text(
          _isTeacher
              ? 'Post "${item.title}" will be permanently deleted. Are you sure?'
              : 'Post "${item.title}" will be permanently deleted. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_isTeacher ? 'Cancel' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _isTeacher ? 'Delete' : 'Delete',
              style: const TextStyle(color: _danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection(item.collection)
        .doc(item.id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final created = item.createdAt;
    final dateStr = created == null
        ? '—'
        : '${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')}.${created.year}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.archived ? const Color(0xFFF0F4F7) : _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty
                          ? (_isTeacher ? '(no title)' : '(no title)')
                          : item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Tag(text: _label, color: _primary),
                        _Tag(
                          text: item.audienceLabel.isEmpty
                              ? (_isTeacher ? 'Whole school' : 'Whole school')
                              : item.audienceLabel,
                          color: const Color(0xFF6F8FA9),
                        ),
                        _Tag(text: dateStr, color: _outline),
                        if (item.archived)
                          _Tag(
                            text: _isTeacher ? 'Archived' : 'Archived',
                            color: _danger,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _outline,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (item.senderName.isNotEmpty)
                Expanded(
                  child: Text(
                    _isTeacher
                        ? 'by ${item.senderName}'
                        : 'by ${item.senderName}',
                    style: const TextStyle(
                      color: _outline,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                const Spacer(),
              TextButton.icon(
                onPressed: () => _archive(context),
                icon: Icon(
                  item.archived
                      ? Icons.unarchive_rounded
                      : Icons.archive_rounded,
                  size: 16,
                ),
                label: Text(
                  _isTeacher
                      ? (item.archived ? 'Reactivate' : 'Archive')
                      : (item.archived ? 'Reactivate' : 'Archive'),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _delete(context),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: Text(_isTeacher ? 'Delete' : 'Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: _danger,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
