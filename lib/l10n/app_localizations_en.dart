// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Aegis';

  @override
  String get languageRomanian => 'Romanian';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsAccountTitle => 'Account settings';

  @override
  String get settingsEditProfile => 'Edit profile';

  @override
  String get settingsAccessibility => 'Accessibility';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLogout => 'Sign out';

  @override
  String get languageSheetTitle => 'Choose language';

  @override
  String get accessibilityHeaderTitle => 'Accessibility';

  @override
  String get accessibilityHeaderSubtitle => 'Customize your visual experience';

  @override
  String get accessibilitySectionDisplay => 'Display';

  @override
  String get accessibilityLargeFontTitle => 'Larger text';

  @override
  String get accessibilityLargeFontSubtitle =>
      'Increase text size for easier reading.';

  @override
  String get accessibilityHighContrastTitle => 'High contrast';

  @override
  String get accessibilityHighContrastSubtitle =>
      'Use black and white for maximum visibility.';

  @override
  String get accessibilityPreviewTitle => 'Preview';

  @override
  String get accessibilityPreviewBody =>
      'This is an example text. Changes you make above are applied immediately across the app.';

  @override
  String get accessibilityInfoBanner =>
      'Settings are stored on this device and stay active the next time you open the app.';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeTodayCardTitle => 'Today';

  @override
  String get homeTodayInProgress => 'You\'re at school right now';

  @override
  String homeTodayUpcoming(String start) {
    return 'School starts at $start';
  }

  @override
  String get homeTodayFinished => 'Today\'s schedule is over';

  @override
  String get homeTodayNoSchedule => 'No classes today';

  @override
  String homeTodayInterval(String start, String end) {
    return 'Schedule: $start – $end';
  }

  @override
  String get homeTodayViewFull => 'View full schedule';

  @override
  String get homeRequestCardTitle => 'Leave request';

  @override
  String get homeRequestNoneSubtitle => 'You have no active request';

  @override
  String get homeRequestNoneCta => 'Create new request';

  @override
  String get homeRequestPendingSubtitle => 'Request sent, awaiting approval';

  @override
  String get homeRequestPendingChip => 'Pending';

  @override
  String get homeRequestActiveSubtitle => 'Approved — ready to leave';

  @override
  String get homeRequestActiveCta => 'Show QR for the gate';

  @override
  String get homeRequestActiveChip => 'Active';

  @override
  String get homeInboxPreviewTitle => 'Recent messages';

  @override
  String get homeInboxNoMessages => 'No new messages';

  @override
  String homeInboxUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: '1 new message',
      zero: 'No new messages',
    );
    return '$_temp0';
  }

  @override
  String get homeInboxOpenCta => 'See all messages';

  @override
  String get homeQuickActionsTitle => 'Quick actions';

  @override
  String get homeQuickActionSchedule => 'Full schedule';

  @override
  String get homeQuickActionMessages => 'Messages';

  @override
  String get qrSheetTitle => 'Code for the gate';

  @override
  String get qrSheetSubtitle =>
      'Show this code to the gate keeper to verify your leave permission.';

  @override
  String qrSheetExpiresIn(int seconds) {
    return 'Refreshes in ${seconds}s';
  }

  @override
  String get qrSheetClose => 'Close';

  @override
  String get inboxTitle => 'Messages';

  @override
  String get inboxFilterAll => 'All';

  @override
  String get inboxFilterSchool => 'School';

  @override
  String get inboxFilterTeachers => 'Teachers';

  @override
  String get inboxFilterVolunteer => 'Volunteering';

  @override
  String get inboxFilterAnnouncements => 'Announcements';

  @override
  String get inboxEmpty => 'No messages in this category.';

  @override
  String get inboxVolunteerSignUp => 'Sign up';

  @override
  String get inboxVolunteerSignedUp => 'Signed up';

  @override
  String inboxVolunteerHours(int hours) {
    return '${hours}h';
  }

  @override
  String get inboxVolunteerLabel => 'Volunteering';

  @override
  String get inboxVolunteerSignupSuccess => 'Successfully signed up!';
}
