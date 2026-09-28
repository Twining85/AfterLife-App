# Interne Supportwebsite

Die Supportwebsite wird vom bestehenden API-Prozess unter `/support` ausgeliefert.
Sie ist in DEV und Produktion identisch; Sichtbarkeit und Detailgrad werden
serverseitig durch `APP_ENV` gesteuert.

Die Auslieferung ist standardmässig deaktiviert. Für die gewünschte Umgebung
muss `SUPPORT_SITE_ENABLED=true` gesetzt werden. In Produktion sollte `/support`
zusätzlich am Reverse Proxy auf ein VPN, feste Administrations-IP-Adressen oder
einen vorgeschalteten Identity-Provider begrenzt werden.

## Adminzugang einrichten

Ein Supportadmin ist ein bestehender, verifizierter App-Benutzer, dessen ID in
`admin_users` eingetragen ist. Die Zuordnung erfolgt einmalig über einen
kontrollierten Datenbankzugang:

```sql
INSERT INTO admin_users (user_id)
SELECT id FROM app_users WHERE email = 'admin@example.ch';
```

Zum Entziehen des Zugangs:

```sql
DELETE a FROM admin_users a
JOIN app_users u ON u.id = a.user_id
WHERE u.email = 'admin@example.ch';
```

Die Anmeldung erzeugt eine nicht erneuerbare Sitzung mit acht Stunden Laufzeit.
Jede Kontosuche wird in `audit_log` protokolliert.

## Umgebungen

- `APP_ENV=production`: nur technischer Status; keine Bereichspayloads und keine
  E-Mail-Adressen von Vertrauenspersonen.
- `APP_ENV=staging`: dieselben Einschränkungen wie Produktion.
- `APP_ENV=development`: ebenfalls nur Status, solange keine zusätzliche
  Freigabe gesetzt ist.
- `SUPPORT_ALLOW_DEV_PAYLOADS=true`: erlaubt ausschliesslich in `development`
  die bewusst anwählbare, automatisch redigierte DEV-Detailansicht.

Passwörter, Tokens, Schlüssel und Binärdaten werden auch in der DEV-Detailansicht
ausgeblendet.

## Noch nicht freigeschaltet

Die Website führt absichtlich keine Konto- oder Dossierlöschungen aus. Dafür ist
ein separater Ablauf mit Identitätsprüfung, Vorgangsnummer, erneuter Bestätigung
und wiederaufnehmbarer Object-Storage-Löschung erforderlich.
