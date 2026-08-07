# E-Mail-Versand einrichten

Der allgemeine Versand über Mailomat SMTP liegt in `api/_email-service.js`. Registrierung und
spätere Passwort-Zurücksetzungen verwenden diesen Transport mit eigenen
Vorlagen und eigenen Verifikationszwecken.

## Mailomat

Der SMTP-Benutzer `tschluessli-backend@send.tschluessli.ch` verbindet sich über
`smtp.mailomat.cloud` auf Port 587 mit STARTTLS. Das SMTP-Passwort darf nur als
geheime Vercel-Umgebungsvariable gespeichert werden.

## Vercel

Im Vercel-Projekt unter **Settings → Environment Variables** folgende Werte für
Development, Preview und Production hinterlegen:

- `MAILOMAT_SMTP_HOST` = `smtp.mailomat.cloud`
- `MAILOMAT_SMTP_PORT` = `587`
- `MAILOMAT_SMTP_USER` = `tschluessli-backend@send.tschluessli.ch`
- `MAILOMAT_SMTP_PASSWORD`
- `EMAIL_FROM` = `Tschlüssli <tschluessli-backend@send.tschluessli.ch>`
- `EMAIL_REPLY_TO` = `hallo@tschluessli.ch`
- `EMAIL_VERIFICATION_SECRET`, mindestens 32 zufällige Bytes
- `EMAIL_VERIFICATION_ALLOWED_RECIPIENT` = freigegebene Testadresse

Nach Änderungen an Umgebungsvariablen ist ein neues Deployment erforderlich.

## iOS-App aktivieren

In `EmailVerifizierungsService.swift` den Modus von `.test` auf `.backend`
umstellen und die HTTPS-Basis-URL des Vercel-Projekts eintragen. Erst danach
verschickt die App echte E-Mails.

Vor dem öffentlichen Betrieb muss auf `/api/email-verification/request`
serverseitiges Rate-Limiting nach IP-Adresse und normalisierter E-Mail-Adresse
ergänzt werden. Bis dahin beschränkt `EMAIL_VERIFICATION_ALLOWED_RECIPIENT`
den Versand auf genau eine Testadresse.
