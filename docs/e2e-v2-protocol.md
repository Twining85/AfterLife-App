# E2E-V2: Format und Implementierungsstand

Stand: 6. Oktober 2026. Lokale V2-Grundlage und explizite Sync-Schnittstellen,
noch keine Aktivierung im normalen App-Sync und keine Bestandsmigration. DEV enthält laut Eigentümer ausschliesslich erfundene Testdaten.

## Implementiert und isoliert testbar

- CryptoKit AES-256-GCM mit zufälligen Nonces und 128-Bit-Tag.
- Pro Dossier, Bereich, Dokument und Schlüsselversion getrennte 256-Bit-Schlüssel,
  mit HKDF-SHA256 aus einem lokalen Owner-Stammschlüssel abgeleitet.
- Owner-Schlüssel in Keychain, an User-ID und Dossier-ID gebunden. Ein fehlender
  Schlüssel wird beim Lesen niemals durch einen neuen ersetzt. Erstellung erfolgt
  ausdrücklich; temporäre Keychain-Fehler werden weitergegeben.
- Recovery-Paket für den Stammschlüssel mit den vorhandenen zufällig generierten
  12 Wörtern. Owner, Dossier und Recovery-ID sind authentifiziert. Ein vorhandener
  anderer Stammschlüssel wird nicht überschrieben. Cloud-Lifecycle und Widerruf
  früherer Recovery-Pakete sind noch nicht angeschlossen.
- Verschlüsselte Freigabepakete enthalten ausschliesslich ausgewählte
  Ressourcenschlüssel. Kein Owner-Stammschlüssel in Freigaben.
- Ein eigenständiges zufälliges 32-Byte-Geheimnis verpackt Freigabeschlüssel.
  Die Einladung/Anmeldung darf dieses Geheimnis nicht als Backend-Token verwenden.
- Browsermodul `support/e2e.js` entschlüsselt lokal via WebCrypto; weder Netzwerk-
  zugriff, Protokollierung noch persistente Schlüsselablage. Noch nicht im UI
  angeschlossen oder über eine Support-Route veröffentlicht.
- Support-API erkennt V2 auch ausserhalb von `zugaenge`, meldet Inhaltsstatus als
  unbekannt und blendet Ciphertext in normalen Details aus. Sie entschlüsselt nicht.

Expliziter V2-Export und -Import sind an die vorhandenen Bereichsadapter
angeschlossen und isoliert getestet. Der normale Adapter-/Import-/Freigabefluss
verwendet weiterhin V1. Der bestehende V1-Transport bleibt bestehen. Deshalb ist weiterhin
keine vollständige E2E-Zusage möglich.

## Wire-Format

Payload:

```json
{
  "formatVersion": 2,
  "algorithm": "AES-256-GCM",
  "context": {
    "dossierID": "11111111-1111-4111-8111-111111111111",
    "sectionType": "gesundheit",
    "schemaVersion": 1,
    "keyVersion": 1,
    "resourceID": "section"
  },
  "ciphertext": "BASE64_NONCE_CIPHERTEXT_TAG"
}
```

`resourceID` ist `section` oder eine kanonische UUID in Kleinbuchstaben. Dokumente
werden mit eigener UUID verschlüsselt; ihre Schlüssel dürfen unabhängig von einem
Bereich freigegeben werden. Die Owner-App muss dazu den bisherigen Payload in
Bereichsinhalt und Dokumente aufteilen. Das ist noch nicht umgesetzt.

AAD ist UTF-8, ohne abschliessenden Zeilenumbruch:

```text
Tschluessli-E2E-v2
<dossier UUID lowercased>
<sectionType>
<schemaVersion decimal>
<keyVersion decimal>
<resourceID>
```

Key derivation: HKDF-SHA256, IKM = 32-Byte-Owner-Stammschlüssel,
Salt = UTF-8 `Tschluessli-E2E-resource-key-v2`, Info = AAD, Länge = 32 Byte.
Ciphertext wird als CryptoKit-combined-Format übertragen: 12 Byte Nonce,
Ciphertext, 16 Byte Tag. Der erwartete Kontext muss aus dem autorisierten
Sync-/Freigabefluss kommen, nicht ungeprüft aus dem Paket übernommen werden.

Freigabe-AAD:

```text
Tschluessli-E2E-grant-v2
<dossier UUID lowercased>
<invitation UUID lowercased>
<normalized recipient email>
<grantVersion decimal>
<partial or full>
```

Wrapping-Key: HKDF-SHA256, IKM = unabhängiges zufälliges Einladungsgeheimnis,
Salt = UTF-8 `Tschluessli-E2E-grant-key-v2`, Info = Freigabe-AAD, Länge = 32 Byte.
Der verschlüsselte Inhalt ist eine Liste von `{context, key}`. Der Schlüssel ist
Base64, exakt 32 Byte. Dossierfremde und doppelte Ressourcen sind ungültig.

Einladungstoken, Auth-Token und geheimes Schlüsselmaterial dürfen sich nicht
überschneiden. Ein Link-Fragment allein genügt nicht: Deep-Link-Parser, QR,
Keychain, Logs und HTTP-Bodies müssen die Trennung durchgängig wahren.

## Noch erforderliche Integration vor Aktivierung

1. Die Rechte-/Zustimmungsmetadaten sind aus Kontakten/Einstellungen herausgelöst
   und revisionstreu im Sync angeschlossen. Noch offen: Rechte an einzelne Dokumente
   und serverseitige Dokumentänderungen im vollständigen V2-Freigabefluss ersetzen.
2. Einladungsprotokoll mit separatem Geheimnis, Teilpaket und vorbereitetem
   Vollpaket implementieren. Migration alter Einladungen verlangt erneute sichere
   Übergabe. Der Server kann Pakete vorzeitig zustellen: Frist ist eine serverseitige
   Zugriffsregel, keine kryptografische Zeitsperre.
3. Rotation nach Widerruf: alte Bereichs-/Dokumentenschlüssel dürfen neue Inhalte
   nicht entschlüsseln. Wiederaufnahme/Recovery muss Versionsstände erhalten.
4. Adapter, Imports und Sync-Konflikte auf V2 umstellen. Dokumente separat
   verschlüsseln; keine V1-Masterpakete mehr für migrierte Dossiers erzeugen.
5. Revision-geprüfte Migration von Dossier, Recovery und Freigaben; alte Clients
   dürfen für migrierte Dossiers keine Klartext-Updates mehr liefern.
6. Alte History, Idempotenzantworten, Storage-Versionen und Backups behandeln.
   Auch synthetische Daten werden nicht vor verifiziertem Umstieg gelöscht.
7. DEV-Support-UI als lokalen berechtigten Client anbinden, inklusive explizitem
   Laden und Verwerfen von Testschlüsseln. Beta/PROD erhalten keinen Generalschlüssel.
8. Zwei-Geräte-Abnahme von Teilfreigabe, Vollfreigabe, Nein/Ja-Wechsel während
   offener Anfrage, Recovery, Widerruf und unterbrochener Migration.

## Verifikation

Gemeinsamer deterministischer Testvektor für Node AES-GCM, WebCrypto und CryptoKit.
Tests für falsche Schlüssel, Ciphertext-Manipulation, Austausch von Kontext,
getrennte Ressourcenschlüssel, ungültige Freigaben und lokale Recovery.

Grundlagen: [CryptoKit AES.GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm)
und [HKDF](https://developer.apple.com/documentation/cryptokit/hkdf).

Nachweis für diesen Stand: 108 Node-Vertragstests erfolgreich; sieben gezielte
iOS-Tests im iPhone-17-Pro-Simulator (iOS 26.5) erfolgreich, einschliesslich
Keychain-Recovery und Schutz vor dem Überschreiben eines vorhandenen Schlüssels.
Logs: `/tmp/tschluessli-e2e-tests.log` und
`/tmp/tschluessli-e2e-ios-recovery-tests.log`.
Das ist kein Nachweis einer Migration oder einer Zwei-Geräte-Freigabe im Livebetrieb.

## Zweiter Umsetzungsschritt: Metadaten und Sync

- Kontakte liefern neben dem verschlüsselten Payload ausschliesslich Empfänger-
  adresse, sichtbare Bereichstypen und ausdrückliche Zustimmung. Einträge ohne
  E-Mail erzeugen keine Freigabe; doppelte Empfänger werden abgelehnt.
- Einstellungen liefern nur die gewählten Bereichstypen. Reihenfolge, Status,
  Prüfdaten und andere Inhalte bleiben im verschlüsselten Payload.
- `accessMetadata` ist ein eigener Teil des Upload-Vertrags, kein Teil des
  Ciphertexts. Unbekannte Felder, Klartext-Zusätze, fehlende Metadaten bei Kontakten/
  Einstellungen und unpassende Verschlüsselungskontexte werden abgelehnt.
- Metadata, Inhaltsrevision, Zustimmungsupdate und Sync-Ereignis werden innerhalb
  derselben bestehenden Datenbanktransaktion gespeichert. Idempotenz-Hashes
  berücksichtigen auch Metadatenänderungen.
- Pull-Ereignisse bewahren die jeweiligen Metadaten; Snapshot-Metadaten müssen
  zur aktuellen Inhaltsrevision passen. Die App transportiert sie getrennt.
- Die bestehende Zustimmungslogik arbeitet nun auch mit V2-Projektionen. Nur Ja
  erlaubt automatische Freigabe; fehlend/Nein bleibt Nein. Wiederholte Ja-Updates
  verschieben die Frist nicht, Nein entfernt die Frist ohne Anfrage zu entscheiden.
- API und Datenbank halten einen dauerhaften V2-Verschlüsselungsstatus pro Bereich.
  Lösch-Tombstones erhalten diesen Status. Alte Clients können anschliessend keine
  Klartext-Inhalte speichern, auch über den älteren PUT-Endpunkt nicht. Beide
  Schreibwege nutzen jetzt denselben Revisions- und Zustimmungsmechanismus.
- Der alte tokenbasierte Freigabe-Endpunkt liefert keine V2-Inhalte oder alte
  Masterpakete für gemischte/migrierte Dossiers aus. Er antwortet stattdessen mit
  `e2e_invitation_migration_required`. Die vollständige neue Freigabe ist offen.
- Ciphertexts werden vom Server nicht verändert, um Wunschdokumente freizugeben.
- Expliziter V2-Export/Import ist getestet, aber nicht im normalen Outbox-/Recovery-
  Ablauf aktiviert. Der vorbereitete Export verschlüsselt Anhänge vorerst zusammen
  mit dem Bereich; separate Dokumentobjekte sind weiterhin erforderlich.

### Migration und Betrieb dieses Zwischenstands

Neue Schema-Migrationen: PostgreSQL `012_e2e_access_metadata.sql`, MySQL
`005_e2e_access_metadata.sql`. API-Readiness verlangt jetzt Schema 12 bzw. 5.
Die Migration fügt Strukturen und Constraints hinzu; sie verschlüsselt oder löscht
keine bestehenden Daten. Alte Migrationen wurden nicht verändert.

`E2E_V2_SYNC_ENABLED=false` bleibt der Standard. V2-Uploads sind nur in DEV und
mit ausdrücklichem `true` erlaubt. Den Schalter noch nicht für den normalen
App-Betrieb einschalten: neue Einladungen, einzelne Dokumentfreigaben, Rotation,
Cloud-Recovery und Bestandsmigration sind nicht vollständig angebunden.

Vor Deployment: Migration mit geeigneter Rolle in einer isolierten MySQL-8.4-
Datenbank prüfen, erneut ausführen und Rückfall testen. Die Rolle benötigt unter
anderem TRIGGER-Rechte. MySQL-DDL ist nicht als Ganzes transaktional; ein teilweise
fehlgeschlagener Lauf muss vor einem erneuten Versuch kontrolliert behandelt werden.
Bei migrierten Bereichen ist ein altes Backend-Image kein vollständiger Rückfall,
da es V2 nicht lesen kann. Die Datenbank verhindert jedoch Klartextüberschreibungen.

Alle MySQL-Migrationen wurden am 6. Oktober 2026 gegen eine isolierte MySQL-8.4-
Instanz auf DEV ausgeführt und erneut aufgerufen. Klartextüberschreibungen sowie
die Wiederherstellung eines gelöschten V2-Bereichs als Klartext wurden abgewiesen;
die Verschlüsselungsversion bleibt auch bei Löschungen erhalten. Derselbe Test
läuft vor dem Image-Build in GitHub Actions. PostgreSQL wurde noch nicht gegen
eine laufende Datenbank geprüft.
Grundlage: [MySQL CREATE TRIGGER](https://dev.mysql.com/doc/refman/8.4/en/create-trigger.html).

Verifikation des zweiten Schritts: 125 Node-Tests und zehn gezielte iOS-Tests
(erfolgreich). Neue Tests decken V2-Kontaktexport/-import, Datenminimierung,
Zustimmungsprojektion, beide SQL-Enginepfade, Idempotenz, Snapshot/Pull,
Klartext-Downgrades, den alten PUT-Endpunkt und blockierte Legacy-Freigaben ab.
Keine echte Cloud-Migration, kein Zwei-Geräte-Test und kein Deployment durchgeführt.
