-- =========================================================
-- VuloGearSets / Modules / BlizzardSets
-- Spiegelt die Sets auf Forever in Blizzards Ausruestungsmanager
-- (C_EquipmentSet). Damit bekommt jedes gespiegelte Set, was nur
-- Blizzards Sets haben:
--   - einen Knopf fuer die Aktionsleiste (PickupEquipmentSet)
--   - Speicherung auf dem Server
--   - Sichtbarkeit fuer andere Addons und Blizzards eigene Taschen-
--     markierung (C_Container.GetContainerItemEquipmentSetInfo)
--
-- WAS BLIZZARDS SCHNITTSTELLE KANN - UND WAS NICHT
--   Ein Blizzard-Set laesst sich nur aus der GETRAGENEN Ausruestung
--   speichern. Teile direkt hineinschreiben geht nicht. Gespiegelt wird
--   deshalb in zwei Faellen:
--     1. beim Speichern in VuloGearSets - da ist das Set per Definition
--        angelegt,
--     2. sobald ein Set vollstaendig getragen wird und Blizzards Kopie
--        fehlt oder nicht mehr passt (etwa nach "Teil ersetzen").
--   Bis dahin kann Blizzards Kopie hinterherhinken.
--
-- WESSEN SET WESSEN IST
--   charDB.blizzMirror[Name]:
--     true   von uns angelegt oder uebernommen - wir pflegen es
--     false  der Spieler hat unsere Kopie in Blizzards Fenster geloescht
--            oder umbenannt; nicht wieder anlegen, bis er das Set in
--            VuloGearSets erneut speichert
--     "rejected"  Blizzard hat das Anlegen abgelehnt (meist der Name);
--            erst ein erneutes Speichern oder Umbenennen versucht es wieder
--     nil    nie gespiegelt
--   Ein Blizzard-Set gleichen Namens, das nicht von uns stammt, wird nur
--   beim ausdruecklichen Speichern uebernommen (dann meint der Spieler
--   dasselbe Set), nie beim stillen Nachziehen.
--
-- BEWUSST NICHT
--   Keine Spec-Zuweisung bei Blizzard: die Talentgruppen-Bindung macht
--   VuloGearSets selbst, zwei Automatiken wuerden gegeneinander anlegen.
-- =========================================================
local _, ns = ...
local L = ns.L

local mod = ns:RegisterModule("blizzsets", {
    name     = "Blizzard Equipment Manager",
    group    = "_hidden",
    defaults = { enabled = true },
})

local CES = _G.C_EquipmentSet
local GetItemInfoInstant = _G.GetItemInfoInstant
    or (_G.C_Item and _G.C_Item.GetItemInfoInstant)

-- Blizzards Sets kennen die Slots 1-19. VuloGearSets speichert Hemd (4)
-- und Wappenrock (19) nie - die bleiben bei Blizzard ignoriert.
local FIRST_SLOT, LAST_SLOT = 1, 19

local function available()
    return ns.isForever and CES ~= nil and CES.CreateEquipmentSet ~= nil
end

local function active()
    if not (available() and mod._enabled and ns:IsModuleEnabled("blizzsets")) then
        return false
    end
    if CES.CanUseEquipmentSets then
        local ok, can = pcall(CES.CanUseEquipmentSets)
        if ok and not can then return false end
    end
    return true
end

local function mirrorMap()
    local c = ns:GetCharDB()
    c.blizzMirror = c.blizzMirror or {}
    return c.blizzMirror
end

local function ourSets()
    local c = ns:GetCharDB()
    c.sets = c.sets or {}
    return c.sets
end

local function blizzID(name)
    if type(name) ~= "string" or not CES.GetEquipmentSetID then return nil end
    local ok, id = pcall(CES.GetEquipmentSetID, name)
    if ok and type(id) == "number" then return id end
    return nil
end

local function maxSets()
    return tonumber(_G.MAX_EQUIPMENT_SETS_PER_PLAYER) or 10
end

local function numBlizzSets()
    if CES.GetNumEquipmentSets then
        local ok, n = pcall(CES.GetNumEquipmentSets)
        if ok and type(n) == "number" then return n end
    end
    local ok, ids = pcall(CES.GetEquipmentSetIDs)
    return (ok and type(ids) == "table") and #ids or 0
end

-- =========================================================
-- Symbol
--
-- Blizzard speichert Symbole als Datei-ID. Symbole aus dem Addon-Ordner
-- haben keine; dann nimmt Blizzards Kopie das Symbol des ersten Teils.
-- =========================================================
local function iconFileID(loadout)
    local ov = loadout and loadout.iconOverride
    if type(ov) == "number" then return ov end
    if type(ov) == "string" and _G.GetFileIDFromPath
       and not ov:lower():find("^interface\\addons\\") then
        local ok, id = pcall(_G.GetFileIDFromPath, ov)
        if ok and type(id) == "number" and id > 0 then return id end
    end
    if loadout and loadout.slots and GetItemInfoInstant then
        local slots = {}
        for s in pairs(loadout.slots) do slots[#slots + 1] = s end
        table.sort(slots)
        for _, s in ipairs(slots) do
            local _, _, _, _, icon = GetItemInfoInstant(loadout.slots[s])
            if type(icon) == "number" then return icon end
        end
    end
    return nil
end

-- =========================================================
-- Vergleich: passt Blizzards Kopie zum Set?
-- =========================================================
local function maskOf(loadout)
    local inMask = {}
    for _, s in ipairs(loadout.slotMask or {}) do inMask[s] = true end
    if not next(inMask) then
        for s in pairs(loadout.slots or {}) do inMask[s] = true end
    end
    inMask[4], inMask[19] = nil, nil
    return inMask
end

-- Wo Blizzard das Teil eines Slots vermutet: getragen in genau diesem Slot?
-- Aufgerufen nur, wenn unser Set vollstaendig getragen wird - dann muss
-- jede Position auf den eigenen Slot am Charakter zeigen, sonst hat
-- Blizzard ein anderes Exemplar gespeichert.
--
-- Blizzard hat das Entpacken der Positionen einmal umgebaut: neuere
-- Clients liefern eine Tabelle (EquipmentManager_GetLocationData), aeltere
-- mehrere Rueckgabewerte. Gibt es keins von beiden, bleibt es beim
-- Vergleich der Item-IDs (Rueckgabe nil).
local function locationIsWornIn(location, slot)
    if type(location) ~= "number" or location < 0 then return nil end
    local player, bank, bags, locSlot
    local getData = _G.EquipmentManager_GetLocationData
    local unpackLoc = _G.EquipmentManager_UnpackLocation
    if getData then
        local ok, d = pcall(getData, location)
        if not (ok and type(d) == "table") then return nil end
        if d.isPlayer == nil and d.slot == nil then return nil end
        player, bank, bags, locSlot = d.isPlayer, d.isBank, d.isBags, d.slot
    elseif unpackLoc then
        local ok, p, bk, bg, _, sl = pcall(unpackLoc, location)
        if not ok then return nil end
        player, bank, bags, locSlot = p, bk, bg, sl
    else
        return nil
    end
    return (player and not bank and not bags and locSlot == slot) and true or false
end

local function mirrorMatches(setID, loadout)
    local okI, ignored = pcall(CES.GetIgnoredSlots, setID)
    local okD, ids     = pcall(CES.GetItemIDs, setID)
    if not (okI and okD and type(ignored) == "table" and type(ids) == "table") then
        return false
    end
    local locations
    if CES.GetItemLocations then
        local ok, t = pcall(CES.GetItemLocations, setID)
        if ok and type(t) == "table" then locations = t end
    end

    local inMask = maskOf(loadout)
    for s = FIRST_SLOT, LAST_SLOT do
        local isIgnored = ignored[s] and true or false
        if not inMask[s] then
            if not isIgnored then return false end
        else
            if isIgnored then return false end
            local link = loadout.slots and loadout.slots[s]
            local want = link and tonumber(link:match("item:(%d+)")) or 0
            if (tonumber(ids[s]) or 0) ~= want then return false end
            if want ~= 0 and locations then
                -- nil heisst "nicht pruefbar" - dann genuegt die ID
                if locationIsWornIn(locations[s], s) == false then return false end
            end
        end
    end
    return true
end

-- =========================================================
-- Schreiben
-- =========================================================
local _pendingCreate = {}   -- Name -> true, bis Blizzard das Set meldet
local _seen          = {}   -- Name -> true: diese Sitzung bei Blizzard gesehen
local _triedCreate   = {}   -- Name -> true: diese Sitzung von uns angelegt
local _fullWarned    = false

-- Die Liste der beim Speichern ignorierten Slots gibt es im Client nur
-- einmal - Blizzards eigenes Fenster laedt dort die Auswahl des gerade
-- markierten Sets hinein. Deshalb vorher merken und danach genau so
-- wiederherstellen, statt sie leer zurueckzulassen.
local function withIgnoredSlots(loadout, fn)
    local before = {}
    if CES.IsSlotIgnoredForSave then
        for s = FIRST_SLOT, LAST_SLOT do
            local ok, ign = pcall(CES.IsSlotIgnoredForSave, s)
            before[s] = ok and ign and true or false
        end
    end
    local inMask = maskOf(loadout)
    pcall(CES.ClearIgnoredSlotsForSave)
    for s = FIRST_SLOT, LAST_SLOT do
        if not inMask[s] then pcall(CES.IgnoreSlotForSave, s) end
    end
    local ok, err = pcall(fn)
    pcall(CES.ClearIgnoredSlotsForSave)
    for s = FIRST_SLOT, LAST_SLOT do
        if before[s] then pcall(CES.IgnoreSlotForSave, s) end
    end
    if not ok then ns:Debug("BlizzardSets: %s", tostring(err)) end
    return ok
end

-- Blizzards Kopie aus der getragenen Ausruestung schreiben. Nur aufrufen,
-- wenn das Set gerade vollstaendig getragen wird.
local function writeMirror(name, loadout)
    local icon = iconFileID(loadout)
    local setID = blizzID(name)
    if setID then
        return withIgnoredSlots(loadout, function() CES.SaveEquipmentSet(setID, icon) end)
    end

    if _pendingCreate[name] then return false end
    -- Noch nicht bestaetigte Anlagen zaehlen mit: werden mehrere Sets auf
    -- einmal vollstaendig getragen, darf nicht jedes die letzte Luecke sehen.
    local pending = 0
    for _ in pairs(_pendingCreate) do pending = pending + 1 end
    if numBlizzSets() + pending >= maxSets() then
        if not _fullWarned then
            _fullWarned = true
            ns:Print(string.format(
                L["Blizzard's equipment manager is full (%d sets). '%s' stays in VuloGearSets only."],
                maxSets(), name))
        end
        return false
    end
    _pendingCreate[name] = true
    _triedCreate[name] = true
    local ok = withIgnoredSlots(loadout, function() CES.CreateEquipmentSet(name, icon) end)
    -- Blizzard lehnt manche Namen ab (zu lang, verbotene Zeichen), ohne
    -- einen Fehler zu werfen. Kommt das Set nicht an, wird das gemerkt -
    -- ueber die Sitzung hinaus, sonst kaeme die Meldung bei jedem Login.
    C_Timer.After(2, function()
        if not _pendingCreate[name] then return end   -- schon gemeldet
        _pendingCreate[name] = nil
        if blizzID(name) then
            mirrorMap()[name] = true
            _seen[name] = true
        else
            if ourSets()[name] then mirrorMap()[name] = "rejected" end
            ns:Print(string.format(
                L["'%s' could not be added to Blizzard's equipment manager, possibly because the name is too long. It stays in VuloGearSets; on the action bar it becomes a macro."], name))
        end
    end)
    return ok
end

-- Ein Set nachziehen, falls es getragen wird und Blizzards Kopie nicht passt.
-- adopt = true: vom Spieler ausdruecklich gespeichert - fremde Blizzard-Sets
-- gleichen Namens und frueher geloeschte Kopien werden (wieder) uebernommen.
local function syncSet(name, adopt)
    -- Vor _ready ist Blizzards Liste womoeglich noch leer: ein vorhandenes
    -- Set saehe fehlend aus und wuerde ein zweites Mal angelegt.
    if not mod._ready or not active() or InCombatLockdown() then return end
    local loadout = ourSets()[name]
    if type(loadout) ~= "table" then return end

    local map = mirrorMap()
    local setID = blizzID(name)
    if adopt then
        -- Uebernommen wird erst, was es bei Blizzard wirklich gibt. Ein Set,
        -- das erst noch angelegt werden muss, gehoert uns, sobald Blizzard
        -- es meldet (siehe writeMirror/onSetsChanged).
        map[name] = setID and true or nil
    elseif map[name] == false or map[name] == "rejected" then
        return
    elseif setID and map[name] ~= true then
        return   -- fremdes Set gleichen Namens: nicht anfassen
    end

    local st = ns.GetSetStatus and ns.GetSetStatus(name)
    if not (st and st.state == "equipped") then return end
    if setID and mirrorMatches(setID, loadout) then return end

    writeMirror(name, loadout)
end

local function syncAll()
    if not active() or InCombatLockdown() then return end
    for name in pairs(ourSets()) do syncSet(name, false) end
end

-- Mehrere Ausruestungsereignisse hintereinander (ein Set-Wechsel tauscht
-- viele Teile) ergeben einen einzigen Abgleich.
local _syncQueued = false
local function queueSync()
    if _syncQueued or not mod._ready then return end
    _syncQueued = true
    C_Timer.After(0.5, function()
        _syncQueued = false
        syncAll()
    end)
end

-- =========================================================
-- Aufrufe aus dem Set-Modul
-- =========================================================
function ns:MirrorSetSaved(name)
    if not active() then return end
    if InCombatLockdown() then return end
    syncSet(name, true)
end

function ns:MirrorSetDeleted(name)
    local map = mirrorMap()
    local owned = map[name]
    map[name] = nil
    _seen[name], _pendingCreate[name] = nil, nil
    -- Loeschen und Umbenennen sind bei Blizzard nicht kampfgesperrt - nur
    -- das Speichern aus der Ausruestung wartet (siehe syncSet).
    if owned ~= true or not available() then return end
    local setID = blizzID(name)
    if setID then
        pcall(CES.DeleteEquipmentSet, setID)
    end
end

function ns:MirrorSetRenamed(oldName, newName)
    local map = mirrorMap()
    local owned = map[oldName]
    map[oldName] = nil
    _seen[oldName], _pendingCreate[oldName] = nil, nil
    -- Ein abgelehnter Name ist mit dem Umbenennen erledigt: der neue
    -- bekommt einen frischen Versuch.
    if owned == nil or owned == "rejected" then return end
    if owned == false then map[newName] = false return end
    if not available() then return end

    local setID = blizzID(oldName)
    if not setID then return end
    if blizzID(newName) then
        -- Den neuen Namen belegt schon ein fremdes Blizzard-Set. Unsere
        -- alte Kopie wuerde sonst unter falschem Namen zurueckbleiben.
        pcall(CES.DeleteEquipmentSet, setID)
        return
    end
    -- Ohne eigenes Symbol (Set ohne Teile) das bisherige behalten.
    local icon = iconFileID(ourSets()[newName])
    if not icon and CES.GetEquipmentSetInfo then
        local ok, _, cur = pcall(CES.GetEquipmentSetInfo, setID)
        if ok and type(cur) == "number" then icon = cur end
    end
    map[newName] = true
    if not pcall(CES.ModifyEquipmentSet, setID, newName, icon) then
        map[newName] = nil
    end
end

function ns:MirrorSetIconChanged(name)
    if not active() or InCombatLockdown() then return end
    if mirrorMap()[name] ~= true then return end
    local setID = blizzID(name)
    if not setID then return end
    local icon = iconFileID(ourSets()[name])
    if icon then pcall(CES.ModifyEquipmentSet, setID, name, icon) end
end

-- Blizzards Set-ID fuer die Aktionsleiste - nur fuer unsere Kopien.
function ns:BlizzSetID(name)
    if not active() or mirrorMap()[name] ~= true then return nil end
    return blizzID(name)
end

function ns:BlizzMirrorActive()
    return active()
end

function ns:PickupBlizzSet(name)
    local setID = ns:BlizzSetID(name)
    if not setID or InCombatLockdown() or not CES.PickupEquipmentSet then return end
    ClearCursor()
    pcall(CES.PickupEquipmentSet, setID)
end

-- =========================================================
-- Hat der Spieler unsere Kopie in Blizzards Fenster geloescht oder
-- umbenannt? Dann nicht stumm wieder anlegen.
--
-- Nur fuer Sets, die diese Sitzung schon bei Blizzard gesehen wurden:
-- kurz nach dem Login kann die Liste noch leer sein, und das darf nicht
-- als "geloescht" gelten.
-- =========================================================
local function onSetsChanged()
    if not available() then return end
    local map = mirrorMap()
    -- Frisch angelegte Kopien: sobald Blizzard sie meldet, gehoeren sie uns.
    for name in pairs(_pendingCreate) do
        if blizzID(name) then
            _pendingCreate[name] = nil
            map[name] = true
        end
    end
    -- Kam die Bestaetigung erst nach Ablauf der Wartezeit, steht das Set
    -- schon als "abgelehnt" da. Hat diese Sitzung es selbst angelegt und
    -- Blizzard kennt es jetzt, ist es doch unseres.
    for name in pairs(_triedCreate) do
        if map[name] == "rejected" and blizzID(name) then
            map[name] = true
            ns:Print(string.format(
                L["'%s' has arrived in Blizzard's equipment manager after all."], name))
        end
    end
    -- Unsere eigenen Loeschungen tauchen hier nicht auf: MirrorSetDeleted
    -- und MirrorSetRenamed nehmen den Namen vorher aus der Liste.
    for name, owned in pairs(map) do
        if blizzID(name) then
            _seen[name] = true
        elseif owned == true and _seen[name] and not _pendingCreate[name] then
            map[name] = false
            _seen[name] = nil
        end
    end
    -- Verwaiste Merker aufraeumen: Sets, die es bei uns nicht mehr gibt.
    local sets = ourSets()
    for name in pairs(map) do
        if sets[name] == nil then map[name] = nil end
    end
end

local function onEquipmentChanged() queueSync() end

-- =========================================================
-- Modul-Lebenszyklus
-- =========================================================
function mod:OnEnable()
    if not available() then return end
    ns:RegisterEvent("EQUIPMENT_SETS_CHANGED",   onSetsChanged)
    ns:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", onEquipmentChanged)
    ns:RegisterEvent("PLAYER_REGEN_ENABLED",     onEquipmentChanged)
    -- Erst abgleichen, wenn Blizzards Set-Liste sicher geladen ist.
    -- Vorher sieht ein vorhandenes Set aus wie ein fehlendes, und das
    -- Nachziehen wuerde es doppelt anlegen wollen.
    if mod._ready then
        onSetsChanged()
        queueSync()
    else
        C_Timer.After(3, function()
            mod._ready = true
            onSetsChanged()
            if mod._enabled then queueSync() end
        end)
    end
end

function mod:OnDisable()
    ns:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED", onEquipmentChanged)
    ns:UnregisterEvent("PLAYER_REGEN_ENABLED",     onEquipmentChanged)
    -- EQUIPMENT_SETS_CHANGED bleibt: auch ohne Spiegeln soll ein im
    -- Blizzard-Fenster geloeschtes Set als geloescht gelten.
end
