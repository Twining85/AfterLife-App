# Tschluessli MySQL- und API-Vertrag v1

Stand: 15. September 2026  
Status: MySQL-Runtime und DEV-Container lokal vorbereitet; noch nicht gegen Infomaniak ausgefuehrt

## Grenzen

Die iOS-App spricht ausschliesslich per HTTPS mit der API. Nur das Backend besitzt
MySQL- und Object-Storage-Zugangsdaten. Die normale App kann keine Admin-Rolle
vergeben. Dossierinhalte werden von Admin-Endpunkten weder geladen noch ausgegeben.

SwiftData bleibt der lokale Arbeitsstand. Serverseitig autoritativ sind Konten,
Sitzungen, Dossiereigentuemer, Einladungen, Zugriffserteilungen, Karenzfristen,
Freigaben und Loeschungen.

## Umgebungen

- DEV: Datenbank `tschluessli_dev`, eigener DB-Benutzer und Container
  `tschluessli-dev-files`.
- PROD: separate Datenbank `tschluessli_prod`, eigener DB-Benutzer und Container
  `tschluessli-prod-files`.
- Der Wechsel auf eine eigene PROD-DB-Instanz erfolgt ausschliesslich ueber
  Umgebungsvariablen.

## Strukturierte Dossierbereiche

Der bestehende Bereichsvertrag bleibt erhalten: `profil`, `gesundheit`,
`wuensche`, `finanzen`, `kontakte`, `herzensstuecke` und `zugaenge`. Jeder Bereich
besitzt Schema-Version, erwartete Revision und Payload. Loeschungen sind
versionierte Tombstones. `weiteres` und `dokumente` werden erst aktiviert, nachdem
ihre bestehenden SwiftData-Modelle einen Adapter und Importtests besitzen.

Lokale Geraeteeinstellungen, Dateipfade, Outbox, Konflikte und Sync-Cursor werden
nicht als Dossierinhalt hochgeladen. Binaerdaten werden nicht in JSON-Payloads
eingebettet.

## HTTP-API

Alle Pfade erhalten vor der Infomaniak-Umschaltung das Praefix `/v1`.

### Konto

- `POST /v1/auth/register`
- `POST /v1/auth/login`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `POST /v1/auth/password/change`
- `POST /v1/auth/password-reset/request`
- `POST /v1/auth/password-reset/confirm`
- `DELETE /v1/me/account`
- `POST /v1/me/test-data-reset`

### Synchronisation

- `POST /v1/dossiers/{dossierID}/sync/push`
- `GET /v1/dossiers/{dossierID}/sync/pull?cursor={cursor}`

Push verlangt `Idempotency-Key`, `sectionType`, `schemaVersion`,
`expectedRevision`, `operation` und bei `upsert` einen Objekt-Payload. Ein
Revisionskonflikt liefert HTTP 409 und den aktuellen Serverstand. Pull liefert
eine geordnete Seite aus Upserts und Tombstones sowie den naechsten undurchsichtigen
Cursor.

### Einladungen und Freigaben

- `POST /v1/dossiers/{dossierID}/invitations`
- `POST /v1/invitations/{token}/validate`
- `POST /v1/invitations/{token}/request-access`
- `POST /v1/invitations/{invitationID}/accept`
- `POST /v1/invitations/{invitationID}/decline`
- `DELETE /v1/invitations/{invitationID}`

Diese Operationen sind die einzige Schreibschnittstelle fuer Einladungsstatus,
Zugriffsrechte und Karenzfristen. Ein normaler Bereichs-Sync darf diese Felder
nicht autoritativ veraendern.

### Dateien

- `POST /v1/dossiers/{dossierID}/files/initiate`
- `POST /v1/dossiers/{dossierID}/files/{fileID}/complete`
- `GET /v1/dossiers/{dossierID}/files/{fileID}/download`
- `DELETE /v1/dossiers/{dossierID}/files/{fileID}`

`initiate` erzeugt einen nicht erratbaren Object Key und eine kurzlebige,
eingeschraenkte Upload-Berechtigung. `complete` prueft Groesse und SHA-256, bevor
die Datei als verfuegbar markiert wird. Downloadberechtigungen werden fuer jede
Anfrage anhand des aktuellen Dossierzugriffs geprueft.

### Admin

- `GET /v1/admin/users`
- `GET /v1/admin/users/{userID}/technical-status`
- `POST /v1/admin/users/{userID}/reset-test-data`
- `DELETE /v1/admin/users/{userID}`
- `POST /v1/admin/users/{userID}/reset-trust-connections`
- `GET /v1/admin/audit-log`

Adminantworten enthalten nur Konto-, Verbindungs-, Speicher- und Fehlerstatus.
Sie enthalten keine Bereichspayloads, Dateiinhalte, Download-URLs oder
entschluesselten Schluessel. Adminzuordnung erfolgt ausschliesslich durch einen
kontrollierten serverseitigen Betriebsprozess.

## Loeschsemantik

Ein Dossier-Reset entfernt Dossierbereiche, Dateien, Einladungen, Freigaben,
Schluesselumschlaege, Idempotenzdaten und Syncereignisse, behaelt aber Konto und
Login. Eine Kontoloeschung entfernt zusaetzlich Sitzungen und den Benutzer. Die
Dateiloeschung wird ueber einen wiederaufnehmbaren Status `deleting` ausgefuehrt,
damit ein temporaerer Object-Storage-Fehler keine verwaisten, unsichtbaren Dateien
hinterlaesst.

## Migration

Das initiale MySQL-8.4-Schema liegt in `database/mysql/migrations`. Es wird mit
`npm run db:mysql:migrate` und ausschliesslich mit `MYSQL_DIRECT_URL` ausgefuehrt.
Vor jedem Lauf sind Backup, Zielumgebung und Datenbankname zu kontrollieren.
Der aktuelle PostgreSQL-Code bleibt bis zur erfolgreichen MySQL-Vertrags- und
Integrationstestphase unangetastet.

Die konkrete erstmalige Inbetriebnahme ist in
[`dev-deployment-infomaniak.md`](dev-deployment-infomaniak.md) beschrieben.
Die unveraenderliche DEV-/PROD-Promotion ist in
[`environment-promotion.md`](environment-promotion.md) festgelegt.
