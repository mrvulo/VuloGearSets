-- =========================================================
-- VuloGearSets / Modules / SetMacros
-- "Auf die Aktionsleiste legen" aus dem Rechtsklick-Menue eines Sets.
--
-- WAS AUF DEN MAUSZEIGER KOMMT
--   Forever mit gespiegeltem Set: Blizzards Kopie (BlizzardSets.lua).
--   Sonst - und auf allen Classic-Clients - ein Makro mit
--   "/gearset equip <Name>". Das laeuft ueber unser eigenes Anlegen
--   (samt Bank, wenn sie offen ist) und braucht keine Vorbedingung: ein
--   Set, das nie getragen wurde, bekommt trotzdem einen Knopf.
--
-- WELCHES MAKRO UNSERES IST
--   Kein eigener Merker: ein Makro gehoert zu einem Set, wenn sein Text
--   genau "/gearset equip <Name>" ist. Das ueberlebt einen Reload, ein
--   vom Spieler umbenanntes Makro und ein neu installiertes Addon. Ein
--   Makro, das der Spieler umschreibt, ist ab da seins und wird nicht
--   mehr angefasst.
--
-- PRO CHARAKTER
--   Die Sets liegen pro Charakter, die Makros deshalb auch.
-- =========================================================
local _, ns = ...
local L = ns.L

local GetItemInfoInstant = _G.GetItemInfoInstant
    or (_G.C_Item and _G.C_Item.GetItemInfoInstant)

local BODY_PREFIX = "/gearset equip "
-- Makronamen sind kurz. 16 Bytes sind auf jedem Client sicher; ein
-- laengerer Name wuerde abgelehnt oder abgeschnitten.
local MACRO_NAME_BYTES = 16
local FALLBACK_ICON = "INV_Misc_QuestionMark"

local function macroBody(name)
    return BODY_PREFIX .. name
end

-- Auf MACRO_NAME_BYTES kuerzen, ohne ein Umlaut-Zeichen zu zerschneiden.
local function macroName(name)
    if #name <= MACRO_NAME_BYTES then return name end
    local out = ""
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if #out + #ch > MACRO_NAME_BYTES then break end
        out = out .. ch
    end
    return out ~= "" and out or name:sub(1, MACRO_NAME_BYTES)
end

local function autoIcon(loadout)
    if not (loadout and loadout.slots and GetItemInfoInstant) then return nil end
    local slots = {}
    for s in pairs(loadout.slots) do slots[#slots + 1] = s end
    table.sort(slots)
    for _, s in ipairs(slots) do
        local _, _, _, _, icon = GetItemInfoInstant(loadout.slots[s])
        if icon then return icon end
    end
    return nil
end

-- Makros kennen nur Spielsymbole. Symbole aus dem Addon-Ordner fallen
-- auf das Symbol des ersten Teils zurueck.
local function macroIcon(name)
    local loadout = ns:GetCharDB().sets and ns:GetCharDB().sets[name]
    local ov = loadout and loadout.iconOverride
    if type(ov) == "number" then return ov end
    if type(ov) == "string" and not ov:lower():find("^interface\\addons\\") then
        if _G.GetFileIDFromPath then
            local ok, id = pcall(_G.GetFileIDFromPath, ov)
            if ok and type(id) == "number" and id > 0 then return id end
        end
        local short = ov:match("([^\\]+)$")
        if short and short ~= "" then return short end
    end
    return autoIcon(loadout) or FALLBACK_ICON
end

-- Die Makros dieses Charakters liegen hinter den kontoweiten.
local function charMacroRange()
    local first = (tonumber(_G.MAX_ACCOUNT_MACROS) or 120) + 1
    local ok, _, numChar = pcall(GetNumMacros)
    numChar = (ok and tonumber(numChar)) or 0
    return first, first + numChar - 1, numChar
end

local function findMacro(setName)
    if not GetMacroInfo then return nil end
    -- Auch der gesuchte Text ohne Rand: ein altes Set "Tank " (vor dem
    -- Zuschneiden gespeichert) fand sein Makro sonst nie und legte bei
    -- jedem Klick ein neues an.
    local want = macroBody(setName):match("^%s*(.-)%s*$")
    local first, last = charMacroRange()
    for i = first, last do
        local ok, _, _, body = pcall(GetMacroInfo, i)
        if ok and type(body) == "string" and body:match("^%s*(.-)%s*$") == want then
            return i
        end
    end
    return nil
end

-- =========================================================
-- Auf den Mauszeiger
-- =========================================================
function ns:PlaceSetOnActionBar(name)
    if InCombatLockdown() then
        ns:Print(L["Not possible in combat."])
        return
    end
    local sets = ns:GetCharDB().sets
    if not (sets and sets[name]) then return end

    if ns.BlizzSetID and ns:BlizzSetID(name) then
        ns:PickupBlizzSet(name)
        ns:Print(string.format(L["'%s' is on your cursor - click an action button to place it."], name))
        return
    end

    if not (CreateMacro and PickupMacro) then return end
    local idx = findMacro(name)
    if not idx then
        -- Kein eigener Test auf "Makros voll": die Obergrenze steht in
        -- Blizzards Makrofenster, das erst beim Oeffnen geladen wird, und
        -- ist je Client verschieden. Der Client lehnt selbst ab.
        local ok, res = pcall(CreateMacro, macroName(name), macroIcon(name), macroBody(name), true)
        -- Ein Symbolname, den dieser Client nicht kennt, darf das Makro
        -- nicht verhindern: einmal mit dem Fragezeichen nachfassen.
        if not ok and not findMacro(name) then
            ok, res = pcall(CreateMacro, macroName(name), FALLBACK_ICON, macroBody(name), true)
        end
        -- Neue Makros werden einsortiert; den Platz deshalb am Text neu
        -- suchen und die Rueckgabe nur als Rueckfall nehmen.
        idx = findMacro(name) or (ok and tonumber(res)) or nil
        if not idx then
            ns:Print(string.format(
                L["Could not create a macro for '%s'. Your character macros may be full - delete one in the macro window and try again."],
                name))
            return
        end
    end
    ClearCursor()
    PickupMacro(idx)
    ns:Print(string.format(L["'%s' is on your cursor - click an action button to place it."], name))
end

-- =========================================================
-- Mitziehen: Umbenennen, Loeschen, Symbol
--
-- Im Kampf laesst der Client Makros nicht aendern; dann bleibt das Makro
-- so stehen. Ein Klick darauf meldet hoechstens, dass es das Set nicht
-- mehr gibt.
-- =========================================================
function ns:RenameSetMacro(oldName, newName)
    if InCombatLockdown() or not EditMacro then return end
    local idx = findMacro(oldName)
    if not idx then return end
    local _, icon = GetMacroInfo(idx)
    pcall(EditMacro, idx, macroName(newName), icon or macroIcon(newName), macroBody(newName))
end

function ns:DeleteSetMacro(name)
    if InCombatLockdown() or not DeleteMacro then return end
    local idx = findMacro(name)
    if idx then pcall(DeleteMacro, idx) end
end

function ns:UpdateSetMacroIcon(name)
    if InCombatLockdown() or not EditMacro then return end
    local idx = findMacro(name)
    if not idx then return end
    local mName, _, body = GetMacroInfo(idx)
    pcall(EditMacro, idx, mName, macroIcon(name), body)
end
