# iOS App Store Release

Diese Anleitung beschreibt den Weg von lokalem Xcode-Build zu TestFlight und App Store Review fuer WebGuard for iOS.

Offizielle Apple-Einstiege:

- [Apple Developer Program](https://developer.apple.com/programs/)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [TestFlight](https://developer.apple.com/testflight/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## 1. Apple Developer Setup

Voraussetzungen:

- Aktive Apple Developer Program Mitgliedschaft
- Zugriff auf App Store Connect
- Zugriff auf Certificates, Identifiers & Profiles
- Ein echtes iPhone oder iPad fuer APNs-Tests

App Identifier:

```text
com.example.webguard
```

Aktiviere fuer diese App ID:

- Push Notifications

Danach einen APNs Auth Key erstellen:

```text
Key ID
Team ID
Auth Key .p8
Bundle ID / Topic: com.example.webguard
```

Der `.p8` Key gehoert ins Backend-Deployment, nicht in die iOS-App und nicht ins Git-Repo.

## 2. Backend Deployment

Die App ist erst voll nutzbar, wenn WebGuard Core diese Mobile-Endpunkte deployt hat:

```text
POST /api/mobile/login
GET  /api/mobile/me
POST /api/mobile/logout
GET  /api/v1/monitorings
POST /api/v1/mobile-push-devices
PATCH /api/v1/mobile-push-devices/{id}
DELETE /api/v1/mobile-push-devices/{id}
```

Produktive APNs-Werte im Backend:

```env
APNS_KEY_ID=
APNS_TEAM_ID=
APNS_BUNDLE_ID=com.example.webguard
APNS_PRIVATE_KEY=
APNS_PRIVATE_KEY_PATH=
APNS_ENVIRONMENT=production
```

Fuer Xcode-Development-Builds ausserhalb von TestFlight:

```env
APNS_ENVIRONMENT=development
```

## 3. Lokales Xcode Setup

Projekt:

```text
ios/WebGuard.xcodeproj
```

Konfiguration:

```text
ios/WebGuard/Config/Debug.xcconfig
ios/WebGuard/Config/Release.xcconfig
```

Setze lokal:

```xcconfig
DEVELOPMENT_TEAM = <apple-team-id>
PRODUCT_BUNDLE_IDENTIFIER = com.example.webguard
WEBGUARD_BASE_URL = https:/$()/app.webguard.marcel-breuer.dev
```

`WEBGUARD_BASE_URL` ist ein Build-Wert. Die App zeigt die Server-URL nicht im Login an und Benutzer melden sich nur mit E-Mail und Passwort an.

Die App ist als Universal-App konfiguriert:

```text
TARGETED_DEVICE_FAMILY = 1,2
```

Unterstuetzte Geraete:

- iPhone
- iPad

Orientierungen:

- iPhone: Portrait
- iPad: Portrait und Landscape

## 4. Lokaler Geraetetest

Ein echter APNs-Test funktioniert nicht im Simulator.

1. iPhone oder iPad per USB oder Netzwerk verbinden.
2. In Xcode das echte Geraet als Run Destination auswaehlen.
3. `WebGuard` Scheme starten.
4. Mit einem Test-Account einloggen.
5. Monitorings muessen sichtbar sein.
6. Push aktivieren.
7. iOS Permission Dialog bestaetigen.
8. Im Backend pruefen, ob ein `mobile_push_devices` Eintrag mit `push_provider = apns` angelegt wurde.

## 5. App Store Connect App Anlegen

In App Store Connect:

1. `My Apps` oeffnen.
2. Neue App erstellen.
3. Platform: iOS.
4. Name: `WebGuard`.
5. Primary language: Deutsch oder Englisch.
6. Bundle ID: `com.example.webguard`.
7. SKU: z. B. `webguard-ios`.
8. User Access passend setzen.

## 6. App Metadata

Empfohlene Werte:

```text
Name: WebGuard
Subtitle: Monitoring Alerts fuer iPhone und iPad
Category: Utilities
Content Rights: keine Drittinhalte
Age Rating: 4+
```

Beschreibung:

```text
WebGuard fuer iOS verbindet sich mit deinem WebGuard Account und zeigt dir deine Monitorings auf iPhone und iPad.

Aktiviere Push-Benachrichtigungen, um kritische Vorfaelle und Wiederherstellungen direkt auf deinem Geraet zu erhalten. Die App ist auf schnelle Einschaetzung ausgelegt: Monitoring-Liste, Status, letzte Push Events und Geraeteeinstellungen bleiben uebersichtlich an einem Ort.

Highlights:
- Login mit deinem WebGuard Account
- Monitoring-Liste mit Statusuebersicht
- Push Alerts fuer Vorfaelle und Recoveries
- Letzte Benachrichtigungen lokal im Blick
- Geraetebezogene Push-Einstellungen
- Native iPhone- und iPad-App

WebGuard fuer iOS ist die mobile Ergaenzung fuer bestehende WebGuard Accounts.
```

## 7. Screenshots

Bereite Screenshots fuer iPhone und iPad vor.

Empfohlene Motive:

- Login Screen mit WebGuard Branding
- Monitoring-Liste mit einem aktiven Monitoring
- Benachrichtigungen Screen
- Einstellungen mit Push Toggle
- iPad Landscape Monitoring-Uebersicht

Screenshots sollten echte Produktoberflaeche zeigen. Keine Zugangsdaten, keine privaten Targets, keine Tokens.

## 8. Datenschutz In App Store Connect

Die App nutzt kein Tracking und keine Werbung.

Angaben fuer App Privacy vorbereiten:

- E-Mail-Adresse: Account Login
- User ID: Account-Zuordnung
- Device ID / Push Token: Push-Zustellung
- Produktinteraktion: Monitoring- und Alertdaten innerhalb des Accounts

Nicht angeben, wenn nicht genutzt:

- Standort
- Kontakte
- Zahlungsdaten
- Tracking ueber Apps oder Websites anderer Unternehmen

Die Privacy Manifest Datei ist im Projekt eingebunden:

```text
ios/WebGuard/PrivacyInfo.xcprivacy
```

## 9. Archive Erstellen

In Xcode:

1. Scheme `WebGuard` auswaehlen.
2. Run Destination `Any iOS Device` oder ein angeschlossenes echtes Geraet auswaehlen.
3. `Product > Archive` starten.
4. Organizer oeffnen.
5. Archive validieren.
6. `Distribute App > App Store Connect` waehlen.
7. Upload abschliessen.

## 10. TestFlight

Nach dem Upload:

1. In App Store Connect den Build abwarten.
2. Export Compliance beantworten.
3. Internen TestFlight-Kreis anlegen.
4. Build fuer interne Tester freigeben.
5. Auf iPhone und iPad installieren.

Testplan:

- Login funktioniert
- Monitoring-Liste wird geladen
- Pull-to-refresh aktualisiert Monitorings
- Push Permission Dialog erscheint
- Device wird im Backend als APNs Device registriert
- Push Toggle deaktiviert/aktiviert das Device
- Logout widerruft Device und Session
- iPad Portrait und Landscape sind nutzbar

## 11. App Review

Vor dem Einreichen:

- Support URL eintragen
- Privacy Policy URL eintragen
- Test-Account fuer App Review bereitstellen
- Kurze Review Notes schreiben
- Erklaeren, dass ein WebGuard Account erforderlich ist
- Push Notification Zweck beschreiben

Beispiel Review Notes:

```text
WebGuard requires a WebGuard account. Please use the provided demo account to log in. The app shows monitorings for the account and can register this device for APNs alerts when notification permission is granted.
```

Keine echten produktiven Admin-Zugangsdaten in Review Notes verwenden. Fuer Apple Review einen separaten Test-Account mit minimalen Rechten anlegen.

## 12. Release

Empfehlung:

1. Erst interner TestFlight.
2. Dann externer TestFlight mit kleiner Gruppe.
3. Danach App Review.
4. Manuelle Freigabe nach Approval.

Nach Release:

- Crash Reports beobachten
- APNs Delivery im Backend loggen
- Login-Fehler und 401/403 API-Fehler pruefen
- App Store Bewertungen und Review Feedback verfolgen
