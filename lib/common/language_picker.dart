import 'package:firster/l10n/app_localizations.dart';
import 'package:firster/services/locale_service.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF1F8BE7);
const _surfaceLowest = Color(0xFFFFFFFF);
const _outlineVariant = Color(0xFFBACCD9);
const _onSurface = Color(0xFF587F9E);

/// Shows a bottom sheet that lets the user pick the application language.
///
/// Writes the choice to [LocaleService] which persists it in SharedPreferences
/// and triggers the MaterialApp to rebuild with the new locale.
Future<void> showLanguagePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _LanguagePickerSheet(),
  );
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet();

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final _service = LocaleService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final current = _service.locale.languageCode;

    return Container(
      decoration: const BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l.languageSheetTitle,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _LanguageTile(
            flag: '🇷🇴',
            label: l.languageRomanian,
            selected: current == 'ro',
            onTap: () async {
              await _service.setLocale(const Locale('ro'));
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          _LanguageTile(
            flag: '🇬🇧',
            label: l.languageEnglish,
            selected: current == 'en',
            onTap: () async {
              await _service.setLocale(const Locale('en'));
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _primary.withValues(alpha: 0.10)
          : const Color(0xFFE7F0F6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? _primary : _onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: _primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
