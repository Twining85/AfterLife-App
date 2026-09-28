# DEV-Deployment über GitHub Actions

Der Workflow **Backend-Image veröffentlichen** kann ein geprüftes Backend-Image
bauen und dasselbe unveränderliche Image direkt auf DEV bereitstellen.

## Einmalige GitHub-Konfiguration

Unter **Settings → Environments** wird das Environment `dev` angelegt. Auf dem
DEV-Server läuft ein ausschließlich für dieses Repository registrierter Runner
mit dem zusätzlichen Label `tschluessli-dev`.

Der Runner hat weder einen allgemeinen SSH-Schlüssel noch direkten Docker- oder
Administratorzugriff. Er darf über `sudo` ausschließlich das root-eigene Skript
`/usr/local/sbin/tschluessli-deploy` mit einem SHA-256-Image-Digest aufrufen.
Das Skript akzeptiert nur Images aus
`ghcr.io/twining85/tschluessli-api`, führt Migration und Healthcheck aus und
stellt bei einem Fehler die vorherige Konfiguration wieder her.

Die früher verwendeten Repository-Secrets `DEV_SSH_HOST`, `DEV_SSH_USER`,
`DEV_SSH_PRIVATE_KEY` und `DEV_SSH_KNOWN_HOSTS` werden nicht benötigt und
sollen gelöscht werden.

## DEV bereitstellen

1. Änderungen per Pull Request nach `main` mergen.
2. **Actions → Backend-Image veröffentlichen → Run workflow** öffnen.
3. Branch `main` wählen.
4. Einen neuen eindeutigen Release-Tag eingeben.
5. **Image nach erfolgreichem Build auf DEV bereitstellen** aktivieren.
6. **Run workflow** wählen.
7. Warten, bis Prüfen, Bauen und **Auf DEV bereitstellen** grün sind.

Der Workflow verwendet den vom Build erzeugten Digest, führt die
Datenbankmigration aus, startet API und Worker neu und prüft den internen
Readiness-Endpunkt. Bei einem Fehler wird die vorherige `.env`-Konfiguration
automatisch wiederhergestellt.
