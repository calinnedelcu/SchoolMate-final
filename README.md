# Aplicația Elevului

A Flutter + Firebase application built around the daily life of a high‑school student. The app brings the school's announcements, competitions, camps, volunteering opportunities, weekly schedule and direct messaging into a single mobile experience, with dedicated views for teachers, form masters, parents and the secretariat.

The project is bilingual (Romanian / English) and ships with accessibility settings (font scaling, high contrast, reduced motion).

---

## What the app is for

The goal is to give a student one place where they can:

- read everything the school sends out (general announcements, competitions, summer camps, volunteering calls, tutoring offers);
- check the weekly timetable and any changes the form master publishes;
- send and receive direct requests (absences, leave permissions, document requests);
- keep a personal profile with a school QR identifier used for in‑school identification.

Teachers and the secretariat have their own surfaces for publishing posts, managing classes and replying to requests.

---

## Main features

### For students

- **Inbox** with category filters: *Requests*, *Announcements*, *Competitions*, *Camps*, *Volunteering*, *Tutoring*. Posts can be school‑wide or targeted to specific classes.
- **Weekly schedule** rendered as a grid, with current period highlighted.
- **Requests** module — absence justifications, permission slips, document requests sent to the form master / secretariat.
- **Profile** screen with personal info and a personal QR identifier.
- **Notifications** for new posts and replies (Firebase Cloud Messaging + local notifications).

### For form masters and teachers

- Dashboard with class overview, pending requests and quick access to the schedule editor.
- **Post composer** locked to the teacher's own class — publish announcements, camps, tutoring offers or volunteering calls.
- Manage volunteering opportunities and student sign‑ups.
- View and reply to student requests.

### For the secretariat / administrators

- **Unified post composer** with four post types (school announcement, competition, camp, volunteering), configurable audience (whole school or a multi‑class selection), with mandatory external link instead of file uploads.
- User management: create / disable / delete student, teacher, parent and admin accounts.
- Class and schedule management, vacation calendar, global broadcast messages.

### For parents

- Linked view of their children: inbox, requests and basic profile information.

---

## Technology stack

- **Flutter** (Dart SDK ^3.11) — Material 3 UI, custom themed components.
- **Firebase**:
  - Authentication (custom username/password flow + 2FA verify screen)
  - Cloud Firestore (posts, requests, schedules, users)
  - Cloud Functions (server‑side validation and admin operations)
  - Cloud Messaging + local notifications
  - Firebase Storage (profile pictures)
- **Localization** via `flutter_localizations` and ARB files (`lib/l10n`).
- **Other packages**: `qr_flutter`, `mobile_scanner`, `google_fonts`, `excel`, `file_saver`, `share_plus`, `image_picker`, `audioplayers`, `shared_preferences`.

---

## Project structure

```
lib/
├── main.dart
├── firebase_options.dart
│
├── Auth/                    # login, onboarding, 2FA
├── student/                 # student inbox, schedule, requests, profile
│   └── widgets/             # bottom sheets and visual decor
├── teacher/                 # teacher dashboard, requests, volunteering, schedules
├── parent/                  # parent home, inbox, requests, linked students
├── admin/                   # secretariat: composer, users, classes, schedules
│   └── services/
├── common/                  # accessibility, language picker, shared messages page
├── core/                    # shared models, theming, utilities
├── services/                # Firebase wrappers and notification glue
├── gate/                    # personal QR identifier helpers
├── l10n/                    # ARB files (RO + EN)
└── utils/
```

Firestore rules (`firestore.rules`), indexes (`firestore.indexes.json`) and Cloud Functions (`functions/`) live at the repo root.

---

## Posts model (high level)

Posts share a single composer but land in two collections so the inbox keeps backward compatibility with earlier modules:

- `secretariatMessages` — announcements, competitions, camps. Audience is described by `audienceClassIds` (`['__ALL__']` for school‑wide or an explicit list of class IDs) and a human‑readable `audienceLabel`.
- `volunteerOpportunities` — volunteering posts, kept as a separate collection because they manage participant sign‑ups and tracked hours.

Each post carries `category`, `senderRole`, `eventDate`, optional `eventEndDate` (for camps), `link`, `location` and a `status` of `active` or `archived`.

---

## Running the project

Prerequisites: Flutter SDK, a configured Firebase project, and `flutterfire` CLI for `firebase_options.dart`.

```bash
flutter pub get
flutter run
```

For Cloud Functions:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

---

## Roadmap

Planned next steps (see project notes for detail):

- **Tutoring (Meditații) overhaul** — dedicated tab with teacher‑driven offers and student requests.
- Richer notifications and post pinning.
- Attendance and grades integration.

---

## Purpose

The project is built as a personal study project exploring full‑stack mobile development — Flutter on the client, Firebase on the backend, and a multi‑role data model that mirrors how a real school operates.
