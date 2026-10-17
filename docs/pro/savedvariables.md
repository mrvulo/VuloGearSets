# Gespeicherte Daten

Namen fest (I-01). Felder nie ohne Migration umbenennen oder entfernen (I-02).
Migrationen laufen in `Modules/GearSets/Lifecycle.lua` (`mod:OnEnable`); Modul-Migrationen in
der jeweiligen Datei (z. B. `Modules/SlotPicker.lua`).

## `VuloGearSetsDB` (Konto)

- `style` – `"classic"` | `"modern"` | `"forever"` (nur Forever, dort Standard); `Core/Skin.lua`
- `debug` – nur von Hand gesetzt
- `charSets["Name-Realm"]{class,sets,updated}` – Abbild der Sets jedes Charakters (Teile als Exemplar-Schlüssel), geschrieben beim An- und Abmelden; nur zum Kopieren auf andere Charaktere (2026-10-17)
- `modules[key]` – Defaults jedes Moduls (`ns:RegisterModule`, `Core/Database.lua`)
  - `gearsets`: `confirmDelete`, `chatMessages` (`"all"` | `"problems"` | `"none"`, 2026-10-13), `combatWeaponSwap` (2026-10-17), `minimap{hidden,angle}`, `autoSwitchEnabled`,
    `specSwitchEnabled`, `ridingCropEnabled`, `triggersEnabled` (2026-10-17), `sidebarEnabled`, `sidebarTopOffset`,
    `sidebarBottomOffset`, `sidebarXOffset`, `sidebarStatsGap`, `sidebarPos` (Alias der
    Charakterkopie), Migrationsmarke `_offsetMigrated_v3`
  - `slotpicker`: `modifier` (`right` | `shift-right` | `alt-right` | `ctrl-right`), `cols`,
    Migrationsmarke `_defaultMigrated_v2`
  - `socketbar`: `markEmpty`, `confirmOverwrite`
  - `setkeybinds`, `blizzsets`, `itemtooltip`: nur `enabled` (die echte An/Aus-Wahl steht je
    Charakter in `modEnabled`)

## `VuloGearSetsCharDB` (Charakter)

- `sets[name]` – ein Set (unten)
- `specMapping[name]` – Talentgruppe, je Gruppe höchstens ein Set
- `formMapping[name]` – Gestalt/Haltung, je Gestalt höchstens ein Set
- `keybinds[name]` – Override-Taste, z. B. `"SHIFT-1"`
- `modEnabled[moduleKey]` – An/Aus je Charakter, schlägt `mod.db.enabled`
- `blizzMirror[name]` – `true` | `false` | `"rejected"` (Forever; Bedeutung im Kopf von
  `Modules/BlizzardSets.lua`)
- `imported` – Übernahme aus VuloClassicUI erledigt (`Core/Coexistence.lua`)
- `previousGear{slots,slotMask,ammo}` – Stand für „Zurück zur vorherigen Ausrüstung“
- `triggers[key]` – Setname je Situation (`mount`, `swim`, `fishing`, `eat`, `pvp`, `arena`, `party`, `raid`, `rest`, `world`); Umbenennen/Löschen ziehen mit (2026-10-17)
- `triggerState{temp,tempSnap,loc,locSnap}` – laufende Situation und Stand davor (wie `previousGear`), überlebt Reload
- `lastSet` – Name des zuletzt angelegten Sets, Ausgangspunkt für „Nächstes/Vorheriges Set“ (2026-10-17)
- `cropState{slot,prevLink}` – Reitgerte gerade angelegt
- `sidebarPos{x,y}` – Versatz der Set-Leiste

## Ein Set `sets[name]`

| Feld | Bedeutung |
|---|---|
| `slots{[slot]=itemLink}` | gespeicherte Teile; leere Slots fehlen. Importierte/kopierte Teile stehen kurz als `item:…`, bis der Client sie kennt (Share.lua) |
| `slotMask{slot…}` | Slots, die das Set verwaltet; Slot im Mask ohne Teil = ablegen |
| `iconOverride` | nil = automatisch, Zahl = Datei-ID, Text = Pfad |
| `order` | Position in der Leiste, nil bis zum ersten Umsortieren |
| `showHelm` / `showCloak` | nil = lassen, true/false = zeigen/verbergen |
| `createdAt` | Zeitstempel der Anlage |
| `ammo` | Item-ID der Munition (Slot 0), nur mit Fernkampfslot gespeichert; nil = Munition nicht anfassen (2026-10-17) |

Umbenennen zieht `specMapping`, `formMapping`, `keybinds`, `blizzMirror`, Makro und die Auswahl in
der Leiste mit (Rename-Hüllen in `Modules/GearSets/Sets.lua`).
