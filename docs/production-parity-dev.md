# Production-Parity-DEV

Stand: 28. September 2026

## Ziel

DEV und PROD verwenden denselben unveraenderlichen Docker-Image-Digest,
denselben Compose-Stand, dieselben MySQL-Migrationen und dieselben Laufzeitpfade.
Unterschiede sind ausschliesslich Konfiguration, Secrets, Domain, Datenbank,
Storage-Container, APNs-Umgebung und fachlich begruendete Zeitwerte.

## Aktueller Nachweis

- Oeffentliche DEV-API: `https://api-dev.tschluessli.ch`
- Live- und Ready-Healthcheck am 28. September 2026 erfolgreich
- Datenbank-Engine laut Readiness: MySQL
- Verbindung, erwartete Datenbank und Schema laut Readiness bereit
- Registrierung, E-Mail-Code, Einladung, Push, Bereichsrechte, manueller und
  automatischer Vollzugriff, Widerruf sowie Dokument-/PDF-Pfade auf zwei iPhones
  funktional getestet
- Backend-Vertragstests: 61 bestanden
- iPhone-Geraetebuild: erfolgreich

## Verbindliche Freigabegates

Ein Stand ist erst promotionsfaehig, wenn alle Punkte erfuellt und dokumentiert
sind:

1. Arbeitsstand ist in Git nachvollziehbar und hat eine eindeutige Release-ID.
2. `npm run verify:release` laeuft erfolgreich.
3. Ein Image wird einmal gebaut und in eine Registry gepusht.
4. DEV laeuft mit dem unveraenderlichen Image-Digest, nicht mit einem lokal
   gepatchten Container.
5. Alle Migrationen laufen vor dem App-Start erfolgreich und ein zweiter Lauf ist
   ohne Aenderung erfolgreich.
6. Live-, Ready-, API-Vertrags- und iOS-End-to-End-Tests gegen DEV sind gruen.
7. Datenbank-Backup und Restore in eine isolierte Zieldatenbank sind nachgewiesen.
8. Object Storage ist mit getrenntem DEV-Container aktiv und getestet.
9. Monitoring prueft API, Datenbankbereitschaft und Workerbetrieb.
10. Rollback auf den vorherigen Image-Digest ist dokumentiert und getestet.

## Erlaubte Umgebungsunterschiede

| Bereich | DEV | PROD |
|---|---|---|
| API | `api-dev.tschluessli.ch` | `api.tschluessli.ch` |
| App-Konfiguration | Debug | Release |
| APNs | Sandbox | Production |
| Datenbank | eigene DEV-Datenbank und Rolle | eigene PROD-Datenbank und Rolle |
| Object Storage | eigener DEV-Container | eigener PROD-Container |
| E-Mail | Empfaenger-Allowlist | regulaere Versandregeln |
| Karenzfrist | 90 Sekunden | 7 Tage |
| Reminder | 30 Sekunden | 24 Stunden |

## Noch offen

### Blockiert die Production-Parity

- Aktuelle lokale Aenderungen pruefen und als nachvollziehbaren Git-Stand sichern.
- GHCR-Workflow ist lokal vorbereitet; nach Git-Sicherung ausführen und den
  ersten Digest in DEV deployen.
- DEV aus einem vollstaendig gebauten Image neu ausrollen; keine Container-Patches.
- Infomaniak Object Storage in DEV aktivieren, bestehende Payloads migrieren
  und Upload, Download sowie Löschung auf zwei iPhones abnehmen.
- Backup-/Restore-Test der Infomaniak-DEV-Datenbank durchfuehren.
- Monitoring fuer Ready-Healthcheck und Worker einrichten.
- SSH-Zugang zum DEV-Host wiederherstellen und den internen Stand erneut pruefen.

### Vor dem ersten PROD-Release

- PROD-Domain, TLS, Datenbank, Rollen, Storage und Secrets getrennt bereitstellen.
- Release-Build mit gesetzter `TSCHLUESSLI_PROD_API_BASE_URL` pruefen.
- Datenschutz-, Aufbewahrungs- und Loeschkonzept fachlich abnehmen.
- Denselben in DEV getesteten Image-Digest nach PROD promoten.

## Naechste Ausfuehrungsreihenfolge

1. Git- und Release-Stand konsolidieren.
2. Registry und digestbasiertes Deployment einrichten.
3. Object Storage implementieren.
4. DEV vollstaendig neu ausrollen und Migrationen verifizieren.
5. Backup/Restore und Monitoring einrichten.
6. Komplette Zwei-iPhone-Abnahme wiederholen.
