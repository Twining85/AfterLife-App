# Unveraenderliche Promotion von DEV nach PROD

Ein Release wird genau einmal als Docker-Image gebaut. DEV und PROD verwenden
denselben Image-Digest, denselben `compose.yml`-Stand und dieselben unveraenderten
SQL-Migrationen. Es gibt keine umgebungsspezifischen Codezweige.

## Konfigurationsgrenzen

Folgende Werte werden pro Umgebung ausserhalb des Images gesetzt:

- `APP_ENV`
- `MYSQL_URL`, `MYSQL_DIRECT_URL` und `MYSQL_EXPECTED_DATABASE`
- MySQL-CA-Mount
- `OBJECT_STORAGE_CONTAINER` und `OBJECT_STORAGE_EXPECTED_CONTAINER`
- Storage-Endpoint und Storage-Credentials
- E-Mail-, APNs-, Signatur- und Cron-Secrets
- `TRUST_ACCESS_GRACE_SECONDS`
- Host-Port des lokalen Reverse-Proxy-Upstreams
- iOS-API-URL

Der Prozess startet nicht, wenn `APP_ENV`, die erwartete MySQL-Datenbank oder die
CA fehlen. Der Readiness-Check wird bei falscher Datenbank oder fehlendem Schema
nicht erfolgreich.

## Releasefolge

1. Commit bzw. Release-ID festlegen.
2. Image einmal bauen und mit unveraenderlichem Tag sowie Digest in eine Registry
   pushen.
3. Exakt diesen Digest in DEV starten.
4. Dieselben Migrationen gegen DEV ausfuehren.
5. Backend-Vertrags-, Health- und iOS-End-to-End-Tests gegen DEV ausfuehren.
6. Freigabe und Backup-/Restore-Nachweis dokumentieren.
7. Denselben Digest in PROD konfigurieren; kein Rebuild.
8. Dieselben Migrationen mit der getrennten PROD-Konfiguration ausfuehren.
9. PROD starten und Health-/Smoke-Tests ausfuehren.

Die Environment-Dateien, Datenbankbenutzer, CAs, Storage-Container und Secrets
werden niemals zwischen DEV und PROD kopiert. Nur Image-Digest und
Migrationsdateien werden promoted.

In beiden Umgebungen wird die vollstaendige Referenz identisch gesetzt:

```sh
export TSCHLUESSLI_IMAGE_REF=REGISTRY/TSCHLUESSLI-API@sha256:TESTED_IMAGE_DIGEST
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml pull
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml --profile tools run --rm migrate
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml up -d api auto-release-worker
```

## iOS

Das Debug-Buildsetting `TSCHLUESSLI_DEV_API_BASE_URL` und das Release-Buildsetting
`TSCHLUESSLI_PROD_API_BASE_URL` werden von Xcode beziehungsweise CI gesetzt.
`Info.plist` enthaelt nur die daraus aufgeloeste `TschluessliAPIBaseURL`. Fehlt sie
oder ist sie nicht HTTPS, startet der Cloudpfad nicht mit einer stillen
Fallback-URL.
