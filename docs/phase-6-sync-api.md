# Phase 6: Vollständige Sync-API

Stand: 17. August 2026

## Vertrag

Die anbieterneutrale API besitzt zwei neue Endpunkte:

- `POST /api/sync/push` schreibt genau eine Bereichsmutation.
- `GET /api/sync/pull?cursor=...` liefert bis zu 100 Änderungen seit einem Cursor.

Beide Endpunkte verlangen eine gültige Bearer-Sitzung und arbeiten innerhalb einer
Benutzertransaktion mit Row-Level-Security. Der App-Client erhält nur Daten des
angemeldeten Kontos.

## Upload

Ein Upload enthält Dossier-ID, Bereich, Vorgang (`upsert` oder `delete`),
Schema-Version, erwartete Serverrevision und bei `upsert` ein JSON-Objekt. Der
Header `Idempotency-Key` ist obligatorisch.

- Ein neuer Stand erhöht die Bereichsrevision genau einmal.
- Eine identische Wiederholung liefert die gespeicherte Antwort und den Header
  `Idempotency-Replayed: true`.
- Derselbe Schlüssel mit anderem Inhalt wird als Konflikt abgelehnt.
- Eine falsche Ausgangsrevision überschreibt nichts und liefert mit HTTP 409 den
  aktuellen Serverstand.
- Unbekannte Bereiche oder Schema-Versionen werden abgelehnt.

## Download und Löschungen

Jede angenommene Mutation erzeugt in derselben Transaktion einen Eintrag in
`sync_changes`. Der Cursor ist eine undurchsichtige Dezimalzeichenfolge, damit auf
Clients kein Genauigkeitsverlust bei PostgreSQL-`bigint` entsteht.

Beim Einführen der Migration werden bereits vorhandene `dossier_sections` einmalig
als Ausgangsstand in `sync_changes` übernommen. Deshalb kann ein neuer Client auch
vor Phase 6 erfasste Neon-Testdaten vollständig herunterladen.

Löschungen bleiben als versionierte Tombstones erhalten. Der Download liefert
`operation: delete`, die Revision und `payload: null`. So erkennen auch Geräte,
die längere Zeit offline waren, die Löschung.

## PostgreSQL-Portabilität

Migration `002_sync_protocol.sql` verwendet nur PostgreSQL-Funktionen, die für
Neon und Infomaniak vorgesehen sind: Tabellen, Identitätsspalte, Transaktionen,
JSONB, Indizes, Advisory Locks und Row-Level-Security. Anbieter-SDKs werden nicht
verwendet.

Die bestehende Neon-Datenbank wird später kontrolliert mit `npm run db:migrate`
aktualisiert. Eine neue Infomaniak-Datenbank erhält Migration 001 und 002 in
derselben Reihenfolge. In Phase 6 wurde keine Cloud-Datenbank direkt verändert.

## Abgrenzung

Phase 6 stellt und testet den Serververtrag bereit. Die produktive Verbindung der
Outbox und der Bereichsadapter mit diesen Endpunkten sowie der lokale Import der
Downloads folgen in Phase 7.
