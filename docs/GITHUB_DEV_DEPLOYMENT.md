# DEV-Deployment über GitHub Actions

Der Workflow **Backend-Image veröffentlichen** kann ein geprüftes Backend-Image
bauen und dasselbe unveränderliche Image direkt auf DEV bereitstellen.

## Einmalige GitHub-Konfiguration

Unter **Settings → Environments** das Environment `dev` anlegen. Anschliessend
unter **Settings → Secrets and variables → Actions** diese Repository-Secrets
hinterlegen:

- `DEV_SSH_HOST`: Hostname oder IP-Adresse des DEV-Servers
- `DEV_SSH_USER`: SSH-Benutzer des DEV-Servers
- `DEV_SSH_PRIVATE_KEY`: vollständiger privater Deployment-Schlüssel inklusive
  BEGIN- und END-Zeile
- `DEV_SSH_KNOWN_HOSTS`: geprüfter SSH-Hostschlüssel des DEV-Servers

Die Secrets werden von GitHub maskiert und dürfen weder im Workflow noch in
Logs oder Repository-Dateien eingetragen werden.

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
