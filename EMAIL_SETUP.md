# E-Mail-Versand mit Infomaniak

DEV und PROD nutzen ein gemeinsames bestehendes Infomaniak-Mailkonto. Die
Zugangsdaten werden in jeder Umgebung als Server-Secrets gespeichert. Ein
Infomaniak-API-Token ersetzt das Passwort der Mailadresse für SMTP nicht.

## SSH-Zugang finden

Für den dokumentierten Ubuntu-DEV-Server werden die öffentliche IP-Adresse,
der Benutzer `ubuntu` und der lokale Pfad des bei der Erstellung verwendeten
privaten SSH-Schlüssels benötigt. Bei Infomaniak Public Cloud steht die Instanz
im Projekt-Dashboard unter Compute → Instances. Dort öffentliche/Floating-IP
und zugeordnetes Key Pair prüfen. Bei Cloud VPS steht die IP in der
Serverübersicht im Infomaniak Manager. Der private Schlüssel liegt lokal auf
dem Mac; sein Inhalt darf nicht weitergegeben werden.

```sh
ssh -i /PFAD/ZUM/SSH_SCHLUESSEL ubuntu@SERVER_IP
```

## Passwort direkt auf dem DEV-Server hinterlegen

Nach erfolgreicher SSH-Anmeldung:

```sh
sudoedit /etc/tschluessli/backend.env
```

Die vorhandenen SMTP-Zeilen ersetzen beziehungsweise fehlende Zeilen ergänzen.
Andere Einstellungen erhalten. Das Passwort im Editor eingeben. In einer
Compose-env-Datei das Passwort in einfache Anführungszeichen setzen, damit
beispielsweise `$` nicht interpoliert wird; ein enthaltenes einfaches
Anführungszeichen mit Backslash maskieren. Keine zusätzlichen SMTP-Zeilen mit
denselben Namen anlegen. In nano speichert Ctrl+O, Enter; Ctrl+X beendet.

Nach dem Speichern:

```sh
sudo chown root:root /etc/tschluessli/backend.env
sudo chmod 0600 /etc/tschluessli/backend.env
```

## Server-Konfiguration

In `/etc/tschluessli/backend.env` auf dem jeweiligen Server eintragen:

```dotenv
SMTP_HOST=mail.infomaniak.com
SMTP_PORT=465
SMTP_NAME=tschluessli.ch
SMTP_USER=hallo@tschluessli.ch
SMTP_PASSWORD='HIER_DAS_MAILPASSWORT_EINTRAGEN'
SMTP_FROM=Tschlüssli <hallo@tschluessli.ch>
SMTP_REPLY_TO=hallo@tschluessli.ch
```

`SMTP_NAME` ist der gültige Domainname für SMTP EHLO. Port 465 verwendet
implizites TLS. Alternativ unterstützt der Code Port 587 mit zwingendem
STARTTLS. Beide Varianten prüfen Zertifikate und verlangen mindestens TLS 1.2.
Die Konfiguration stammt aus der [Infomaniak-Mail-Dokumentation](https://www.infomaniak.com/en/support/faq/admin2/email-service).

Nur DEV erhält zusätzlich:

```dotenv
APP_ENV=development
SMTP_DEV_ALLOWED_RECIPIENTS=r_engeler@me.com,rene.engeler@me.com,neuigkeitenzumir@gmail.com,hallo@tschluessli.ch
EMAIL_VERIFICATION_ALLOWED_RECIPIENTS=r_engeler@me.com,rene.engeler@me.com,neuigkeitenzumir@gmail.com,hallo@tschluessli.ch
EMAIL_VERIFICATION_ALLOW_UNLISTED=false
```

Die zentrale Versandfunktion blockiert in DEV alle nicht freigegebenen
Empfänger für alle Mails, die diese Versandfunktion verwenden. Eine leere Freigabeliste
blockiert den Versand vollständig. Der Betreff erhält automatisch `[DEV]`.
`EMAIL_VERIFICATION_ALLOWED_RECIPIENTS` steuert zusätzlich die vorhandene
Registrierungsprüfung; beide Listen für DEV gemeinsam pflegen.

PROD und TestFlight-Beta verwenden `APP_ENV=production`. Die DEV-Begrenzung
und Betreffkennzeichnung gelten dort nicht. Die vorhandene Registrierungs-
Empfängerregel muss separat für den gewünschten öffentlichen Betrieb gesetzt
werden. Das SMTP-Passwort gehört weder in Git noch in Chat-Nachrichten.
Bestehende Server-Konfiguration mit `sudoedit` bearbeiten, nicht überschreiben.

## Verbindung und Versand prüfen

Nach Deployment des aktualisierten Images auf dem Server:

```sh
cd /opt/tschluessli
sudo docker compose --env-file /etc/tschluessli/deploy.env -f compose.yml exec -T api node scripts/verify-smtp.js
sudo docker compose --env-file /etc/tschluessli/deploy.env -f compose.yml exec -T api node scripts/verify-smtp.js r_engeler@me.com
```

Die erste Prüfung verbindet sich mit TLS und prüft die Anmeldung, ohne eine
Mail zu senden. Die zweite sendet eine Testmail; in DEV muss die Adresse
freigegeben sein. Im empfangenen Mailheader SPF, DKIM und DMARC prüfen.
Die Annahme durch den SMTP-Server bestätigt noch nicht die Zustellung.

Nach Änderungen an den Server-Secrets API und Worker neu erstellen:

```sh
sudo docker compose --env-file /etc/tschluessli/deploy.env -f compose.yml up -d --force-recreate api auto-release-worker
```

Danach Registrierung, Login-Verifikation und Passwortzurücksetzung testen.
Einladungen und Erinnerungen verwenden derzeit Pushbenachrichtigungen;
ein zusätzlicher Mailversand dafür ist hier nicht implementiert.
Alte Anbieter-Secrets erst nach erfolgreicher Umstellung entfernen.
