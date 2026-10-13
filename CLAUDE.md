# VuloGearSets

Ausrüstungs-Set-Manager für **TBC Classic Anniversary** (`VuloGearSets.toc`, Interface 20506),
**World of Warcraft: Forever** (gleiche TOC, Interface 16001, erkannt als `ns.isForever`) und
**Classic Era** (`VuloGearSets_Vanilla.toc`). Der Repo-Wurzelordner ist der Addon-Ordner.
Veröffentlicht über GitHub, CurseForge (1629333) und Wago (b6mv8yKP).
Der Nutzer schreibt Deutsch; antworte auf Deutsch, kurz.

## Projektgedächtnis – vor jeder Änderung lesen

- [docs/pro/invariants.md](docs/pro/invariants.md) – was nicht kaputtgehen darf
- [docs/pro/regressions.md](docs/pro/regressions.md) – schon behobene Fehler, nach Bereich
- [docs/pro/features.md](docs/pro/features.md) – Features, Status, offene Ideen
- [docs/pro/decisions.md](docs/pro/decisions.md) – was der Nutzer wann entschieden hat
- [docs/pro/savedvariables.md](docs/pro/savedvariables.md) – gespeicherte Daten
- [docs/pro/smoke-test.md](docs/pro/smoke-test.md) – Kurztest im Spiel

Gedächtnis im selben Commit wie der Code nachführen. „Was ist offen?“ beantwortet `features.md`.
Ein Fix ist erst `done`, wenn der Nutzer ihn im Spiel bestätigt hat (bis dahin `test-in-game`).

## Vor jedem Commit

`python3 tools/check.py` muss `OK` melden. Er prüft TOC ↔ Dateien, Versionen, Lua-Syntax und
Globals über einen echten Parser (`tools/lua_check.cjs` mit luaparse aus
`~/addons/VuloClassicUI/tools/node_modules`, Node unter `~/.local/node/bin`), SavedVariables-Namen,
Locale-Keys in allen Sprachen samt Platzhaltern, Media-Pfade, die Form von `CHANGELOG.md`
(`## x.y.z — JJJJ-MM-TT`, Punkte mit `New:`/`Improved:`/`Changed:`/`Fixed:`) und die Code-Regeln der Invarianten.
Grün ist kein Spieltest: Nichttriviales bekommt ein Review, dann testet der Nutzer.

Commits thematisch auf `main`, deutsche Botschaft, ASCII-transliteriert (ue/ae/oe), ohne
`Co-Authored-By`. Speichern = Deploy (Syncthing → Gaming-PC). Der Feature-Commit steht **vor** der
Fertigmeldung (die mit `/reload` und 1–3 Dingen zum Prüfen); der Release-Commit trägt nur Changelog
und Version. Release nur auf „release“: englischer Block oben in `CHANGELOG.md`,
`python3 tools/release.py <x.y.z>` (zeigt die Release-Notiz, die `tools/release_notes.py` im Workflow erzeugt), Commit `v<x.y.z>: …`, Push, annotierter Tag, Tag pushen,
Workflow `release.yml` abwarten.

## Aufbau (Ladereihenfolge = TOC)

Spätere Dateien dürfen frühere benutzen, nie umgekehrt – außer zur Laufzeit über `GS.*`/`ns.*`.

| Pfad | Aufgabe |
|---|---|
| `Core/Namespace.lua`, `Compat.lua` | `ns`, Version, Farben, Client-Erkennung, API-Shims |
| `Core/Locale.lua`, `Locales/*.lua` | `ns.L`, Keys = englischer Text; deDE frFR esES ruRU zhCN |
| `Core/Database.lua`, `Modules.lua` | SavedVariables, Modul-Defaults, Modulregistry |
| `Core/Events.lua`, `Slash.lua` | Ereignisverteiler, `/vgsfont`, `/rl` |
| `Core/Skin.lua` | Stile classic/modern/forever, Fensterarten (I-08) |
| `Core/PopupMenu.lua`, `Mover.lua` | gemeinsames Menü (I-07), Bearbeiten-Modus |
| `UI/Widgets.lua` | `UI.Font` (I-05), Knöpfe (I-06), Schalter, Regler, Auswahllisten, Schatten |
| `UI/OptionsFrame.lua` | Einstellungsfenster (`/vgs`) |
| `Modules/GearSets/` | Kernmodul: `Shared` → `Sets` (Speichern, Anlegen, Zurück, Bank, Slash) → `AutoSwitch` → `Minimap` → `Pickers` (Slot- und Symbolauswahl) → `Sidebar` → `Lifecycle` (Migrationen, Events) → `Options` |
| `Modules/SlotPicker.lua`, `SocketBar.lua` | Flyout am Slot, Sockel-Leiste |
| `Modules/ItemTooltip.lua` | „Sets:“ im Tooltip (I-10) |
| `Modules/SetKeybinds.lua`, `SetMacros.lua` | Tasten und Makros je Set |
| `Modules/BlizzardSets.lua` | nur Forever: Spiegel in Blizzards Ausrüstungsmanager |
| `Core/Coexistence.lua`, `Init.lua` | Übernahme aus VuloClassicUI (I-17), Start |
| `Media/` | Expressway, vier Symbole (I-13) |
| `docs/`, `tools/`, `.github/`, `CLAUDE.md` | nie ausgeliefert, nicht auf den PC gespiegelt |

GearSets-Dateien teilen Helfer über `GS` (Export am Dateiende, Import als `local x = GS.x`).

## Härteste Regeln

- SavedVariables-Namen fest, Felder nur mit Migration ändern (I-01, I-02)
- Nichts ohne Auftrag entfernen (I-03)
- Expressway nur über `UI.Font`, Knöpfe mit eigenem FontString (I-05, I-06) – leere Texte kamen sechsmal zurück
- Ebenen und Fensterarten wie festgelegt (I-07, I-08)
- Symbole nur über Blizzards Makro-Symbolfunktionen, nie `IconDataProviderMixin` (I-09)
- Tooltip-Zeile sofort, ohne Verzögerung und eigenes `Show()` (I-10)
- Jeder Text in allen fünf Sprachen (I-12)
- Forever-Eigenes hinter `ns.isForever` (I-14); nie ein fremdes Addon nennen (I-18)
