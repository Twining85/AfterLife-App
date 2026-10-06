# Datenschutz und Ende-zu-Ende-Verschlüsselung

Stand: 6. Oktober 2026. Dies ist eine technische Bestandsaufnahme und ein
Umsetzungsentwurf, kein Nachweis einer bereits erfolgten Produktionsumstellung.

## Bereits in diesem Arbeitsschritt geändert

- Die App schreibt eingehende Einladungstoken nicht mehr ins Log.
- SMTP benötigt einen explizit konfigurierten Host. Der bisherige implizite
  Fallback auf Mailomat ist entfernt. Explizite bestehende Konfigurationen bleiben
  unterstützt; das ist keine Migration des Mailanbieters zu Infomaniak.
- SMTP unterstützt Port 465 mit direktem TLS und Port 587 mit verpflichtendem
  STARTTLS. Zertifikatsprüfung und mindestens TLS 1.2 sind ausdrücklich gesetzt.
- PostgreSQL-TLS kann ausserhalb von Tests nicht über Umgebungsvariablen
  abgeschaltet werden. SSL-Parameter der Verbindungsadresse dürfen die explizite
  Zertifikatsprüfung nicht überschreiben. Eine konfigurierte CA wird übernommen.

Diese Änderungen müssen noch auf die tatsächlich betriebenen Umgebungen
ausgerollt werden. Fehlt dort der explizite SMTP-Host, schlägt der Mailversand
künftig fehl, statt stillschweigend einen Anbieter auszuwählen.

## Befunde aus dem Code

| Datenfluss | Aktueller Schutz | Verbleibende Arbeit |
| --- | --- | --- |
| Eigene Dossierbereiche | HTTPS; nur `zugaenge` ist vor dem Upload AES-256-GCM-verschlüsselt | Übrige Bereiche inklusive Anhänge verschlüsseln |
| Lokale Speicherung | SwiftData und iOS-Dateischutz; Schlüssel im Keychain | Backup-Verhalten, temporäre Dateien und Exporte prüfen |
| Freigabe von `zugaenge` | Dossierschlüssel wird mit einem aus dem Einladungstoken abgeleiteten Schlüssel verpackt | Backend verarbeitet denselben Token und das Schlüsselpaket: echte Trennung fehlt |
| Freigaberechte | Server liest `kontakte` und `dossier_einstellungen` | Berechtigungsmetadaten von verschlüsselten Inhalten trennen |
| Wünsche und Dokumentfreigaben | Server verändert Freigabefelder im Inhalt | Berechtigung und Dokumentauswahl auf verschlüsselte Freigabeobjekte umstellen |
| Object Storage | Grosse Payloads werden bei aktiviertem Treiber serverseitig AES-256-GCM-verschlüsselt | Künftig nur bereits clientseitig verschlüsselte Inhalte auslagern |
| Konto und Betrieb | E-Mail, IDs, Rollen, Zeiten, Geräte- und Sessiondaten serverseitig verfügbar | Datenminimierung; diese Metadaten nicht als E2E-Inhalte bezeichnen |

Relevante Stellen: `DossierBereichAdapter.swift`, `DossierBereichImport.swift`,
`CloudWeitereBereiche.swift`, `PushEinladungsService.swift`,
`EinladungsStatusSynchronisation.swift`, `api/_invitation-handler.js`,
`api/_storage.js`.

## Ziel für die Verschlüsselung

Die Umsetzung ist für DEV autorisiert. PROD wird dadurch nicht umgestellt.
Die tatsächliche DEV-Konfiguration und die Art der bestehenden Daten sind vor
einer Bestandsmigration zu klären. Die Supportanwendung soll weiterhin Inhalte
von berechtigten Testdossiers anzeigen können.

### Vereinbarte Umgebungen

Es bleiben zwei Backend-Umgebungen: DEV und PROD. Beta bezeichnet die
TestFlight-Phase auf der geschützten PROD-Umgebung, keine dritte Datenhaltung.
Echte Daten von Testern werden wie spätere produktive Daten behandelt. Vor
dieser Beta müssen die vorgesehene Verschlüsselung und die Migration abgenommen
sein; die noch offene E2E-Implementierung ist keine bereits erfüllte Zusage.

DEV dient technischen Tests mit erfundenen Daten, verkürzten Freigabefristen
und echten APNs-Benachrichtigungen. Die dokumentierten DEV-Werte sind 90 Sekunden
Karenzfrist und 30 Sekunden Reminder-Intervall. Beta/PROD verwenden sieben Tage
Karenzfrist und das dokumentierte Reminder-Intervall von 24 Stunden. In beiden
Umgebungen erlaubt nur Ja automatische Freigabe; Nein und fehlende Auswahl
lassen Anfragen offen und Reminder aktiv. Die APNs-Umgebung richtet sich nach
der Signierung des Builds; ein über TestFlight verteilter Build verwendet die
Produktions-APNs-Konfiguration auch dann, wenn er gezielt auf DEV zeigen sollte.

Die geplante lesbare Supportansicht für technische Testdossiers ist eine
DEV-Funktion. Beta/PROD erhalten dadurch keinen allgemeinen Supportzugriff auf
entschlüsselte Dossierinhalte.

### Supportansicht für verschlüsselte Testdaten

Die Supportansicht soll als berechtigter Client arbeiten: Testdossier-Schlüssel
werden lokal im Browser verwendet, um vom Server gelieferte verschlüsselte
Payloads zu entschlüsseln. Schlüssel und Wiederherstellungswörter werden dabei
nicht an die Support-API gesendet. Der Server erhält keinen Generalschlüssel.
Ohne lokale Freigabe bleiben nur Metadaten und Verschlüsselungsstatus sichtbar.

Das ist noch nicht implementiert. Die bestehende Supportansicht redigiert
verschlüsselte `daten` und erkennt bislang nur `zugaenge` als verschlüsselten
Bereich. Beides muss für die neue Payload-Struktur angepasst und getestet werden.
Der Umgang mit Klartext im Browser sowie die Freigabe ausschliesslich geeigneter
Testdossiers gehören zur Umsetzung. Der bisherige serverseitige DEV-Payload-
Schalter allein ist keine Entschlüsselungsberechtigung.

### Transport und aktive Datenbank

Infomaniak Mail unterstützt `mail.infomaniak.com` auf Port 465 mit direktem TLS
oder Port 587 mit STARTTLS. Unsere SMTP-Konfiguration unterstützt beide Varianten
mit Zertifikatsprüfung. Ein explizit konfiguriertes Infomaniak-Mailkonto und ein
Versandtest aus der tatsächlich betriebenen Umgebung bleiben erforderlich.
Quelle: https://www.infomaniak.com/en/support/faq/468/understanding-mail-server-ports-and-protocols

Die DEV-Dokumentation `production-parity-dev.md` belegt für den 28. September
2026 MySQL. PostgreSQL ist ein zusätzlicher, älterer Laufzeitpfad. Für MySQL ist
die bereitgestellte CA bereits in Compose vorgesehen. Für PostgreSQL setzt der
Code Zertifikatsprüfung ausdrücklich und übernimmt eine konfigurierte CA über
`DATABASE_SSL_CA`; SSL-Parameter in der URL können diese Einstellung nicht
aufheben. Der tatsächliche Verbindungsnachweis auf DEV ist gesondert zu führen.

Das belastbare Ziel lautet: **Alle synchronisierten Dossierinhalte einschliesslich
Anhängen werden vor dem Upload verschlüsselt. Das Backend erhält keine Schlüssel,
mit denen es diese Inhalte entschlüsseln kann.** Konto- und Betriebsmetadaten
bleiben gesondert zu beschreiben.

1. Eine neue versionierte Payload-Struktur einführen. AES-256-GCM authentifiziert
   neben dem Inhalt auch Dossier-ID, Bereich, Schema- und Schlüsselversion als
   zusätzliche Daten. Damit lassen sich Pakete nicht unbemerkt zwischen Bereichen
   oder Dossiers austauschen.
2. Pro Dossier getrennte Schlüssel für Bereiche und separat freigebbare Dokumente
   verwalten. Ein gemeinsamer Master-Schlüssel darf nicht an Vertrauenspersonen
   gehen: Er würde auch nicht freigegebene Bereiche entschlüsselbar machen.
3. Geräte und berechtigte Empfänger erhalten ausschliesslich verpackte Schlüssel
   für ihre Freigaben. Private Empfängerschlüssel bleiben im Keychain. Einladungs-
   und Anmeldungstoken dürfen keine Entschlüsselungsschlüssel sein. Empfänger-
   schlüssel brauchen eine verifizierte Bindung an den Empfänger; eine ungeprüfte
   öffentliche Schlüsselantwort des Servers genügt dafür nicht.
4. Rechteverwaltung erhält getrennte, möglichst kleine Metadaten. Der Server
   entscheidet über Zustellung, liest oder verändert aber keine Dossierinhalte.
   Insbesondere muss `releaseAllWishDocuments` ersetzt werden.
5. Eigentümer-Recovery und Gerätewechsel auf das ganze Dossier ausweiten.
   Fremddossier-Schlüssel dürfen weiterhin nicht den eigenen Keychain-Schlüssel
   oder das eigene Recovery-Paket überschreiben.
6. Widerruf verhindert weitere Zustellung. Bereits gelesene oder exportierte
   Inhalte lassen sich nicht zurückholen. Für zukünftige Änderungen Schlüssel
   rotieren und nur an weiterhin berechtigte Geräte verteilen.

### Automatische Freigabe

Die manuelle Freigabe bleibt erhalten. Automatische Freigabe setzt ein
ausdrückliches Ja pro Vertrauensperson voraus; ohne Auswahl gilt Nein.
Die Zustimmung wird mit den Kontakten synchronisiert und auch für offene
Anfragen berücksichtigt. Details: `automatic-release-consent.md`.
Automatische Freigabe bei
offline befindlichem Eigentümer benötigt schon vorher vorbereitete, für den
Empfänger verschlüsselte Pakete. Der Server kann deren Zustellung nach Ablauf
der Frist steuern, ohne selbst entschlüsseln zu können. Das ist keine
kryptografische Garantie gegen eine vorzeitige Zustellung durch den Server.
Diese Grenze muss in der Produktbeschreibung klar bleiben.

### Migration und Abnahme

- Neue App und API unterstützen zunächst alte und neue Versionen beim Lesen.
  Für migrierte Dossiers werden alte Klartext-Uploads abgelehnt, damit ältere
  Clients die Verschlüsselung nicht wieder aufheben.
- Der Eigentümer entschlüsselt bzw. liest den Altbestand lokal, verschlüsselt ihn
  neu und lädt ihn mit Revisionsprüfung hoch. Recovery und Freigaben werden vor
  dem endgültigen Umschalten überprüft. Ein fehlerhafter Schritt darf weder
  lokalen Inhalt löschen noch den alten Bestand vorzeitig entfernen.
- Bestehende Sync-Konflikte und ausstehende Outbox-Aufträge berücksichtigen.
  Alte Einladungen und freigegebene Dossiers benötigen eine eigene Migration.
- Nicht nur aktuelle `dossier_sections`, sondern Änderungsverlauf,
  Idempotenzantworten, alte Storage-Objekte, Supportzugriffe und Logs prüfen.
  Alte Klartextbestände erst nach verifiziertem Umstieg gezielt bereinigen.
- Backups können weiterhin Klartext enthalten. Aufbewahrungsfristen und
  Wiederherstellungsverfahren dokumentieren; ein Restore darf die Migration
  nicht unbemerkt rückgängig machen.
- Tests: Wiederherstellung auf neuem Gerät; falscher Schlüssel; manipuliertes
  Paket; Austausch zwischen Bereichen; Teilfreigabe; automatische Freigabe;
  fremdes Dossier; Widerruf und Rotation; gemischte Alt-/Neuversionen;
  unterbrochene Migration und Backup-Restore.

## Schweizer Datenstandort: Nachweis noch offen

Der Repository-Stand beweist keine aktive Hostingregion. Providerwahl und
Storage-Regionbezeichnungen allein beweisen keinen Schweizer Speicherstandort.
Insbesondere ist `OBJECT_STORAGE_REGION=us-east-1` bei S3-kompatiblen Diensten
nicht ohne Weiteres als tatsächlicher physischer Standort interpretierbar.

| Dienst | Hinweis im Repository | Benötigter Nachweis |
| --- | --- | --- |
| API und Worker | Infomaniak-Compose-/Deployment-Anleitung; auch Vercel-Dateien vorhanden | Aktive DEV-/PROD-Hosts, Region, Routing, abgeschaltete Altdeployments |
| Datenbank | Infomaniak-MySQL-Konfiguration; PostgreSQL-/Neon-Pfad bleibt vorhanden | Aktiver Anbieter und Region pro Umgebung, Replikate, Restbestände |
| Dateispeicher | Infomaniak-Treiber; Beispiel setzt `STORAGE_DRIVER=disabled` | Aktiver Endpunkt, Container, physische Region, Versionierung |
| E-Mail | Mailomat-Konfigurationsvariablen und ältere Vercel-Anleitung | Tatsächlicher SMTP-Anbieter, Verarbeitung, Logs, Aufbewahrung; Migration falls nötig |
| Apple Push | Apple APNs; Nachrichten enthalten teilweise Namen und E-Mail | Payloads minimieren; Apple als weiteren Verarbeiter berücksichtigen |
| Backups und Betrieb | Backup-/Restore-Nachweise werden in Deployment-Dokumenten verlangt | Orte, Verschlüsselung, Zugang, Fristen, Restore-Test, externe Logs/Monitoring |
| Geräte und Exporte | iOS-Gerät, Keychain, PDF-Export | iCloud-/Gerätebackup-Regeln, temporäre Dateien, vom Nutzer gewählte Exportziele |

E-Mails an Empfänger bei ausländischen Anbietern, Apple Push und vom Nutzer
exportierte Dateien lassen sich nicht mit einem pauschalen Versprechen
«Alle Daten bleiben ausschliesslich in der Schweiz» zusammenfassen. Die spätere
Aussage soll ihren Geltungsbereich ausdrücklich nennen, beispielsweise die
serverseitige Speicherung der Dossierinhalte bei Infomaniak.

## Noch benötigte Informationen

- Welche Dienste laufen tatsächlich produktiv für API, Datenbank, Dateispeicher,
  E-Mail, Backups und Monitoring, und in welchen Regionen?

Keine Produktionsänderung, Bestandslöschung oder vollständige E2E-Migration wurde
in diesem Arbeitsschritt durchgeführt. Bis zu deren Abnahme bleiben die bisherigen
Grenzen der Nutzerkommunikation bestehen.

## Fortschritt am 6. Oktober 2026

Der Eigentümer hat bestätigt: Bestehende DEV-Dossiers enthalten ausschliesslich
erfundene Testdaten. SMTP auf DEV ist mittlerweile nachgewiesen: Infomaniak,
Port 587 mit STARTTLS, Anmeldung und Testzustellung erfolgreich; iCloud bestätigt
SPF, DKIM und DMARC jeweils mit `pass`. DMARC-Policy ist `reject`.

Die erste V2-Grundlage ist lokal implementiert: authentifizierte Payloads,
getrennte Ressourcen-Schlüssel, kontogebundene Keychain-Ablage, lokales
Recovery-Paket und selektive Freigabepakete mit unabhängigem Geheimnis.
WebCrypto-Entschlüsselung und Support-Redaktion sind vorbereitet. Protokoll und
noch fehlende Integration stehen in `e2e-v2-protocol.md`.

Die Komponenten sind noch nicht im normalen Sync aktiv. Insbesondere sind
Metadaten-Trennung, QR-/Link-Lifecycle, Dokumentaufteilung, Freigabemigration,
Cloud-Recovery und Support-UI weiterhin umzusetzen. Kein bestehendes Dossier
wurde migriert oder gelöscht und kein E2E-Update auf DEV/PROD deployt.

Der zweite lokale Schritt verbindet revisionstreue Rechte-/Zustimmungsmetadaten
mit dem Sync und explizitem V2-Export/-Import. Neue SQL-Migrationen halten die
Verschlüsselungsstufe auch nach Löschung und blockieren Klartext-Downgrades.
125 Backendtests und zehn iOS-Tests bestehen. Aktivierung und Live-Migration
bleiben ausstehend; die neue Freigabe benötigt weiterhin ein getrenntes Geheimnis.
