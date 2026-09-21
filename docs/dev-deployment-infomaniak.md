# Erstmaliger DEV-Deploy auf `tschluessli-dev-api`

Stand: 15. September 2026

Diese Anleitung migriert nur die leere DEV-Datenbank `tschluessli_dev`. Sie
veraendert weder PROD noch den bisherigen Vercel/PostgreSQL-Pfad. Die iOS-App wird
noch nicht auf den neuen Server umgeschaltet.

## 1. Lokal pruefen

Im Projektverzeichnis:

```sh
cd /Users/reneengeler/AfterLife
npm ci
npm test
node --check server.js
node --check worker.js
```

Falls Docker lokal vorhanden ist:

```sh
TSCHLUESSLI_ENV_FILE=.env.example \
TSCHLUESSLI_MYSQL_CA_FILE=/tmp/mysql-ca-placeholder \
docker compose -f compose.yml config --quiet
docker build -t tschluessli-api:dev .
```

## 2. Nur Backend-Dateien uebertragen

`SERVER_IP` durch die oeffentliche Serveradresse ersetzen. Der vorhandene
SSH-Zugang wird verwendet; kein privater Schluessel wird in das Projekt kopiert.

```sh
ssh ubuntu@SERVER_IP 'sudo install -d -o ubuntu -g ubuntu -m 0750 /opt/tschluessli'
rsync -av \
  Dockerfile compose.yml package.json package-lock.json server.js worker.js \
  api database \
  ubuntu@SERVER_IP:/opt/tschluessli/
```

Nicht mehr benoetigte Dateien werden bei diesem ersten Deployment bewusst nicht
automatisch geloescht.

## 3. Server-Konfiguration vorbereiten

Auf dem Server anmelden:

```sh
ssh ubuntu@SERVER_IP
cd /opt/tschluessli
sudo test -r /etc/tschluessli/certs/mysql-ca.cert
sudo install -o root -g root -m 0600 /dev/null /etc/tschluessli/backend.env
sudoedit /etc/tschluessli/backend.env
```

In `backend.env` werden die realen Werte ausschliesslich auf dem Server
eingetragen. Das folgende Muster nicht unveraendert verwenden:

```dotenv
DATABASE_ENGINE=mysql
DATABASE_POOL_MAX=5
MYSQL_URL=mysql://tschluessli_api_dev:URL_ENCODED_PASSWORD@MYSQL_HOST:24856/tschluessli_dev
MYSQL_DIRECT_URL=mysql://tschluessli_api_dev:URL_ENCODED_PASSWORD@MYSQL_HOST:24856/tschluessli_dev
MYSQL_EXPECTED_DATABASE=tschluessli_dev
MYSQL_SSL_MODE=verify_identity

EMAIL_VERIFICATION_SECRET=RANDOM_SECRET
MAILOMAT_SMTP_HOST=SMTP_HOST
MAILOMAT_SMTP_PORT=587
MAILOMAT_SMTP_USER=SMTP_USER
MAILOMAT_SMTP_PASSWORD=SMTP_PASSWORD
EMAIL_FROM=Tschluessli <SENDER_ADDRESS>
EMAIL_REPLY_TO=REPLY_ADDRESS
EMAIL_VERIFICATION_ALLOWED_RECIPIENTS=DEV_TEST_ADDRESS_1,DEV_TEST_ADDRESS_2
EMAIL_VERIFICATION_ALLOW_UNLISTED=false
EMAIL_VERIFICATION_BLOCKED_DOMAINS=gmail.com,gmx.net,outlook.com

APNS_BUNDLE_ID=IOS_BUNDLE_IDENTIFIER
APNS_TEAM_ID=APPLE_DEVELOPER_TEAM_ID
APNS_SANDBOX_KEY_ID=APPLE_APNS_KEY_ID
APNS_SANDBOX_PRIVATE_KEY=APPLE_P8_INHALT_MIT_ESCAPED_ZEILENUMBRUECHEN

TRUST_ACCESS_GRACE_SECONDS=60
CRON_SECRET=RANDOM_SECRET
STORAGE_DRIVER=disabled
OBJECT_STORAGE_CONTAINER=tschluessli-dev-files
OBJECT_STORAGE_EXPECTED_CONTAINER=tschluessli-dev-files
```

Das DB-Passwort muss URL-kodiert sein, falls es Zeichen wie `@`, `:`, `/`, `#`
oder `%` enthaelt. `MYSQL_SSL_CA_PATH` wird durch Compose auf den internen,
read-only gemounteten Pfad gesetzt und gehoert nicht in die Datei.

Fuer ein physisches iPhone im Debug-Build werden die Sandbox-APNs-Werte
benoetigt. Der Inhalt der Apple-`.p8`-Datei wird direkt in `backend.env` mit
`\\n` statt echten Zeilenumbruechen gespeichert. Die Datei, Key-ID und Team-ID
duerfen weder ins Repository noch in Chat-Nachrichten kopiert werden. PROD nutzt
separate `APNS_PRODUCTION_KEY_ID`- und `APNS_PRODUCTION_PRIVATE_KEY`-Secrets;
derselbe Docker-Stand bleibt dabei unveraendert.

Anschliessend:

```sh
sudo chown root:root /etc/tschluessli/backend.env /etc/tschluessli/certs/mysql-ca.cert
sudo chmod 0600 /etc/tschluessli/backend.env
sudo chmod 0644 /etc/tschluessli/certs/mysql-ca.cert
sudo docker compose -f compose.yml config --quiet
```

`config --quiet` verwenden, damit auf dem Terminal keine aufgeloesten Secrets
ausgegeben werden.

## 4. Image bauen

```sh
cd /opt/tschluessli
export TSCHLUESSLI_IMAGE_REF=tschluessli-api:VERSION_TAG
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml build --pull api
```

Das Image enthaelt nur Node-Runtime, produktive Abhaengigkeiten, API-Code und
Migrationen. Xcode-Projekt, `.git`, lokale Builds, Bilder und lokale
`node_modules` werden nicht aufgenommen.

## 5. Initialmigration kontrolliert ausfuehren

Vor diesem Schritt nochmals sicherstellen, dass in beiden MySQL-URLs
`tschluessli_dev` steht. Danach:

```sh
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml --profile tools run --rm migrate
```

Der Runner prueft:

- erwarteten Datenbanknamen,
- TLS mit der gemounteten CA,
- exklusive MySQL-Migrationssperre,
- SHA-256-Pruefsummen bereits angewendeter Migrationen,
- Vollstaendigkeit des Initialschemas.

Ein erfolgreicher Wiederholungslauf fuehrt keine Migration erneut aus:

```sh
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml --profile tools run --rm migrate
```

## 6. API und Karenzfrist-Worker starten

```sh
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml up -d api auto-release-worker
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml ps
```

Der API-Port ist nur als `127.0.0.1:3000` auf dem Server veroeffentlicht. Er ist
nicht ueber die oeffentliche Netzwerkschnittstelle erreichbar und oeffnet somit
keinen zusaetzlichen Port an UFW vorbei. Der Worker besitzt gar keinen Port.

## 7. Healthchecks

Auf dem Server:

```sh
curl --fail --silent http://127.0.0.1:3000/health/live
curl --fail --silent http://127.0.0.1:3000/health/ready
```

Erwartete Antworten:

```json
{"status":"ok"}
```

```json
{"status":"ok","database":{"engine":"mysql","connected":true,"expectedDatabase":true,"schemaReady":true}}
```

Der echte Datenbankname, Host, Benutzer und alle Secrets werden bewusst nicht
ausgegeben. Bei falscher Datenbank, fehlender Migration oder DB-/TLS-Fehler liefert
`ready` HTTP 503.

Logs ohne Payload-Ausgabe kontrollieren:

```sh
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml logs --tail=100 api auto-release-worker
```

## 8. Reverse Proxy und HTTPS

Vor der Umschaltung der iOS-DEV-Konfiguration muss ein Reverse Proxy auf dem Host
TLS fuer die DEV-Domain terminieren und intern an `127.0.0.1:3000` weiterleiten.
Nur Ports 80/443 bleiben oeffentlich. Port 3000 darf weder in der Security Group
noch in UFW freigegeben werden.

Erst nach gueltigem Zertifikat von ausserhalb pruefen:

```sh
curl --fail --silent https://DEV_API_DOMAIN/health/ready
```

## 9. Aktualisierung und Rueckfall

Fuer ein spaeteres Update Dateien erneut uebertragen und dann:

```sh
cd /opt/tschluessli
export TSCHLUESSLI_IMAGE_REF=REGISTRY/TSCHLUESSLI-API@sha256:TESTED_IMAGE_DIGEST
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml pull api auto-release-worker
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml --profile tools run --rm migrate
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml up -d api auto-release-worker
```

Nur den neuen DEV-Pfad stoppen:

```sh
sudo --preserve-env=TSCHLUESSLI_IMAGE_REF docker compose -f compose.yml down
```

Der bestehende PostgreSQL/Vercel-Pfad wird dadurch nicht beruehrt. Datenbank oder
Object Storage werden beim Stoppen nicht geloescht.
