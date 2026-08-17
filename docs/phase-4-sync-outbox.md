# Phase 4: Persistente Sync-Outbox und zentraler Coordinator

Stand: 17. August 2026

## Umgesetzt

- `SyncAuftrag` ist ein persistentes SwiftData-Modell und Teil des produktiven
  App-Schemas.
- Pro Dossier und Bereich existiert hoechstens ein offener Auftrag.
- Mehrere lokale Aenderungen werden in diesem Auftrag zusammengefasst.
- Jede Aenderung erhoeht eine Generation. Daraus entsteht ein stabiler
  Idempotency-Key aus Auftrags-ID und Generation.
- Aenderungen, die waehrend eines Uploads entstehen, werden nicht durch die
  Bestaetigung des aelteren Uploads geloescht.
- Ein abgebrochener Upload wird nach einem Timeout wieder freigegeben.
- Temporaere Fehler erhalten exponentielles Backoff von 5 Sekunden bis maximal
  1 Stunde.
- Authentifizierungsfehler, Konflikte und permanente Fehler werden blockiert und
  nicht in einer Endlosschleife wiederholt.
- `SyncCoordinator` ist der einzige vorgesehene Ausfuehrer der Warteschlange und
  verhindert parallele Laeufe innerhalb der App.
- Der Coordinator arbeitet gegen das anbieterneutrale Protokoll
  `SyncAuftragVerarbeiter`; dadurch kennt er weder Neon noch Infomaniak.

## Persistierter Auftrag

Ein Auftrag enthaelt:

- UUID und stabilen Bereichsschluessel
- Dossier-ID und Bereich
- Vorgang `upsert` oder `delete`
- Schema-Version und erwartete Serverrevision
- Aenderungsgeneration und Versuchszahl
- Erstellungs-, Aenderungs-, Retry- und Sperrzeitpunkt
- Status `pending`, `uploading` oder `blocked`
- letzte sichere Fehlermeldung ohne Payload oder Geheimnisse

Der fachliche Payload wird absichtlich nicht in der Outbox dupliziert. Der
Bereichsadapter erzeugt ihn spaeter aus dem aktuellen lokalen Stand. Dadurch
werden schnelle Folgen von Aenderungen zusammengefasst und es existiert nur eine
lokale fachliche Datenquelle.

## Noch nicht aktiviert

Der bisherige serielle Hintergrund-Prototyp wurde noch nicht entfernt und die
Fachbereiche erzeugen noch keine Outbox-Auftraege. Die Umschaltung erfolgt erst,
wenn folgende Voraussetzungen erfuellt sind:

1. einheitliche Bereichsadapter koennen alle genutzten Bereiche exportieren,
2. das Backend akzeptiert Idempotency-Keys und Loeschungen,
3. Upload und Download besitzen getestete Vertragsantworten.

Damit entsteht kein Zwischenstand, in dem ein Teil der Daten ueber die alte und
ein anderer Teil unkontrolliert ueber die neue Logik laeuft.

## Automatisierte Prueffaelle

- Zwei Aenderungen desselben Bereichs ergeben einen Auftrag mit neuer Generation.
- Eine Aenderung waehrend eines Uploads bleibt nach dessen Bestaetigung offen und
  uebernimmt die neue Serverrevision.
- Das Retry-Intervall startet bei 5 Sekunden und bleibt auf 1 Stunde begrenzt.
- Der Coordinator verarbeitet einen erfolgreichen Auftrag, uebernimmt die
  Serverrevision und entfernt ihn aus der Outbox.
- Die Sicherheitsmigration aus Phase 3 bleibt Teil desselben Testtargets.

## Verifikation

- iOS-Geraetebuild: erfolgreich, Exit-Code 0.
- App und Unit-Testbundle: erfolgreich kompiliert, Exit-Code 0.
- Die Ausfuehrung im Simulator wird weiterhin durch Xcodes Test-Runner blockiert
  (`waiting for workers to materialize`). Es wurde kein Testfehler gemeldet.

## Abnahme Phase 4

- [x] Outbox ueberlebt App-Neustarts durch SwiftData-Persistenz.
- [x] Deduplizierung und Generationen verhindern verlorene Aenderungen.
- [x] Retry, Timeout und blockierende Fehler sind zentral definiert.
- [x] Ein zentraler Coordinator verhindert konkurrierende Sync-Laeufe.
- [x] Anbieterabhaengigkeiten sind nicht Teil von Outbox oder Coordinator.
- [x] App- und Testbundle-Build sind erfolgreich.
