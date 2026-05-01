# SchoolMate

**Hardcore Entrepreneur 6.0 — categoria liceu**
**Tema concursului:** *„Incluziune pentru toți. Viitor durabil pentru fiecare."*
**Echipa:** TransylvanianBears
**Membri (clasa 11i):**
- Nedelcu Călin — [@calinnedelcu](https://github.com/calinnedelcu)
- Buloi Cristian — [@oldbulai](https://github.com/oldbulai)
- Boștină Vlad — [@Vladfromstars](https://github.com/Vladfromstars), [@BosRegele](https://github.com/BosRegele)
- Cheroiu Andrei — [@ache12345](https://github.com/ache12345)
**Mentor:** fără mentor

---

## Ce este SchoolMate

SchoolMate este o aplicație Flutter + Firebase (mobile Android + web) care unifică toate fluxurile de comunicare ale unei școli — anunțuri, concursuri, tabere, voluntariat, cereri, orar, identificare la poartă — într-o singură experiență accesibilă, gratuită pentru elev și părinte. Versiunea web ([schoolmate-portal.web.app](https://schoolmate-portal.web.app/)) e folosită în special de personalul de secretariat. Interfața este în engleză, cu arhitectură pregătită pentru a fi extinsă multilingv.

Aplicația are roluri distincte pentru **elev**, **profesor**, **diriginte**, **secretariat**, **părinte** și **portar**, fiecare cu surface-ul propriu.

## SDG-uri vizate

SchoolMate țintește direct două Obiective de Dezvoltare Durabilă ONU, în linie cu business-planul ([livrabile/business-plan.md](livrabile/business-plan.md)):

- **Quality Education (SDG 4)** — un canal oficial unic pentru anunțuri, orar și cereri elimină comunicarea fragmentată (WhatsApp, fluturași, emailuri pierdute) și asigură că niciun elev nu pierde informații despre olimpiade, burse, tabere sau voluntariat.
- **Reduced Inequalities (SDG 10)** — gratuit pentru elev și părinte, model B2B2C subvenționabil prin ONG-uri pentru școlile rurale; interfață în engleză deschisă către părinți non-vorbitori de română, cu arhitectură pregătită pentru extindere multilingvă (țintă: EN, RO, ES, FR).

## Livrabile pentru juriu

Toate materialele cerute de regulament sunt în [livrabile/](livrabile/):

- [livrabile/business-plan.md](livrabile/business-plan.md) — plan de afaceri (cu obiective SMART, grup-țintă, sustenabilitate, monetizare).
- `livrabile/app-release.apk` — APK Android release (generat cu `flutter build apk --release`).
- **Pitch video (max 3 min, în engleză):** https://www.youtube.com/watch?v=-88aeGVd3Fg
- **Demo video (max 3 min):** https://www.youtube.com/watch?v=wNU1WhSMBKU
- **Web app (portal secretariat):** https://schoolmate-portal.web.app/

## Funcționalități principale

### Elev
- Inbox cu filtre pe categorii: cereri, anunțuri, concursuri, tabere, voluntariat.
- Orar săptămânal cu evidențierea orei curente.
- Cereri digitale: motivare absențe, învoire, adeverință.
- QR personal de identificare la poarta școlii.
- Notificări push (Firebase Cloud Messaging) + notificări locale.
- Profil personal cu poză și informații de contact.

### Profesor / Diriginte
- Dashboard cu clasa proprie, cereri în așteptare, acces rapid la orar.
- Compunere postări (anunțuri, tabere, voluntariat) cu audiență configurabilă.
- Gestionare voluntariat și înscrieri elevi.
- Răspuns la cereri elev/părinte.

### Secretariat / Admin
- Compunere unificată pentru anunțuri școlare, concursuri, tabere, voluntariat — audiență „toată școala" sau listă de clase.
- Management conturi: elevi, profesori, părinți, admini.
- Management clase, orar, calendar de vacanțe, mesaje globale.

### Părinte
- Vizualizare unificată pentru toți copiii: inbox, cereri, profil.

### Portar
- Modul scanare QR la intrarea în școală.

## Stack tehnic

- **Flutter** (Dart SDK ^3.11) — UI Material 3, componente custom temate.
- **Firebase**:
  - Authentication (flux custom username/parolă + ecran 2FA)
  - Cloud Firestore (postări, cereri, orar, utilizatori)
  - Cloud Functions (validare server-side + operațiuni admin)
  - Cloud Messaging + notificări locale
  - Storage (poze de profil)
- **Pachete:** `qr_flutter`, `mobile_scanner`, `google_fonts`, `excel`, `file_saver`, `share_plus`, `image_picker`, `audioplayers`, `shared_preferences`, `url_launcher`, `cached_network_image`, `flutter_local_notifications`, `path_provider`, `crypto`, `cryptography`.

## Structura proiectului

```
lib/
├── main.dart
├── core/                    # firebase_options, session
├── auth/                    # login, onboarding, 2FA, add photo
├── student/                 # inbox, orar, cereri, profil, QR personal, bookmarks
│   └── widgets/
├── teacher/                 # dashboard, cereri, mesaje diriginte, status elevi
│   └── widgets/
├── parent/                  # home, inbox, orar, cereri, lista copii
├── admin/                   # secretariat: composer, useri, clase, orar, vacanțe, portari
│   ├── models/
│   ├── services/
│   ├── utils/
│   └── widgets/
├── gate/                    # modul portar (scanner QR)
├── common/                  # pagini și componente partajate între roluri
│   └── widgets/
├── services/                # wrappers Firebase (admin API, security flags)
└── utils/                   # password hashing
```

Regulile Firestore: [firestore.rules](firestore.rules). Indexurile: [firestore.indexes.json](firestore.indexes.json). Cloud Functions: [functions/](functions/).

## Modelul de postări

Postările au un compositor unic dar sunt salvate în două colecții:

- `secretariatMessages` — anunțuri, concursuri, tabere. Audiența este descrisă prin `audienceClassIds` (`['__ALL__']` pentru toată școala sau listă explicită de class IDs) și un `audienceLabel` lizibil.
- `volunteerOpportunities` — voluntariat, ținut separat pentru că gestionează înscrieri și ore de muncă.

Fiecare postare are: `category`, `senderRole`, `eventDate`, `eventEndDate` (opțional, pentru tabere), `link`, `location`, `status` (`active` / `archived`).

## Rulare locală

**Cerințe:** Flutter SDK ≥ 3.11, un proiect Firebase configurat, CLI `flutterfire` pentru `firebase_options.dart`.

```bash
flutter pub get
flutter run
```

Pentru Cloud Functions:

```bash
cd functions
npm install
firebase deploy --only functions
```

## Instalarea APK-ului din `livrabile/`

1. Pe un telefon Android (≥ 8.0), descarcă `livrabile/app-release.apk`.
2. Activează „Instalare din surse necunoscute" în Setări → Securitate.
3. Instalează APK-ul și deschide aplicația.
4. Folosește unul din conturile demo (descrise în [livrabile/README.md](livrabile/README.md)).

## Contact

Echipa TransylvanianBears — calin.nedelcu08@gmail.com
