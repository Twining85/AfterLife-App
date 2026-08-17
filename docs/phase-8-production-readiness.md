# Phase 8: Recovery, Konfliktaufloesung und Produktionsabnahme

Stand: 17. August 2026  
Status: App-Funktionen implementiert; externe Produktionsabnahme ausstehend

## Wiederherstellung des Dossier-Schluessels

Die App erzeugt auf ausdruecklichen Wunsch zwoelf kryptografisch zufaellige
deutsche Codewoerter aus einer stabilen Liste von 2'048 eindeutigen Woertern. Das
entspricht 132 Bit Zufallsentropie. Der Code ist ein Tschluessli-eigenes Format und
keine BIP-39-Kryptowallet-Phrase.

Aus dem normalisierten Code wird mit einer versionsgebundenen Domaenentrennung und
SHA-256 ein AES-Schluessel abgeleitet. Dieser verschluesselt den zufaelligen
256-Bit-Dossier-Schluessel mit AES-256-GCM. Nur das verschluesselte Recovery-Paket
wird zusammen mit dem bereits clientseitig verschluesselten Bereich `zugaenge`
synchronisiert. Weder Code noch Klartextschluessel verlassen das Geraet.

In der App befindet sich der Ablauf unter **Mein Profil -> Zugangsdaten ->
Dossier-Schluessel sichern oder wiederherstellen**:

1. Code erzeugen und die zwoelf Woerter abschreiben.
2. Wort 3, 7 und 11 zur Kontrolle bestaetigen.
3. Optional ein PDF ueber den iOS-Teilen-Dialog sicher ablegen.
4. Auf einem neuen Geraet die zwoelf Woerter eingeben.

Das PDF erhaelt iOS-Dateischutz, wird vom Backup ausgeschlossen und nach dem
Schliessen des Teilen-Dialogs aus dem temporaeren App-Verzeichnis entfernt. Eine
vom Benutzer gewaehlte externe Ablage liegt anschliessend ausserhalb der Kontrolle
der App. Ein neu erzeugter Code ersetzt das Recovery-Paket und macht ein frueheres
PDF ungueltig.

## Konfliktaufloesung

Persistente Sync-Konflikte werden im Profil sichtbar angezeigt. Die App verlangt
eine bewusste Entscheidung:

- **Cloud-Version uebernehmen** importiert die gespeicherte Serverrevision und
  verwirft den dazu kollidierenden lokalen Auftrag.
- **Lokale Version behalten** setzt die erwartete Revision auf den Cloud-Stand und
  stellt den lokalen Bereich erneut kontrolliert zum Upload bereit.

Es erfolgt weiterhin kein stilles Last-Write-Wins. Kann ein Zugangs-Payload mangels
Schluessel nicht importiert werden, bleibt er als Konflikt erhalten. Nach korrekter
Recovery wird er erneut verarbeitet.

## Anbieterneutralitaet

Das Recovery-Paket ist Teil des bestehenden versionierten JSON-Payloads. App und
Kryptografie kennen weder Neon noch Infomaniak. Der Ablauf funktioniert daher mit
beiden Umgebungen, sofern dieselbe Phase-6-Migration und API-Version ausgerollt sind.

## Noch erforderliche externe Abnahme

- Migration und Vertragstests gegen eine isolierte Neon-Testdatenbank
- End-to-End-Test mit zwei getrennten App-Installationen/Geraeten
- Migration und identische Vertragstests gegen Infomaniak Staging
- Backup und dokumentierter Restore-Test
- Monitoring-, Datenschutz- und Release-Freigabe

Diese Punkte benoetigen die jeweiligen laufenden Cloudumgebungen und werden nicht
durch einen lokalen Build als bestanden betrachtet.

