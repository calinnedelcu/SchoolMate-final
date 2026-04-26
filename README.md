# SchoolMate

**Hardcore Entrepreneur 6.0 — categoria liceu**
**Tema concursului:** *„Incluziune pentru toți. Viitor durabil pentru fiecare."*
**Echipa:** TransylvanianBears
**Membri:** Nedelcu Călin, Buloi Cristian, Boștină Vlad, Cheroiu Andrei (clasa 11i)
**Mentor:** fără mentor

---

## Ce este SchoolMate

SchoolMate este o aplicație mobilă (Flutter + Firebase) care unifică toate fluxurile de comunicare ale unei școli — anunțuri, concursuri, tabere, voluntariat, meditații, cereri, orar, identificare la poartă — într-o singură experiență accesibilă, gratuită pentru elev și părinte. Interfața principală este în engleză, cu arhitectură pregătită pentru a fi extinsă multilingv (vezi roadmap).

Aplicația are roluri distincte pentru **elev**, **profesor**, **diriginte**, **secretariat**, **părinte** și **portar**, fiecare cu surface-ul propriu.

## Cum respectă tema concursului

Aplicația țintește direct pilonul *„Incluziune pentru toți. Viitor durabil pentru fiecare."* prin:

- **Incluziune digitală** — elevii din zone defavorizate primesc același acces la informații despre olimpiade, burse, tabere și voluntariat ca elevii din școli de top, prin canalul oficial al școlii.
- **Incluziune lingvistică (planificat)** — interfața principală este în engleză și deschide app-ul către părinți non-vorbitori de română (expați, refugiați); pe roadmap este suport multi-limbă (RO + UA) prin ARB files, pentru a acoperi complet comunitățile vulnerabile.
- **Accesibilitate (planificat)** — pe roadmap intră setări dedicate pentru scalare font, contrast ridicat și reducerea animațiilor, pentru elevi cu deficiențe de vedere, dislexie sau sensibilități motorii.
- **Reziliență în criză** — un canal unic, oficial, fără dependență de WhatsApp/grupuri neoficiale, util în pandemii, valuri de refugiați, evenimente meteo extreme.
- **Sustenabilitate ecologică** — eliminarea complet a fluturașilor și formularelor pe hârtie (~12 kg hârtie/elev/an).
- **Sustenabilitate economică** — model freemium B2B2C: gratuit pentru elev și părinte, subvenționabil prin ONG-uri pentru școlile rurale (vezi `livrabile/business-plan.md`).

## Livrabile pentru juriu

Toate materialele cerute de regulament sunt în [livrabile/](livrabile/):

- [livrabile/business-plan.md](livrabile/business-plan.md) — plan de afaceri (cu obiective SMART, grup-țintă, sustenabilitate, monetizare).
- `livrabile/app-release.apk` — APK Android release (generat cu `flutter build apk --release`).
- **Pitch video (max 3 min, în engleză):** _link YouTube unlisted — va fi adăugat înainte de 1 mai_
- **Demo video (max 3 min):** _link YouTube unlisted — va fi adăugat înainte de 1 mai_

## Funcționalități principale

### Elev
- Inbox cu filtre pe categorii: cereri, anunțuri, concursuri, tabere, voluntariat, meditații.
- Orar săptămânal cu evidențierea orei curente.
- Cereri digitale: motivare absențe, învoire, adeverință.
- QR personal de identificare la poarta școlii.
- Notificări push (Firebase Cloud Messaging) + notificări locale.
- Profil personal cu poză și informații de contact.

### Profesor / Diriginte
- Dashboard cu clasa proprie, cereri în așteptare, acces rapid la orar.
- Compunere postări (anunțuri, tabere, meditații, voluntariat) cu audiență configurabilă.
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
- **Pachete:** `qr_flutter`, `mobile_scanner`, `google_fonts`, `excel`, `file_saver`, `share_plus`, `image_picker`, `audioplayers`, `shared_preferences`.

## Structura proiectului

```
lib/
├── main.dart
├── core/                    # firebase_options, session, modele partajate
├── Auth/                    # login, onboarding, 2FA
├── student/                 # inbox, orar, cereri, profil, QR personal
│   └── widgets/
├── teacher/                 # dashboard, cereri, mesaje diriginte, status elevi
│   └── widgets/
├── parent/                  # home părinte, inbox, cereri, copii
├── admin/                   # secretariat: composer, useri, clase, orar
│   ├── services/
│   └── widgets/
├── gate/                    # modul portar (scanner QR)
├── common/                  # pagini și componente partajate între roluri
├── services/                # wrappers Firebase, glue notificări
└── utils/                   # CSV download (mobile + web)
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
npm run build
firebase deploy --only functions
```

## Instalarea APK-ului din `livrabile/`

1. Pe un telefon Android (≥ 8.0), descarcă `livrabile/app-release.apk`.
2. Activează „Instalare din surse necunoscute" în Setări → Securitate.
3. Instalează APK-ul și deschide aplicația.
4. Folosește unul din conturile demo (descrise în [livrabile/README.md](livrabile/README.md)).

## Contact

Echipa TransylvanianBears — calin.nedelcu08@gmail.com
