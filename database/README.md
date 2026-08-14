# Tschlüssli-Datenbank

Die Migrationen sind in numerischer Reihenfolge gegen eine PostgreSQL-Datenbank auszuführen.
Für die API wird `DATABASE_URL` als verschlüsselte Umgebungsvariable benötigt. Die Verbindung
muss in der Cloud TLS verwenden. `001_initial.sql` legt Konten, Sitzungen, Dossiers und flexible,
versionierte Dossierbereiche an. Dokumentinhalte gehören ausdrücklich nicht in diese Tabellen.

Die Row-Level-Security erwartet innerhalb jeder Dossier-Transaktion `app.user_id`. Das Backend
setzt diesen Wert lokal in der Transaktion; direkte Abfragen ohne Benutzerkontext sehen keine
Dossierdaten.
