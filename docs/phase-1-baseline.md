# Phase 1: Gesicherter Ausgangspunkt

Stand: 17. August 2026

## Ziel

Dieser Stand ist die nachvollziehbare Basis fuer den Neuaufbau der Synchronisation.
Neon dient als Testumgebung. Die spaetere Produktion laeuft bei Infomaniak. App,
API-Vertrag und Datenmodell muessen in beiden Umgebungen identisch funktionieren.

## Git-Sicherung

- Unveraenderter Prototyp: `codex/neon-account-preview`
- Letzter Prototyp-Commit: `9d6e3fe5259c1f030a57f814899c22c3df40fc4e`
- Neuer Arbeitsbranch: `codex/sync-production-foundation`
- Der Prototyp-Branch war bei der Sicherung einen Commit vor seinem Remote-Branch.

## Erfolgreiche Basistests

- Backend: `npm test` — 10 von 10 Tests erfolgreich.
- iOS: Debug-Build fuer `generic/platform=iOS` mit deaktivierter Codesignierung erfolgreich.
- Xcode-Projekt: Target und Scheme heissen `Tschluessli`.

## Beibehaltene, bereits funktionierende Basis

- Registrierung, E-Mail-Bestaetigung, Anmeldung und serverseitige Sitzungen.
- PostgreSQL-Tabellen fuer Benutzer, Sitzungen, Dossiers und Dossierbereiche.
- Versionierte JSON-Payloads pro Dossierbereich.
- Row-Level-Security fuer Dossiers und Dossierbereiche.
- Transportverschluesselung der Datenbankverbindung in der Cloud.

## Isolierter Prototyp — nicht als Produktionsarchitektur weiterbauen

- Die Synchronisation wird beim Wechsel in den Hintergrund seriell gestartet.
- Ein Fehler in einem Bereich kann die nachfolgenden Bereiche stoppen.
- Es gibt keine persistente Outbox fuer noch nicht uebertragene Aenderungen.
- Upload und Wiederherstellung sind noch kein geschlossener, konfliktfester Prozess.
- Revisionen liegen teilweise nur in `UserDefaults`.
- Der letzte Prototyp-Commit verlaengert lediglich die iOS-Hintergrundlaufzeit.
- Der lokale Verschluesselungsschluessel fuer sensible Dossierfelder besitzt noch
  keinen produktionsfaehigen Wiederherstellungsweg fuer Neuinstallation oder Zweitgeraet.
- Das Registrierungspasswort ist noch Teil des lokalen Profilmodells und muss in
  der Sicherheitsphase entfernt und migriert werden.

## Portabilitaetsregeln fuer Neon und Infomaniak

- Nur standardkonformes PostgreSQL; anbieterspezifische Erweiterungen nur nach
  dokumentierter Freigabe und hinter einer austauschbaren Schnittstelle.
- Dieselben, versionierten SQL-Migrationen laufen in Test und Produktion.
- Keine Datenbank-Zugangsdaten in der App; ausschliesslich das Backend verbindet
  sich mit PostgreSQL.
- Umgebungsunterschiede werden nur durch Server-Konfiguration und Secrets bestimmt.
- Objekt- und Dokumentenspeicher wird spaeter ueber einen Storage-Adapter angebunden.
- Vor jeder Produktionsmigration: Migration und Schnittstellentests zuerst gegen Neon,
  danach identisch gegen eine Infomaniak-Staging-/Produktionsumgebung.

## Bekannte technische Schulden fuer die folgenden Phasen

- `database/migrations/001_initial.sql` ist eine einmalige Initialmigration und nicht
  fuer wiederholte Ausfuehrung vorgesehen. Eine Migrationstabelle und ein Runner fehlen.
- Automatisierte Tests fuer Dossier-Synchronisation, RLS, Migrationen und Wiederherstellung fehlen.
- Die vorhandenen iOS-Testtargets enthalten noch keine belastbaren Sync-Tests.
- Loeschungen, Idempotenzschluessel, Geraeteidentitaet, Token-Erneuerung und Bulk-Download fehlen.

## Abnahme Phase 1

- [x] Arbeitsbaum war vor Beginn sauber.
- [x] Prototyp wurde durch einen separaten Arbeitsbranch unveraendert bewahrt.
- [x] Backend-Basistests wurden erfolgreich ausgefuehrt.
- [x] iOS-Baseline-Build wurde erfolgreich ausgefuehrt.
- [x] Prototypgrenzen und produktionsrelevante Risiken sind dokumentiert.
- [x] Neon/Infomaniak-Portabilitaet ist als verbindliche Regel dokumentiert.

Phase 1 veraendert bewusst weder Produktionsdaten noch Vercel-, Neon- oder
Infomaniak-Konfigurationen. Der naechste Schritt ist die gemeinsame,
anbieterneutrale Zielarchitektur.
