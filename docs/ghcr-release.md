# Backend-Releases über GitHub Container Registry

Stand: 6. Oktober 2026

Das Backend-Image wird durch `.github/workflows/backend-image.yml` genau einmal
gebaut und unter `ghcr.io/twining85/tschluessli-api` veröffentlicht. Aktuell ist
nur DEV eingerichtet. Produktion erhält später einen separaten Freigabeablauf.

## Branches und Push

Die laufende Entwicklung findet auf `DEV` statt. Release-Branches wie
`release/1.0` werden bei Beginn der Abschlussprüfung von `DEV` erstellt;
Git-Branches haben dabei keine technische Eltern-Kind-Beziehung. Korrekturen
auf Release-Branches werden auch nach `DEV` übernommen.

`DEV` verfolgt `origin/DEV`. Ein normaler Commit und `git push` aktualisieren
damit den DEV-Branch im bestehenden GitHub-Repository. Für einen neuen
Release-Branch wird einmalig `git push -u origin release/1.0` verwendet.
`main` bleibt vorerst auf seinem bisherigen Stand und ist noch keine
eingerichtete Produktionsumgebung. Später verfolgt `main` weiterhin
`origin/main`; der Produktionsworkflow erhält eigene Umgebung und Secrets.

## Release auslösen

Der Workflow wird manuell mit einem eindeutigen Image-Tag wie
`dev-2026-10-06.1` gestartet. Unter **Use workflow from** muss `DEV` oder ein
`release/*`-Branch gewählt werden. Mit **Auf DEV bereitstellen** wird zusätzlich
das Deployment gestartet. Weder Branch-Pushes noch Git-Tags starten den Workflow.
Der eingegebene Image-Tag ist kein Git-Tag.

Solange GitHub `main` als Standardbranch verwendet, kann dort noch die frühere
Workflow-Version angezeigt werden. Deshalb immer ausdrücklich `DEV` auswählen.
Vor der Einrichtung von Produktion muss auch der Workflow auf `main` angepasst
werden, damit er nicht mehr den früheren DEV-Ablauf anbietet.

Vor dem Image-Build führt GitHub aus:

- reproduzierbare Installation mit `npm ci`,
- JavaScript-Syntaxprüfung,
- sämtliche Backend-Vertragstests,
- Compose-Konfigurationsprüfung.

Das veröffentlichte Image enthält SBOM- und Provenance-Metadaten. Massgeblich für
Deployment und Promotion ist immer der ausgegebene Digest, nie nur der lesbare
Tag.

## Einmalige Anmeldung des Servers

Falls das GHCR-Paket privat bleibt, benötigt der DEV-/PROD-Host einen eigenen,
widerrufbaren **Personal Access Token (classic)** mit ausschliesslich
`read:packages`. Das Token wird nur interaktiv an Docker übergeben und weder in
`backend.env` noch im Repository gespeichert:

```sh
read -s GHCR_READ_TOKEN
printf '%s' "$GHCR_READ_TOKEN" | sudo docker login ghcr.io -u GITHUB_BENUTZER --password-stdin
unset GHCR_READ_TOKEN
```

DEV und PROD erhalten getrennte Tokens. Schreibrechte sind auf den Hosts nicht
erforderlich.

Das Image enthält bei jedem Build BuildKit-Provenance und eine SBOM. Die
zusätzliche GitHub-Artefakt-Attestierung erzeugt der Workflow für öffentliche
Repositories. Bei privaten Repositories ist diese GitHub-Funktion vom Tarif
abhängig und darf deshalb die Veröffentlichung des Images nicht blockieren.

## Digest in DEV deployen

```sh
cd /opt/tschluessli
export TSCHLUESSLI_IMAGE_REF='ghcr.io/twining85/tschluessli-api@sha256:GEPRUEFTER_DIGEST'
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml pull api auto-release-worker
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml --profile tools run --rm migrate
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml up -d api auto-release-worker
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml ps
```

Danach interne und öffentliche Readiness prüfen. Der geprüfte Digest wird im
Abnahmeprotokoll festgehalten.

## Promotion nach PROD

Nach DEV-Abnahme, Backup-/Restore-Nachweis und Zwei-iPhone-Test wird exakt die
gleiche `image@sha256:...`-Referenz in PROD gesetzt. Ein erneuter Build für PROD
ist nicht zulässig.

## Rollback

Der vorherige funktionierende Digest bleibt dokumentiert. Für einen Rollback wird
nur `TSCHLUESSLI_IMAGE_REF` auf diesen Digest zurückgesetzt und Compose erneut
ausgeführt. Datenbankmigrationen benötigen vorab eine eigene
Vorwärts-/Rückwärtsstrategie; ein Image-Rollback allein ändert das Schema nicht.
