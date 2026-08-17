# Kontopasswort: Aendern und Zuruecksetzen

Stand: 17. August 2026

## Passwort aendern

Angemeldete E-Mail-Konten koennen das Passwort im Profil aendern. Die API verlangt
die aktive Bearer-Sitzung, prueft das bisherige Passwort mit `scrypt` und speichert
das neue Passwort ausschliesslich als neuen Hash mit neuem zufaelligem Salt. Der
Dossier-Recovery-Code wird nicht uebertragen und nicht veraendert.

## Passwort vergessen

Auf der E-Mail-Loginmaske kann ein sechsstelliger Code angefordert werden. Die API
antwortet fuer bekannte und unbekannte Adressen gleich, um keine Konten offenzulegen.
Ein vorhandenes Konto erhaelt den Code per E-Mail.

Der Reset-Code:

- ist an Zweck und E-Mail-Adresse gebunden,
- ist zehn Minuten gueltig,
- erlaubt maximal fuenf Fehlversuche,
- wird nach erfolgreicher Verwendung als verbraucht markiert,
- kann kein zweites Mal verwendet werden.

Nach erfolgreichem Reset werden alle bisherigen Sitzungen widerrufen. Das neue
Passwort wird nur als `scrypt`-Hash mit neuem Salt gespeichert. Eine neue Anmeldung
ist erforderlich.

## Deployment

Vor dem Test in Neon muss Migration `003_password_reset.sql` angewendet und danach
das Backend mit den neuen Konto-Endpunkten bereitgestellt werden. Fuer Infomaniak
wird dieselbe Migration und derselbe API-Code verwendet.
