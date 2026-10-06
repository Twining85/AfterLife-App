# Automatische Freigabe pro Vertrauensperson

Stand: 6. Oktober 2026. Implementiert im Arbeitsbaum; noch nicht deployt.

## Verhalten

- Die Auswahl wird beim Erfassen und später beim Verwalten der Vertrauensperson
  angezeigt. Ohne Auswahl gilt Nein; eine Einladung bleibt möglich.
- Nur ein ausdrücklich gewähltes Ja erlaubt automatische Freigabe.
- In Produktion beträgt die Karenzfrist sieben Tage. Sie beginnt mit der
  Vollzugriffsanfrage. DEV und Staging behalten die konfigurierte Testfrist.
- Bei Nein bleibt die Anfrage unbeantwortet. Die bereits freigegebenen Bereiche
  bleiben zugänglich. Reminder laufen in beiden Fällen bis zur Entscheidung oder
  zum Widerruf weiter.
- Manuelles Bestätigen und Ablehnen bleiben jederzeit möglich.
- Ein erneut gesendeter Request verlängert eine bereits laufende Frist nicht.
- Eine während einer offenen Anfrage synchronisierte Änderung auf Nein entfernt
  die Frist, ohne die Anfrage abzulehnen oder vorhandene Zugriffe zu verändern.
- Ein Wechsel auf Ja während einer offenen Anfrage beginnt eine neue Karenzfrist
  beim Speichern auf dem Server. Wiederholte Synchronisation desselben Ja-Werts
  setzt die Frist nicht zurück.
- Eine bereits abgeschlossene Vollfreigabe wird durch Änderungen dieser Option
  nicht rückgängig gemacht. Dafür gibt es die Verwaltung der Zugriffsrechte bzw.
  den Widerruf.

## Speicherung und Synchronisation

`VertrauenspersonModell.automatischeVollfreigabeErlaubt` ist optional, damit alte
lokale Modelle und Cloud-Payloads ohne Feld gelesen werden können. nil wird
überall wie false behandelt.

Die Option ist Teil des Kontakte-Payloads. Beim erfolgreichen Upload aktualisiert
die API die zugehörigen Einladungen innerhalb derselben Transaktion. Der Server
speichert `automatic_release_allowed` getrennt von `access_release_at`. Die
automatische Freigabe verlangt beide Werte: ausdrückliche Erlaubnis und fällige
Frist. Fehlende oder mehrdeutige Kontaktzuordnungen ergeben keine Erlaubnis.

Anfrage und Freigabe lesen den gespeicherten Wert serverseitig; die anfragende
Person kann die Auswahl nicht überschreiben. Zeilensperren serialisieren eine
gleichzeitig eintreffende Auswahländerung und automatische Freigabe.

Die App zeigt den Sync-Status der Änderung und wartet beim Erstellen einer
Einladung auf den Kontakte-Upload. Bei Fehlern bleibt der Auftrag in der
dauerhaften Outbox. Solange eine Änderung offline oder wegen eines Konflikts
nicht synchronisiert ist, gilt die bisher auf dem Server gespeicherte Auswahl.

## Deployment und Bestandsdaten

Vor dem Start der neuen API und des Workers die passende Migration ausführen:

- PostgreSQL: `011_automatic_release_consent.sql`
- MySQL: `004_automatic_release_consent.sql`

Bestehende Einladungen erhalten false. Laufende Fristen offener Anfragen werden
entfernt; bereits angenommene Zugriffe und vorhandene Teilfreigaben bleiben
erhalten. Bereits erteilte explizite Ja-Auswahlen neuer Apps werden nach dem
Upgrade über Registrierung oder Kontakte-Sync gespeichert.

API-Readiness und Worker verlangen das neue Schema. Rollout: Migration, neue
API und neuer Worker, danach neue App. Alte Worker dürfen nicht parallel
weiterlaufen: Sie kennen die Zustimmungsbedingung nicht.

## Verifikation

Backend-Tests prüfen ausdrückliche Zustimmung, fehlende Werte, beide
Datenbankpfade, Reminder ohne Frist, Friständerungen, Registrierung, erneute
Anfragen und Migration/Readiness. iOS-Tests prüfen den Kontakte-Roundtrip mit
Ja, Nein und fehlender Auswahl. Ein Test gegen die tatsächlich betriebene
DEV-Datenbank und Push-Zustellung ist nach dem Deployment erforderlich.
