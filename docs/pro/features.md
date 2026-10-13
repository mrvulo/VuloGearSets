# Features

Stand: 2026-10-10. Status: `done` = ausgeliefert und bestätigt, `test-in-game` = noch nicht im Spiel gesehen, `dropped` = entfernt oder ersetzt.

| ID | Feature | Status | Spec | Hauptdateien |
|---|---|---|---|---|
| F001 | Sets speichern, anlegen, überschreiben, löschen (ganze Ausrüstung oder Gruppen Schmuck/Waffen) | done | [spec](../superpowers/specs/2026-07-28-vulogearsets-standalone-design.md) | Modules/GearSets/Sets.lua, Modules/GearSets/Shared.lua |
| F002 | Seitenleiste am Charakterfenster mit Symbol je Set, Rechtsklick-Menü, verschiebbar (`/gearset unlock`) | done | [spec](../superpowers/specs/2026-07-28-vulogearsets-standalone-design.md) | Modules/GearSets/Sidebar.lua, Core/Mover.lua, Core/PopupMenu.lua |
| F003 | Minimap-Knopf: Linksklick Set-Wechsler, Rechtsklick Einstellungen | done | [spec](../superpowers/specs/2026-07-28-vulogearsets-standalone-design.md) | Modules/GearSets/Minimap.lua |
| F004 | Automatischer Wechsel bei Haltung/Gestalt und Talentgruppe | done | [spec](../superpowers/specs/2026-07-28-vulogearsets-standalone-design.md) | Modules/GearSets/AutoSwitch.lua |
| F005 | Kampfsperre: Wechsel im Kampf wird nach Kampfende nachgeholt | done | [spec](../superpowers/specs/2026-07-28-vulogearsets-standalone-design.md) | Modules/GearSets/Sets.lua, Modules/GearSets/Lifecycle.lua |
| F006 | Slot-Auswahl: Teile aus den Taschen am Slot, Klick legt an (Hover kompakt, Klick öffnet großes Fenster; Waffenslots öffnen nach unten) | done | [spec](../superpowers/specs/2026-07-28-vulogearsets-standalone-design.md) | Modules/SlotPicker.lua, Modules/GearSets/Pickers.lua |
| F007 | Eigenes Einstellungsfenster (`/vgs`) mit Modul-Seiten | done | [spec](../superpowers/specs/2026-07-28-vulogearsets-standalone-design.md) | UI/OptionsFrame.lua, UI/Widgets.lua, Modules/GearSets/Options.lua |
| F008 | Einmal-Import der Sets aus VuloClassicUI, Hinweis bei Doppelbetrieb | done | [spec](../superpowers/specs/2026-07-28-vulogearsets-standalone-design.md) | Core/Coexistence.lua, Core/Init.lua |
| F009 | Eigene Schrift Expressway (Rückfall Arial Narrow, Blizzard-Schrift auf ruRU/zhCN/zhTW/koKR) | done | — | UI/Widgets.lua |
| F010 | Diagnosebefehle `/vgsfont` und `/rl` | done | — | Core/Slash.lua |
| F011 | Discord-Knopf und Versionsanzeige in der Fußzeile der Einstellungen | done | — | UI/OptionsFrame.lua |
| F012 | Fensterstil Modern/Classic, live umschaltbar (Classic seit 1.7.1 Standard) | done | — | Core/Skin.lua, UI/Widgets.lua |
| F013 | Dropdown-Pfeil als Grafik, folgt dem Stil | done | — | UI/Widgets.lua |
| F014 | Statuspunkt je Set (grün/orange/rot) mit Tooltip, wo welches Teil liegt | done | — | Modules/GearSets/Sidebar.lua, Modules/GearSets/Shared.lua |
| F015 | Seitenleiste nur auf dem Reiter Charakter | done | — | Modules/GearSets/Sidebar.lua |
| F016 | Seitenleiste bündig am sichtbaren Fensterrand, `/gearset tune left\|show\|reset` | done | — | Modules/GearSets/Sidebar.lua, Modules/GearSets/Sets.lua |
| F017 | Scrollende Set-Liste in der Seitenleiste | done | — | Modules/GearSets/Sidebar.lua |
| F018 | Schnellspeichern-Gruppen Ringe und Rüstung | done | — | Modules/GearSets/Options.lua, Modules/GearSets/Minimap.lua |
| F019 | Anlegen vergleicht Item-IDs statt Links (verzauberte Teile gelten nicht als fehlend) | done | — | Modules/GearSets/Shared.lua, Modules/GearSets/Sets.lua |
| F020 | Classic Era und Season of Discovery (zweite TOC, Interface 11509) | done | — | Core/Namespace.lua, Modules/GearSets/AutoSwitch.lua |
| F021 | Sets umbenennen (behält Symbol, Spec-/Gestalt-Bindungen) | done | — | Modules/GearSets/Sets.lua, Modules/GearSets/Sidebar.lua |
| F022 | Symbolauswahl mit scrollbarem Fenster, Schließen-Knopf, Symbole der Set-Teile | done | — | Modules/GearSets/Pickers.lua |
| F023 | Tausch getragener Teile zwischen Slots (vertauschte Ringe/Schmuck); Statuspunkt zählt Exemplare | done | — | Modules/GearSets/Sets.lua, Modules/GearSets/Shared.lua |
| F024 | Seitenleiste weicht fremder Statistikspalte aus (`/gearset tune stats`), Breite folgt dem Symbolraster | done | — | Modules/GearSets/Sidebar.lua |
| F025 | Tempo-Schmuck beim Aufsitzen (Reitgerte/Karotte, Druiden Glücksbringer in Fluggestalt), Zustand überlebt Reload | done | — | Modules/GearSets/AutoSwitch.lua, Modules/GearSets/Options.lua |
| F026 | Sockel-Leiste unter der Seitenleiste: leere Sockel rot, Klick wählt Stein aus Taschen | done | — | Modules/SocketBar.lua |
| F027 | Rückfrage vor dem Überschreiben eines belegten Sockels (abschaltbar) | done | — | Modules/SocketBar.lua |
| F028 | Zeile "Sets: …" im Item-Tooltip, alphabetisch bzw. in eigener Reihenfolge | done | [spec](../superpowers/specs/2026-08-06-set-zugehoerigkeit-im-tooltip-design.md) | Modules/ItemTooltip.lua |
| F029 | Sets von der Bank anlegen, solange das Bankfenster offen ist; geschlossene Bank meldet Teile eigens | done | [spec](../superpowers/specs/2026-08-06-sets-von-der-bank-anlegen-design.md) | Modules/GearSets/Sets.lua, Modules/GearSets/Shared.lua |
| F030 | Set auf eine Taste legen ("Taste belegen…"), pro Charakter, Override-Bindungen | done | — | Modules/SetKeybinds.lua |
| F031 | Eigene Reihenfolge der Sets (Nach oben/unten, Ziehen mit Einfügemarke) | done | — | Modules/GearSets/Sidebar.lua, Modules/GearSets/Sets.lua |
| F032 | Helm und Umhang je Set anzeigen/verbergen/nicht ändern | done | — | Modules/GearSets/Sets.lua, Modules/GearSets/Sidebar.lua |
| F033 | Zwei Exemplare desselben Teils (Sockel/Verzauberung) beim Wechsel unterscheiden (variantKey) | done | — | Modules/GearSets/Shared.lua, Modules/GearSets/Sets.lua |
| F034 | Beim Speichern leere Slots werden beim Anlegen geleert ("%d Teile abgelegt") | done | — | Modules/GearSets/Sets.lua, Modules/GearSets/Sidebar.lua |
| F035 | Meldung eines nichtstuenden Anlegens nur einmal im Chat | done | — | Modules/GearSets/Sets.lua |
| F036 | Unterstützung für WoW: Forever (Interface 16001, Retail-API-Fallbacks, Bankreiter) | done | — | Core/Compat.lua, Core/Namespace.lua, Modules/GearSets/Shared.lua |
| F037 | Fensterstil "Forever" (Standard auf Forever, übernimmt VuloForeverUI-Look und Blizzard-Metallrahmen) | done | — | Core/Skin.lua |
| F038 | Neuer "Neues Set"-Knopf (dunkle Karte, Goldrand, grünes Plus); auf Forever Blizzards Original | done | — | Modules/GearSets/Sidebar.lua, UI/Widgets.lua |
| F039 | Forever: Sets zusätzlich in Blizzards Ausrüstungsmanager spiegeln (Schalter, Standard an) | done | — | Modules/BlizzardSets.lua |
| F040 | "Auf die Aktionsleiste legen": Blizzard-Set (Forever) oder Makro mit Set-Symbol | done | — | Modules/SetMacros.lua, Modules/BlizzardSets.lua |
| F041 | "Zurück zur vorherigen Ausrüstung" (Minimap-Menü, Taste, `/gearset back`) | done | — | Modules/GearSets/Sets.lua, Modules/GearSets/Minimap.lua |
| F042 | Set "In die Bank legen" bei offener Bank (`/gearset bank <Name>`), nur Teile aus den Taschen | done | — | Modules/GearSets/Sets.lua, Modules/GearSets/Sidebar.lua |
| F043 | Automatisches Set-Symbol = erstes Teil nach Slot-Reihenfolge; Set-Namen beim Speichern getrimmt | done | — | Modules/GearSets/Sets.lua, Modules/GearSets/Pickers.lua |
| F044 | Symbolauswahl mit den Spielsymbolen (Alle/Zauber/Gegenstände, markiertes Symbol, ziehbarer Balken); Symbol auch auf Makro und Blizzard-Kopie | done | — | Modules/GearSets/Pickers.lua, Modules/SetMacros.lua |
| F045 | Forever-Look für Symbolauswahl und Slot-Flyout (Blizzard-Rahmen, schmaler Theme-Rand) | done | — | Core/Skin.lua, Modules/GearSets/Pickers.lua, Modules/SlotPicker.lua |
| F046 | Auswahllisten in den Einstellungen klappen direkt unter der Liste auf, über allen Fenstern | done | — | Core/PopupMenu.lua, UI/Widgets.lua |
| F047 | Kein Schlagschatten im Forever-Stil (Classic/Modern behalten ihn) | done | — | UI/Widgets.lua, Core/Skin.lua |
| F048 | Neue Sprachen Französisch, Spanisch (auch esMX), Russisch, Chinesisch (vereinfacht) | test-in-game | — | Locales/frFR.lua, Locales/esES.lua, Locales/ruRU.lua, Locales/zhCN.lua |
| F049 | `/vgs` und `/gearset` allein öffnen/schließen die Einstellungen (Hilfe unter `/vgs help`) | done | — | Modules/GearSets/Sets.lua |
| F050 | Forever: Anlegen/Speichern in Blizzards Ausrüstungsmanager speichert das Set auch in VuloGearSets und verknüpft es | test-in-game | [F050](features/F050-blizzard-speichern-uebernehmen.md) | Modules/BlizzardSets.lua, Modules/GearSets/Sets.lua |
| F051 | Forever: Umbenennen und Symbolwechsel in Blizzards Bearbeiten-Fenster übernehmen | done | [F051](features/F051-blizzard-bearbeiten-uebernehmen.md) | Modules/BlizzardSets.lua, Modules/GearSets/Sets.lua |
| F054 | Speichern unter vorhandenem Namen (Namensdialog, auch „Nur Schmuck/Waffen/…“) fragt erst nach; bei Teilgruppen mit Hinweis, dass die übrigen Teile wegfallen | test-in-game | — | Modules/GearSets/Sets.lua |
| D001 | Schlafmodus (Addon schaltet sich ab, wenn VuloClassicUI sein Set-Modul hat) | dropped | [spec](../superpowers/specs/2026-07-28-vulogearsets-standalone-design.md) | Core/Coexistence.lua |
| D002 | Kontoweiter Set-Pool und separater Importbefehl der Altversion | dropped | [spec](../superpowers/specs/2026-07-28-vulogearsets-standalone-design.md) | Core/Coexistence.lua |
| D003 | Auslöseart "Beim Überfahren" im Slot-Auswahl-Dropdown: Hover ist jetzt immer aktiv, das Dropdown wählt nur den Klick fürs große Fenster | dropped | — | Modules/SlotPicker.lua |
| D004 | Hover-Standard der Slot-Auswahl: erst Rechtsklick (599bbae), dann Hover (52e3ab1), dann parallel zum Klick (c5aa029); Wert `hover` wird auf `right` migriert | dropped | — | Modules/SlotPicker.lua |
| D005 | Standard-Fensterstil Modern, ersetzt durch Classic (1.7.1); gespeicherte Wahl bleibt | dropped | — | Core/Skin.lua |
| D006 | 209 mitgelieferte Set-Symbole (Media/Icons/sets), ersetzt in 1.16.0 durch die Spielsymbole; betroffene Sets fallen auf Auto zurück | dropped | — | Modules/GearSets/Pickers.lua |
| D007 | Chatmeldung zur Ersatzschrift (b8b1d31) und Schrift-Messung als Entscheidungsgrundlage (Breite war immer 0, c8e5b4d); Expressway wird direkt gesetzt, /vgsfont misst nur noch zur Diagnose | dropped | — | UI/Widgets.lua |

## Wartet auf Spieltest

- F050: siehe Spieltest in der Spezifikation (neues Set in Blizzards Fenster, Speichern, Umbenennen bei uns).
- F054: Sets-Menü → „Nur Schmuck speichern…“, vorhandenen Namen eingeben – Rückfrage mit Hinweis; Nein lässt das Set unverändert.
- R-69 bis R-75 (Code-Audit 2026-10-13): Set mit zwei gleichen Ringen und mit mehreren Leer-Slots anlegen; Tastenabfrage offen lassen und Kampf beginnen; im Sattel mit Auto-Reitgerte speichern.
- F048: Spielsprache auf Français und Русский stellen – passen die Texte in die Knöpfe, sind russische Texte lesbar (Blizzard-Schrift)?

## Ideen

Neue Vorschläge von Claude hier mit ID als `idea` eintragen, damit „mach 1 und 2“ später zuzuordnen ist.

| ID | Idee | Status |
|---|---|---|
| F052 | Vorhandene Blizzard-Sets, die nie neu gespeichert werden, einmalig in VuloGearSets übernehmen | idea |
