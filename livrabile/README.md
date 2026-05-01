# Livrabile — SchoolMate / Hardcore Entrepreneur 6.0

Acest folder conține livrabilele cerute de regulamentul concursului.

## Conținut

| Fișier | Descriere |
|--------|-----------|
| `business-plan.md` | Plan de afaceri (1 pagină extinsă) cu obiective SMART, grup-țintă, sustenabilitate, monetizare și legătura cu tema concursului. Generează PDF din acest fișier înainte de submisie. |
| `app-release.apk` | Executabilul aplicației pentru Android (build release). |
| Pitch video (YouTube) | https://www.youtube.com/watch?v=-88aeGVd3Fg — pitch de maximum 3 minute, în engleză. |
| Demo video (YouTube) | https://www.youtube.com/watch?v=wNU1WhSMBKU — demo funcțional al aplicației, maximum 3 minute. |
| Web app (portal secretariat) | https://schoolmate-portal.web.app/ — versiunea web pentru contul de secretariat. |

## Cum se rulează aplicația din APK

1. Pe un telefon Android (≥ 8.0), descarcă `app-release.apk`.
2. Activează „Instalare din surse necunoscute" în Setări → Securitate.
3. Instalează APK-ul.
4. La prima rulare, folosește unul din conturile demo:

| Rol | Username | Parolă |
|-----|----------|--------|
| Elev | {{DEMO_ELEV}} | {{PAROLA}} |
| Profesor / Diriginte | {{DEMO_PROFESOR}} | {{PAROLA}} |
| Secretariat | {{DEMO_ADMIN}} | {{PAROLA}} |
| Părinte | {{DEMO_PARINTE}} | {{PAROLA}} |
| Portar | {{DEMO_PORTAR}} | {{PAROLA}} |

## Conversie business plan în PDF

Pe Windows, cea mai rapidă variantă:
- Deschide `business-plan.md` în VS Code → extensia „Markdown PDF" → click dreapta → „Markdown PDF: Export (pdf)".
- Sau pe https://www.markdowntopdf.com/ încarci fișierul și descarci PDF-ul.
