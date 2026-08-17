# Phase 7: Einheitliche App-Synchronisation

Stand: 17. August 2026  
Status: implementiert und build-geprueft

## Ziel

Die iPhone-App verwendet fuer alle aktuell genutzten Dossierbereiche denselben
Local-first-Synchronisationsweg. Die App kommuniziert nur mit der HTTPS-API; ob
dahinter Neon (Test) oder Infomaniak PostgreSQL (Produktion) arbeitet, ist fuer sie
unerheblich.

## Synchronisierte Bereiche

- Profil
- Gesundheit
- Wuensche
- Finanzen
- Kontakte und Vertrauenspersonen
- Herzensmenschen
- Zugaenge und Abonnemente

## Ablauf

1. Eine Eingabe wird zuerst lokal in SwiftData gespeichert.
2. Der zentrale `DossierSyncDienst` erkennt die gespeicherten Modelle und markiert
   den zugehoerigen Bereich in der persistenten Outbox.
3. Schnelle Folgeaenderungen werden kurz gebuendelt und als aktueller Gesamtstand
   des Bereichs exportiert.
4. Der `SyncCoordinator` sendet offene Auftraege idempotent an `/api/sync/push`.
5. Anschliessend laedt die App mit einem persistenten Cursor Aenderungen und
   Loeschungen ueber `/api/sync/pull`.
6. Erfolgreich importierte Serverrevisionen werden je Dossier und Bereich lokal
   gespeichert.

Der Ablauf wird beim App-Start, beim Wechsel in den aktiven Zustand, bei lokalen
Aenderungen und zusaetzlich beim Wechsel in den Hintergrund angestossen. Der
Hintergrundwechsel ist damit keine Voraussetzung mehr fuer das Speichern.

## Importe und lokale Dateien

Serverdaten werden ueber einen zentralen Importer wieder in die bestehenden
SwiftData-Modelle uebernommen. Lokal gespeicherte Binaerdaten, die noch nicht zum
Cloudvertrag gehoeren, werden beim Import nicht unabsichtlich entfernt. Dazu
gehoeren insbesondere Profilbilder, Dokumentdateien, Steuerdateien,
Beziehungsmedien und lokale Einladungstokens.

## Konflikte und Fehler

- Eine abweichende Serverrevision fuehrt nicht zu einem stillen Ueberschreiben.
- Trifft eine Serveraenderung auf einen lokal offenen Auftrag, wird sie als
  `SyncKonflikt` mit Serverpayload und Revision persistent gespeichert.
- Auch nicht importierbare oder nicht entschluesselbare Payloads werden als
  Konflikt gesichert.
- Temporäre Netzwerk- und Serverfehler bleiben ueber die Outbox wiederholbar.
- Dauerhafte Validierungs-, Authentifizierungs- oder Konfliktfehler werden vom
  Coordinator klassifiziert und blockiert, statt endlos wiederholt zu werden.

Eine sichtbare Benutzeroberflaeche zur manuellen Konfliktaufloesung ist noch eine
Produktionsvoraussetzung fuer Phase 8.

## Sicherheitsgrenze bei Zugaengen

Passwoerter, PINs und vergleichbare Dossier-Geheimnisse werden vor dem Upload mit
AES-GCM verschluesselt. Auf demselben Geraet koennen sie wieder entschluesselt und
importiert werden. Der derzeitige Schluessel liegt gemaess bisheriger
Sicherheitsentscheidung nur auf diesem Geraet im Keychain.

Damit Zugaenge nach einer Neuinstallation oder auf einem Zweitgeraet nutzbar sind,
muss vor dem Produktivbetrieb noch eine sichere Wiederherstellungs- und
Geraeteuebertragungsloesung fuer den Dossier-Schluessel umgesetzt werden. Bis dahin
werden fremde, nicht entschluesselbare Zugangspayloads als Konflikt erhalten und
nicht ueber lokale Daten geschrieben.

## Portabilitaet Neon / Infomaniak

Diese Phase enthaelt keine anbieterspezifische App-Logik. Beide Zielumgebungen
verwenden denselben API-Vertrag, dieselben PostgreSQL-Migrationen und dieselben
Sync-Payloads. In dieser Phase wurden weder die Neon-Datenbank migriert noch ein
Produktivdeployment bei Infomaniak ausgefuehrt.

## Abnahme Phase 7

- [x] Alle sieben genutzten Bereiche verwenden denselben Outbox- und Sync-Ablauf.
- [x] Upload, Download, Loeschungen und Revisionen sind in der App verbunden.
- [x] Lokale Aenderungen starten die Synchronisation ohne Abhaengigkeit vom
  Hintergrundwechsel.
- [x] Serverkonflikte werden persistent erhalten und nicht still ueberschrieben.
- [x] Der bisherige separate Kernbereichs-Hintergrundsync ist abgeloest.
- [x] App- und Testtargets lassen sich fuer den iOS-Simulator bauen.
- [ ] Manuelle Konfliktaufloesung ist vor Produktion sichtbar umzusetzen.
- [ ] Schluessel-Recovery fuer Zugangsdaten ist vor Mehrgeraete-/Produktivbetrieb
  umzusetzen und zu testen.

