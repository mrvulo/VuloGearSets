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
        -- Hemd und Wappenrock speichert VuloGearSets nie. Ein in Blizzards
        -- Fenster neu angelegtes Set enthaelt sie aber (dessen Fenster
        -- raeumt die Ausnahmen vor dem Anlegen ab) - sonst ueberschriebe
        -- der naechste Abgleich das Set des Spielers still.
        if s == 4 or s == 19 then
            -- nicht vergleichen
        elseif not inMask[s] then
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
-- > 0, solange wir selbst in Blizzards Manager schreiben. Die Gegenrichtung
-- (F050) uebergeht diese Aufrufe, sonst schaukelten sich beide Seiten auf.
local _selfWrite     = 0
-- true, solange ein in Blizzards Fenster gespeichertes Set bei uns
-- gespeichert wird - dann nicht zurueckspiegeln, Blizzard hat es schon.
local _fromBlizzard  = false
-- Set-ID -> { name = unser Name, icon = Blizzards Symbol }, je Sitzung.
-- Nach Blizzards Umbenennen kennt der Client den alten Namen nicht mehr,
-- und Blizzards OK schickt immer ein Symbol mit - nur ein anderes als das
-- gemerkte ist eine echte Aenderung (F051). Blizzard vergibt Set-IDs neu:
-- je Name gibt es deshalb hoechstens einen Eintrag, und Loeschen oder
-- Loesen der Verknuepfung raeumt ihn ab.
local _idInfo        = {}

local function forgetName(name)
    for id, info in pairs(_idInfo) do
        if info.name == name then _idInfo[id] = nil end
    end
end

-- keep = true: einen vorhandenen Eintrag fuer denselben Namen nicht
-- anfassen. So ruft ihn onSetsChanged auf - Blizzard meldet die Aenderung
-- schon WAEHREND des Bearbeiten-Aufrufs, und ein dort aufgefrischtes
-- Symbol sah fuer den Hook danach aus wie das alte: ein in Blizzards
-- Fenster gewaehltes Symbol kam nie an (R-68).
local function rememberID(name, keep)
    local setID = blizzID(name)
    if not setID then return end
    local cur = _idInfo[setID]
    if keep and cur and cur.name == name then return end
    forgetName(name)
    local icon
    if CES.GetEquipmentSetInfo then
        local ok, _, ic = pcall(CES.GetEquipmentSetInfo, setID)
        if ok then icon = ic end
    end
    _idInfo[setID] = { name = name, icon = icon }
end

local function idForName(name)
    for id, info in pairs(_idInfo) do
        if info.name == name then return id end
    end
    return nil
end

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
    _selfWrite = _selfWrite + 1
    local ok, err = pcall(fn)
    _selfWrite = _selfWrite - 1
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
        local ok = withIgnoredSlots(loadout, function() CES.SaveEquipmentSet(setID, icon) end)
        -- Blizzards Symbol ist jetzt unseres - fuer den Vergleich im Hook.
        rememberID(name)
        return ok
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
            rememberID(name)
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
        if setID then rememberID(name) end
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
    if _fromBlizzard or not active() then return end
    if InCombatLockdown() then return end
    syncSet(name, true)
end

-- Ein Teil des Sets wurde geaendert (Ersetzen, Entfernen in der Leiste).
-- Anders als MirrorSetSaved ohne Uebernahme: eine in Blizzards Fenster
-- geloeschte oder abgelehnte Kopie bleibt weg, ein fremdes Set gleichen
-- Namens unberuehrt. Geschrieben wird nur, wenn das Set gerade getragen ist.
function ns:MirrorSetChanged(name)
    if _fromBlizzard or not active() then return end
    if InCombatLockdown() then return end
    syncSet(name, false)
end

function ns:MirrorSetDeleted(name)
    local map = mirrorMap()
    local owned = map[name]
    map[name] = nil
    forgetName(name)
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
    -- In Blizzards Fenster umbenannt (F051): dort ist es schon geschehen,
    -- nur die Verknuepfung wandert mit.
    if _fromBlizzard then
        map[newName] = owned
        _seen[newName] = true
        rememberID(newName)
        return
    end
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
        forgetName(oldName)
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
    _selfWrite = _selfWrite + 1
    local ok = pcall(CES.ModifyEquipmentSet, setID, newName, icon)
    _selfWrite = _selfWrite - 1
    if ok then
        forgetName(oldName)
        rememberID(newName)
    else
        map[newName] = nil
    end
end

function ns:MirrorSetIconChanged(name)
    if not active() or InCombatLockdown() then return end
    if mirrorMap()[name] ~= true then return end
    local setID = blizzID(name)
    if not setID then return end
    local icon = iconFileID(ourSets()[name])
    if icon then
        _selfWrite = _selfWrite + 1
        pcall(CES.ModifyEquipmentSet, setID, name, icon)
        _selfWrite = _selfWrite - 1
        rememberID(name)
    end
end

-- Blizzards Set-ID fuer die Aktionsleiste - nur fuer unsere Kopien.
function ns:BlizzSetID(name)
    if not active() or mirrorMap()[name] ~= true then return nil end
    return blizzID(name)
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
        if blizzID(name) then
            if map[name] == "rejected" then
                map[name] = true
                ns:Print(string.format(
                    L["'%s' has arrived in Blizzard's equipment manager after all."], name))
            elseif map[name] == nil and ourSets()[name] then
                -- In Blizzards Fenster angelegt, Meldung kam spaet (F050).
                map[name] = true
            end
        end
    end
    -- Unsere eigenen Loeschungen tauchen hier nicht auf: MirrorSetDeleted
    -- und MirrorSetRenamed nehmen den Namen vorher aus der Liste.
    for name, owned in pairs(map) do
        if blizzID(name) then
            _seen[name] = true
            if owned == true then rememberID(name, true) end
        elseif owned == true and _seen[name] and not _pendingCreate[name] then
            -- Gibt es die gemerkte Set-ID noch, hat Blizzard das Set nur
            -- umbenannt - das entscheidet der Hook direkt danach (F051).
            local id = idForName(name)
            local okInfo, still = false, nil
            if id and CES.GetEquipmentSetInfo then
                okInfo, still = pcall(CES.GetEquipmentSetInfo, id)
            end
            if not (okInfo and type(still) == "string") then
                map[name] = false
                _seen[name] = nil
                forgetName(name)
            end
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
-- Gegenrichtung (F050): in Blizzards Fenster angelegt oder gespeichert
-- -> auch bei uns gespeichert und verknuepft.
--
-- Blizzards Aufrufe werden nur beobachtet (hooksecurefunc): ihr Ablauf
-- bleibt sicher, und an Blizzards Frames wird nichts geschrieben.
-- =========================================================
local QUESTION_MARK = 134400   -- Blizzards "?" = kein Symbol gewaehlt

local function chosenIcon(icon)
    if type(icon) == "number" then
        return (icon > 0 and icon ~= QUESTION_MARK) and icon or nil
    end
    if type(icon) == "string" and icon ~= ""
       and not icon:upper():find("INV_MISC_QUESTIONMARK", 1, true) then
        return icon
    end
    return nil
end

-- Die Slots, die Blizzard gerade gespeichert hat. Beim Speichern eines
-- vorhandenen Sets aus dessen gespeicherten Ausnahmen (GetIgnoredSlots) -
-- das ist, was Blizzard tatsaechlich gesichert hat. Beim Anlegen gibt es
-- noch keine Set-ID; dann die Ausnahmen fuers Speichern, die Blizzards
-- Fenster beim Anlegen schon vor dem Aufruf geleert hat. Hemd und
-- Wappenrock speichert VuloGearSets nie.
local function savedSlotList(setID)
    local ignored
    if setID and CES.GetIgnoredSlots then
        local ok, t = pcall(CES.GetIgnoredSlots, setID)
        if ok and type(t) == "table" then ignored = t end
    end
    local list = {}
    for s = FIRST_SLOT, LAST_SLOT do
        if s ~= 4 and s ~= 19 then
            local ign
            if ignored then
                ign = ignored[s]
            else
                local ok, v = pcall(CES.IsSlotIgnoredForSave, s)
                ign = ok and v
            end
            if not ign then list[#list + 1] = s end
        end
    end
    return list
end

local function adoptFromBlizzard(name, icon, isNew, setID)
    if _selfWrite > 0 or not active() then return end
    if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then
        return
    end
    -- Wie beim Speichern bei uns: Leerzeichen am Rand gehoeren nicht zum
    -- Namen, sonst liefe die Verknuepfung unter einem anderen Schluessel.
    name = name:match("^%s*(.-)%s*$")
    if name == "" then return end
    local GS = ns.GS
    if not (GS and GS.saveAs) then return end

    local slotList = savedSlotList(setID)
    _fromBlizzard = true
    local ok, err = pcall(GS.saveAs, name, slotList)
    _fromBlizzard = false
    if not ok then
        ns:Debug("BlizzardSets: %s", tostring(err))
        return
    end
    local loadout = ourSets()[name]
    if type(loadout) ~= "table" then return end

    -- Symbol: beim Anlegen das gewaehlte (Blizzards "?" = automatisch),
    -- beim Speichern nur ein anderes als unser bisheriges. Ohne Symbol
    -- (Speichern-Knopf im Fenster) bleibt es, wie es ist.
    local pick = chosenIcon(icon)
    local changed = false
    if isNew then
        changed = loadout.iconOverride ~= pick
        loadout.iconOverride = pick
    elseif pick and pick ~= iconFileID(loadout) then
        changed = true
        loadout.iconOverride = pick
    end
    if changed then
        if GS.refreshSidebar then GS.refreshSidebar() end
        if ns.UpdateSetMacroIcon then ns:UpdateSetMacroIcon(name) end
    end

    -- Verknuepfen: Blizzards Set gehoert jetzt zu unserem. Ein neues meldet
    -- Blizzard erst etwas spaeter (onSetsChanged); lehnt es den Namen ab,
    -- bleibt unser Set trotzdem gespeichert.
    if blizzID(name) then
        mirrorMap()[name] = true
        _seen[name] = true
        rememberID(name)
    else
        -- Kommt Blizzards Meldung spaeter, nimmt onSetsChanged sie ueber
        -- _triedCreate noch an.
        _pendingCreate[name] = true
        _triedCreate[name] = true
        C_Timer.After(2, function()
            if _pendingCreate[name] and not blizzID(name) then
                _pendingCreate[name] = nil
            end
        end)
    end
end

-- Bearbeiten in Blizzards Fenster (F051): Name und Symbol eines
-- verknuepften Sets uebernehmen. Umbenannt wird ueber denselben Weg wie
-- bei uns, damit Taste, Bindungen, Makro und Leiste mitgehen.
local function adoptModifyFromBlizzard(setID, newName, icon)
    if _selfWrite > 0 then return end
    local info = _idInfo[setID]
    if not info then return end
    local oldName = info.name
    local map = mirrorMap()
    if map[oldName] ~= true then return end

    local name = oldName
    if type(newName) == "string" and not (issecretvalue and issecretvalue(newName)) then
        newName = newName:match("^%s*(.-)%s*$")
    else
        newName = oldName
    end
    local renamed = newName ~= "" and newName ~= oldName

    local GS = ns.GS
    if not (active() and GS and GS.renameLoadout) then
        -- Spiegel aus: nichts uebernehmen, aber die Verknuepfung loesen wie
        -- bisher - sonst legte der naechste Abgleich ein zweites Set an.
        if renamed then map[oldName] = false; forgetName(oldName) end
        return
    end

    if renamed then
        _fromBlizzard = true
        local ok, final = pcall(GS.renameLoadout, oldName, newName)
        _fromBlizzard = false
        if not (ok and final) then
            -- Name bei uns schon vergeben: unser Set bleibt, die
            -- Verknuepfung wird geloest.
            map[oldName] = false
            forgetName(oldName)
            return
        end
        name = final
    end

    -- Symbol nur, wenn es in Blizzards Fenster wirklich geaendert wurde.
    local loadout = ourSets()[name]
    if icon ~= nil and icon ~= info.icon and type(loadout) == "table" then
        loadout.iconOverride = chosenIcon(icon)   -- "?" = automatisch
        if GS.refreshSidebar then GS.refreshSidebar() end
        if ns.UpdateSetMacroIcon then ns:UpdateSetMacroIcon(name) end
        -- Automatisch: unser Symbol zu Blizzard zurueck, statt "?" stehen
        -- zu lassen (laeuft unter _selfWrite).
        if loadout.iconOverride == nil then ns:MirrorSetIconChanged(name) end
    end
    rememberID(name)
end

local function installReverseHooks()
    if mod._hooked or not (hooksecurefunc and CES) then return end
    mod._hooked = true
    if CES.CreateEquipmentSet then
        -- Alles im Hook abgesichert: ein Fehler hier landete sonst mitten in
        -- Blizzards OK-Knopf.
        pcall(hooksecurefunc, CES, "CreateEquipmentSet", function(name, icon)
            local ok, err = pcall(adoptFromBlizzard, name, icon, true, nil)
            if not ok then ns:Debug("BlizzardSets: %s", tostring(err)) end
        end)
    end
    if CES.SaveEquipmentSet and CES.GetEquipmentSetInfo then
        pcall(hooksecurefunc, CES, "SaveEquipmentSet", function(setID, icon)
            if _selfWrite > 0 then return end
            local ok, name = pcall(CES.GetEquipmentSetInfo, setID)
            if not ok then return end
            local ok2, err = pcall(adoptFromBlizzard, name, icon, false, setID)
            if not ok2 then ns:Debug("BlizzardSets: %s", tostring(err)) end
        end)
    end
    if CES.ModifyEquipmentSet then
        pcall(hooksecurefunc, CES, "ModifyEquipmentSet", function(setID, newName, icon)
            local ok, err = pcall(adoptModifyFromBlizzard, setID, newName, icon)
            if not ok then ns:Debug("BlizzardSets: %s", tostring(err)) end
        end)
    end
end

-- =========================================================
-- Modul-Lebenszyklus
-- =========================================================
function mod:OnEnable()
    if not available() then return end
    -- Einmal je Sitzung; ein Hook laesst sich nicht wieder loesen, er
    -- fragt deshalb selbst active().
    installReverseHooks()
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

-- =========================================================
-- Optionen (Seite "Allgemein", nur Forever)
-- =========================================================
mod.optionsOrder = { general = 30 }

function mod:GetOptions(page)
    if page ~= "general" or not ns.isForever then return nil end
    return {
        { type = "toggle", label = L["Also keep sets in Blizzard's equipment manager"],
          tooltip = L["Mirrors every set into the equipment manager of the character window as soon as you save it or wear it completely. This gives the set a button for your action bars (right-click menu of the set), stores it on the server and lets other addons and bag windows see which items belong to it. Blizzard only allows a limited number of sets per character."],
          -- Bewusst kein default: "Alles zuruecksetzen" soll nicht wieder
          -- Sets in Blizzards Ausruestungsmanager (begrenzte Plaetze, liegt
          -- auf dem Server) schreiben, wenn jemand das abgeschaltet hatte.
          get = function() return ns:IsModuleEnabled("blizzsets") end,
          set = function(_, v) ns:ToggleModule("blizzsets", v, true) end },
    }
end
