# VuloGearSets – Projektregeln

Ausrüstungs-Set-Manager für **TBC Classic Anniversary** (`VuloGearSets.toc`, Interface 20506),
**World of Warcraft: Forever** (gleiche TOC, Interface 16001, `ns.isForever`) und **Classic Era**
(`VuloGearSets_Vanilla.toc`). Der Repo-Wurzelordner ist der Addon-Ordner.

Diese Datei ist verbindlich. Vor jeder Änderung den passenden Abschnitt lesen; wer eine Regel
bricht, schreibt hier vorher hinein, warum.

## Arbeitsablauf

1. Ändern. Neue Lua-Datei → in **beide** TOCs eintragen.
2. `python3 tools/check.py` muss `OK` melden. Er prüft TOC ↔ Dateien, Versionen, Locale-Keys in
   allen Sprachen, Platzhalter-Reihenfolge, fehlende/unbenutzte Media-Dateien, versehentliche
   globale Funktionen, Blockstruktur und Lua-5.1-Syntax.
3. Syntax der geänderten Dateien:
   `NODE_PATH=~/addons/VuloClassicUI/tools/node_modules node -e 'require("luaparse").parse(require("fs").readFileSync("<datei>","utf8"),{luaVersion:"5.1"})'`
   (Node unter `~/.local/node/bin`).
4. Thematischer Commit auf `main`, deutsche Botschaft, Kommentare/Commits ASCII-transliteriert
   (ue/ae/oe), **kein Co-Authored-By**, nie ein fremdes Addon nennen.
5. Speichern = Deploy (Syncthing → Gaming-PC). Fertigmeldung mit `/reload`-Hinweis und 1–3
   konkreten Dingen zum Prüfen im Spiel.
6. Release nur auf ausdrückliches „release“: Changelog-Block (Englisch) oben in `CHANGELOG.md`,
   `python3 tools/release.py <x.y.z>`, Commit `v<x.y.z>: …`, `git push`, annotierter Tag, Tag pushen,
   Workflow `release.yml` abwarten.

## Aufbau und Ladereihenfolge

Reihenfolge = TOC. Spätere Dateien dürfen frühere benutzen, nie umgekehrt (außer zur Laufzeit
über `GS.*`/`ns.*`).

| Datei | Aufgabe |
|---|---|
| `Core/Namespace.lua` | `ns`, Version, Farben, Client-Erkennung (`ns.isForever`) |
| `Core/Compat.lua` | API-Shims |
| `Core/Locale.lua`, `Locales/*.lua` | `ns.L`, Keys = englischer Text |
| `Core/Database.lua` | SavedVariables anlegen, Modul-Defaults |
| `Core/Modules.lua` | Modulregistry, An/Aus je Charakter |
| `Core/Events.lua`, `Core/Slash.lua` | Ereignisverteiler, allgemeine Slash-Befehle |
| `Core/Skin.lua` | Stile classic/modern/forever, Fensterarten (siehe unten) |
| `Core/PopupMenu.lua` | gemeinsames Rechtsklick-/Auswahlmenü |
| `Core/Mover.lua` | verschiebbare Rahmen im Bearbeiten-Modus |
| `UI/Widgets.lua` | Schrift (`UI.Font`), Knöpfe, Schalter, Regler, Auswahllisten |
| `UI/OptionsFrame.lua` | Einstellungsfenster `/vgs`, rendert `mod:GetOptions()` |
| `Modules/GearSets/*` | Kernmodul, aufgeteilt: `Shared` (Daten, Helfer) → `Sets` (Speichern, Anlegen, Zurück, Bank) → `AutoSwitch` → `Minimap` → `Pickers` (Slot- und Symbolauswahl) → `Sidebar` → `Lifecycle` (Migrationen, Events) → `Options` |
| `Modules/SlotPicker.lua` | Flyout am Ausrüstungsslot |
| `Modules/SocketBar.lua` | Sockel-Leiste unter der Set-Leiste |
| `Modules/ItemTooltip.lua` | „Sets: …“ im Item-Tooltip |
| `Modules/SetKeybinds.lua`, `Modules/SetMacros.lua` | Tasten und Makros je Set |
| `Modules/BlizzardSets.lua` | nur Forever: Spiegel in Blizzards Ausrüstungsmanager |
| `Core/Coexistence.lua` | einziger Ort, der VuloClassicUIs SavedVariables liest |
| `Core/Init.lua` | Start: DB → Import → Module |

Die GearSets-Dateien teilen Helfer über die Tabelle `GS` (Export am Dateiende, Import als
`local x = GS.x` oben). Eine Funktion, die eine *früher* geladene Datei braucht, ruft sie zur
Laufzeit über `GS.name()` auf.

## Gespeicherte Daten – nie still brechen

Felder werden **nie** umbenannt oder entfernt ohne Migration in `Modules/GearSets/Lifecycle.lua`
(`mod:OnEnable`). Spieler verlieren sonst Sets.

**`VuloGearSetsDB`** (Konto): `style`, `debug` (nur von Hand), `modules[key]` mit den Defaults
jedes Moduls. `gearsets`: `confirmDelete`, `minimap{hidden,angle}`, `autoSwitchEnabled`,
`specSwitchEnabled`, `ridingCropEnabled`, `sidebarEnabled`, `sidebarTopOffset`,
`sidebarBottomOffset`, `sidebarXOffset`, `sidebarStatsGap`, `sidebarPos` (Alias der Charakterkopie),
`_offsetMigrated_v3`. `slotpicker`: `modifier`, `cols`, `_defaultMigrated_v2`. `socketbar`:
`markEmpty`, `confirmOverwrite`.

**`VuloGearSetsCharDB`** (Charakter): `sets`, `specMapping`, `formMapping`, `keybinds`,
`modEnabled`, `blizzMirror` (true/false/"rejected", siehe Kopf von BlizzardSets.lua), `imported`,
`previousGear{slots,slotMask}`, `cropState{slot,prevLink}`, `sidebarPos{x,y}`.

**Ein Set** `sets[name]`: `slots{[slot]=itemLink}`, `slotMask{slot…}` (leerer Slot im Mask =
ablegen), `iconOverride` (nil = auto, Zahl = Datei-ID, Text = Pfad), `order`, `showHelm`/`showCloak`
(nil/true/false), `createdAt`. Umbenennen muss `specMapping`, `formMapping`, `keybinds`,
`blizzMirror`, Makro und Sidebar-Auswahl mitziehen (siehe `Sets.lua`, Rename-Hüllen).

## Feste Regeln (aus Fehlern gelernt)

- **Schrift:** Eigene Texte über `UI.Font` (Expressway, erst wenn sie zeichnet). Setnamen in der
  Leiste und Fenstertitel bleiben Blizzard-Schrift (`GameFontNormal`). Auf ruRU/zhCN/zhTW/koKR
  immer `STANDARD_TEXT_FONT` – Expressway hat dort keine Zeichen.
- **Knöpfe:** `UI:CreateButton` hat einen *eigenen* FontString `b.text`. Nie Blizzards Knopftext
  (`GetFontString`) stylen – die Vorlage setzt dessen Schrift bei jedem Zustandswechsel neu, und
  „Anlegen“/„Speichern“ blieben nach dem Einloggen leer. `b:SetText`/`b:GetText` sind umgeleitet.
- **Ebenen:** Set-Leiste `HIGH`, Einstellungen und Slot-Flyout `DIALOG`, Symbolauswahl und
  Sockel-Auswahl `FULLSCREEN_DIALOG`, gemeinsames Menü `FULLSCREEN_DIALOG` Stufe 100. Der
  Forever-Metallrahmen liegt 30 Stufen über seinem Fenster – was darüber erscheinen soll, braucht
  eine höhere Ebene.
- **Fensterarten** (`UI:SkinFrame(frame, kind)`, Innenabstand `ns:FrameInset(kind)`): `window`,
  `pane`, `sidebar` (Forever: Ausrüstungsmanager-Grafik), `selector` (Forever: Rahmen von Blizzards
  Symbolauswahl, nur für große Fenster – Ecken über 70 px), `flyout` (Forever: schmaler Theme-Rand).
  Der Schlagschatten (`UI:CreateShadow`) erscheint im Forever-Stil nicht – um Metall und
  Blizzard-Ränder wirkte er wie ein grauer Rand.
- **Symbole:** Die Symbolauswahl holt ihre Liste mit `GetLooseMacroIcons`, `GetLooseMacroItemIcons`,
  `GetMacroIcons`, `GetMacroItemIcons`. **Nicht** `IconDataProviderMixin` benutzen – dessen geteilter
  Zwischenspeicher würde Blizzards Ausrüstungsmanager und Makrofenster mit Taint belegen. Keine
  eigenen Symbol-Dateien mehr ausliefern.
- **Forever/Classic:** Was es nur auf Forever gibt (`C_EquipmentSet`-Spiegel, Forever-Stil), hinter
  `ns.isForever`. Texte, die VuloClassicUI erwähnen, auf Forever nicht zeigen.
- **Kampf:** Nichts tauschen in `InCombatLockdown()`; aufschieben bis `PLAYER_REGEN_ENABLED`.
- **Bank:** „In die Bank legen“ nimmt nur Teile aus den Taschen, getragene bleiben an.
- **Globale Namen:** Alles `local`. Einzige Ausnahme: `VuloGearSets_*` für `Bindings.xml`, und
  Frame-Namen mit Präfix `VGS_`.
- **Übersetzungen:** Neuer Text = neuer Key in **allen** Sprachdateien (`deDE`, `frFR`, `esES` –
  gilt auch für esMX –, `ruRU`, `zhCN`), alphabetisch einsortiert, Reihenfolge der übrigen nicht
  anfassen. Platzhalter in derselben Reihenfolge wie im Englischen (`string.format` kennt keine
  Positionen). Umlaute echt, Lua-Kommentare ASCII.
- **Media:** Jede Datei unter `Media/` muss benutzt werden, jeder Pfad im Code muss existieren
  (`check.py`). Neue `.tga` brauchen einen Spiel-Neustart, nicht nur `/reload`.
- **Löschen:** Keine Funktion, Option oder Datei entfernen, ohne dass der Nutzer es gesagt hat.
  Ersetzte Funktionen bekommen eine Migration für gespeicherte Werte.

## Im Spiel prüfen (Kurztest nach größeren Änderungen)

1. Einloggen, Charakterfenster: Set-Leiste mit Texten auf „Anlegen“/„Speichern“, Statuspunkte.
2. Set anlegen, speichern, umbenennen, Symbol ändern, löschen.
3. Rechtsklick-Menü eines Sets und Auswahllisten in `/vgs` liegen vorne.
4. Über einen Ausrüstungsslot fahren: Flyout mit passenden Teilen.
5. Forever: Set erscheint auch in Blizzards Ausrüstungsmanager.
