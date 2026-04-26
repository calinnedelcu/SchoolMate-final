# SchoolMate — Business Plan

**Concurs:** Hardcore Entrepreneur 6.0
**Tema:** Incluziune pentru toți. Viitor durabil pentru fiecare.
**Categorie:** {{CATEGORIE — gimnaziu / liceu}}
**Echipa:** {{NUME_ECHIPA}}
**Membri:** {{NUME_MEMBRI}}
**Mentor:** {{MENTOR_SAU_NICIUNUL}}

---

## 1. Problema

În școlile din România, comunicarea școală–elev–părinte este fragmentată: anunțuri pe grupuri WhatsApp neoficiale, fluturași imprimați, emailuri pierdute, catalog separat de orar, formulare pe hârtie pentru cereri de motivare/învoiri. Rezultatul:

- **Elevii din zone defavorizate** pierd informații despre olimpiade, burse, tabere și voluntariat pentru că nu sunt în „grupul potrivit" sau nu au părinți activi în comunitate.
- **Părinții care nu vorbesc fluent româna** (comunități rome, ucrainene, expați) sunt excluși din circuitul de informații al școlii.
- **Elevii cu dizabilități** (deficiențe de vedere, dislexie, sensibilități motorii) nu au interfețe de comunicare adaptate.
- În **perioade de criză** (pandemii, conflict armat, dezastre), absența unui canal oficial unic produce dezinformare și inegalitate de acces la educație.

## 2. Soluția — SchoolMate

Aplicație mobilă Flutter + Firebase, multi-rol, care unifică toate fluxurile de comunicare ale unei școli într-o experiență accesibilă, gratuită pentru elev și părinte, bilingvă (RO/EN, extensibilă).

**Module:**
- **Inbox unificat** cu filtre pe categorii (anunțuri, concursuri, tabere, voluntariat, meditații, cereri).
- **Orar săptămânal** cu evidențierea orei curente și sincronizare cu modificările dirigintelui.
- **Cereri digitale** — motivări, învoiri, adeverințe; trimise instant către diriginte/secretariat.
- **QR personal** pentru identificare la poarta școlii (modul „portar" cu scanner).
- **Compunere de postări** pentru profesori și secretariat, cu audiență configurabilă (toată școala sau clase selectate).
- **Vizualizare părinte** — un cont, mai mulți copii.
- **Notificări push** (FCM) pentru fiecare anunț relevant.

**Funcționalități de incluziune (legate direct de tema concursului):**
- Setări de accesibilitate: scalare font, contrast ridicat, reducere animații.
- Interfață bilingvă (română + engleză), arhitectură pregătită pentru limbi suplimentare.
- Conținut text-only + linkuri (fără upload de fișiere mari) → funcționează pe conexiuni 3G slabe.
- Audiențe segmentate → niciun elev nu „rămâne pe dinafară" indiferent de clasă/profil.

## 3. Grup-țintă

**Primar:** elevii (gimnaziu și liceu) și părinții lor din școlile de stat și particulare din România — ~2,5 milioane elevi (sursa INS).

**Secundar:** profesori, diriginți, secretariate școlare, administrație — ~280.000 cadre didactice.

**Segment de încălzire (pilot):** licee din mediul rural și suburban din județele Ilfov, Dâmbovița, Argeș (acces digital existent, dar fără platformă oficială unificată).

## 4. Obiective SMART

| # | Obiectiv | Specific | Măsurabil | Asignat | Realist | Timp |
|---|----------|----------|-----------|---------|---------|------|
| 1 | **Pilot în 3 licee** | Implementare în 3 unități școlare pilot din Ilfov | 3 școli, ≥500 conturi active | Echipa SchoolMate + un mentor ISJ | Da — există deja contact cu o școală | Sept 2026 — Dec 2026 |
| 2 | **1.000 utilizatori activi lunar** | Elevi + părinți care deschid app ≥1×/săptămână | MAU ≥ 1.000 măsurat în Firebase Analytics | PM tehnic | Da — la 3 școli pilot e atins | Iunie 2027 |
| 3 | **Suport 3 limbi** | RO, EN, UA (refugiați) | 3 fișiere ARB complete, traduceri verificate | Dev frontend | Da — arhitectura e pregătită | Decembrie 2026 |
| 4 | **Auto-finanțare** | Acoperirea costurilor Firebase din venituri | Venit lunar ≥ cost lunar (~80 EUR/lună la 1.000 MAU) | Co-fondatori | Da, pe modelul B2B școală | Septembrie 2027 |
| 5 | **Conformitate GDPR** | Datele elevilor minori protejate | Audit GDPR + consimțământ parental digital | Mentor juridic | Da — Firebase EU region | Iunie 2026, înainte de pilot |

## 5. Sustenabilitate & dezvoltare

- **Stack scalabil:** Firebase scalează automat; cost ≈ 0,02 EUR/utilizator/lună la volum mediu.
- **Cod open-source pentru modulul de bază** → adopție rapidă, contribuții comunitare, reducere cost mentenanță.
- **Roadmap 12 luni:** integrare catalog electronic, modul note + medii, integrare cu ARGES (sistemul național), modul meditații peer-to-peer.
- **Componenta socială:** parteneriat cu ONG-uri (Salvați Copiii, World Vision) pentru subvenționarea licenței în școli rurale.

## 6. Monetizare

Model **B2B2C** — gratuit pentru elev/părinte, plătit de școală sau finanțator.

| Sursă | Tarif | Volum țintă (an 2) | Venit anual |
|-------|-------|---------------------|-------------|
| Licență școală (stat, prin asociația părinților) | 1,5 EUR/elev/an | 50 școli × 600 elevi | 45.000 EUR |
| Licență școală privată | 4 EUR/elev/an | 10 școli × 300 elevi | 12.000 EUR |
| Sponsorizări corporate (modul carieră) | 500 EUR/lună | 4 sponsori | 24.000 EUR |
| Granturi UE/ONG (incluziune digitală) | one-shot | 1 grant Erasmus+ | 30.000 EUR |
| **Total estimat An 2** | | | **~111.000 EUR** |

**Costuri estimate An 2:** infra Firebase ~3.500 EUR + dezvoltare part-time ~60.000 EUR + juridic/marketing ~10.000 EUR = **~73.500 EUR**.

**Profit estimat An 2:** ~37.500 EUR, reinvestit în extindere națională.

## 7. De ce SchoolMate respectă tema „Incluziune pentru toți. Viitor durabil pentru fiecare."

- **Incluziune digitală:** elevii din medii defavorizate primesc același acces la informații (olimpiade, burse, tabere) ca cei din școli de top.
- **Incluziune lingvistică:** interfață multilingvă pentru părinți non-vorbitori de română.
- **Incluziune pentru dizabilități:** accesibilitate built-in (font scale, contrast, motion).
- **Reziliență în criză:** un canal unic, oficial, pentru pandemii, refugiați (modulul UA), evenimente meteo extreme.
- **Sustenabilitate financiară:** model freemium care nu lasă școlile rurale pe dinafară (subvenționare ONG).
- **Sustenabilitate de mediu:** zero hârtie pentru cereri/anunțuri (~12 kg hârtie/elev/an economisită).
