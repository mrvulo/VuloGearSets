# F050 — Speichern in Blizzards Ausrüstungsmanager übernimmt das Set

Status: test-in-game · Gewünscht 2026-10-11 · Hängt an: F039 (Spiegel zu Blizzard)

## Ziel
Wer auf Forever in Blizzards Ausrüstungsmanager ein Set anlegt oder „Speichern“ drückt, hat
dasselbe Set danach auch in VuloGearSets – ohne es dort ein zweites Mal speichern zu müssen.

## Abnahmekriterien
1. Neues Set in Blizzards Fenster („Neues Set“ → Name → OK): In der Set-Leiste erscheint ein
   Set gleichen Namens mit der getragenen Ausrüstung, ohne die Slots, die Blizzard beim
   Speichern ignoriert, und ohne Hemd und Wappenrock.
2. Das gewählte Symbol wird übernommen; Blizzards „?“ bedeutet automatisch.
3. „Speichern“ eines vorhandenen Blizzard-Sets aktualisiert das gleichnamige Set bei uns
   (Teile und Slots); ein dort neu gewähltes Symbol wird übernommen.
4. Das übernommene Set gilt als gespiegelt: Umbenennen, Löschen und Symbolwechsel in
   VuloGearSets ziehen Blizzards Kopie wie bisher mit.
5. Unsere eigenen Schreibvorgänge in Blizzards Manager lösen keine Übernahme aus – keine
   Schleife, kein doppelter Chat-Hinweis.
6. Mit ausgeschaltetem „Sets auch in Blizzards Ausrüstungsmanager führen“ passiert nichts.
7. Nur auf Forever; Classic Era und Anniversary unverändert.

## Randfälle
- `/reload`, Relog: Hook wird bei jedem Modulstart einmal gesetzt (`mod._hooked`).
- Im Kampf: Speichern ist nur Daten, kein geschützter Aufruf – erlaubt.
- Taint: `hooksecurefunc` auf `C_EquipmentSet`, Blizzards Aufruf bleibt sicher; kein Feld an
  Blizzards Frames geschrieben.
- Name bei uns schon vergeben, aber nicht gespiegelt: gleicher Name = dasselbe Set, wird
  aktualisiert und verknüpft (wie beim ausdrücklichen Speichern bei uns, I-02 bleibt gewahrt –
  nur Felder `slots`, `slotMask`, `iconOverride`).
- Blizzard lehnt das Anlegen ab (Name): bei uns ist das Set trotzdem gespeichert; Verknüpfung
  erst, wenn Blizzard es meldet.
- Andere Sprache: neue Texte keine (Meldung kommt aus dem bestehenden Speichern).
- Alte SavedVariables: keine neuen Felder.
- Blizzards Fenster leert die Slot-Ausnahmen beim Anlegen schon vor dem Aufruf: das neue Set
  enthält Hemd und Wappenrock. Der Abgleich vergleicht 4 und 19 deshalb nicht mehr, sonst würde
  er Blizzards Set still überschreiben (Review 2026-10-11).
- Blizzards Bestätigung kommt später als 2 s: wird über `_triedCreate` noch verknüpft.
- Name mit Leerzeichen am Rand: wird wie bei uns gekürzt.
- Speichern eines vorhandenen Sets: Slots aus `GetIgnoredSlots(setID)`, also genau das, was
  Blizzard gesichert hat.
- Fremde Addons, die `CreateEquipmentSet`/`SaveEquipmentSet` aufrufen, landen ebenfalls bei uns
  (der Hook ist global) – bewusst hingenommen.

## Nicht enthalten
- Umbenennen und Löschen in Blizzards Fenster werden nicht übernommen (bisheriges Verhalten:
  die Verknüpfung wird gelöst, unser Set bleibt).
- Schon vorhandene Blizzard-Sets, die nicht neu gespeichert werden, werden nicht importiert.

## Dateien
- `Modules/BlizzardSets.lua` (Hook, Merker gegen Schleifen)
- `Modules/GearSets/Sets.lua` (Export `GS.saveAs`)

## Spieltest
1. Charakterfenster → Blizzards Ausrüstungsmanager → „Neues Set“, Namen „Test“, Symbol wählen,
   OK: „Test“ erscheint in der Set-Leiste mit dem Symbol, Chat meldet das Speichern einmal.
2. Ein Teil wechseln, in Blizzards Fenster „Test“ markieren und „Speichern“: In der Leiste ist
   „Test“ wieder grün (vollständig angelegt) und zeigt das neue Teil.
3. „Test“ in der Set-Leiste umbenennen: Blizzards Fenster zeigt den neuen Namen.
