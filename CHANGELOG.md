# Changelog

## 1.0.0

Erste Fassung. Ausgekoppelt aus dem Ausrüstungsset-Modul von VuloClassicUI und als
eigenständiges Addon aufgebaut.

**Ausrüstungssets**

- Sets speichern, anlegen, überschreiben und löschen, wahlweise für die komplette
  Ausrüstung oder nur für Schmuckstücke, Waffen, Ringe oder Rüstung
- Seitenleiste am Charakterfenster mit eigenem Symbol je Set, Slot-weisem Ersetzen
  und Kontextmenü; per `/gearset unlock` frei verschiebbar
- Minimap-Button mit Set-Auswahl auf Links- und Einstellungen auf Rechtsklick
- Automatischer Wechsel bei Haltung und Gestalt sowie bei Dual-Spec
- Umrüsten wird im Kampf abgelehnt und nach Kampfende nachgeholt

**Slot-Auswahl**

- Beim Überfahren eines Ausrüstungsslots erscheinen die passenden Teile aus den
  Taschen direkt daneben; ein Klick legt sie an. Ohne passende Teile bleibt die
  Anzeige aus.
- Der eingestellte Klick öffnet zusätzlich das große Fenster mit allen Teilen,
  Zähler und verschiebbarer Titelleiste

**Gegenüber dem Modul in VuloClassicUI**

- Läuft eigenständig, ohne weitere Addons
- Eigenes Einstellungsfenster statt der Navigationsleiste
- Sets liegen pro Charakter; die kontoweite Sammlung älterer Versionen entfällt
- Bestehende Sets werden beim ersten Start je Charakter automatisch übernommen,
  ein eigener Import-Befehl ist nicht mehr nötig
- Kein Addon schaltet das andere ab; bei Doppelbetrieb gibt es einen Hinweis
- `/gearset unlock` ersetzt das UnlockMode-Modul, `/gearset config` öffnet die
  Einstellungen
- Die Slot-Auswahl reagiert zusätzlich auf das bloße Überfahren

**Bekannt**

- Der Anniversary-Client lädt keine Schriftdateien aus Addon-Ordnern. Das
  mitgelieferte Expressway wird deshalb derzeit nicht verwendet; stattdessen greift
  Arial Narrow aus dem Client. Details über `/vgsfont`.
