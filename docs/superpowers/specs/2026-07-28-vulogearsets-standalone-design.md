# VuloGearSets — Standalone-Addon aus dem VuloClassicUI-Modul "Equipment Sets"

Datum: 2026-07-28
Status: Design freigegeben

## Ziel

Das Ausrüstungsset-Modul von VuloClassicUI (`Modules/Loadouts.lua` + `Modules/SlotPicker.lua`)
wird als eigenständiges Addon `VuloGearSets` ausgekoppelt. Es läuft ohne VuloClassicUI,
bringt seine eigene Optionsoberfläche mit und übernimmt bestehende Sets beim ersten Start.

Zielversion: TBC Classic Anniversary, Interface 20505. Eine TOC, keine Vanilla-Variante.

## Ausgangslage

Die beiden Quellmodule umfassen 2188 Zeilen:

- `Modules/Loadouts.lua` (1823 Zeilen) — Sets speichern, equippen, löschen; Equip über
  `UseContainerItem`, weil `AutoEquipCursorItem` in Anniversary geschützt ist; Minimap-Button
  mit Menü; Auto-Switch bei Stance/Form und bei Dual-Spec; Sidebar am Charakterfenster mit
  Icon-Picker und Slot-Ersetzen; Slash-Commands; `GetOptions()`-Seite (184 Zeilen)
- `Modules/SlotPicker.lua` (365 Zeilen) — Rechtsklick auf einen Ausrüstungsslot öffnet ein
  Popup mit allen passenden Items aus den Taschen

Die Kopplung an das Vulo-Framework beschränkt sich auf:

| Symbol | Herkunft | Behandlung im Standalone |
|---|---|---|
| `ns:RegisterModule`, `ns.modules`, `ns:IsModuleEnabled`, `ns:ToggleModule` | `Core/Modules.lua` | schlanke Neufassung ohne Profilbezug |
| `ns:Print` | `Core/Utils.lua` | nach `Core/Namespace.lua` |
| `ns:RegisterEvent` / `ns:UnregisterEvent` | `Core/Events.lua` | weitgehend übernommen |
| `ns:ShowPopupMenu` | `Core/PopupMenu.lua` | übernommen, siehe unten |
| `ns:CreateMover`, `ns:IsMoverEditMode` | `Core/Mover.lua` | API-kompatible Minimalfassung |
| `ns.L` | `Core/Locale.lua` + `Locales/` | übernommen, auf 116 Keys reduziert |
| `ns.UI:ToggleMainFrame` | `UI/MainFrame.lua` | ersetzt durch `ns:ToggleOptions` |
| `ns:OpenConfig` + `mod:GetOptions()` | `UI/OptionsBuilder.lua`, `UI/Widgets.lua` | neuer Minimal-Renderer |

`ns:EquipBagItemToSlot` ist in `Loadouts.lua:132` definiert, `ns:ScanBagsForSlot` in
`SlotPicker.lua` — beide wandern also automatisch mit.

Zwei Befunde verkleinern den Aufwand erheblich:

1. `mod:GetOptions()` liefert eine **deklarative Item-Liste** mit neun Typen: `header`, `desc`,
   `toggle`, `dropdown`, `slider`, `button`, `group` (mit `layout = "row"`), `section`
   (aufklappbar), `spacer`. Ein Renderer für genau diese Typen ersetzt 72 KB
   `Widgets.lua` + `OptionsBuilder.lua`, und die Optionsseite bleibt unverändert.
2. Beide Module laden **ausschließlich Blizzard-interne Texturen**. Es gibt keine einzige
   Referenz auf `Interface\AddOns\VuloClassicUI\Media\`. Mitgeliefert werden muss deshalb
   nur die Schrift, die die Widgets benutzen — keine Icons, keine Rahmen.

## Struktur

Der Repo-Root ist zugleich der Addon-Ordner: `VuloGearSets.toc` liegt direkt im Root, damit
sich das Repository ohne Zwischenschritt ins `Interface\AddOns`-Verzeichnis bringen lässt.
`docs/` und `tools/` liegen mit im Repo und werden vom Auslieferungsskript ausgelassen.

```
VuloGearSets/                     = Git-Repo-Root = Addon-Ordner
├─ .gitignore
├─ VuloGearSets.toc                Interface 20505
├─ Core/
│  ├─ Namespace.lua      ~80    ns, COLORS, Print, Debug, DeepCopy, ApplyDefaults
│  ├─ Compat.lua         ~30    ns:IsAddOnLoaded über C_AddOns mit Fallback
│  ├─ Locale.lua         ~40    L-Metatable, fällt auf den Key zurück
│  ├─ Database.lua       ~90    DB-Init + Defaults-Merge, kein Profilsystem
│  ├─ Modules.lua        ~80    RegisterModule / IsModuleEnabled / ToggleModule
│  ├─ Events.lua         ~60    RegisterEvent / UnregisterEvent
│  ├─ PopupMenu.lua      ~200   aus Vulo übernommen
│  ├─ Mover.lua          ~180   CreateMover / IsMoverEditMode für einen Frame
│  ├─ Coexistence.lua    ~70    Vulo-Erkennung, Import, Schlafmodus
│  └─ Init.lua           ~70    PLAYER_LOGIN-Ablauf, Module aktivieren
├─ UI/
│  ├─ Widgets.lua        ~300   Backdrop, CreateShadow, Font, Button, Toggle,
│  │                            Slider, Dropdown
│  └─ OptionsFrame.lua   ~350   Fenster + Renderer für die neun Item-Typen
├─ Locales/
│  ├─ enUS.lua           ~15   leer, Keys sind der englische Text
│  └─ deDE.lua           ~130  116 Übersetzungen, aus Vulo extrahiert
├─ Modules/
│  ├─ GearSets.lua       ~1800  aus Loadouts.lua
│  └─ SlotPicker.lua      ~365  unverändert
├─ Media/
│  └─ Fonts/Expressway.TTF      Schrift, wie in VuloClassicUI
├─ tools/                       nicht Teil der Auslieferung
│  ├─ extract_locales.py        zieht die benutzten Keys aus Vulos deDE.lua
│  ├─ rename_keys.py            Loadout → Gear Set in Code und Übersetzung
│  ├─ check.py                  TOC-, Locale- und Kopplungsprüfung
│  └─ deploy.ps1                kopiert das Addon ins Spielverzeichnis
├─ docs/superpowers/            Spezifikation und Umsetzungsplan
├─ README.md
└─ CHANGELOG.md
```

Etwa 3900 Zeilen, davon rund 2200 übernommen.

### TOC-Kopf und Ladereihenfolge

```
## Interface: 20505
## Title: |cff9b6cffVuloGearSets|r
## Notes: Equipment set manager for TBC Classic Anniversary
## Author: Vulo
## Version: 1.0.0
## SavedVariables: VuloGearSetsDB
## SavedVariablesPerCharacter: VuloGearSetsCharDB
## IconTexture: Interface\Icons\INV_Chest_Plate06
## Category: VuloUI

Core\Namespace.lua
Core\Compat.lua
Core\Locale.lua
Locales\enUS.lua
Locales\deDE.lua
Core\Database.lua
Core\Modules.lua
Core\Events.lua
Core\PopupMenu.lua
Core\Mover.lua
UI\Widgets.lua
UI\OptionsFrame.lua
Modules\GearSets.lua
Modules\SlotPicker.lua
Core\Coexistence.lua
Core\Init.lua
```

`IconTexture` verweist auf eine Blizzard-interne Textur, damit kein eigenes Asset nötig ist.

## Änderungen an den übernommenen Modulen

`GearSets.lua` wird an sechs Stellen angefasst; der Rest bleibt Zeile für Zeile identisch,
damit Logik-Fixes zwischen beiden Addons weiter übertragbar bleiben:

1. Modul-Key `loadouts` → `gearsets`, Anzeigename `Equipment Sets`
2. `charDB()` liest `VuloGearSetsCharDB` statt `VuloClassicUICharDB`
3. Slash-Commands `/gearset` und `/vgs` statt `/loadout` und `/lo`
4. `ns.UI:ToggleMainFrame` (`Loadouts.lua:485`) → `ns:ToggleOptions`
5. `mod.ImportLegacy` wird durch den neuen Import aus `Coexistence.lua` ersetzt
6. Locale-Keys von "Loadout" auf "Gear Set" umbenannt (siehe unten)

`SlotPicker.lua` wird unverändert übernommen. Es registriert sich weiterhin unter dem Key
`slotpicker` in der Gruppe `_hidden`, weil seine Einstellungen in der GearSets-Optionsseite
liegen.

### Core/PopupMenu.lua

Wird übernommen. Die drei Framework-Referenzen sind bereits mit Fallbacks geschrieben
(`(ns.COLORS and ns.COLORS.accent) or { r = 0.608, ... }`, `if ns.UI and ns.UI.CreateShadow then`),
also genügt es, `ns.COLORS` in `Namespace.lua` und `CreateShadow` sowie `Font` in
`Widgets.lua` bereitzustellen.

### Locale-Umbenennung

Das Locale-System übernimmt Vulos Muster: die Keys **sind** der englische Text, `enUS.lua`
bleibt leer, und der Metatable-Fallback in `Core/Locale.lua` gibt bei fehlender Übersetzung
den Key zurück. Übersetzt wird nur `deDE.lua`.

Weil das Addon VuloGearSets heißt, werden die sichtbaren Texte von "Loadout" auf "Gear Set"
umgestellt. Von den 116 Keys enthalten 31 das Wort; alle 116 sind auf Deutsch übersetzt.
Da der Key selbst der englische Text ist, bedeutet eine Textänderung immer einen
Key-Wechsel — er muss also gleichzeitig in `GearSets.lua` und in `deDE.lua` passieren.

Das erledigt eine explizite Umbenennungstabelle in `tools/rename_keys.py`, die auf beide
Seiten angewendet wird. Fünf der 31 Keys betreffen den alten kontoweiten Legacy-Import und
werden nicht umbenannt, sondern durch neue Texte für den VuloClassicUI-Import ersetzt.
`tools/check.py` verifiziert anschließend, dass jeder im Code benutzte Key in `deDE.lua`
existiert und dass `deDE.lua` keine verwaisten Keys enthält.

Die deutschen Übersetzungen werden dabei mit übernommen und dort angepasst, wo sie
"Loadout" enthalten — Zielbegriff ist "Ausrüstungsset".

### Core/Mover.lua

Vulos Fassung hat 19 KB, weil sie Layouts serialisiert, benannte Edit-Mode-Profile verwaltet,
Gruppen-Drag beherrscht und Blizzards Edit Mode hookt. VuloGearSets hat genau einen
beweglichen Frame — die Sidebar am Charakterfenster. Die Minimalfassung stellt bereit:

- `ns:CreateMover(frame, key, label)` — Drag-Handle mit lila Overlay, nur sichtbar im Edit-Mode
- `ns:IsMoverEditMode()` — Zustandsabfrage, die `GearSets.lua` bereits benutzt
- Position speichern nach `VuloGearSetsCharDB.sidebarPos`
- Rechtsklick auf das Overlay setzt die Position zurück
- Umschalten über `/vgs unlock`

## Was bewusst nicht mitkommt

Profilsystem, Edit-Mode-Layouts mit Serialisierung, Gruppen-Drag, MediaRegistry und
LibSharedMedia, ColorPicker, Dashboard, Sidebar-Navigation des Hauptfensters, alle übrigen
Vulo-Module. Keine Libs — weder LibStub noch CallbackHandler werden von den beiden Modulen
benötigt.

## Datenmodell

| SavedVariable | Geltungsbereich | Inhalt |
|---|---|---|
| `VuloGearSetsDB` | account | `confirmDelete`, `minimap` (`hidden`, `angle`), `sidebarEnabled`, `sidebarTopOffset`, `sidebarBottomOffset`, `autoSwitchEnabled`, `specSwitchEnabled`, SlotPicker `modifier` und `cols` |
| `VuloGearSetsCharDB` | pro Charakter | `sets`, `specMapping`, `formMapping`, `sidebarPos`, `modEnabled`, `imported` |

Die Trennung entspricht dem Original: Sets referenzieren die Ausrüstung eines bestimmten
Charakters und gehören deshalb samt ihrer Spec- und Form-Bindungen in die Char-DB, während
reine Darstellungsoptionen account-weit gelten.

Das Set-Format bleibt unverändert:
`{ [name] = { slots = { [slotID] = itemLink }, createdAt = epoch, formIdx = nil, icon = nil } }`

## Ablauf bei PLAYER_LOGIN

Die Reihenfolge ist bindend:

1. **DB initialisieren** — Defaults mergen, fehlende Tabellen anlegen.
2. **Import** — wenn `VuloGearSetsCharDB.imported` nicht gesetzt ist und
   `_G.VuloClassicUICharDB` existiert: `loadouts`, `specMapping` und `formMapping` per
   DeepCopy übernehmen, `imported = true` setzen, einmalig eine Chat-Meldung mit der Anzahl
   ausgeben. Vulos SavedVariables werden nur gelesen, nie geschrieben.
3. **Konflikt-Check** — ist VuloClassicUI geladen und dessen Loadouts-Modul aktiv, geht
   VuloGearSets in den Schlafmodus.

Import vor Konflikt-Check ist entscheidend: läge es umgekehrt, könnte ein Nutzer mit aktivem
VuloClassicUI seine Sets nie übernehmen.

### Konflikt-Erkennung

Vulos Modul-Zustand liegt per Charakter in `VuloClassicUICharDB.modEnabled[key]` und fällt
sonst auf den Profil-Default zurück:

```lua
local function vuloLoadoutsActive()
    if not (C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded)("VuloClassicUI") then
        return false
    end
    local charDB = _G.VuloClassicUICharDB
    local ov = charDB and charDB.modEnabled
    if ov and ov.loadouts ~= nil then
        return ov.loadouts and true or false
    end
    local db   = _G.VuloClassicUIDB
    local prof = db and db.profiles and db.profiles[db.activeProfile or "Default"]
    local m    = prof and prof.modules and prof.modules.loadouts
    -- Vulo setzt enabled per Default auf true; nur ein explizites false zählt als aus.
    return not (m and m.enabled == false)
end
```

Lässt sich der Zustand nicht ermitteln, gilt er als aktiv. Diese konservative Annahme
verhindert doppelte Minimap-Buttons, doppelte Sidebars und doppelte Slot-Hooks.

### Schlafmodus

Es werden keine Frames erzeugt, keine Events registriert, keine Blizzard-Slots gehookt und
keine Slash-Commands außer `/vgs` registriert. Einmal pro Session erscheint im Chat der
Hinweis, dass VuloClassicUI das Modul bereits bereitstellt und wo man eins von beiden
abschalten kann. `/vgs` bleibt nutzbar und meldet den Zustand.

## Optionsoberfläche

Ein einzelnes Fenster, kein Sidebar-Navigationsbaum. Aufbau: Titelzeile mit Schließen-Button,
darunter ein Scrollbereich, in den `OptionsFrame.lua` die Item-Liste aus `mod:GetOptions()`
rendert. Geöffnet über `/gearset config`, Rechtsklick auf den Minimap-Button oder
`ns:ToggleOptions()`.

Es gibt kein Eingabefeld-Widget: die Optionsliste kennt keinen Eingabetyp, und die
Namensabfrage beim Speichern läuft wie im Original über Blizzards `StaticPopup`.

Der Renderer muss die neun Typen unterstützen, die `GetOptions()` tatsächlich verwendet:
`header`, `desc`, `spacer`, `button`, `toggle`, `slider`, `dropdown`, `group` und `section`.
Jeder Typ ist eine eigene Funktion mit einheitlicher Signatur `(parent, item, y, width)`, die
die Höhe des erzeugten Blocks zurückgibt; `section` und `group` rufen den Renderer rekursiv
auf ihren `items`-Tabellen auf. Damit bleibt jeder Typ einzeln testbar und neue Typen kosten
je eine Funktion.

Die Setter werden als `set(nil, value)` aufgerufen. Diese Signatur stammt aus Vulos
OptionsBuilder und muss beibehalten werden, weil `GetOptions()` sie so schreibt.

Optik: dunkler Hintergrund, lila Akzent aus `ns.COLORS.accent` (0.608, 0.424, 1) und
`Media/Fonts/Expressway.TTF` als Schrift — alles wie in VuloClassicUI, damit die beiden
Addons nebeneinander stimmig aussehen. `UI.Font` fällt auf `STANDARD_TEXT_FONT` zurück,
falls `SetFont` fehlschlägt; ohne diesen Rückfall wäre der Text bei fehlender Schriftdatei
unsichtbar statt nur anders.

Nicht übernommen werden die Masken-Texturen des runden Pill-Toggles. Der Schalter ist ein
Kästchen mit Füllung — funktional gleichwertig, eine Textur weniger im Paket.

## Slash-Commands

`/gearset` mit den Subcommands des Originals (`save`, `equip`, `spec`, `delete`, `list`,
`debug`, `tune`) plus zwei neuen: `unlock` schaltet den Verschiebemodus der Seitenleiste — in
VuloClassicUI erledigt das ein eigenes UnlockMode-Modul — und `config` öffnet das
Optionsfenster, was nötig ist, weil sich der Minimap-Button ausblenden lässt. Der Subcommand
`import` entfällt, weil der Import automatisch läuft.

`/vgs` wird in `Core/Init.lua` registriert statt im Modul, weil er auch im Schlafmodus
antworten muss; im Wachzustand reicht er an den Modul-Handler weiter.

`/gs` bleibt bewusst frei — das ist historisch von GearScore-Addons belegt.

## Fehlerbehandlung

Übernommen aus dem Original und nicht neu erfunden:

- Equippen im Kampf wird abgelehnt, mit Meldung im Chat
- Fehlt ein Item aus einem Set in den Taschen, wird der Slot übersprungen und am Ende
  gesammelt gemeldet, statt den Vorgang abzubrechen
- `ns:SafeEnable` und `ns:SafeDisable` rufen `OnEnable`/`OnDisable` in `pcall`, ein Fehler in
  einem Modul legt nicht das Addon lahm
- Auto-Switch reagiert nicht während des Kampfes; der Wechsel wird bis
  `PLAYER_REGEN_ENABLED` verschoben

## Tests

Es gibt für WoW-Addons keine sinnvolle Unit-Test-Ebene ohne WoW-API-Mock, deshalb manuell,
im Spiel, gegen diese Liste:

1. Frische Installation ohne VuloClassicUI: Set speichern, ausrüsten, löschen, Liste anzeigen
2. Sidebar: erscheint am Charakterfenster, Icon-Picker, Slot-Ersetzen, Drag im Unlock-Modus,
   Rechtsklick-Reset, Position übersteht `/reload`
3. Minimap-Button: Linksklick-Menü, Rechtsklick öffnet Optionen, Drag, Ausblenden
4. SlotPicker: Rechtsklick auf jeden der 17 Slots, alle vier Modifier-Varianten, Spaltenzahl
5. Auto-Switch: Stance-Wechsel beim Krieger, Form-Wechsel beim Druiden, Dual-Spec-Wechsel
6. Kampf: Equippen im Kampf wird sauber abgelehnt, verschobener Wechsel läuft nach Kampfende
7. Import: mit installiertem VuloClassicUI und vorhandenen Loadouts starten, Sets erscheinen,
   Vulos Daten unverändert, zweiter Start importiert nicht erneut
8. Koexistenz: Vulo-Modul aktiv → Schlafmodus, genau ein Hinweis, keine doppelten Frames;
   Vulo-Modul deaktiviert → VuloGearSets übernimmt nach `/reload`
9. Beide Sprachen durchklicken, keine sichtbaren rohen Schlüssel

## Bekannte Einschränkung

Wer VuloClassicUI deinstalliert, **bevor** er VuloGearSets zum ersten Mal startet, hat keine
SavedVariables mehr zum Auslesen — der Import läuft dann ins Leere und die Set-Liste bleibt
leer. Die Reihenfolge "erst VuloGearSets starten, dann Vulo entfernen" gehört in die README.
