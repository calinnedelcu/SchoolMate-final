// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'Aegis';

  @override
  String get languageRomanian => 'Română';

  @override
  String get languageEnglish => 'Engleză';

  @override
  String get settingsAccountTitle => 'Setări cont';

  @override
  String get settingsEditProfile => 'Editare profil';

  @override
  String get settingsAccessibility => 'Accesibilitate';

  @override
  String get settingsLanguage => 'Limbă';

  @override
  String get settingsLogout => 'Deconectează-te';

  @override
  String get languageSheetTitle => 'Alege limba';

  @override
  String get accessibilityHeaderTitle => 'Accesibilitate';

  @override
  String get accessibilityHeaderSubtitle => 'Personalizează experiența vizuală';

  @override
  String get accessibilitySectionDisplay => 'Vizualizare';

  @override
  String get accessibilityLargeFontTitle => 'Text mărit';

  @override
  String get accessibilityLargeFontSubtitle =>
      'Mărește dimensiunea textului pentru o citire mai ușoară.';

  @override
  String get accessibilityHighContrastTitle => 'Contrast ridicat';

  @override
  String get accessibilityHighContrastSubtitle =>
      'Folosește alb și negru pentru o vizibilitate maximă.';

  @override
  String get accessibilityPreviewTitle => 'Previzualizare';

  @override
  String get accessibilityPreviewBody =>
      'Acesta este un exemplu de text. Modificările făcute mai sus se aplică imediat în toată aplicația.';

  @override
  String get accessibilityInfoBanner =>
      'Setările sunt salvate pe acest dispozitiv și rămân active la următoarea deschidere.';

  @override
  String homeGreeting(String name) {
    return 'Bună, $name';
  }

  @override
  String get homeTodayCardTitle => 'Azi';

  @override
  String get homeTodayInProgress => 'Ești la școală acum';

  @override
  String homeTodayUpcoming(String start) {
    return 'Programul începe la $start';
  }

  @override
  String get homeTodayFinished => 'Programul de azi s-a încheiat';

  @override
  String get homeTodayNoSchedule => 'Astăzi nu ai program';

  @override
  String homeTodayInterval(String start, String end) {
    return 'Program: $start – $end';
  }

  @override
  String get homeTodayViewFull => 'Vezi orarul complet';

  @override
  String get homeRequestCardTitle => 'Cerere de învoire';

  @override
  String get homeRequestNoneSubtitle => 'Nu ai nicio cerere activă';

  @override
  String get homeRequestNoneCta => 'Creează cerere nouă';

  @override
  String get homeRequestPendingSubtitle => 'Cerere trimisă, așteaptă aprobare';

  @override
  String get homeRequestPendingChip => 'În așteptare';

  @override
  String get homeRequestActiveSubtitle =>
      'Învoire aprobată — gata pentru ieșire';

  @override
  String get homeRequestActiveCta => 'Arată QR pentru portar';

  @override
  String get homeRequestActiveChip => 'Activă';

  @override
  String get homeInboxPreviewTitle => 'Mesaje recente';

  @override
  String get homeInboxNoMessages => 'Nu ai mesaje noi';

  @override
  String homeInboxUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesaje noi',
      one: '1 mesaj nou',
      zero: 'Niciun mesaj nou',
    );
    return '$_temp0';
  }

  @override
  String get homeInboxOpenCta => 'Vezi toate mesajele';

  @override
  String get homeQuickActionsTitle => 'Acces rapid';

  @override
  String get homeQuickActionTutoring => 'Peer Tutoring';

  @override
  String get homeQuickActionSchedule => 'Orar complet';

  @override
  String get homeQuickActionMessages => 'Mesaje';

  @override
  String get qrSheetTitle => 'Cod pentru portar';

  @override
  String get qrSheetSubtitle =>
      'Arată acest cod portarului pentru a verifica învoirea ta.';

  @override
  String qrSheetExpiresIn(int seconds) {
    return 'Se reînnoiește în ${seconds}s';
  }

  @override
  String get qrSheetClose => 'Închide';

  @override
  String get inboxTitle => 'Mesaje';

  @override
  String get inboxFilterAll => 'Toate';

  @override
  String get inboxFilterSchool => 'Școală';

  @override
  String get inboxFilterTeachers => 'Profesori';

  @override
  String get inboxFilterVolunteer => 'Voluntariat';

  @override
  String get inboxFilterAnnouncements => 'Anunțuri';

  @override
  String get inboxEmpty => 'Nu există mesaje în această categorie.';

  @override
  String get inboxVolunteerSignUp => 'Mă înscriu';

  @override
  String get inboxVolunteerSignedUp => 'Înscris';

  @override
  String inboxVolunteerHours(int hours) {
    return '${hours}h';
  }

  @override
  String get inboxVolunteerLabel => 'Voluntariat';

  @override
  String get inboxVolunteerSignupSuccess => 'Te-ai înscris cu succes!';
}
