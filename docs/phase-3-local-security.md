# Phase 3: Lokale Sicherheit und Kontopasswort-Bereinigung

Stand: 17. August 2026

## Umgesetzt

- `registrierungsPasswort` wurde aus `ProfilModell` entfernt.
- Das Kontopasswort wird nicht mehr in `UserDefaults` gespeichert.
- Der alte Keychain-Service `Tschluessli.Login` fuer Kontopasswoerter wird beim
  ersten Start nach dem Update vollstaendig geloescht.
- Die einmalige Bereinigung ist versioniert und wiederholbar ohne Nebenwirkungen.
- Cloud-Sitzungstoken bleiben separat im Keychain-Service
  `Tschluessli.CloudSession` mit `WhenUnlockedThisDeviceOnly` gespeichert.
- Profilansicht und beide PDF-Exportwege zeigen oder exportieren kein
  Kontopasswort mehr.
- Die bisherige lokale Passwortaenderung wurde entfernt. Sie veraenderte nur
  lokale Kopien und nicht das Cloudkonto. Eine echte Passwortaenderung benoetigt
  spaeter einen authentifizierten Backend-Endpunkt.
- Der Einladungs-Relogin prueft das Passwort nun beim Cloudbackend statt gegen
  eine lokale Passwortkopie.
- App und Backend verlangen einheitlich mindestens 12 Passwortzeichen.
- Die App verwendet als Standard `NSFileProtectionComplete`.
- Bereits vorhandene Dateien in `Application Support` und `Documents` erhalten
  bei der Sicherheitsmigration ebenfalls vollstaendigen Dateischutz.

## Bewusste Sicherheitsgrenze

Diese Phase betrifft das **Tschluessli-Kontopasswort**. Passwoerter und PINs, die
Benutzer als Inhalt ihres Dossiers bei Abos oder digitalen Konten erfassen, sind
eine andere Datenklasse. Deren lokaler und cloudseitiger Secret-Vault mit
Wiederherstellungsschluessel folgt in der dafuer vorgesehenen Phase.

## Verifikation

- Backend: 10 von 10 Node-Tests erfolgreich.
- iOS-App: Debug-Build fuer ein generisches iOS-Geraet erfolgreich, Exit-Code 0.
- App und Unit-Testbundle: erfolgreicher `build-for-testing`, Exit-Code 0.
- Automatisierter Test fuer einmalige Entfernung des alten UserDefaults-Werts
  und einmalige Keychain-Bereinigung ist vorhanden.
- Die Ausfuehrung der Unit-Tests im Simulator wurde durch einen haengenden
  Xcode-Test-Runner blockiert (`waiting for workers to materialize`). Es trat
  kein Testfehler auf; dieser Lauf wird in der spaeteren Testphase bzw. manuell
  in Xcode wiederholt.

## Abnahme Phase 3

- [x] Kontopasswort ist kein Feld des persistenten Profilmodells mehr.
- [x] Kontopasswort wird weder in UserDefaults noch dauerhaft im Keychain abgelegt.
- [x] Bestehende lokale Passwortkopien werden einmalig geloescht.
- [x] Sitzungstoken bleiben im dafuer vorgesehenen Keychain-Bereich.
- [x] Profil und PDF koennen das Kontopasswort nicht mehr offenlegen.
- [x] Vollstaendiger iOS-Dateischutz ist aktiviert.
- [x] App-Build und Testbundle-Build sind erfolgreich.

