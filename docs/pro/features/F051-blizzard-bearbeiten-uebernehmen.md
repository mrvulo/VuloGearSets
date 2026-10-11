# F051 — Umbenennen und Symbolwechsel in Blizzards Bearbeiten-Fenster übernehmen

Status: test-in-game · Gewünscht 2026-10-11 · Hängt an: F039, F050

## Ziel
Wer auf Forever ein verknüpftes Set in Blizzards Ausrüstungsmanager über „Bearbeiten“
umbenennt oder ihm ein anderes Symbol gibt, sieht dieselbe Änderung in VuloGearSets.

## Abnahmekriterien
1. Umbenennen in Blizzards Bearbeiten-Fenster benennt das verknüpfte Set bei uns um –
   samt Taste, Spec- und Gestalt-Bindung, Makro und Auswahl in der Leiste (derselbe Weg wie
   Umbenennen bei uns).
2. Neues Symbol im Bearbeiten-Fenster wird übernommen; „?“ heißt automatisch.
3. Die Verknüpfung bleibt erhalten (kein „false“ mehr nach dem Umbenennen).
4. Gibt es bei uns schon ein Set mit dem neuen Namen, bleibt unser Set unverändert, die
   bekannte Meldung „Ein Set mit dem Namen … existiert bereits“ erscheint, und die Verknüpfung
   wird wie bisher gelöst.
5. Unsere eigenen Umbenennungen und Symbolwechsel bei Blizzard lösen nichts aus.
6. Nicht verknüpfte (fremde) Blizzard-Sets werden nicht angefasst.
7. Nur Forever; mit ausgeschaltetem Spiegel-Schalter passiert nichts.

## Randfälle
- Blizzard meldet den alten Namen nach dem Aufruf nicht mehr: Set-ID → Name und Symbol werden je
  Sitzung gemerkt (`_idInfo`), gefüllt bei jedem Abgleich und jeder Verknüpfung.
- `/reload`: Merker wird beim ersten Abgleich nach dem Login neu gefüllt (3 s).
- Taint: nur `hooksecurefunc`, alles im Hook per `pcall`.
- Keine neuen gespeicherten Felder, keine neuen Texte.
- Blizzards OK schickt immer ein Symbol mit (das gespeicherte): übernommen wird nur ein anderes als
  das gemerkte, sonst würde ein reines Umbenennen das automatische Symbol festschreiben.
- Blizzard vergibt Set-IDs neu: je Name höchstens ein Merker, Löschen und Lösen räumen ihn ab.
- Feuert `EQUIPMENT_SETS_CHANGED` schon während Blizzards Aufruf: die Verknüpfung wird nicht
  gelöst, solange die gemerkte Set-ID noch existiert; der Hook entscheidet direkt danach.
- Spiegel-Schalter aus: nichts übernehmen, aber die Verknüpfung lösen (wie vorher).
- „?“ gewählt: bei uns automatisch, und unser automatisches Symbol geht zu Blizzard zurück.

## Nicht enthalten
- Löschen in Blizzards Fenster löscht unser Set nicht (I-03: nichts still entfernen).

## Dateien
- `Modules/BlizzardSets.lua`, `Modules/GearSets/Sets.lua` (Export `GS.renameLoadout`)

## Spieltest
1. Verknüpftes Set „Test“ in Blizzards Fenster → Bearbeiten → Namen „Test2“, OK: Leiste zeigt
   „Test2“, eine gesetzte Taste funktioniert weiter.
2. Bearbeiten → anderes Symbol, OK: Leiste zeigt das neue Symbol.
3. „Test2“ bei uns umbenennen: Blizzards Fenster folgt, kein doppeltes Set.
