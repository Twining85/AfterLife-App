# Tschlüssli-Datenbank

Die Migrationen werden mit `npm run db:migrate` in numerischer Reihenfolge gegen
`DATABASE_DIRECT_URL` ausgeführt. Der Runner verwendet eine PostgreSQL-Advisory-Lock,
Transaktionen und SHA-256-Prüfsummen in `schema_migrations`. Bereits registrierte
Migrationen dürfen nicht nachträglich verändert werden. Die API verwendet getrennt
davon `DATABASE_URL`. Beide Cloudverbindungen müssen TLS mit Zertifikatsprüfung nutzen.
Da der Runner die Transaktion verwaltet, enthalten die SQL-Dateien selbst kein
`BEGIN` oder `COMMIT`.

Für die bereits vor Einführung des Runners erstellte Neon-Testdatenbank wird genau
einmal `npm run db:migrate:baseline` verwendet. Der Runner registriert Migration 001
nur, wenn alle vier erwarteten Initialtabellen vorhanden sind. Dieser Befehl ist nicht
für eine leere Datenbank gedacht. Neue Neon- und Infomaniak-Datenbanken verwenden
direkt `npm run db:migrate`.

`001_initial.sql` legt Konten, Sitzungen, Dossiers und flexible, versionierte
Dossierbereiche an. Dokumentinhalte gehören ausdrücklich nicht in diese Tabellen.
`002_sync_protocol.sql` ergänzt Tombstones, den cursorbasierten Änderungsverlauf
und idempotente Upload-Antworten für die Sync-API.

Die Row-Level-Security erwartet innerhalb jeder Dossier-Transaktion `app.user_id`. Das Backend
setzt diesen Wert lokal in der Transaktion; direkte Abfragen ohne Benutzerkontext sehen keine
Dossierdaten.
