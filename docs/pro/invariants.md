# Invarianten – was nicht kaputtgehen darf

Jede Regel mit Grund, Datum, Quelle und Schutz.
Schutz: `check` = `tools/check.py` schlägt fehl · `code` = ein gemeinsamer Codepfad · `manual` = Review/Spieltest.
Quelle: `user` (Zitat) · `code` · Commit · `spec` · `R-xx` (aus einem Fehler gelernt).

Eine Änderung, die eine Regel brechen würde: anhalten und den Nutzer fragen. Nie still.

| ID | Regel | Warum | Datum · Quelle | Schutz |
|---|---|---|---|---|
| I-01 | SavedVariables heißen `VuloGearSetsDB` (Konto) und `VuloGearSetsCharDB` (Charakter) | Umbenennen löscht Sets und Einstellungen aller Spieler | 2026-07-28 · spec | check |
| I-02 | Gespeicherte Felder werden nie umbenannt oder entfernt ohne Migration in `Modules/GearSets/Lifecycle.lua` (`mod:OnEnable`); Schema in [savedvariables.md](savedvariables.md) | Spieler verlieren sonst Sets | 2026-10-09 · user „nicht iwas kaputt machen oder löschen“ | manual |
| I-03 | Keine Funktion, Option oder Datei entfernen, ohne dass der Nutzer es gesagt hat; Ersetztes bekommt eine Migration | Nutzer will, dass nichts still verschwindet | 2026-10-09 · user | manual |
| I-04 | Setnamen in der Leiste und Fenstertitel bleiben Blizzard-Schrift (`GameFontNormal`) | Sollen zu Blizzards Ausrüstungsmanager daneben passen | 2026-09-28 · user „nein setnamen soll so bleiben“ | manual |
| I-05 | Eigene Texte bekommen Expressway nur über `UI.Font` (`UI/Widgets.lua`); es setzt Expressway erst, wenn sie zeichnet, und zeichnet jeden Text bei `OnShow` seines Fensters und nach `LOADING_SCREEN_DISABLED` neu. Auf ruRU/zhCN/zhTW/koKR `STANDARD_TEXT_FONT` | Während des Ladebildschirms gesetzter Text bleibt leer – sechsmal aufgetreten (R-Schrift) | 2026-10-10 · R-Schrift | check |
| I-06 | `UI:CreateButton` beschriftet über einen eigenen FontString `b.text`; nie Blizzards Knopftext (`GetFontString`) stylen | Die Vorlage setzt dessen Schrift bei Zustandswechseln um | 2026-10-09 · R-Schrift | check |
| I-07 | Ebenen: Set-Leiste `HIGH`; Einstellungen und Slot-Flyout `DIALOG`; Symbol- und Sockelauswahl `FULLSCREEN_DIALOG`; gemeinsames Menü `FULLSCREEN_DIALOG` Stufe 100. Der Forever-Metallrahmen liegt 30 Stufen über seinem Fenster | Menü lag hinter dem Einstellungsfenster | 2026-10-06 · user „eine ebene zu niedrig“ | manual |
| I-08 | Fensterarten über `UI:SkinFrame(frame, kind)` und `ns:FrameInset(kind)`: `window`, `pane`, `sidebar`, `selector` (nur große Fenster – Ecken über 70 px), `flyout`. Kein Schlagschatten im Forever-Stil | Forever-Look wie Blizzard; Schatten wirkte als grauer Rand | 2026-10-04/09 · user | code |
| I-09 | Symbolliste nur über `GetLooseMacroIcons`, `GetLooseMacroItemIcons`, `GetMacroIcons`, `GetMacroItemIcons`; nie `IconDataProviderMixin`; keine eigenen Symboldateien ausliefern | Blizzards geteilter Zwischenspeicher bekäme Taint; Nutzer wollte Blizzards Symbole statt eigener | 2026-10-04 · user | check |
| I-10 | Item-Tooltip: „Sets:“-Zeile sofort im `TooltipDataProcessor`-Rückruf, ohne eigenes `Show()` und ohne Verzögerung | Händler-/Taschen-Tooltips bauen sich alle 0,2 s neu; Verzögerung flackert | 2026-10-10 · R-Tooltip | manual |
| I-11 | Keine Globals außer `VuloGearSets_*` (Bindings.xml), `SLASH_*`, `BINDING_*`; Frame-Namen mit Präfix `VGS_` | Kollision mit anderen Addons | 2026-10-09 · code | check |
| I-12 | Jeder Text-Key in allen Sprachdateien (`deDE`, `frFR`, `esES` = esES+esMX, `ruRU`, `zhCN`), Platzhalter in derselben Reihenfolge wie im Englischen, Umlaute echt, Lua-Kommentare ASCII | Fehlender Key fällt still auf Englisch; falsche Platzhalter-Reihenfolge lässt `string.format` abstürzen | 2026-10-06 · user „die 4 wichtigsten sprachen“ | check |
| I-13 | Jeder Pfad auf eine Grafik/Schrift existiert, jede Datei unter `Media/` wird benutzt; neue `.tga` brauchen einen Spiel-Neustart | Fehlende Datei = grünes Feld oder leerer Text ohne Fehlermeldung | 2026-10-09 · code | check |
| I-14 | Was es nur auf Forever gibt (`C_EquipmentSet`-Spiegel, Forever-Stil), steht hinter `ns.isForever`; Texte über VuloClassicUI auf Forever nicht zeigen | VuloClassicUI gibt es auf Forever nicht | 2026-10-06 · user „VuloClassicUi soll da nicht stehen“ | manual |
| I-15 | Im Kampf nichts tauschen, außer Waffen (16/17/18) bei einem Anlegen durch den Spieler (Taste, Klick), Schalter `combatWeaponSwap`, nie auf Forever; der Rest und alle Automatiken warten auf `PLAYER_REGEN_ENABLED` | Server erlaubt im Kampf nur Waffen, und nur aus einem echten Tastendruck; Forever hat strengere Regeln | 2026-07-29 · 5ff1363; geändert 2026-10-17 · user wählte F065 | manual |
| I-16 | „In die Bank legen“ nimmt nur Teile aus den Taschen, getragene bleiben an | Nutzer hat Ausziehen abgelehnt | 2026-09-28 · user „nein“ | manual |
| I-17 | VuloClassicUIs SavedVariables nur in `Core/Coexistence.lua` lesen | Keine Kopplung an ein anderes Addon | 2026-07-28 · spec | check |
| I-18 | Nie ein fremdes Addon nennen – Code, Kommentare, Texte, Commits, Changelog, README, CurseForge | Hausregel | Hausregel | manual |
| I-19 | Commits ohne `Co-Authored-By` | Hausregel | Hausregel | manual |
| I-20 | Release nur auf ausdrückliches „release“ des Nutzers | Veröffentlichung erreicht andere | user | manual |
| I-21 | Jedes Modul bringt seine Optionen selbst mit (`mod:GetOptions(page)`); kein Modul schreibt in die Daten eines anderen. Jede Option hat einen Tooltip; Einstellungen mit Standard tragen `default`, Sets und Bindungen nie | Einstellungen leicht findbar, Zurücksetzen fasst nichts Falsches an | 2026-10-13 · user „Einstellungen sollen sich leichter finden und ändern lassen“ | manual |
