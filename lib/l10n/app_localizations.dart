import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ro'),
  ];

  /// Application title shown in the system task switcher
  ///
  /// In ro, this message translates to:
  /// **'Aegis'**
  String get appTitle;

  /// No description provided for @languageRomanian.
  ///
  /// In ro, this message translates to:
  /// **'Română'**
  String get languageRomanian;

  /// No description provided for @languageEnglish.
  ///
  /// In ro, this message translates to:
  /// **'Engleză'**
  String get languageEnglish;

  /// No description provided for @settingsAccountTitle.
  ///
  /// In ro, this message translates to:
  /// **'Setări cont'**
  String get settingsAccountTitle;

  /// No description provided for @settingsEditProfile.
  ///
  /// In ro, this message translates to:
  /// **'Editare profil'**
  String get settingsEditProfile;

  /// No description provided for @settingsAccessibility.
  ///
  /// In ro, this message translates to:
  /// **'Accesibilitate'**
  String get settingsAccessibility;

  /// No description provided for @settingsLanguage.
  ///
  /// In ro, this message translates to:
  /// **'Limbă'**
  String get settingsLanguage;

  /// No description provided for @settingsLogout.
  ///
  /// In ro, this message translates to:
  /// **'Deconectează-te'**
  String get settingsLogout;

  /// No description provided for @languageSheetTitle.
  ///
  /// In ro, this message translates to:
  /// **'Alege limba'**
  String get languageSheetTitle;

  /// No description provided for @accessibilityHeaderTitle.
  ///
  /// In ro, this message translates to:
  /// **'Accesibilitate'**
  String get accessibilityHeaderTitle;

  /// No description provided for @accessibilityHeaderSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Personalizează experiența vizuală'**
  String get accessibilityHeaderSubtitle;

  /// No description provided for @accessibilitySectionDisplay.
  ///
  /// In ro, this message translates to:
  /// **'Vizualizare'**
  String get accessibilitySectionDisplay;

  /// No description provided for @accessibilityLargeFontTitle.
  ///
  /// In ro, this message translates to:
  /// **'Text mărit'**
  String get accessibilityLargeFontTitle;

  /// No description provided for @accessibilityLargeFontSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Mărește dimensiunea textului pentru o citire mai ușoară.'**
  String get accessibilityLargeFontSubtitle;

  /// No description provided for @accessibilityHighContrastTitle.
  ///
  /// In ro, this message translates to:
  /// **'Contrast ridicat'**
  String get accessibilityHighContrastTitle;

  /// No description provided for @accessibilityHighContrastSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Folosește alb și negru pentru o vizibilitate maximă.'**
  String get accessibilityHighContrastSubtitle;

  /// No description provided for @accessibilityPreviewTitle.
  ///
  /// In ro, this message translates to:
  /// **'Previzualizare'**
  String get accessibilityPreviewTitle;

  /// No description provided for @accessibilityPreviewBody.
  ///
  /// In ro, this message translates to:
  /// **'Acesta este un exemplu de text. Modificările făcute mai sus se aplică imediat în toată aplicația.'**
  String get accessibilityPreviewBody;

  /// No description provided for @accessibilityInfoBanner.
  ///
  /// In ro, this message translates to:
  /// **'Setările sunt salvate pe acest dispozitiv și rămân active la următoarea deschidere.'**
  String get accessibilityInfoBanner;

  /// No description provided for @homeGreeting.
  ///
  /// In ro, this message translates to:
  /// **'Bună, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeTodayCardTitle.
  ///
  /// In ro, this message translates to:
  /// **'Azi'**
  String get homeTodayCardTitle;

  /// No description provided for @homeTodayInProgress.
  ///
  /// In ro, this message translates to:
  /// **'Ești la școală acum'**
  String get homeTodayInProgress;

  /// No description provided for @homeTodayUpcoming.
  ///
  /// In ro, this message translates to:
  /// **'Programul începe la {start}'**
  String homeTodayUpcoming(String start);

  /// No description provided for @homeTodayFinished.
  ///
  /// In ro, this message translates to:
  /// **'Programul de azi s-a încheiat'**
  String get homeTodayFinished;

  /// No description provided for @homeTodayNoSchedule.
  ///
  /// In ro, this message translates to:
  /// **'Astăzi nu ai program'**
  String get homeTodayNoSchedule;

  /// No description provided for @homeTodayInterval.
  ///
  /// In ro, this message translates to:
  /// **'Program: {start} – {end}'**
  String homeTodayInterval(String start, String end);

  /// No description provided for @homeTodayViewFull.
  ///
  /// In ro, this message translates to:
  /// **'Vezi orarul complet'**
  String get homeTodayViewFull;

  /// No description provided for @homeRequestCardTitle.
  ///
  /// In ro, this message translates to:
  /// **'Cerere de învoire'**
  String get homeRequestCardTitle;

  /// No description provided for @homeRequestNoneSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai nicio cerere activă'**
  String get homeRequestNoneSubtitle;

  /// No description provided for @homeRequestNoneCta.
  ///
  /// In ro, this message translates to:
  /// **'Creează cerere nouă'**
  String get homeRequestNoneCta;

  /// No description provided for @homeRequestPendingSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Cerere trimisă, așteaptă aprobare'**
  String get homeRequestPendingSubtitle;

  /// No description provided for @homeRequestPendingChip.
  ///
  /// In ro, this message translates to:
  /// **'În așteptare'**
  String get homeRequestPendingChip;

  /// No description provided for @homeRequestActiveSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Învoire aprobată — gata pentru ieșire'**
  String get homeRequestActiveSubtitle;

  /// No description provided for @homeRequestActiveCta.
  ///
  /// In ro, this message translates to:
  /// **'Arată QR pentru portar'**
  String get homeRequestActiveCta;

  /// No description provided for @homeRequestActiveChip.
  ///
  /// In ro, this message translates to:
  /// **'Activă'**
  String get homeRequestActiveChip;

  /// No description provided for @homeInboxPreviewTitle.
  ///
  /// In ro, this message translates to:
  /// **'Mesaje recente'**
  String get homeInboxPreviewTitle;

  /// No description provided for @homeInboxNoMessages.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai mesaje noi'**
  String get homeInboxNoMessages;

  /// No description provided for @homeInboxUnreadCount.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, =0{Niciun mesaj nou} =1{1 mesaj nou} other{{count} mesaje noi}}'**
  String homeInboxUnreadCount(int count);

  /// No description provided for @homeInboxOpenCta.
  ///
  /// In ro, this message translates to:
  /// **'Vezi toate mesajele'**
  String get homeInboxOpenCta;

  /// No description provided for @homeQuickActionsTitle.
  ///
  /// In ro, this message translates to:
  /// **'Acces rapid'**
  String get homeQuickActionsTitle;

  /// No description provided for @homeQuickActionTutoring.
  ///
  /// In ro, this message translates to:
  /// **'Peer Tutoring'**
  String get homeQuickActionTutoring;

  /// No description provided for @homeQuickActionSchedule.
  ///
  /// In ro, this message translates to:
  /// **'Orar complet'**
  String get homeQuickActionSchedule;

  /// No description provided for @homeQuickActionMessages.
  ///
  /// In ro, this message translates to:
  /// **'Mesaje'**
  String get homeQuickActionMessages;

  /// No description provided for @qrSheetTitle.
  ///
  /// In ro, this message translates to:
  /// **'Cod pentru portar'**
  String get qrSheetTitle;

  /// No description provided for @qrSheetSubtitle.
  ///
  /// In ro, this message translates to:
  /// **'Arată acest cod portarului pentru a verifica învoirea ta.'**
  String get qrSheetSubtitle;

  /// No description provided for @qrSheetExpiresIn.
  ///
  /// In ro, this message translates to:
  /// **'Se reînnoiește în {seconds}s'**
  String qrSheetExpiresIn(int seconds);

  /// No description provided for @qrSheetClose.
  ///
  /// In ro, this message translates to:
  /// **'Închide'**
  String get qrSheetClose;

  /// No description provided for @inboxTitle.
  ///
  /// In ro, this message translates to:
  /// **'Mesaje'**
  String get inboxTitle;

  /// No description provided for @inboxFilterAll.
  ///
  /// In ro, this message translates to:
  /// **'Toate'**
  String get inboxFilterAll;

  /// No description provided for @inboxFilterSchool.
  ///
  /// In ro, this message translates to:
  /// **'Școală'**
  String get inboxFilterSchool;

  /// No description provided for @inboxFilterTeachers.
  ///
  /// In ro, this message translates to:
  /// **'Profesori'**
  String get inboxFilterTeachers;

  /// No description provided for @inboxFilterVolunteer.
  ///
  /// In ro, this message translates to:
  /// **'Voluntariat'**
  String get inboxFilterVolunteer;

  /// No description provided for @inboxFilterAnnouncements.
  ///
  /// In ro, this message translates to:
  /// **'Anunțuri'**
  String get inboxFilterAnnouncements;

  /// No description provided for @inboxEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nu există mesaje în această categorie.'**
  String get inboxEmpty;

  /// No description provided for @inboxVolunteerSignUp.
  ///
  /// In ro, this message translates to:
  /// **'Mă înscriu'**
  String get inboxVolunteerSignUp;

  /// No description provided for @inboxVolunteerSignedUp.
  ///
  /// In ro, this message translates to:
  /// **'Înscris'**
  String get inboxVolunteerSignedUp;

  /// No description provided for @inboxVolunteerHours.
  ///
  /// In ro, this message translates to:
  /// **'{hours}h'**
  String inboxVolunteerHours(int hours);

  /// No description provided for @inboxVolunteerLabel.
  ///
  /// In ro, this message translates to:
  /// **'Voluntariat'**
  String get inboxVolunteerLabel;

  /// No description provided for @inboxVolunteerSignupSuccess.
  ///
  /// In ro, this message translates to:
  /// **'Te-ai înscris cu succes!'**
  String get inboxVolunteerSignupSuccess;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
