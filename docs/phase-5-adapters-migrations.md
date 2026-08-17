# Phase 5: Bereichsadapter und portable PostgreSQL-Migrationen

Stand: 17. August 2026

## Einheitliche Bereichsadapter

Alle aktuell genutzten strukturierten Cloudbereiche implementieren denselben
Vertrag:

- stabiler Bereichsname
- aktuelle Schema-Version
- Export aus SwiftData fuer genau ein Dossier
- deterministischer JSON-Encoder mit ISO-8601-Daten und sortierten Schluesseln
- Validierung des Payloads gegen Typ und Schema-Version

Registriert sind:

| Bereich | Schema | Inhalt |
| --- | ---: | --- |
| `profil` | 1 | Profil- und Registrierungsmetadaten ohne Kontopasswort |
| `gesundheit` | 1 | Gesundheitsangaben |
| `wuensche` | 1 | Wuensche und Vorsorgeangaben |
| `finanzen` | 1 | Konten, Schulden, Versicherungen, Liegenschaften, Wertsachen und Steuermetadaten |
| `kontakte` | 1 | Hinterbliebene und Vertrauenspersonen |
| `herzensstuecke` | 1 | strukturierte Metadaten ohne Binaerdateien |
| `zugaenge` | 1 | Abos und digitale Konten als AES-GCM-verschluesselter Payload |

Die Registry lehnt doppelte, unbekannte oder syntaktisch ungueltige Bereiche ab.
Neue Felder werden kuenftig ueber eine erhoehte Schema-Version und eine explizite
Migration im betroffenen Adapter eingefuehrt.

Der Import von Serverdaten in die lokalen Fachmodelle wird bewusst erst mit dem
Download-/Konfliktvertrag und der kontrollierten Migration aller Bereiche
aktiviert. Bis dahin werden die Adapter noch nicht im produktiven Sync-Pfad
verwendet.

## PostgreSQL-Migrationsrunner

`database/migrate.js` stellt fuer Neon und Infomaniak denselben Ablauf bereit:

- Migrationen werden aus unveraenderlichen `NNN_name.sql`-Dateien gelesen.
- Doppelte Versionsnummern werden abgelehnt.
- SHA-256-Pruefsummen verhindern nachtraeglich veraenderte Migrationen.
- Eine PostgreSQL-Advisory-Lock verhindert parallele Runner.
- Jede neue Migration und ihr Protokolleintrag laufen in derselben Transaktion.
- `schema_migrations` dokumentiert Version, Name, Pruefsumme und Zeitpunkt.
- Der Runner verwendet ausschliesslich `DATABASE_DIRECT_URL` mit TLS-Pruefung.
- Eine optionale CA kann ueber `DATABASE_SSL_CA` geliefert werden.

Befehle:

- Neue Datenbank: `npm run db:migrate`
- Einmalige Registrierung des bereits vorhandenen Neon-Initialschemas:
  `npm run db:migrate:baseline`

Die Baseline wird abgelehnt, wenn eine der erwarteten Tabellen `app_users`,
`user_sessions`, `dossiers` oder `dossier_sections` fehlt. In Phase 5 wird keiner
der Befehle gegen eine Cloud-Datenbank ausgefuehrt.

## Verifikation

- 14 Node-Tests erfolgreich, einschliesslich Sortierung, Pruefsumme,
  Duplikaterkennung, Manipulationsschutz und Transaktionsreihenfolge.
- iOS-Geraetebuild erfolgreich, Exit-Code 0.
- App und Unit-Testbundle mit Registry- und Profiladapter-Test erfolgreich
  kompiliert, Exit-Code 0.
- Der Profiladapter-Test stellt sicher, dass kein Kontopasswort exportiert wird.
- Die Simulator-Ausfuehrung bleibt wegen des bereits dokumentierten
  Xcode-Test-Runner-Problems offen.

## Abnahme Phase 5

- [x] Alle genutzten strukturierten Bereiche besitzen denselben Exportvertrag.
- [x] Bereich, Schema-Version und Payload sind zentral validierbar.
- [x] Der sensible Zugangsbereich bleibt vor dem Transport verschluesselt.
- [x] Migrationen sind versioniert, transaktional und gegen Manipulation geschuetzt.
- [x] Derselbe Runner ist fuer Neon und Infomaniak vorgesehen.
- [x] Keine Cloud-Datenbank wurde in dieser Phase veraendert.

