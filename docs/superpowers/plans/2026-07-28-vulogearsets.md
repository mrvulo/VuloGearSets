# VuloGearSets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das Ausrüstungsset-Modul aus VuloClassicUI als eigenständiges Addon `VuloGearSets` ausliefern, das ohne VuloClassicUI läuft, eine eigene Optionsoberfläche mitbringt und bestehende Sets beim ersten Start übernimmt.

**Architecture:** Die beiden Quellmodule (`Loadouts.lua`, `SlotPicker.lua`, zusammen 2188 Zeilen) werden möglichst wörtlich übernommen. Darunter kommt ein schlanker Ersatz für die Teile des Vulo-Frameworks, die sie benutzen: Namespace, Locale, Datenbank ohne Profilsystem, Modulregistry, Events, PopupMenu, ein Ein-Frame-Mover und ein Optionsfenster, das die vorhandene deklarative `GetOptions()`-Liste rendert. Ein Koexistenz-Modul erkennt ein aktives VuloClassicUI, importiert einmalig dessen Sets und legt sich dann schlafen.

**Tech Stack:** Lua 5.1 (WoW-Client), WoW-API Interface 20505 (TBC Classic Anniversary). Keine externen Libs. Python 3 nur für Build-/Prüfwerkzeuge auf dem Entwicklungsrechner, nie zur Laufzeit.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-07-28-vulogearsets-standalone-design.md`. Bei Abweichung gilt die Spec.
- **Zielverzeichnis Entwicklung:** `C:\Users\aobiw\Desktop\Test\VuloGearSets\`
- **Zielverzeichnis Spiel:** `C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\VuloGearSets\`
- **Referenzquelle (nur lesen, nie ändern):** `C:\Users\aobiw\Desktop\entpackte addons\VuloClassicUI\`
- **Lua-Dialekt:** Lua 5.1. Kein `goto`, kein `//`, keine Bitoperatoren, kein `#!`-Shebang. String-Verkettung mit `..`.
- **Interface-Version:** exakt `20505`.
- **Sprache im Code:** Alle nutzersichtbaren Texte und alle Chat-/Log-Ausgaben auf Englisch. Code-Kommentare auf Deutsch.
- **Locale-Muster:** Keys **sind** der englische Text. `Locales/enUS.lua` bleibt leer, der Metatable-Fallback liefert den Key. Übersetzt wird nur `deDE.lua`.
- **Begriff:** Nutzersichtbar heißt es "gear set" bzw. "Ausrüstungsset", nicht "loadout". Ausnahme: der Slash-Alias und interne Variablennamen dürfen bleiben, wo sie nicht sichtbar sind.
- **Akzentfarbe:** `r = 0.608, g = 0.424, b = 1` (dasselbe Lila wie VuloClassicUI).
- **SavedVariables:** `VuloGearSetsDB` (account), `VuloGearSetsCharDB` (pro Charakter). Vulos SavedVariables werden ausschließlich gelesen.
- **Nach jeder Task:** `python tools/check.py` muss fehlerfrei durchlaufen.
- **Commits:** Deutsche Commit-Messages, kein `Co-Authored-By`, keine Fremdaddon-Namen außer VuloClassicUI.

## Ausgangszustand des Repos

Das Repository ist bereits eingerichtet: `C:\Users\aobiw\Desktop\Test\VuloGearSets` ist ein
Git-Repo auf dem Branch `main`, mit einem ersten Commit, der `.gitignore`, diesen Plan, die
Spezifikation und `Media/Fonts/Expressway.TTF` enthält.

**Der Repo-Root ist zugleich der Addon-Ordner** — `VuloGearSets.toc` liegt direkt im Root.
Alle Pfadangaben in diesem Plan sind relativ dazu. `docs/` und `tools/` liegen mit im Repo;
WoW ignoriert sie, weil sie nicht in der TOC stehen.

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `VuloGearSets.toc` | Ladereihenfolge, SavedVariables, Metadaten |
| `Core/Namespace.lua` | `ns`, `ns.COLORS`, `Print`, `Debug`, `DeepCopy`, `ApplyDefaults` |
| `Core/Compat.lua` | `ns:IsAddOnLoaded` über `C_AddOns` mit Fallback |
| `Core/Locale.lua` | `ns.L`-Metatable, `RegisterLocale`, `GetActiveLocale` |
| `Core/Database.lua` | `InitDB`, Defaults-Merge, `GetModuleDB` — ohne Profilsystem |
| `Core/Modules.lua` | `RegisterModule`, `IsModuleEnabled`, `ToggleModule`, `SafeEnable/Disable` |
| `Core/Events.lua` | `RegisterEvent`, `UnregisterEvent` über einen gemeinsamen Frame |
| `Core/PopupMenu.lua` | `ShowPopupMenu`, `HidePopupMenu` |
| `Core/Mover.lua` | `CreateMover`, `IsMoverEditMode`, `SetMoversEditMode` für einen Frame |
| `Core/Coexistence.lua` | Vulo-Erkennung, Einmal-Import, Schlafmodus |
| `Core/Init.lua` | `PLAYER_LOGIN`-Ablauf, Reihenfolge Import → Konflikt → Module |
| `UI/Widgets.lua` | Backdrop, Shadow, Font, Button, Toggle, Slider, Dropdown |
| `UI/OptionsFrame.lua` | Fenster + Renderer für die neun `GetOptions()`-Item-Typen |
| `Locales/enUS.lua` | leer, dokumentiert nur das Muster |
| `Locales/deDE.lua` | deutsche Übersetzungen |
| `Modules/GearSets.lua` | portiert aus `Loadouts.lua` |
| `Modules/SlotPicker.lua` | portiert aus `SlotPicker.lua` |
| `Media/Fonts/Expressway.TTF` | Schrift, liegt bereits im Repo |
| `tools/check.py` | TOC-, Locale- und Kopplungsprüfung |
| `tools/extract_locales.py` | zieht benutzte Keys aus Vulos `deDE.lua` |
| `tools/rename_keys.py` | wendet die Umbenennungstabelle an |
| `tools/deploy.ps1` | kopiert das Addon ins Spielverzeichnis |

---

### Task 1: Gerüst, Namespace und Prüfwerkzeug

Am Ende dieser Task lädt WoW ein leeres, fehlerfreies Addon und `check.py` prüft die Struktur.

**Files:**
- Create: `VuloGearSets.toc`
- Create: `Core/Namespace.lua`
- Create: `Core/Compat.lua`
- Create: `Core/Locale.lua`
- Create: `Locales/enUS.lua`
- Create: `Locales/deDE.lua`
- Create: `tools/check.py`
- Create: `tools/deploy.ps1`

**Interfaces:**
- Produces: `ns.COLORS.accent/bg/bgLight/border/borderDark/text/textDim` (Tabellen mit `r`,`g`,`b`), `ns:Print(fmt, ...)`, `ns:Debug(fmt, ...)`, `ns:DeepCopy(tbl)`, `ns:ApplyDefaults(target, defaults)`, `ns.L`, `ns:RegisterLocale(code, tbl)`, `ns:GetActiveLocale()`, `ns:IsAddOnLoaded(name)`

- [ ] **Step 1: Ordner anlegen**

Die Ordner `Core/`, `UI/`, `Locales/`, `Modules/`, `Media/Fonts/`, `tools/` und `docs/`
existieren bereits aus dem Repo-Setup. Gegenprobe:

```powershell
Get-ChildItem "C:\Users\aobiw\Desktop\Test\VuloGearSets" -Directory | Select-Object Name
```

Expected: `Core`, `docs`, `Locales`, `Media`, `Modules`, `tools`, `UI`

- [ ] **Step 2: `tools/check.py` schreiben**

Das ist der Prüfer, der nach jeder Task läuft. Er kennt vier Fehlerklassen, die beim Auskoppeln real auftreten.

```python
"""Struktur- und Kopplungspruefung fuer VuloGearSets."""
import re
import sys
from pathlib import Path

# Repo-Root ist zugleich der Addon-Ordner.
ADDON = Path(__file__).resolve().parent.parent
TOC = ADDON / "VuloGearSets.toc"

# Ordner ohne Addon-Code, die der Pruefer nicht anfassen darf.
SKIP_DIRS = {"docs", "tools"}

# Nur diese Datei darf VuloClassicUI-Globals lesen.
COEXIST_FILE = "Core/Coexistence.lua"

# Symbole aus dem Vulo-Framework, die es hier nicht mehr gibt.
FORBIDDEN = [
    (r"ns\.UI\s*[:.]\s*ToggleMainFrame", "ns.UI:ToggleMainFrame gibt es hier nicht"),
    (r"ns\s*:\s*OpenConfig", "ns:OpenConfig heisst hier ns:ToggleOptions"),
    (r"LibStub", "keine Libs im Standalone"),
    (r"ns\s*:\s*GetModuleDB\s*\(\s*\)", "GetModuleDB braucht einen Key"),
]

errors = []


def lua_files():
    return sorted(
        p for p in ADDON.rglob("*.lua")
        if not set(p.relative_to(ADDON).parts) & SKIP_DIRS
    )


def rel(p):
    return p.relative_to(ADDON).as_posix()


def check_toc():
    if not TOC.exists():
        errors.append(f"TOC fehlt: {TOC}")
        return
    listed = []
    for line in TOC.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        listed.append(line.replace("\\", "/"))
    on_disk = {rel(p) for p in lua_files()}
    for entry in listed:
        if entry not in on_disk:
            errors.append(f"TOC listet nicht vorhandene Datei: {entry}")
    for f in sorted(on_disk - set(listed)):
        errors.append(f"Datei nicht in der TOC gelistet: {f}")


def used_locale_keys():
    """Alle L["..."]-Keys aus dem Addon-Code, ohne die Locale-Dateien selbst."""
    keys = set()
    pattern = re.compile(r'L\["((?:[^"\\]|\\.)*)"\]')
    for p in lua_files():
        if rel(p).startswith("Locales/"):
            continue
        keys.update(pattern.findall(p.read_text(encoding="utf-8")))
    return keys


def defined_locale_keys():
    p = ADDON / "Locales" / "deDE.lua"
    if not p.exists():
        return set()
    pattern = re.compile(r'\["((?:[^"\\]|\\.)*)"\]\s*=')
    return set(pattern.findall(p.read_text(encoding="utf-8")))


def check_locales():
    used = used_locale_keys()
    defined = defined_locale_keys()
    for k in sorted(used - defined):
        errors.append(f"Key ohne deutsche Uebersetzung: {k!r}")
    for k in sorted(defined - used):
        errors.append(f"Verwaister Key in deDE.lua: {k!r}")


def check_coupling():
    for p in lua_files():
        name = rel(p)
        text = p.read_text(encoding="utf-8")
        if name != COEXIST_FILE and "VuloClassicUI" in text:
            errors.append(f"{name}: VuloClassicUI darf nur in {COEXIST_FILE} vorkommen")
        for pattern, msg in FORBIDDEN:
            if re.search(pattern, text):
                errors.append(f"{name}: {msg}")


def check_lua5_1():
    """Lua-5.2+-Syntax, die der WoW-Client nicht versteht."""
    for p in lua_files():
        text = p.read_text(encoding="utf-8")
        for n, line in enumerate(text.splitlines(), 1):
            code = line.split("--", 1)[0]
            if "::" in code and "goto" not in code:
                continue
            if re.search(r"\bgoto\b", code):
                errors.append(f"{rel(p)}:{n}: goto gibt es in Lua 5.1 nicht")


def main():
    if not TOC.exists():
        print(f"FEHLER: {TOC} existiert nicht")
        return 1
    check_toc()
    check_locales()
    check_coupling()
    check_lua5_1()
    if errors:
        print(f"{len(errors)} Problem(e):")
        for e in errors:
            print(f"  - {e}")
        return 1
    print(f"OK - {len(lua_files())} Lua-Dateien, {len(used_locale_keys())} Locale-Keys")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: `tools/deploy.ps1` schreiben**

```powershell
# Kopiert das Addon ins Anniversary-AddOns-Verzeichnis.
# Repo-Root ist der Addon-Ordner; .git, docs und tools bleiben draussen.
$src = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$dst = "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\VuloGearSets"

if (-not (Test-Path (Join-Path $src "VuloGearSets.toc"))) {
    throw "Keine TOC in $src - falscher Ordner?"
}
if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
New-Item -ItemType Directory -Force $dst | Out-Null

Copy-Item (Join-Path $src "VuloGearSets.toc") $dst
foreach ($d in 'Core', 'UI', 'Locales', 'Modules', 'Media') {
    $p = Join-Path $src $d
    if (Test-Path $p) { Copy-Item $p $dst -Recurse -Force }
}
Write-Output "Deployed nach $dst"
```

Schlägt das Kopieren mit "Zugriff verweigert" fehl, muss PowerShell als Administrator laufen — das AddOns-Verzeichnis liegt unter `Program Files (x86)`.

- [ ] **Step 4: `VuloGearSets.toc` schreiben**

Zunächst nur die Dateien dieser Task. Jede spätere Task ergänzt ihre Zeilen.

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
```

- [ ] **Step 5: `Core/Namespace.lua` schreiben**

```lua
-- =========================================================
-- VuloGearSets / Core / Namespace
-- Basis-Namespace, Farben und die Helfer, die ueberall gebraucht werden.
-- =========================================================
local addonName, ns = ...

ns.ADDON_NAME  = addonName
ns.VERSION     = "1.0.0"
ns.modules     = {}
ns.moduleOrder = {}

-- Dieselbe Palette wie VuloClassicUI, damit beide Addons zusammenpassen.
ns.COLORS = {
    accent     = { r = 0.608, g = 0.424, b = 1 },
    bg         = { r = 0.06,  g = 0.06,  b = 0.08 },
    bgLight    = { r = 0.11,  g = 0.11,  b = 0.14 },
    border     = { r = 0.18,  g = 0.18,  b = 0.22 },
    borderDark = { r = 0.02,  g = 0.02,  b = 0.03 },
    text       = { r = 0.90,  g = 0.90,  b = 0.92 },
    textDim    = { r = 0.60,  g = 0.60,  b = 0.65 },
}

local PREFIX = "|cff9b6cffVuloGearSets|r: "

function ns:Print(fmt, ...)
    if not fmt then return end
    local msg = fmt
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, fmt, ...)
        if ok then msg = formatted end
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

-- Nur aktiv, wenn jemand VuloGearSetsDB.debug von Hand setzt.
function ns:Debug(fmt, ...)
    local db = _G.VuloGearSetsDB
    if not (db and db.debug) then return end
    ns:Print("|cff888888[debug]|r " .. tostring(fmt), ...)
end

function ns:DeepCopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do
        out[k] = (type(v) == "table") and ns:DeepCopy(v) or v
    end
    return out
end

-- Ergaenzt fehlende Default-Werte, ohne vorhandene zu ueberschreiben.
function ns:ApplyDefaults(target, defaults)
    if type(target) ~= "table" then target = {} end
    if type(defaults) ~= "table" then return target end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            target[k] = ns:ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end
```

- [ ] **Step 6: `Core/Compat.lua` schreiben**

Die Container-Funktionen bekommen hier **keinen** Shim: `GearSets.lua` und `SlotPicker.lua` bringen ihre eigenen lokalen Fallbacks mit (`local GetContainerItemID = (C_Container and ...) or _G....`) und werden unverändert übernommen. Ein zweiter Satz im Namespace wäre toter Code.

```lua
-- =========================================================
-- VuloGearSets / Core / Compat
-- API-Shims fuer das, was die Module NICHT selbst abfangen.
-- Die Container-Funktionen bringen GearSets und SlotPicker
-- bereits als eigene lokale Fallbacks mit.
-- =========================================================
local _, ns = ...

function ns:IsAddOnLoaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    if not fn then return false end
    local ok, loaded = pcall(fn, name)
    return ok and loaded and true or false
end
```

- [ ] **Step 7: `Core/Locale.lua` schreiben**

Übernommen aus Vulo, ohne den Sprachumschalter (das Standalone folgt immer der Clientsprache).

```lua
-- =========================================================
-- VuloGearSets / Core / Locale
-- Die Keys SIND der englische Text. Fehlt eine Uebersetzung,
-- liefert der Fallback den Key zurueck.
-- =========================================================
local _, ns = ...

ns.localeData = ns.localeData or {}

local _cached = nil

local function resolveLocale()
    if _cached then return _cached end
    _cached = (GetLocale and GetLocale()) or "enUS"
    return _cached
end

ns.L = setmetatable({}, {
    __index = function(_, key)
        local data = ns.localeData[resolveLocale()]
        if data and data[key] then return data[key] end
        return key
    end,
})

function ns:RegisterLocale(code, tbl)
    if type(code) ~= "string" or type(tbl) ~= "table" then return end
    ns.localeData[code] = ns.localeData[code] or {}
    for k, v in pairs(tbl) do
        ns.localeData[code][k] = v
    end
end

function ns:GetActiveLocale()
    return resolveLocale()
end
```

- [ ] **Step 8: `Locales/enUS.lua` und `Locales/deDE.lua` als Gerüst anlegen**

```lua
-- =========================================================
-- VuloGearSets / Locales / enUS
-- Leer mit Absicht: Englisch ist die Default-Sprache und die Keys
-- in L["..."] sind bereits der englische Text.
-- =========================================================
local _, ns = ...

ns:RegisterLocale("enUS", {})
```

```lua
-- =========================================================
-- VuloGearSets / Locales / deDE
-- Format: ["English key"] = "Deutsche Uebersetzung",
-- Wird in Task 3 befuellt.
-- =========================================================
local _, ns = ...

ns:RegisterLocale("deDE", {})
```

- [ ] **Step 9: Prüfer laufen lassen**

Run: `python tools/check.py`
Expected: `OK - 5 Lua-Dateien, 0 Locale-Keys`

- [ ] **Step 10: Im Spiel verifizieren**

Run: `powershell -File tools/deploy.ps1`

Dann WoW starten (Anniversary-Client), an der Charakterauswahl auf AddOns klicken. Erwartet: `VuloGearSets` steht in der Liste, ist aktivierbar und zeigt kein "Out of date". Nach dem Einloggen zeigt BugSack keine Fehler (Minimap-Icon bleibt grau).

- [ ] **Step 11: Commit**

```bash
git add VuloGearSets tools docs
git commit -m "Grundgeruest fuer VuloGearSets mit Namespace, Locale und Pruefwerkzeug"
```

---

### Task 2: Datenbank, Modulregistry und Events

**Files:**
- Create: `Core/Database.lua`
- Create: `Core/Modules.lua`
- Create: `Core/Events.lua`
- Modify: `VuloGearSets.toc`

**Interfaces:**
- Consumes: `ns:ApplyDefaults`, `ns:Print`, `ns:Debug`, `ns.L` aus Task 1
- Produces: `ns:InitDB()`, `ns:GetCharDB()`, `ns:RegisterModule(key, def)` → gibt `def` zurück mit `def.db` nach `InitDB`, `ns:IsModuleEnabled(key)` → boolean, `ns:SetModuleEnabledPref(key, state)`, `ns:ToggleModule(key, state, silent)`, `ns:EnableModules()`, `ns:SafeEnable(mod)`, `ns:SafeDisable(mod)`, `ns:RegisterEvent(event, handler)`, `ns:UnregisterEvent(event, handler)`

- [ ] **Step 1: `Core/Database.lua` schreiben**

Kein Profilsystem: die Modul-Settings liegen flach unter `VuloGearSetsDB.modules[key]`.

```lua
-- =========================================================
-- VuloGearSets / Core / Database
-- Zwei SavedVariables, kein Profilsystem:
--   VuloGearSetsDB.modules[key]  -- kontoweite Darstellungsoptionen
--   VuloGearSetsCharDB           -- Sets, Bindungen, Position
-- =========================================================
local _, ns = ...

function ns:GetCharDB()
    _G.VuloGearSetsCharDB = _G.VuloGearSetsCharDB or {}
    return _G.VuloGearSetsCharDB
end

function ns:InitDB()
    _G.VuloGearSetsDB = _G.VuloGearSetsDB or {}
    local db = _G.VuloGearSetsDB
    db.modules = db.modules or {}

    for key, mod in pairs(ns.modules) do
        db.modules[key] = ns:ApplyDefaults(db.modules[key], mod.defaults or {})
        mod.db = db.modules[key]
    end

    local char = ns:GetCharDB()
    char.sets        = char.sets        or {}
    char.specMapping = char.specMapping or {}
    char.formMapping = char.formMapping or {}
    char.modEnabled  = char.modEnabled  or {}

    ns.db = db
end
```

- [ ] **Step 2: `Core/Modules.lua` schreiben**

Übernimmt Vulos Semantik: der Ein/Aus-Zustand liegt pro Charakter, alle übrigen Einstellungen kontoweit.

```lua
-- =========================================================
-- VuloGearSets / Core / Modules
-- Modulregistry.
--
-- def = {
--   name        = "Anzeigename",
--   description = "Was das Modul tut",
--   defaults    = { enabled = true, ... },
--   OnEnable    = function(self) end,
--   OnDisable   = function(self) end,
--   GetOptions  = function(self) return { ... } end,
-- }
-- =========================================================
local _, ns = ...
local L = ns.L

function ns:RegisterModule(key, def)
    if ns.modules[key] then
        ns:Print(L["WARN: Module '%s' already registered."], key)
        return ns.modules[key]
    end
    def.key      = key
    def.name     = def.name or key
    def.defaults = def.defaults or {}
    if def.defaults.enabled == nil then
        def.defaults.enabled = true
    end
    ns.modules[key] = def
    table.insert(ns.moduleOrder, key)
    return def
end

-- Ein/Aus liegt PRO CHARAKTER, alles andere kontoweit.
function ns:IsModuleEnabled(key)
    local mod = ns.modules[key]
    if not mod then return false end
    local ov = ns:GetCharDB().modEnabled
    if ov[key] ~= nil then return ov[key] end
    return (mod.db and mod.db.enabled) and true or false
end

function ns:SetModuleEnabledPref(key, state)
    ns:GetCharDB().modEnabled[key] = state and true or false
end

function ns:SafeEnable(mod)
    if mod._enabled then return end
    if not mod.OnEnable then mod._enabled = true; return end
    local ok, err = pcall(mod.OnEnable, mod)
    if not ok then
        ns:Print(L["|cffff5555Error enabling module '%s':|r %s"], mod.name, tostring(err))
        return
    end
    mod._enabled = true
    ns:Debug("Module enabled: %s", mod.name)
end

function ns:SafeDisable(mod)
    if not mod._enabled then return end
    if mod.OnDisable then
        local ok, err = pcall(mod.OnDisable, mod)
        if not ok then
            ns:Print(L["|cffff5555Error disabling '%s':|r %s"], mod.name, tostring(err))
        end
    end
    mod._enabled = false
end

function ns:EnableModules()
    for _, key in ipairs(ns.moduleOrder) do
        local mod = ns.modules[key]
        if mod and ns:IsModuleEnabled(key) then
            ns:SafeEnable(mod)
        end
    end
end

function ns:ToggleModule(key, state, silent)
    local mod = ns.modules[key]
    if not mod then return end
    state = state and true or false
    ns:SetModuleEnabledPref(key, state)
    if state then
        ns:SafeEnable(mod)
    elseif not silent then
        ns:SafeDisable(mod)
        -- Viele Hooks lassen sich zur Laufzeit nicht loesen.
        ns:Print(L["Module '%s' disabled. /reload recommended for full effect."], mod.name)
    else
        ns:SafeDisable(mod)
    end
end
```

- [ ] **Step 3: `Core/Events.lua` schreiben**

```lua
-- =========================================================
-- VuloGearSets / Core / Events
-- Ein gemeinsamer Frame verteilt an beliebig viele Handler.
-- =========================================================
local _, ns = ...

local frame    = CreateFrame("Frame", "VuloGearSetsEventFrame")
local handlers = {}

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    -- Rueckwaerts iterieren, damit ein Handler sich selbst abmelden darf.
    for i = #list, 1, -1 do
        local fn = list[i]
        if fn then
            local ok, err = pcall(fn, event, ...)
            if not ok then ns:Debug("Event %s: %s", event, tostring(err)) end
        end
    end
end)

function ns:RegisterEvent(event, handler)
    if type(event) ~= "string" or type(handler) ~= "function" then return end
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    for _, fn in ipairs(handlers[event]) do
        if fn == handler then return end   -- schon registriert
    end
    table.insert(handlers[event], handler)
end

function ns:UnregisterEvent(event, handler)
    local list = handlers[event]
    if not list then return end
    if handler then
        for i = #list, 1, -1 do
            if list[i] == handler then table.remove(list, i) end
        end
    else
        wipe(list)
    end
    if #list == 0 then
        handlers[event] = nil
        frame:UnregisterEvent(event)
    end
end
```

- [ ] **Step 4: TOC ergänzen**

Nach `Locales\deDE.lua` einfügen:

```
Core\Database.lua
Core\Modules.lua
Core\Events.lua
```

- [ ] **Step 5: Prüfer laufen lassen**

Run: `python tools/check.py`
Expected: `OK - 8 Lua-Dateien, ...`

Der Prüfer meldet jetzt fehlende Übersetzungen für die vier Meldungstexte aus `Modules.lua` (`WARN: Module '%s' already registered.` usw.). Das ist erwartet und wird in Task 3 behoben. Bis dahin gilt: Der Locale-Check darf diese vier melden, sonst nichts.

- [ ] **Step 6: Commit**

```bash
git add VuloGearSets
git commit -m "Datenbank, Modulregistry und Eventverteilung ergaenzt"
```

---

### Task 3: Locales extrahieren und Begriffe umstellen

Erzeugt die deutsche Übersetzungsdatei aus VuloClassicUI und stellt dabei "Loadout" auf "Gear Set" um.

**Files:**
- Create: `tools/extract_locales.py`
- Create: `tools/rename_keys.py`
- Modify: `Locales/deDE.lua`

**Interfaces:**
- Produces: `RENAME_MAP` in `tools/rename_keys.py` — ein `dict[str, str]` von altem auf neuen englischen Key. Task 8 und 9 wenden dieselbe Tabelle auf den portierten Modulcode an.

- [ ] **Step 1: `tools/rename_keys.py` mit der Umbenennungstabelle schreiben**

Die Tabelle ist bewusst explizit statt regelbasiert — "loadout" durch "gear set" zu ersetzen produziert sonst Grammatikfehler wie "a gear sets".

```python
"""Umbenennungstabelle Loadout -> Gear Set, plus Anwendung auf Lua-Dateien."""
import sys
from pathlib import Path

# Alter englischer Key -> neuer englischer Key.
# Die Keys sind gleichzeitig der sichtbare Text, deshalb aendert jede
# Textaenderung auch den Key. Beide Seiten (Code + deDE) muessen zusammen wandern.
RENAME_MAP = {
    "Loadouts":
        "Gear Sets",
    "Saved Loadouts":
        "Saved Gear Sets",
    "Saved loadouts:":
        "Saved gear sets:",
    "Confirm before deleting a loadout":
        "Confirm before deleting a gear set",
    "Delete loadout '%s'?":
        "Delete gear set '%s'?",
    "Loadout '%s' already equipped.":
        "Gear set '%s' already equipped.",
    "Loadout '%s' deleted.":
        "Gear set '%s' deleted.",
    "Loadout '%s' does not exist.":
        "Gear set '%s' does not exist.",
    "Loadout '%s' equipped (%d items swapped).":
        "Gear set '%s' equipped (%d items swapped).",
    "Loadout '%s' equipped (%d swapped, %d missing from bags).":
        "Gear set '%s' equipped (%d swapped, %d missing from bags).",
    "Loadout '%s' saved (%d items).":
        "Gear set '%s' saved (%d items).",
    "Loadout '%s' updated with current gear.":
        "Gear set '%s' updated with current gear.",
    "Loadout '%s': %d items missing from bags, nothing swapped.":
        "Gear set '%s': %d items missing from bags, nothing swapped.",
    "Loadout '%s': slot updated.":
        "Gear set '%s': slot updated.",
    "No loadouts saved yet.":
        "No gear sets saved yet.",
    "Please provide a name for the loadout.":
        "Please provide a name for the gear set.",
    "Save current equipment as a new loadout. Enter name:":
        "Save current equipment as a new gear set. Enter name:",
    "Equip this loadout automatically when the chosen stance/form is activated.":
        "Equip this gear set automatically when the chosen stance/form is activated.",
    "Equip this loadout automatically when you switch to this spec.":
        "Equip this gear set automatically when you switch to this spec.",
    "Automatically equips a loadout when you switch between Spec 1 and Spec 2 (dual spec). "
    "Bind each loadout to a spec below. Requires dual spec to be active.":
        "Automatically equips a gear set when you switch between Spec 1 and Spec 2 (dual spec). "
        "Bind each gear set to a spec below. Requires dual spec to be active.",
    "Automatically equips a loadout when your stance/form changes (warrior stances, druid forms). "
    "Out-of-combat only \u2014 if a stance change happens in combat, the swap is deferred until combat ends.":
        "Automatically equips a gear set when your stance/form changes (warrior stances, druid forms). "
        "Out-of-combat only \u2014 if a stance change happens in combat, the swap is deferred until combat ends.",
    "Usage: /loadout delete <name>":
        "Usage: /gearset delete <name>",
    "Usage: /loadout equip <name> | save <name> | delete <name> | list":
        "Usage: /gearset equip <name> | save <name> | delete <name> | list",
    "|cffaaaaaaNo loadouts saved yet. Use the button above to save your current gear.|r":
        "|cffaaaaaaNo gear sets saved yet. Use the button above to save your current gear.|r",
    "|cffaaaaaaSlash commands: /loadout save <name>, /loadout equip <name>, "
    "/loadout delete <name>, /loadout list. Short alias: /lo|r":
        "|cffaaaaaaSlash commands: /gearset save <name>, /gearset equip <name>, "
        "/gearset delete <name>, /gearset list. Short alias: /vgs|r",
    "|cffffffffLOADOUTS SIDEBAR|r\\n|cffaaaaaaDrag or arrow keys|r":
        "|cffffffffGEAR SETS SIDEBAR|r\\n|cffaaaaaaDrag or arrow keys|r",
}

# Diese fuenf Keys betreffen den alten kontoweiten Legacy-Import aus Vulo.
# Sie werden nicht umbenannt, sondern in Task 10 durch neue Texte fuer den
# VuloClassicUI-Import ersetzt und hier deshalb ersatzlos entfernt.
DROP_KEYS = [
    "Import account-wide loadouts",
    "Imported %d account-wide loadout(s) onto this character.",
    "No account-wide loadouts to import.",
    "You have account-wide loadouts from an older version. Type /lo import to copy them onto this character.",
    "|cffaaaaaaYou have gear sets saved account-wide by an older version. Loadouts are now per-character "
    "\u2014 import copies them onto THIS character.|r",
]


def apply_to_file(path: Path) -> int:
    """Ersetzt alte durch neue Keys. Gibt die Anzahl der Ersetzungen zurueck."""
    text = path.read_text(encoding="utf-8")
    count = 0
    # Laengste zuerst, damit "Loadouts" nicht Teiltreffer in laengeren Keys zerstoert.
    for old in sorted(RENAME_MAP, key=len, reverse=True):
        needle = f'"{old}"'
        if needle in text:
            count += text.count(needle)
            text = text.replace(needle, f'"{RENAME_MAP[old]}"')
    path.write_text(text, encoding="utf-8")
    return count


if __name__ == "__main__":
    total = 0
    for arg in sys.argv[1:]:
        n = apply_to_file(Path(arg))
        print(f"{arg}: {n} Ersetzungen")
        total += n
    print(f"gesamt: {total}")
```

- [ ] **Step 2: `tools/extract_locales.py` schreiben**

```python
"""Zieht die von den beiden Modulen benutzten Keys aus Vulos deDE.lua."""
import re
from pathlib import Path

from rename_keys import DROP_KEYS, RENAME_MAP

VULO = Path(r"C:\Users\aobiw\Desktop\entpackte addons\VuloClassicUI")
SOURCES = [VULO / "Modules" / "Loadouts.lua", VULO / "Modules" / "SlotPicker.lua"]
VULO_DE = VULO / "Locales" / "deDE.lua"
OUT = Path(__file__).resolve().parent.parent / "VuloGearSets" / "Locales" / "deDE.lua"

KEY_IN_CODE = re.compile(r'L\["((?:[^"\\]|\\.)*)"\]')
ENTRY_IN_LOCALE = re.compile(r'\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*,')

HEADER = """-- =========================================================
-- VuloGearSets / Locales / deDE
-- Deutsche Uebersetzungen.
--
-- Format: ["English key"] = "Deutsche Uebersetzung",
-- Fehlende Keys fallen automatisch auf das englische Original zurueck.
-- Erzeugt von tools/extract_locales.py
-- =========================================================
local _, ns = ...

ns:RegisterLocale("deDE", {
"""

FOOTER = "})\n"


def main():
    used = set()
    for src in SOURCES:
        used.update(KEY_IN_CODE.findall(src.read_text(encoding="utf-8")))
    used -= set(DROP_KEYS)

    translations = dict(ENTRY_IN_LOCALE.findall(VULO_DE.read_text(encoding="utf-8")))

    lines, missing = [], []
    for key in sorted(used):
        de = translations.get(key)
        if de is None:
            missing.append(key)
            continue
        # Key mitwandern lassen, wenn er umbenannt wurde.
        new_key = RENAME_MAP.get(key, key)
        lines.append(f'    ["{new_key}"] = "{de}",')

    OUT.write_text(HEADER + "\n".join(lines) + "\n" + FOOTER, encoding="utf-8")
    print(f"{len(lines)} Uebersetzungen nach {OUT.name} geschrieben")
    if missing:
        print(f"WARNUNG: {len(missing)} Keys ohne deutsche Uebersetzung:")
        for k in missing:
            print(f"  - {k}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Extraktion ausführen**

Run: `python tools/extract_locales.py`
Expected: `111 Uebersetzungen nach deDE.lua geschrieben`, keine Warnung. (116 benutzte Keys minus 5 aus `DROP_KEYS`.)

Erscheint eine Warnung über fehlende Übersetzungen, ist der Regex an einem Key mit Escape-Sequenz gescheitert — den Key von Hand aus Vulos `deDE.lua` übertragen.

- [ ] **Step 4: Deutsche Texte auf "Ausrüstungsset" durchsehen**

Die übernommenen Übersetzungen enthalten noch "Loadout". In `Locales/deDE.lua` alle Vorkommen auf der **Wertseite** ersetzen: "Loadout" → "Ausrüstungsset", "Loadouts" → "Ausrüstungssets". Die Keys (linke Seite) bleiben unangetastet — die hat `extract_locales.py` bereits umbenannt.

Run zum Auffinden: `python -c "import re,pathlib; p=pathlib.Path('Locales/deDE.lua'); [print(n,l) for n,l in enumerate(p.read_text(encoding='utf-8').splitlines(),1) if 'oadout' in l.split('] = ')[-1]]"`
Expected nach der Korrektur: keine Ausgabe.

- [ ] **Step 5: Die vier Framework-Meldungen ergänzen**

`Core/Modules.lua` benutzt vier Texte, die es in Vulos Loadouts-Modul nicht gab. Von Hand in `deDE.lua` ergänzen:

```lua
    ["WARN: Module '%s' already registered."] = "WARNUNG: Modul '%s' ist bereits registriert.",
    ["|cffff5555Error enabling module '%s':|r %s"] = "|cffff5555Fehler beim Aktivieren von Modul '%s':|r %s",
    ["|cffff5555Error disabling '%s':|r %s"] = "|cffff5555Fehler beim Deaktivieren von '%s':|r %s",
    ["Module '%s' disabled. /reload recommended for full effect."] = "Modul '%s' deaktiviert. /reload wird empfohlen.",
```

- [ ] **Step 6: Prüfer laufen lassen**

Run: `python tools/check.py`
Expected: `OK - 8 Lua-Dateien, 4 Locale-Keys`

Der Prüfer meldet jetzt verwaiste Keys, weil `deDE.lua` 115 Übersetzungen enthält, der Code aber erst vier benutzt. Das ist bis Task 9 erwartet. Danach muss die Meldung verschwinden.

Um die Zwischenzeit ruhig zu halten, in `check.py` `check_locales()` vorübergehend so aufrufen, dass verwaiste Keys nur gezählt statt einzeln gemeldet werden — der Fehler "Key ohne deutsche Übersetzung" bleibt scharf, weil er echte Bugs findet.

- [ ] **Step 7: Commit**

```bash
git add Locales tools
git commit -m "Deutsche Uebersetzungen uebernommen und auf Ausruestungsset umgestellt"
```

---

### Task 4: Widgets und Popup-Menü

**Files:**
- Create: `UI/Widgets.lua`
- Create: `Core/PopupMenu.lua`
- Modify: `VuloGearSets.toc`

**Interfaces:**
- Consumes: `ns.COLORS`, `ns.L` aus Task 1
- Produces: `ns.UI.Font(fs, size, flags)` → FontString, `ns.UI.SetColorBG(frame, r, g, b, a, layer)` → Texture, `ns.UI:CreateShadow(frame)`, `ns.UI:CreateBackdrop(frame)`, `ns.UI:CreateButton(parent, text, width, height)` → Button mit `:SetOnClick(fn)`, `ns.UI:CreateToggle(parent, label)` → Frame mit `:SetChecked(bool)`, `:GetChecked()`, `.OnValueChanged`, `ns.UI:CreateSlider(parent, label, min, max, step)` → Frame mit `:SetValue(n)`, `:GetValue()`, `.OnValueChanged`, `ns.UI:CreateDropdown(parent, label, values)` → Frame mit `:SetValue(v)`, `:GetValue()`, `.OnValueChanged`, `ns:ShowPopupMenu(entries, anchor)`, `ns:HidePopupMenu()`

**Signatur von `ShowPopupMenu`:** `ns:ShowPopupMenu(entries, anchor)` — die Einträge kommen zuerst, der Anker danach. `entries` ist eine Liste aus `{ text = "...", func = fn }`, `{ separator = true }` oder `{ title = true, text = "..." }`. `GearSets.lua:477` ruft es bereits so auf; die Reihenfolge darf nicht gedreht werden.

Es gibt bewusst **kein** EditBox-Widget: die Optionsliste kennt keinen Eingabetyp, und die Namensabfrage beim Speichern läuft über Blizzards `StaticPopup`.

**Hinweis zur Schrift:** VuloGearSets liefert `Media/Fonts/Expressway.TTF` mit, dieselbe Schrift wie VuloClassicUI — sie liegt bereits im Repo. `UI.Font` setzt sie mit einem Rückfall auf `STANDARD_TEXT_FONT`, falls `SetFont` fehlschlägt (fehlende oder beschädigte Datei würde sonst unsichtbaren Text erzeugen).

Die Masken-Texturen für den Pill-Toggle werden **nicht** übernommen; der Toggle bleibt ein einfaches Kästchen mit Füllung. Wer auch die Pill-Optik will, kopiert zusätzlich `Media/Masks/circle_mask.tga` und `csquare_mask.tga` und übernimmt den Toggle-Code aus Vulos `UI/Widgets.lua`.

- [ ] **Step 1: `UI/Widgets.lua` schreiben**

```lua
-- =========================================================
-- VuloGearSets / UI / Widgets
-- Nur die Bausteine, die das Optionsfenster tatsaechlich braucht.
-- Kein Media: Client-Schrift und Volltonflaechen statt eigener Texturen.
-- =========================================================
local _, ns = ...
ns.UI = ns.UI or {}
local UI = ns.UI
local C  = ns.COLORS

-- Dieselbe Schrift wie VuloClassicUI. Schlaegt SetFont fehl (Datei fehlt
-- oder ist beschaedigt), bliebe der Text sonst unsichtbar -> Rueckfall.
local FONT_PATH = "Interface\\AddOns\\VuloGearSets\\Media\\Fonts\\Expressway.TTF"
UI.FONT_PATH = FONT_PATH

function UI.Font(fs, size, flags)
    if not fs:SetFont(FONT_PATH, size or 12, flags or "") then
        fs:SetFont(STANDARD_TEXT_FONT, size or 12, flags or "")
    end
    return fs
end

function UI.SetColorBG(frame, r, g, b, a, layer)
    local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetAllPoints(frame)
    tex:SetColorTexture(r, g, b, a or 1)
    return tex
end

-- Weicher Schatten aus mehreren halbtransparenten Ringen.
function UI:CreateShadow(frame)
    if frame._vgsShadow then return end
    frame._vgsShadow = {}
    local layers = { { 1, 0.45 }, { 3, 0.28 }, { 5, 0.15 }, { 7, 0.07 } }
    for i, l in ipairs(layers) do
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, -8 + (i - 1))
        t:SetPoint("TOPLEFT",     frame, "TOPLEFT",     -l[1],  l[1])
        t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",  l[1], -l[1])
        t:SetColorTexture(0, 0, 0, l[2])
        frame._vgsShadow[i] = t
    end
end

-- Dunkler Grund mit 1px-Rand.
function UI:CreateBackdrop(frame, bg)
    bg = bg or C.bg
    UI.SetColorBG(frame, bg.r, bg.g, bg.b, 0.95)
    local edges = {
        { "TOPLEFT", "TOPRIGHT",       0, 0,  0, 0, 1 },
        { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 0,  0, 0, 1 },
        { "TOPLEFT", "BOTTOMLEFT",     0, 0,  0, 0, 2 },
        { "TOPRIGHT", "BOTTOMRIGHT",   0, 0,  0, 0, 2 },
    }
    for _, e in ipairs(edges) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(C.border.r, C.border.g, C.border.b, 1)
        t:SetPoint(e[1]); t:SetPoint(e[2])
        if e[7] == 1 then t:SetHeight(1) else t:SetWidth(1) end
    end
end

function UI:CreateButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 120, height or 22)
    b.bg = UI.SetColorBG(b, C.bgLight.r, C.bgLight.g, C.bgLight.b, 1)
    b.text = b:CreateFontString(nil, "OVERLAY")
    UI.Font(b.text, 12)
    b.text:SetPoint("CENTER")
    b.text:SetText(text or "")
    b.text:SetTextColor(C.text.r, C.text.g, C.text.b)
    b:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(C.accent.r * 0.5, C.accent.g * 0.5, C.accent.b * 0.5, 1)
    end)
    b:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(C.bgLight.r, C.bgLight.g, C.bgLight.b, 1)
    end)
    function b:SetOnClick(fn)
        self:SetScript("OnClick", function() if fn then fn() end end)
    end
    return b
end

-- Kaestchen mit Haken. OnValueChanged(newState) wird von aussen gesetzt.
function UI:CreateToggle(parent, label)
    local f = CreateFrame("Button", nil, parent)
    f:SetHeight(22)
    f.box = CreateFrame("Frame", nil, f)
    f.box:SetSize(16, 16)
    f.box:SetPoint("LEFT", 0, 0)
    UI.SetColorBG(f.box, C.bgLight.r, C.bgLight.g, C.bgLight.b, 1)
    f.fill = f.box:CreateTexture(nil, "ARTWORK")
    f.fill:SetPoint("TOPLEFT", 3, -3)
    f.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    f.fill:SetColorTexture(C.accent.r, C.accent.g, C.accent.b, 1)
    f.fill:Hide()
    f.label = f:CreateFontString(nil, "OVERLAY")
    UI.Font(f.label, 12)
    f.label:SetPoint("LEFT", f.box, "RIGHT", 8, 0)
    f.label:SetText(label or "")
    f.label:SetTextColor(C.text.r, C.text.g, C.text.b)
    f._checked = false
    function f:GetChecked() return self._checked end
    function f:SetChecked(v)
        self._checked = v and true or false
        if self._checked then self.fill:Show() else self.fill:Hide() end
    end
    f:SetScript("OnClick", function(self)
        self:SetChecked(not self._checked)
        if self.OnValueChanged then self.OnValueChanged(self._checked) end
    end)
    return f
end

function UI:CreateSlider(parent, label, minV, maxV, step)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(44)
    f.label = f:CreateFontString(nil, "OVERLAY")
    UI.Font(f.label, 12)
    f.label:SetPoint("TOPLEFT")
    f.label:SetText(label or "")
    f.label:SetTextColor(C.text.r, C.text.g, C.text.b)

    f.slider = CreateFrame("Slider", nil, f, "OptionsSliderTemplate")
    f.slider:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -6)
    f.slider:SetWidth(200)
    f.slider:SetMinMaxValues(minV or 0, maxV or 100)
    f.slider:SetValueStep(step or 1)
    f.slider:SetObeyStepOnDrag(true)
    -- Die Template-Beschriftungen stoeren das Layout.
    if f.slider.Low  then f.slider.Low:SetText("")  end
    if f.slider.High then f.slider.High:SetText("") end
    if f.slider.Text then f.slider.Text:SetText("") end

    f.value = f:CreateFontString(nil, "OVERLAY")
    UI.Font(f.value, 12)
    f.value:SetPoint("LEFT", f.slider, "RIGHT", 10, 0)
    f.value:SetTextColor(C.accent.r, C.accent.g, C.accent.b)

    f.slider:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v + 0.5)
        f.value:SetText(tostring(v))
        if not f._suppress and f.OnValueChanged then f.OnValueChanged(v) end
    end)
    function f:SetValue(v)
        self._suppress = true
        self.slider:SetValue(v or minV or 0)
        self.value:SetText(tostring(math.floor((v or 0) + 0.5)))
        self._suppress = false
    end
    function f:GetValue() return math.floor(self.slider:GetValue() + 0.5) end
    return f
end

-- values = { { value = "x", text = "Anzeige" }, ... }
function UI:CreateDropdown(parent, label, values)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(46)
    f.values = values or {}
    f.label = f:CreateFontString(nil, "OVERLAY")
    UI.Font(f.label, 12)
    f.label:SetPoint("TOPLEFT")
    f.label:SetText(label or "")
    f.label:SetTextColor(C.text.r, C.text.g, C.text.b)

    f.button = UI:CreateButton(f, "", 220, 22)
    f.button:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -6)
    f.button.text:ClearAllPoints()
    f.button.text:SetPoint("LEFT", 8, 0)

    local arrow = f.button:CreateFontString(nil, "OVERLAY")
    UI.Font(arrow, 12)
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")
    arrow:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)

    function f:SetValue(v)
        self._value = v
        for _, entry in ipairs(self.values) do
            if entry.value == v then self.button.text:SetText(entry.text); return end
        end
        self.button.text:SetText(tostring(v or ""))
    end
    function f:GetValue() return self._value end

    f.button:SetOnClick(function()
        local entries = {}
        for _, entry in ipairs(f.values) do
            table.insert(entries, {
                text = entry.text,
                func = function()
                    f:SetValue(entry.value)
                    if f.OnValueChanged then f.OnValueChanged(entry.value) end
                end,
            })
        end
        -- Achtung: entries kommt ZUERST, dann der Anker.
        ns:ShowPopupMenu(entries, f.button)
    end)
    return f
end
```

- [ ] **Step 2: `Core/PopupMenu.lua` aus VuloClassicUI übernehmen**

Kopieren:

```powershell
Copy-Item "C:\Users\aobiw\Desktop\entpackte addons\VuloClassicUI\Core\PopupMenu.lua" `
          "C:\Users\aobiw\Desktop\Test\VuloGearSets\Core\PopupMenu.lua"
```

Dann in der Kopie genau zwei Dinge ändern:

1. Den Kopfkommentar von `VuloClassicUI / Core / PopupMenu` auf `VuloGearSets / Core / PopupMenu` setzen — sonst schlägt der Kopplungscheck an, der `VuloClassicUI` außerhalb von `Coexistence.lua` verbietet.
2. Falls der Frame einen globalen Namen mit `VuloClassicUI`-Präfix bekommt (`CreateFrame("Frame", "VuloClassicUI...")`), auf `VuloGearSets...` umbenennen.

Die drei Framework-Referenzen (`ns.COLORS.borderDark`, `ns.COLORS.accent`, `ns.UI:CreateShadow`, `ns.UI.Font`) funktionieren unverändert, weil Task 1 und Step 1 sie bereitstellen.

- [ ] **Step 3: Prüfen, dass keine VuloClassicUI-Reste übrig sind**

Run: `python -c "import pathlib; t=pathlib.Path('Core/PopupMenu.lua').read_text(encoding='utf-8'); print('TREFFER' if 'VuloClassicUI' in t else 'sauber')"`
Expected: `sauber`

- [ ] **Step 4: TOC ergänzen**

Nach `Core\Events.lua`:

```
Core\PopupMenu.lua
UI\Widgets.lua
```

- [ ] **Step 5: Prüfer laufen lassen**

Run: `python tools/check.py`
Expected: keine Fehler außer den bekannten verwaisten Locale-Keys

- [ ] **Step 6: Im Spiel verifizieren**

Nach `powershell -File tools/deploy.ps1` und `/reload` im Spiel diese Zeile in den Chat eingeben:

```
/run local f=CreateFrame("Frame",nil,UIParent) f:SetSize(300,120) f:SetPoint("CENTER") VuloGearSetsTestFrame=f
```

Das geht nur mit Zugriff auf `ns`, den es von außen nicht gibt. Stattdessen zur Prüfung vorübergehend ans Ende von `UI/Widgets.lua` anhängen:

```lua
-- Nur zum Sichtpruefen waehrend der Entwicklung, vor dem Release entfernen.
function ns:_WidgetDemo()
    local f = CreateFrame("Frame", "VuloGearSetsDemo", UIParent)
    f:SetSize(320, 200); f:SetPoint("CENTER")
    UI:CreateBackdrop(f); UI:CreateShadow(f)
    local t = UI:CreateToggle(f, "Demo toggle"); t:SetPoint("TOPLEFT", 16, -16); t:SetChecked(true)
    local s = UI:CreateSlider(f, "Demo slider", 4, 14, 1); s:SetPoint("TOPLEFT", 16, -50); s:SetValue(8)
    local d = UI:CreateDropdown(f, "Demo dropdown", {
        { value = "a", text = "Option A" }, { value = "b", text = "Option B" },
    }); d:SetPoint("TOPLEFT", 16, -104); d:SetValue("a")
    local b = UI:CreateButton(f, "Demo button", 120, 22); b:SetPoint("TOPLEFT", 16, -164)
    b:SetOnClick(function() ns:Print("button ok") end)
end
SLASH_VGSDEMO1 = "/vgsdemo"
SlashCmdList["VGSDEMO"] = function() ns:_WidgetDemo() end
```

Dann `/reload` und `/vgsdemo`. Erwartet: dunkles Fenster mit Schatten, Haken lässt sich umschalten, Slider zeigt den Wert rechts daneben, Dropdown öffnet das Popup-Menü und übernimmt die Auswahl, Button gibt `button ok` im Chat aus. BugSack bleibt leer.

- [ ] **Step 7: Demo-Code wieder entfernen**

Den in Step 6 angehängten Block (`ns:_WidgetDemo`, `SLASH_VGSDEMO1`, `SlashCmdList["VGSDEMO"]`) aus `UI/Widgets.lua` löschen.

Run: `python -c "import pathlib; t=pathlib.Path('UI/Widgets.lua').read_text(encoding='utf-8'); print('RESTE' if '_WidgetDemo' in t or 'VGSDEMO' in t else 'sauber')"`
Expected: `sauber`

- [ ] **Step 8: Commit**

```bash
git add VuloGearSets
git commit -m "Widgets und Popup-Menue ergaenzt"
```

---

### Task 5: Optionsfenster mit Renderer

Rendert die deklarative Item-Liste aus `mod:GetOptions()`. Die Liste benutzt exakt neun Typen und siebzehn Felder — mehr muss der Renderer nicht können.

**Files:**
- Create: `UI/OptionsFrame.lua`
- Modify: `VuloGearSets.toc`

**Interfaces:**
- Consumes: `ns.UI:CreateBackdrop/CreateShadow/CreateButton/CreateToggle/CreateSlider/CreateDropdown`, `ns.UI.Font`, `ns.COLORS`, `ns.L`, `ns.modules`
- Produces: `ns:ToggleOptions()`, `ns:OpenOptions()`, `ns:RefreshOptions()`

**Zu unterstützende Item-Typen und Felder:**

| Typ | Felder |
|---|---|
| `header` | `text` |
| `desc` | `text` |
| `spacer` | `height` |
| `button` | `label`, `width`, `onClick` |
| `toggle` | `label`, `tooltip`, `get`, `set` |
| `slider` | `label`, `tooltip`, `min`, `max`, `step`, `get`, `set` |
| `dropdown` | `label`, `tooltip`, `values`, `get`, `set` |
| `group` | `layout = "row"`, `gap`, `items` |
| `section` | `title`, `collapsed`, `items` |

`get` wird ohne Argumente aufgerufen und liefert den Wert. `set` wird als `set(nil, value)` aufgerufen — die Signatur stammt aus Vulos OptionsBuilder und muss beibehalten werden, weil `GearSets.lua` sie so schreibt.

- [ ] **Step 1: `UI/OptionsFrame.lua` schreiben**

```lua
-- =========================================================
-- VuloGearSets / UI / OptionsFrame
-- Ein Fenster, ein Scrollbereich, ein Renderer fuer die
-- deklarative Item-Liste aus mod:GetOptions().
-- =========================================================
local _, ns = ...
local UI = ns.UI
local L  = ns.L
local C  = ns.COLORS

local WIDTH, HEIGHT = 460, 560
local PAD           = 16
local CONTENT_W     = WIDTH - PAD * 2 - 20   -- 20px fuer die Scrollleiste

local frame, content
local renderItems   -- vorwaerts deklariert: section/group rufen rekursiv auf

-- =========================================================
-- Tooltip-Helfer
-- =========================================================
local function attachTooltip(widget, text)
    if not text or text == "" then return end
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- =========================================================
-- Ein Renderer je Typ. Signatur immer (parent, item, y, width),
-- Rueckgabe ist die verbrauchte Hoehe in Pixeln.
-- =========================================================
local renderers = {}

renderers.header = function(parent, item, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    UI.Font(fs, 14, "OUTLINE")
    fs:SetPoint("TOPLEFT", PAD, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetText(item.text or "")
    fs:SetTextColor(C.accent.r, C.accent.g, C.accent.b)
    return fs:GetStringHeight() + 8
end

renderers.desc = function(parent, item, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    UI.Font(fs, 11)
    fs:SetPoint("TOPLEFT", PAD, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetText(item.text or "")
    fs:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
    return fs:GetStringHeight() + 6
end

renderers.spacer = function(_, item)
    return item.height or 8
end

renderers.button = function(parent, item, y)
    local b = UI:CreateButton(parent, item.label or "", item.width or 130, 22)
    b:SetPoint("TOPLEFT", PAD, y)
    b:SetOnClick(item.onClick)
    attachTooltip(b, item.tooltip)
    return 26
end

renderers.toggle = function(parent, item, y, width)
    local t = UI:CreateToggle(parent, item.label or "")
    t:SetPoint("TOPLEFT", PAD, y)
    t:SetWidth(width)
    t:SetChecked(item.get and item.get() or false)
    t.OnValueChanged = function(v)
        if item.set then item.set(nil, v) end
    end
    attachTooltip(t, item.tooltip)
    return 26
end

renderers.slider = function(parent, item, y)
    local s = UI:CreateSlider(parent, item.label or "", item.min, item.max, item.step)
    s:SetPoint("TOPLEFT", PAD, y)
    s:SetValue(item.get and item.get() or item.min or 0)
    s.OnValueChanged = function(v)
        if item.set then item.set(nil, v) end
    end
    attachTooltip(s.slider, item.tooltip)
    return 48
end

renderers.dropdown = function(parent, item, y)
    local d = UI:CreateDropdown(parent, item.label or "", item.values)
    d:SetPoint("TOPLEFT", PAD, y)
    d:SetValue(item.get and item.get() or nil)
    d.OnValueChanged = function(v)
        if item.set then item.set(nil, v) end
    end
    attachTooltip(d.button, item.tooltip)
    return 50
end

-- Nebeneinander in einer Zeile, sonst wie eine normale Liste.
renderers.group = function(parent, item, y, width)
    if item.layout ~= "row" then
        return renderItems(parent, item.items or {}, y, width)
    end
    local gap, x, maxH = item.gap or 6, 0, 0
    for _, sub in ipairs(item.items or {}) do
        local w = sub.width or 130
        local b = UI:CreateButton(parent, sub.label or "", w, 22)
        b:SetPoint("TOPLEFT", PAD + x, y)
        b:SetOnClick(sub.onClick)
        attachTooltip(b, sub.tooltip)
        x = x + w + gap
        maxH = math.max(maxH, 26)
    end
    return maxH
end

-- Aufklappbarer Block. Der Zustand lebt nur solange das Fenster offen ist.
renderers.section = function(parent, item, y, width)
    local head = CreateFrame("Button", nil, parent)
    head:SetPoint("TOPLEFT", PAD, y)
    head:SetSize(width, 20)

    local fs = head:CreateFontString(nil, "OVERLAY")
    UI.Font(fs, 13, "OUTLINE")
    fs:SetPoint("LEFT")
    fs:SetTextColor(C.accent.r, C.accent.g, C.accent.b)

    local collapsed = item.collapsed and true or false
    local function label()
        fs:SetText((collapsed and "+ " or "- ") .. (item.title or ""))
    end
    label()

    head:SetScript("OnClick", function()
        collapsed = not collapsed
        item.collapsed = collapsed
        ns:RefreshOptions()
    end)

    if collapsed then return 24 end
    local inner = renderItems(parent, item.items or {}, y - 24, width - 10)
    return 24 + inner
end

-- =========================================================
-- Liste rendern. Gibt die Gesamthoehe zurueck.
-- =========================================================
renderItems = function(parent, items, y, width)
    local used = 0
    for _, item in ipairs(items) do
        local fn = renderers[item.type]
        if fn then
            used = used + fn(parent, item, y - used, width)
        else
            ns:Debug("Unbekannter Options-Typ: %s", tostring(item.type))
        end
    end
    return used
end

-- =========================================================
-- Fenster
-- =========================================================
local function createFrame()
    frame = CreateFrame("Frame", "VuloGearSetsOptions", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    UI:CreateBackdrop(frame)
    UI:CreateShadow(frame)
    tinsert(UISpecialFrames, "VuloGearSetsOptions")   -- Escape schliesst

    local title = frame:CreateFontString(nil, "OVERLAY")
    UI.Font(title, 15, "OUTLINE")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(L["Gear Sets"])
    title:SetTextColor(C.accent.r, C.accent.g, C.accent.b)

    local close = UI:CreateButton(frame, "X", 22, 22)
    close:SetPoint("TOPRIGHT", -PAD, -PAD + 2)
    close:SetOnClick(function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "VuloGearSetsOptionsScroll", frame,
                               "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     PAD, -PAD - 30)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 20, PAD)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CONTENT_W, 10)
    scroll:SetScrollChild(content)
    frame.scroll = scroll
end

-- Erzeugt den Inhalt neu. Alte Kinder werden verworfen, weil sich
-- Sektionen auf- und zuklappen lassen und die Liste dann anders aussieht.
function ns:RefreshOptions()
    if not frame or not frame:IsShown() then return end
    if content then content:Hide() end
    content = CreateFrame("Frame", nil, frame.scroll)
    content:SetSize(CONTENT_W, 10)
    frame.scroll:SetScrollChild(content)

    local mod = ns.modules and ns.modules.gearsets
    if not (mod and mod.GetOptions) then return end
    local height = renderItems(content, mod:GetOptions(), -PAD, CONTENT_W - PAD * 2)
    content:SetHeight(math.max(height + PAD * 2, 10))
end

function ns:OpenOptions()
    if not frame then createFrame() end
    frame:Show()
    ns:RefreshOptions()
end

function ns:ToggleOptions()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        ns:OpenOptions()
    end
end
```

- [ ] **Step 2: TOC ergänzen**

Nach `UI\Widgets.lua`:

```
UI\OptionsFrame.lua
```

- [ ] **Step 3: Prüfer laufen lassen**

Run: `python tools/check.py`
Expected: keine Fehler außer den bekannten verwaisten Locale-Keys

Der neue Key `Gear Sets` muss in `deDE.lua` existieren (aus Task 3, umbenannt aus `Loadouts`). Meldet der Prüfer ihn als fehlend, wurde in Task 3 die Umbenennung nicht angewendet.

- [ ] **Step 4: Im Spiel verifizieren**

Das Fenster braucht ein Modul namens `gearsets`, das es erst ab Task 7 gibt. Für diese Task genügt der Nachweis, dass Fenster und Renderer laufen. Dazu vorübergehend ans Ende von `UI/OptionsFrame.lua` anhängen:

```lua
-- Nur zum Sichtpruefen waehrend der Entwicklung, in Task 7 entfernen.
SLASH_VGSOPT1 = "/vgsopt"
SlashCmdList["VGSOPT"] = function()
    ns.modules.gearsets = ns.modules.gearsets or { GetOptions = function()
        return {
            { type = "header", text = "Demo header" },
            { type = "desc",   text = "Ein laengerer Beschreibungstext, der umbrechen soll." },
            { type = "spacer", height = 6 },
            { type = "group", layout = "row", gap = 6, items = {
                { type = "button", label = "A", width = 60, onClick = function() ns:Print("A") end },
                { type = "button", label = "B", width = 60, onClick = function() ns:Print("B") end },
            } },
            { type = "toggle", label = "Demo toggle", tooltip = "Tooltip-Text",
              get = function() return true end, set = function(_, v) ns:Print("toggle %s", tostring(v)) end },
            { type = "section", title = "Demo section", collapsed = false, items = {
                { type = "slider", label = "Demo slider", min = 4, max = 14, step = 1,
                  get = function() return 8 end, set = function(_, v) ns:Print("slider %d", v) end },
                { type = "dropdown", label = "Demo dropdown",
                  values = { { value = "a", text = "Option A" }, { value = "b", text = "Option B" } },
                  get = function() return "a" end, set = function(_, v) ns:Print("dd %s", v) end },
            } },
        }
    end }
    ns:ToggleOptions()
end
```

Dann `/reload` und `/vgsopt`. Erwartet: Fenster erscheint mittig, ist verschiebbar, Escape schließt es. Alle neun Typen werden gezeichnet, der Beschreibungstext bricht um, die Sektion klappt auf Klick zu und wieder auf, Tooltips erscheinen, Toggle/Slider/Dropdown geben ihre Werte im Chat aus. BugSack bleibt leer.

- [ ] **Step 5: Demo-Code wieder entfernen**

Den in Step 4 angehängten Block löschen.

Run: `python -c "import pathlib; t=pathlib.Path('UI/OptionsFrame.lua').read_text(encoding='utf-8'); print('RESTE' if 'VGSOPT' in t else 'sauber')"`
Expected: `sauber`

- [ ] **Step 6: Commit**

```bash
git add VuloGearSets
git commit -m "Optionsfenster mit Renderer fuer die Modulseite ergaenzt"
```

---

### Task 6: Mover für die Sidebar

`GearSets.lua` ruft `ns:CreateMover` und `ns:IsMoverEditMode` auf. Vulos Fassung kann Layout-Serialisierung, benannte Profile und Gruppen-Drag; hier reicht ein einzelner verschiebbarer Frame.

**Files:**
- Create: `Core/Mover.lua`
- Modify: `VuloGearSets.toc`

**Interfaces:**
- Consumes: `ns.COLORS`, `ns.L`, `ns.UI.Font`
- Produces: `ns:CreateMover(target, opts)` → Mover-Frame, `ns:IsMoverEditMode()` → boolean, `ns:SetMoversEditMode(state)`

**Vertrag — exakt so nachbilden, sonst bricht Task 7.** `GearSets.lua:1423` ruft auf:

```lua
sidebar.mover = ns:CreateMover(sidebar, {
    key      = "loadouts.sidebar",
    label    = L["|cffffffffGEAR SETS SIDEBAR|r\n|cffaaaaaaDrag or arrow keys|r"],
    db       = mod.db.sidebarPos,          -- Tabelle mit .x und .y, wird direkt beschrieben
    width    = 168,
    height   = 44,
    applyPos = anchorToCharacterFrame,     -- wird nach jeder Aenderung aufgerufen
})
sidebar.mover:SetFrameLevel((sidebar:GetFrameLevel() or 1) + 20)
```

Daraus folgt:
- Der Mover ist ein echter Frame und Kind von `target`, damit `SetFrameLevel` wirkt.
- Die Position wird **nicht** vom Mover gespeichert, sondern direkt in `opts.db.x` / `opts.db.y` geschrieben. Die Persistenz übernimmt die SavedVariable, in der diese Tabelle liegt.
- Nach jeder Änderung ruft der Mover `opts.applyPos(mover)` auf.
- `GearSets.lua:1436-1451` **überschreibt** `OnDragStart` und `OnDragStop` direkt nach dem Aufruf, weil die Sidebar am Charakterfenster verankert bleiben muss statt frei zu schweben. Die eigenen Drag-Skripte müssen also überschreibbar sein und dürfen keinen Zustand hinterlassen, auf den der Rest angewiesen ist.
- Pfeiltasten bleiben Sache des Movers: 1 px, mit Shift 5 px, danach `applyPos`.
- Rechtsklick setzt zurück — das verspricht der Hinweistext auf der Optionsseite. In VuloClassicUI erledigt das ein Edit-Mode-Panel, das es hier nicht gibt.

- [ ] **Step 1: `Core/Mover.lua` schreiben**

```lua
-- =========================================================
-- VuloGearSets / Core / Mover
-- Ein verschiebbarer Frame, kein Layoutsystem.
--
-- Vertrag (identisch zu VuloClassicUI, damit das Modul unveraendert bleibt):
--   ns:CreateMover(target, { key, label, db, width, height, applyPos })
--   Die Position lebt in opts.db.x / opts.db.y, nicht im Mover.
--   Nach jeder Aenderung wird opts.applyPos(mover) gerufen.
--
-- Im Edit-Modus liegt ein lila Kasten ueber dem Frame:
--   ziehen              -> verschieben
--   Pfeiltasten         -> 1px, mit Shift 5px
--   Rechtsklick         -> Position zuruecksetzen
-- =========================================================
local _, ns = ...
local L = ns.L

local editMode = false
local movers   = {}

function ns:IsMoverEditMode()
    return editMode
end

function ns:SetMoversEditMode(state)
    editMode = state and true or false
    for _, mover in ipairs(movers) do
        -- Nur zeigen, wenn der Zielframe selbst sichtbar ist.
        if editMode and mover.target:IsShown() then mover:Show() else mover:Hide() end
    end
    ns:Print(editMode and L["Edit mode enabled. Drag the purple box, arrow keys nudge, right-click resets."]
                      or L["Edit mode disabled."])
end

function ns:CreateMover(target, opts)
    opts = opts or {}
    local db = opts.db
    assert(db,     "ns:CreateMover braucht opts.db")
    assert(target, "ns:CreateMover braucht target")

    target:SetMovable(true)
    target:SetClampedToScreen(false)

    local mover = CreateFrame("Frame", nil, target)
    mover.target = target
    mover.opts   = opts
    mover.key    = opts.key
    mover:SetPoint("CENTER", target, "CENTER", 0, 0)
    mover:SetSize(opts.width or 200, opts.height or 40)
    mover:SetFrameStrata("HIGH")
    mover:EnableMouse(true)
    mover:Hide()

    mover.bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.bg:SetAllPoints(mover)
    mover.bg:SetColorTexture(0.6, 0.4, 1.0, 0.4)

    mover.border = CreateFrame("Frame", nil, mover,
        BackdropTemplateMixin and "BackdropTemplate")
    mover.border:SetAllPoints(mover)
    if mover.border.SetBackdrop then
        mover.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        mover.border:SetBackdropBorderColor(0.75, 0.35, 1, 1)
    end

    if opts.label then
        mover.label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        mover.label:SetPoint("CENTER", mover, "CENTER", 0, 6)
        mover.label:SetJustifyH("CENTER")
        mover.label:SetText(opts.label)
    end

    local function applyPos()
        if opts.applyPos then opts.applyPos(mover) end
    end

    -- Standardverhalten: frei ziehen und die Mitte relativ zu UIParent speichern.
    -- GearSets ueberschreibt beide Skripte, weil die Seitenleiste am
    -- Charakterfenster verankert bleiben muss.
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function() target:StartMoving() end)
    mover:SetScript("OnDragStop", function()
        target:StopMovingOrSizing()
        local fx, fy = target:GetCenter()
        local px, py = UIParent:GetCenter()
        if fx and fy and px and py then
            db.x, db.y = fx - px, fy - py
            applyPos()
        end
    end)

    mover:SetScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" then return end
        db.x, db.y = 0, 0
        applyPos()
        ns:Print(L["Sidebar position reset."])
    end)

    mover:EnableKeyboard(true)
    mover:SetPropagateKeyboardInput(true)
    mover:SetScript("OnKeyDown", function(self, key)
        if not editMode then self:SetPropagateKeyboardInput(true); return end
        local step = IsShiftKeyDown() and 5 or 1
        local dx, dy = 0, 0
        if     key == "UP"    then dy =  step
        elseif key == "DOWN"  then dy = -step
        elseif key == "LEFT"  then dx = -step
        elseif key == "RIGHT" then dx =  step
        else   self:SetPropagateKeyboardInput(true); return end
        self:SetPropagateKeyboardInput(false)
        db.x = (db.x or 0) + dx
        db.y = (db.y or 0) + dy
        applyPos()
    end)

    movers[#movers + 1] = mover
    return mover
end
```

- [ ] **Step 2: Die drei neuen Locale-Keys ergänzen**

In `Locales/deDE.lua`:

```lua
    ["Edit mode enabled. Drag the purple box, arrow keys nudge, right-click resets."] = "Bearbeitungsmodus aktiv. Ziehe das lila Feld, Pfeiltasten verschieben pixelweise, Rechtsklick setzt zurueck.",
    ["Edit mode disabled."] = "Bearbeitungsmodus beendet.",
    ["Sidebar position reset."] = "Position der Seitenleiste zurueckgesetzt.",
```

- [ ] **Step 3: TOC ergänzen**

Nach `Core\PopupMenu.lua`:

```
Core\Mover.lua
```

- [ ] **Step 4: Prüfer laufen lassen**

Run: `python tools/check.py`
Expected: keine Fehler außer den bekannten verwaisten Locale-Keys

- [ ] **Step 5: Commit**

```bash
git add VuloGearSets
git commit -m "Mover fuer die Seitenleiste ergaenzt"
```

---

### Task 7: GearSets-Modul portieren

Der Kern. Die 1823 Zeichen umfassende Datei wird kopiert und an genau den unten aufgezählten Stellen geändert. Alles andere bleibt Zeile für Zeile identisch.

**Files:**
- Create: `Modules/GearSets.lua` (Kopie von `Loadouts.lua`)
- Modify: `VuloGearSets.toc`
- Modify: `Locales/deDE.lua`

**Interfaces:**
- Consumes: alles aus Task 1–6
- Produces: `ns.modules.gearsets` mit `GetOptions`, `OnEnable`, `OnDisable`; `ns:EquipBagItemToSlot(bag, bagSlot, equipSlot)` (wird von SlotPicker in Task 8 gebraucht)

- [ ] **Step 1: Datei kopieren**

```powershell
Copy-Item "C:\Users\aobiw\Desktop\entpackte addons\VuloClassicUI\Modules\Loadouts.lua" `
          "C:\Users\aobiw\Desktop\Test\VuloGearSets\Modules\GearSets.lua"
```

- [ ] **Step 2: Locale-Keys umbenennen**

Run: `python tools/rename_keys.py Modules/GearSets.lua`
Expected: `Modules/GearSets.lua: 31 Ersetzungen` (die Zahl darf abweichen, wenn ein Key mehrfach vorkommt — sie darf nur nicht 0 sein)

- [ ] **Step 3: Modulkopf und Registrierung ändern**

Zeile 1–2, den Kopfkommentar:

```lua
-- =========================================================
-- VuloGearSets / Modules / GearSets
-- Equipment set manager.
```

Zeile 15–18:

```lua
local mod = ns:RegisterModule("gearsets", {
    name        = "Equipment Sets",
    description = "Save and quickly equip gear sets for different specs, content, or roles.",
```

Das Feld `group = "QoL"` ersatzlos streichen — im Standalone gibt es keine Sidebar-Gruppen.

- [ ] **Step 4: Per-Charakter-Speicher umstellen**

Die Funktion `charDB()` (Zeile 46–49) ersetzen:

```lua
local function charDB()
    return ns:GetCharDB()
end
```

Und in `LO()` (Zeile 50–52) den Feldnamen an das neue Schema anpassen — die Char-DB benutzt `sets` statt `loadouts`:

```lua
local function LO()
    local c = charDB(); c.sets = c.sets or {}; return c.sets
end
```

Den Kommentarblock darüber (Zeile 39–45) auf den neuen Sachverhalt umschreiben: die kontoweite Legacy-Sammlung gibt es hier nicht, importiert wird stattdessen aus VuloClassicUI.

- [ ] **Step 5: Globale Frame-Namen umbenennen**

Vier Stellen mit `VCUI_`-Präfix auf `VGS_` ändern, damit nichts mit VuloClassicUI kollidiert:

| Zeile | alt | neu |
|---|---|---|
| 496 | `"VCUI_LoadoutsMinimapButton"` | `"VGS_GearSetsMinimapButton"` |
| 884 | `"VCUI_LoadoutIconPicker"` | `"VGS_GearSetIconPicker"` |
| 900 | `tinsert(UISpecialFrames, "VCUI_LoadoutIconPicker")` | `tinsert(UISpecialFrames, "VGS_GearSetIconPicker")` |
| 1322 | `"VCUI_LoadoutsSidebar"` | `"VGS_GearSetsSidebar"` |

- [ ] **Step 6: Slash-Commands umstellen**

Zeile 354–356. Nur `/gearset` wird hier registriert — den zweiten Alias bewusst weglassen:

```lua
_G.SLASH_VGSGEARSET1 = "/gearset"
_G.SlashCmdList["VGSGEARSET"] = function(msg)
```

`/vgs` registriert in Task 9 `Core/Init.lua`, weil dieser Befehl auch im Schlafmodus antworten muss, wenn das Modul gar nicht erst startet. Er reicht im Wachzustand an `SlashCmdList["VGSGEARSET"]` weiter. Würden beide Dateien denselben Befehl belegen, gewänne einer davon unvorhersehbar.

- [ ] **Step 7: Die Unterbefehle `unlock` und `config` ergänzen**

Der Handler kennt bisher `save`, `equip`, `spec`, `delete`, `list`, `import`, `debug` und `tune`. Zwei fehlen im Standalone. Im Slash-Handler vor dem `else`-Zweig, der unbekannte Wörter als Set-Namen behandelt (Zeile ~424), einfügen:

```lua
    elseif cmd == "unlock" then
        ns:SetMoversEditMode(not ns:IsMoverEditMode())
    elseif cmd == "config" or cmd == "options" then
        ns:ToggleOptions()
```

`unlock` ersetzt VuloClassicUIs eigenes UnlockMode-Modul, ohne das sich die Seitenleiste nicht verschieben ließe. `config` ist nötig, weil der Minimap-Button sich ausblenden lässt — ohne diesen Befehl gäbe es dann keinen Weg mehr in die Einstellungen.

Die Usage-Zeile (Zeile 425) entsprechend erweitern:

```lua
            ns:Print(L["Usage: /gearset equip <name> | save <name> | delete <name> | list | config | unlock"])
```

Dieser Key ist neu und muss in Step 13 nach `deDE.lua`; der alte Key `Usage: /gearset equip <name> | save <name> | delete <name> | list` wird dann verwaist und ist dort zu entfernen.

- [ ] **Step 8: Nicht lokalisierte Texte mit Slash-Bezug korrigieren**

Diese vier Stellen benutzen kein `L[...]` und werden vom Umbenennungsskript deshalb nicht erfasst:

| Zeile | alt | neu |
|---|---|---|
| 373 | `"\|cff9b6cff[Loadouts spec debug]\|r"` | `"\|cff9b6cff[Gear Sets spec debug]\|r"` |
| 419 | `"Usage: /loadout tune top <n> \| tune bottom <n> \| tune reset"` | `"Usage: /gearset tune top <n> \| tune bottom <n> \| tune reset"` |
| 1366 | `"\|cff9b6cff[Loadouts size debug]\|r"` | `"\|cff9b6cff[Gear Sets size debug]\|r"` |
| 1425 | Label im `CreateMover`-Aufruf | wurde in Step 2 automatisch umbenannt — prüfen, dass dort jetzt `GEAR SETS SIDEBAR` steht |

Zeile 417 (`ns:Print("Sidebar offsets reset to 0.")`) bleibt unverändert.

- [ ] **Step 9: Optionsfenster statt Vulo-Hauptfenster**

Zeile 482–489, die Funktion `openLoadoutsSettings`, komplett ersetzen:

```lua
-- Oeffnet die Einstellungen. Im Standalone gibt es genau ein Fenster.
function openLoadoutsSettings()
    ns:ToggleOptions()
end
```

Damit verschwinden die beiden verbotenen Aufrufe `ns:OpenConfig("loadouts")` und `ns.UI:ToggleMainFrame()` in einem Zug.

- [ ] **Step 10: Legacy-Import entfernen**

Die Funktion `mod.ImportLegacy` vollständig löschen. Ebenso im Slash-Handler den `import`-Zweig und in `OnEnable` den Block "One-time hint (per character)" (Zeile ~1558–1570), der auf `mod.db.loadouts` und `charDB()._importHintShown` verweist. Der Import aus VuloClassicUI kommt in Task 9 und läuft ohne Zutun des Nutzers.

Ebenfalls streichen: das Feld `loadouts = {}` aus dem `defaults`-Block (Zeile 21) samt seinem Kommentar — die kontoweite Sammlung gibt es nicht mehr.

- [ ] **Step 11: `mod.db.sidebarPos` in die Char-DB verlegen**

`GearSets.lua:1422` schreibt die Position nach `mod.db.sidebarPos`, also kontoweit. Die Spec verlangt sie pro Charakter. Zeile 1422 ersetzen:

```lua
    -- Die Position der Seitenleiste haengt am Charakterfenster dieses Charakters.
    local char = ns:GetCharDB()
    char.sidebarPos = char.sidebarPos or { x = 0, y = 0 }
    mod.db.sidebarPos = char.sidebarPos
```

Damit bleiben alle weiteren Zugriffe auf `mod.db.sidebarPos` unverändert gültig — sie zeigen jetzt auf dieselbe Tabelle in der Char-DB. Das Feld `sidebarPos` aus dem `defaults`-Block (Zeile 35) streichen, sonst überschreibt der Defaults-Merge die Referenz.

- [ ] **Step 12: TOC ergänzen**

Nach `UI\OptionsFrame.lua`:

```
Modules\GearSets.lua
```

- [ ] **Step 13: Locale-Datei nachziehen**

In `Locales/deDE.lua` den in Step 7 neu eingeführten Key ergänzen:

```lua
    ["Usage: /gearset equip <name> | save <name> | delete <name> | list | config | unlock"] = "Verwendung: /gearset equip <Name> | save <Name> | delete <Name> | list | config | unlock",
```

Und den alten Key `["Usage: /gearset equip <name> | save <name> | delete <name> | list"]` entfernen — er wird durch den neuen ersetzt.

Ebenso die fünf Keys aus `DROP_KEYS` entfernen, falls `extract_locales.py` sie doch geschrieben hat, sowie alle Keys, die nur der in Step 10 gelöschte Legacy-Import benutzt hat.

- [ ] **Step 14: Prüfer laufen lassen**

Run: `python tools/check.py`
Expected: keine Fehler mehr zu `VuloClassicUI`, `ns.UI:ToggleMainFrame` oder `ns:OpenConfig`. Verwaiste Locale-Keys sollten jetzt fast verschwunden sein.

Meldet der Prüfer "Key ohne deutsche Übersetzung", wurde in Step 2 eine Umbenennung nur auf einer Seite angewendet — den gemeldeten Key in `RENAME_MAP` und in `deDE.lua` abgleichen.

- [ ] **Step 15: Im Spiel verifizieren**

Nach `powershell -File tools/deploy.ps1`: **vorher VuloClassicUI in der AddOn-Liste deaktivieren**, sonst greift ab Task 9 der Schlafmodus — in dieser Task gibt es ihn noch nicht, aber doppelte Minimap-Buttons und doppelte Sidebars würden die Prüfung unbrauchbar machen.

Dann im Spiel:

1. `/gearset list` → meldet, dass noch nichts gespeichert ist
2. `/gearset save Test` → bestätigt das Speichern mit Anzahl der Teile
3. Etwas anderes anlegen, dann `/gearset equip Test` → Ausrüstung wird zurückgetauscht
4. Charakterfenster öffnen → Seitenleiste rechts daneben, mit dem Set `Test`
5. `/gearset unlock` → lila Kasten erscheint, Ziehen verschiebt, Pfeiltasten bewegen pixelweise, Rechtsklick setzt zurück, `/gearset unlock` erneut beendet den Modus
6. Position übersteht `/reload`
7. Minimap-Button: Linksklick zeigt das Set-Menü, Rechtsklick öffnet das Optionsfenster
8. Im Optionsfenster alle Schalter durchklicken — jeder Wert übersteht `/reload`
9. BugSack bleibt leer

- [ ] **Step 16: Commit**

```bash
git add VuloGearSets
git commit -m "Modul fuer Ausruestungssets aus VuloClassicUI portiert"
```

---

### Task 8: SlotPicker portieren

**Files:**
- Create: `Modules/SlotPicker.lua`
- Modify: `VuloGearSets.toc`

**Interfaces:**
- Consumes: `ns:EquipBagItemToSlot` aus Task 7
- Produces: `ns.modules.slotpicker`, `ns:ScanBagsForSlot(slotID)`

- [ ] **Step 1: Datei kopieren**

```powershell
Copy-Item "C:\Users\aobiw\Desktop\entpackte addons\VuloClassicUI\Modules\SlotPicker.lua" `
          "C:\Users\aobiw\Desktop\Test\VuloGearSets\Modules\SlotPicker.lua"
```

- [ ] **Step 2: Locale-Keys umbenennen**

Run: `python tools/rename_keys.py Modules/SlotPicker.lua`
Expected: eine kleine Zahl oder 0 — SlotPicker spricht kaum von Loadouts

- [ ] **Step 3: Kopfkommentar anpassen**

Zeile 1–3 auf `VuloGearSets / Modules / SlotPicker` ändern und in Zeile 12–14 den Verweis auf die "Loadouts (\"Equipment Sets\") page" umschreiben auf "Equipment Sets page". Der Prüfer verbietet `VuloClassicUI` außerhalb von `Coexistence.lua`.

- [ ] **Step 4: Registrierung prüfen**

Der Modul-Key `slotpicker` und die Gruppe `_hidden` bleiben. `GetOptions()` von GearSets greift über `ns.modules.slotpicker` darauf zu — die Referenzen stimmen bereits.

- [ ] **Step 5: TOC ergänzen**

Nach `Modules\GearSets.lua`:

```
Modules\SlotPicker.lua
```

- [ ] **Step 6: Prüfer laufen lassen**

Run: `python tools/check.py`
Expected: `OK - ... Lua-Dateien, ... Locale-Keys` ohne Fehler

Ab hier muss der Locale-Check sauber sein. Falls in Task 3 Step 6 der Check für verwaiste Keys abgeschwächt wurde: jetzt wieder scharf stellen und die dann gemeldeten verwaisten Keys aus `deDE.lua` entfernen.

- [ ] **Step 7: Im Spiel verifizieren**

Bei weiterhin deaktiviertem VuloClassicUI:

1. Charakterfenster öffnen, auf einen Ausrüstungsslot rechtsklicken → Popup mit passenden Taschenteilen
2. Ein Teil anklicken → wird angelegt
3. Alle 17 Slots durchgehen, besonders Waffenhand, Schildhand und Distanzwaffe
4. Im Optionsfenster unter "Slot Picker" den Modifier auf "Alt + Right-click" stellen → nur noch Alt+Rechtsklick öffnet das Popup
5. Spaltenzahl auf 4 und auf 14 stellen → Raster ändert sich
6. Slot Picker abschalten → Rechtsklick tut nichts mehr
7. BugSack bleibt leer

- [ ] **Step 8: Commit**

```bash
git add VuloGearSets
git commit -m "Slot-Picker portiert"
```

---

### Task 9: Koexistenz, Import und Start

**Files:**
- Create: `Core/Coexistence.lua`
- Create: `Core/Init.lua`
- Modify: `VuloGearSets.toc`
- Modify: `Locales/deDE.lua`

**Interfaces:**
- Consumes: `ns:InitDB`, `ns:GetCharDB`, `ns:EnableModules`, `ns:DeepCopy`, `ns:IsAddOnLoaded`, `ns:Print`, `ns.L`
- Produces: `ns:ImportFromVuloClassicUI()` → Anzahl importierter Sets, `ns:IsVuloLoadoutsActive()` → boolean, `ns.asleep` → boolean

Reihenfolge ist bindend: DB → Import → Konflikt → Module. Läge der Import nach dem Konflikt-Check, könnte ein Nutzer mit aktivem VuloClassicUI seine Sets nie übernehmen.

- [ ] **Step 1: `Core/Coexistence.lua` schreiben**

Dies ist die **einzige** Datei, die `VuloClassicUI` erwähnen darf.

```lua
-- =========================================================
-- VuloGearSets / Core / Coexistence
-- Erkennt ein aktives VuloClassicUI, uebernimmt einmalig dessen
-- Sets und legt sich schlafen, damit es keine doppelten Buttons,
-- Seitenleisten und Slot-Hooks gibt.
--
-- VuloClassicUIs SavedVariables werden ausschliesslich GELESEN.
-- =========================================================
local _, ns = ...
local L = ns.L

-- Ist VuloClassicUI geladen UND dessen Loadouts-Modul aktiv?
-- Der Zustand liegt pro Charakter in modEnabled und faellt sonst auf den
-- Profil-Default zurueck. Laesst er sich nicht ermitteln, gilt "aktiv" —
-- die konservative Annahme verhindert doppelte Oberflaechen.
function ns:IsVuloLoadoutsActive()
    if not ns:IsAddOnLoaded("VuloClassicUI") then return false end

    local charDB = _G.VuloClassicUICharDB
    local ov = charDB and charDB.modEnabled
    if ov and ov.loadouts ~= nil then
        return ov.loadouts and true or false
    end

    local db   = _G.VuloClassicUIDB
    local prof = db and db.profiles and db.profiles[db.activeProfile or "Default"]
    local m    = prof and prof.modules and prof.modules.loadouts
    -- Vulo setzt enabled per Default auf true; nur ein explizites false zaehlt als aus.
    return not (m and m.enabled == false)
end

-- Einmaliger Import. Gibt die Anzahl uebernommener Sets zurueck.
function ns:ImportFromVuloClassicUI()
    local char = ns:GetCharDB()
    if char.imported then return 0 end

    local src = _G.VuloClassicUICharDB
    if not src then
        -- Vulo ist nicht (mehr) installiert: nichts zu holen, aber auch
        -- nicht als erledigt markieren — vielleicht kommt es zurueck.
        return 0
    end

    char.imported = true

    local n = 0
    for name, data in pairs(src.loadouts or {}) do
        if not char.sets[name] then
            char.sets[name] = ns:DeepCopy(data)
            n = n + 1
        end
    end
    for name, g in pairs(src.specMapping or {}) do
        if char.specMapping[name] == nil then char.specMapping[name] = g end
    end
    for name, g in pairs(src.formMapping or {}) do
        if char.formMapping[name] == nil then char.formMapping[name] = g end
    end

    if n > 0 then
        ns:Print(L["Imported %d gear set(s) from VuloClassicUI onto this character."], n)
    end
    return n
end

-- Schlafmodus: keine Frames, keine Hooks, keine Module.
function ns:GoToSleep()
    ns.asleep = true
    ns:Print(L["VuloClassicUI already provides gear sets, so VuloGearSets stayed inactive. Disable one of them to use the other. Type /vgs for details."])
end
```

- [ ] **Step 2: `Core/Init.lua` schreiben**

```lua
-- =========================================================
-- VuloGearSets / Core / Init
-- Startreihenfolge: Datenbank -> Import -> Konfliktpruefung -> Module.
-- =========================================================
local _, ns = ...
local L = ns.L

local function onLogin()
    ns:InitDB()

    -- Vor der Konfliktpruefung, sonst koennte ein Nutzer mit aktivem
    -- VuloClassicUI seine Sets nie uebernehmen.
    ns:ImportFromVuloClassicUI()

    if ns:IsVuloLoadoutsActive() then
        ns:GoToSleep()
        return
    end

    ns:EnableModules()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    onLogin()
end)

-- Im Schlafmodus registriert das Modul seine Slash-Befehle nicht,
-- deshalb hier ein eigener Einstieg, der den Zustand erklaert.
_G.SLASH_VGSSTATUS1 = "/vgs"
local function statusHandler(msg)
    if not ns.asleep then
        -- Wach: an den Modul-Handler weiterreichen.
        local fn = _G.SlashCmdList["VGSGEARSET"]
        if fn then fn(msg) end
        return
    end
    ns:Print(L["Inactive: VuloClassicUI is handling gear sets. Disable its Equipment Sets module, or disable VuloClassicUI, then /reload."])
end
_G.SlashCmdList["VGSSTATUS"] = statusHandler
```

- [ ] **Step 3: Prüfen, dass `/vgs` nur einmal registriert wird**

Task 7 Step 6 hat `/gearset` beim Modul gelassen und `/vgs` bewusst nicht vergeben. Gegenprobe:

Run: `python -c "import pathlib,re; ps=list(pathlib.Path('VuloGearSets').rglob('*.lua')); hits=[(p.as_posix(),n) for p in ps for n,l in enumerate(p.read_text(encoding='utf-8').splitlines(),1) if '\"/vgs\"' in l]; print(hits)"`
Expected: genau ein Treffer, in `Core/Init.lua`

- [ ] **Step 4: Die drei neuen Locale-Keys ergänzen**

In `Locales/deDE.lua`:

```lua
    ["Imported %d gear set(s) from VuloClassicUI onto this character."] = "%d Ausruestungsset(s) aus VuloClassicUI auf diesen Charakter uebernommen.",
    ["VuloClassicUI already provides gear sets, so VuloGearSets stayed inactive. Disable one of them to use the other. Type /vgs for details."] = "VuloClassicUI stellt Ausruestungssets bereits bereit, deshalb bleibt VuloGearSets inaktiv. Deaktiviere eines von beiden. Tippe /vgs fuer Details.",
    ["Inactive: VuloClassicUI is handling gear sets. Disable its Equipment Sets module, or disable VuloClassicUI, then /reload."] = "Inaktiv: VuloClassicUI verwaltet die Ausruestungssets. Deaktiviere dort das Modul Ausruestungssets oder das ganze Addon und dann /reload.",
```

- [ ] **Step 5: TOC ergänzen**

Ganz ans Ende, nach `Modules\SlotPicker.lua`:

```
Core\Coexistence.lua
Core\Init.lua
```

Die Reihenfolge ist wichtig: `Init.lua` ruft Funktionen aus `Coexistence.lua` auf und muss danach geladen werden.

- [ ] **Step 6: Prüfer laufen lassen**

Run: `python tools/check.py`
Expected: `OK - 13 Lua-Dateien, ... Locale-Keys` ohne Fehler

- [ ] **Step 7: Import verifizieren**

Voraussetzung: VuloClassicUI ist **aktiv** und hat auf diesem Charakter mindestens zwei gespeicherte Sets.

1. `powershell -File tools/deploy.ps1`, dann VuloGearSets in der AddOn-Liste aktivieren, VuloClassicUI aktiv lassen
2. Einloggen → im Chat erscheint die Import-Meldung mit der Anzahl **und** der Hinweis auf den Schlafmodus
3. `/vgs` → erklärt den Schlafmodus
4. Keine zweite Seitenleiste am Charakterfenster, kein zweiter Minimap-Button
5. In VuloClassicUI prüfen, dass die Sets dort unverändert vorhanden sind
6. `/reload` → die Import-Meldung erscheint **nicht** erneut

- [ ] **Step 8: Übernahme verifizieren**

1. VuloClassicUI in der AddOn-Liste deaktivieren, ausloggen und wieder einloggen
2. VuloGearSets ist wach, `/gearset list` zeigt die importierten Sets
3. Charakterfenster öffnen → Seitenleiste mit den importierten Sets, Icons stimmen
4. Ein importiertes Set anlegen → funktioniert
5. Spec-Bindungen sind übernommen: im Optionsfenster stehen die Zuordnungen wie vorher

- [ ] **Step 9: Commit**

```bash
git add VuloGearSets
git commit -m "Koexistenz mit VuloClassicUI, Einmal-Import und Startablauf ergaenzt"
```

---

### Task 10: Dokumentation und Abnahme

**Files:**
- Create: `README.md`
- Create: `CHANGELOG.md`

- [ ] **Step 1: `README.md` schreiben**

Muss enthalten: was das Addon tut, die Slash-Befehle (`/gearset save|equip|delete|list|unlock|config`, `/vgs`), das Verhältnis zu VuloClassicUI (Schlafmodus und automatischer Import) und die bekannte Einschränkung aus der Spec:

> Wer VuloClassicUI deinstalliert, **bevor** er VuloGearSets zum ersten Mal startet, hat keine SavedVariables mehr zum Auslesen. Der Import läuft dann ins Leere. Richtige Reihenfolge: VuloGearSets einmal mit installiertem VuloClassicUI starten, danach VuloClassicUI entfernen.

- [ ] **Step 2: `CHANGELOG.md` mit dem Eintrag für 1.0.0 anlegen**

- [ ] **Step 3: Vollständige Abnahme im Spiel**

Die neun Punkte aus der Spec, in dieser Reihenfolge, mit deaktiviertem VuloClassicUI außer bei Punkt 7 und 8:

1. Frische Installation: Set speichern, ausrüsten, löschen, Liste anzeigen
2. Seitenleiste: erscheint am Charakterfenster, Icon-Picker, Slot-Ersetzen, Ziehen im Unlock-Modus, Rechtsklick-Reset, Position übersteht `/reload`
3. Minimap-Button: Linksklick-Menü, Rechtsklick öffnet Optionen, Ziehen, Ausblenden
4. Slot-Picker: alle 17 Slots, alle vier Modifier-Varianten, Spaltenzahl
5. Auto-Switch: Stance-Wechsel beim Krieger, Form-Wechsel beim Druiden, Dual-Spec-Wechsel
6. Kampf: Ausrüsten im Kampf wird abgelehnt, verschobener Wechsel läuft nach Kampfende
7. Import: mit aktivem VuloClassicUI starten, Sets erscheinen, Vulos Daten unverändert, zweiter Start importiert nicht erneut
8. Koexistenz: Vulo-Modul aktiv → Schlafmodus, genau ein Hinweis, keine doppelten Frames; Vulo-Modul deaktiviert → VuloGearSets übernimmt nach `/reload`
9. Beide Sprachen durchklicken (deutscher und englischer Client), keine sichtbaren rohen Schlüssel

Jeden Punkt abhaken. Ein fehlgeschlagener Punkt ist ein Bug, kein Grund zum Weitermachen.

- [ ] **Step 4: Prüfer ein letztes Mal**

Run: `python tools/check.py`
Expected: `OK` ohne jede Meldung

- [ ] **Step 5: Commit**

```bash
git add VuloGearSets
git commit -m "Dokumentation ergaenzt und Abnahme durchgefuehrt"
```

---

## Was dieser Plan bewusst offen lässt

- **Pill-Toggle.** Die Schrift ist übernommen, die Masken-Texturen des runden Schalters nicht. Wer auch die will, kopiert `Media/Masks/circle_mask.tga` und `csquare_mask.tga` aus VuloClassicUI und übernimmt den Toggle-Code aus dessen `UI/Widgets.lua`.
- **Weitere Sprachen.** Die Struktur trägt beliebige Locales; es sind bewusst nur enUS und deDE eingeplant.
- **Verteilung.** Kein CurseForge-/Wago-Paket, keine `.pkgmeta`, keine Release-Automatisierung.
