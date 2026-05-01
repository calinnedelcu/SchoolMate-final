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

SchoolMate este o aplicație Flutter + Firebase (mobile Android + web) care unifică toate fluxurile de comunicare ale unei școli — anunțuri, concursuri, tabere, cereri, orar, identificare la poartă — într-o singură experiență accesibilă, gratuită pentru elev și părinte. Versiunea web ([schoolmate-portal.web.app](https://schoolmate-portal.web.app/)) e folosită în special de personalul de secretariat. Interfața este în engleză, cu arhitectură pregătită pentru a fi extinsă multilingv.

Aplicația are roluri distincte pentru **elev**, **profesor**, **diriginte**, **secretariat**, **părinte** și **portar**, fiecare cu surface-ul propriu.

## SDG-uri vizate

SchoolMate țintește direct două Obiective de Dezvoltare Durabilă ONU, în linie cu business-planul ([livrabile/business-plan.pdf](livrabile/business-plan.pdf)):

- **Quality Education (SDG 4)** — un canal oficial unic pentru anunțuri, orar și cereri elimină comunicarea fragmentată (WhatsApp, fluturași, emailuri pierdute) și asigură că niciun elev nu pierde informații despre olimpiade, burse sau tabere.
- **Reduced Inequalities (SDG 10)** — gratuit pentru elev și părinte, model B2B2C subvenționabil prin ONG-uri pentru școlile rurale; interfață în engleză deschisă către părinți non-vorbitori de română, cu arhitectură pregătită pentru extindere multilingvă (țintă: EN, RO, ES, FR).

## Livrabile pentru juriu

Toate materialele cerute de regulament sunt în [livrabile/](livrabile/):

- [livrabile/business-plan.pdf](livrabile/business-plan.pdf) — planul de afaceri trimis (forma oficială pentru juriu); varianta sursă în Markdown: [livrabile/business-plan.md](livrabile/business-plan.md).
- `livrabile/app-release.apk` — APK Android release (generat cu `flutter build apk --release`).
- **Pitch video (max 3 min, în engleză):** https://www.youtube.com/watch?v=-88aeGVd3Fg
- **Demo video (max 3 min):** https://www.youtube.com/watch?v=wNU1WhSMBKU
- **Web app (portal secretariat):** https://schoolmate-portal.web.app/

## Funcționalități principale

### Elev
Bottom nav cu 5 tab-uri: Home, Orar, Cereri, Inbox, Profil.
- **Inbox** cu filtre pe categorii: toate, cereri, anunțuri, concursuri, tabere.
- **Orar săptămânal** generat din configurația dirigintelui.
- **Cereri digitale** către diriginte sau secretariat (motivare absențe / învoire), cu dată, oră și mesaj; ecran dedicat de istoric cu statusuri (în așteptare / aprobat / respins).
- **QR personal** afișat dintr-un bottom sheet pentru identificare la poarta școlii.
- **Bookmarks** — salvare locală a postărilor relevante, cu același set de filtre ca inbox-ul.
- **Notificări push** (Firebase Cloud Messaging) + notificări locale (`flutter_local_notifications`).
- **Profil** cu poză, nume, clasă, listă de părinți asociați.

### Profesor / Diriginte
Bottom nav cu 3 tab-uri: Dashboard, Clasa mea, Profil.
- **Dashboard** cu clasa proprie, cereri în așteptare și ultima vizită în inbox.
- **Cereri în așteptare** — aprobă / respinge cererile elevilor din clasă.
- **Compunere postări** (anunț, concurs, tabără) — audiența e fixată automat pe propria clasă.
- **Inbox dirigintelui** — postările trimise în clasă, cu opțiunea de a compune unele noi.
- **Status elevi** — listă cu elevii din clasă.

### Secretariat / Admin
Portal cu sidebar și versiune web la [schoolmate-portal.web.app](https://schoolmate-portal.web.app/).
- **Compositor unificat** pentru anunțuri, concursuri, tabere și vacanțe — audiență „toată școala" sau listă explicită de clase, cu imagine, dată eveniment și link.
- **Management conturi**: elevi, profesori, părinți, admini — creare, căutare, reset parolă, mutare între clase, asociere părinte-copil.
- **Management clase** și **configurare orar** (ore de start, durate sloturi, layout pe zile).
- **Calendar de vacanțe**.
- **Istoric scanări QR la poartă** — nume elev, clasă, rezultat (allowed / denied), motiv și timestamp.

### Părinte
Bottom nav cu 3 tab-uri: Home, Children, Profil. De pe Home se navighează spre:
- **Inbox** cu postările relevante pentru clasele copiilor.
- **Cereri** — aprobă sau respinge cererile copiilor.
- **Orar** — selector de copil + orarul clasei alese.
- **Lista copii** cu poză, nume, clasă, link către detalii fiecărui copil.

### Portar
- **Meniu portar** cu ceas live.
- **Scanner QR** (camera + lanternă, feedback sonor la scanare).
- **Pagina de rezultat** — afișează numele elevului, clasa, „Exit recorded" sau „Access denied" cu motiv (ex: nu există cerere aprobată, deja folosit, ziua s-a încheiat); fiecare scanare e logată în Firestore pentru audit-ul din portalul admin.

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

Postările sunt salvate în colecția `secretariatMessages`, cu audiența descrisă prin `audienceClassIds` (`['__ALL__']` pentru toată școala sau listă explicită de class IDs) și un `audienceLabel` lizibil.

Fiecare postare are: `category` (announcement / competition / camp / vacation), `senderRole`, `eventDate`, `eventEndDate` (opțional, pentru tabere), `link`, `location`, `status` (`active` / `archived`).

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
