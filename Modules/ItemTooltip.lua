-- =========================================================
-- VuloGearSets / Modules / ItemTooltip
-- Haengt an jeden Item-Tooltip eine Zeile mit den Sets, in denen das
-- Teil vorkommt: "Sets: Tank, PvP".
--
-- WARUM EIN EIGENES MODUL
--   Es braucht vom Set-Modul nichts ausser den Daten, und die stehen in
--   der Charakter-Datenbank. GearSets.lua ist gross genug. Versteckt
--   registriert wie Slot-Picker und Sockel-Leiste: der Schalter steht
--   auf der Optionsseite des Set-Moduls.
--
-- NUR LESEN
--   Weder Sets noch Blizzard-Frames werden angefasst. Der Tooltip
--   bekommt eine Zeile, mehr nicht - kein Taint-Risiko.
-- =========================================================
local _, ns = ...
local L = ns.L

local mod = ns:RegisterModule("itemtooltip", {
    name     = "Item Tooltip",
    group    = "_hidden",
    defaults = { enabled = true },
})

-- =========================================================
-- Itemlink zerlegen
--
-- Verglichen wird die Item-ID - Verzauberung und Steine machen aus
-- einem Teil kein anderes. Der Zufalls-Suffix (Feld 7) zaehlt aber mit:
-- "Ring des Baeren" und "Ring der Eule" teilen sich in Classic die ID
-- und waeren sonst nicht auseinanderzuhalten.
-- =========================================================
local function parseLink(link)
    if type(link) ~= "string" then return nil end
    local payload = link:match("item:([%-%d:]+)")
    if not payload then return nil end

    local fields, n = {}, 0
    for v in (payload .. ":"):gmatch("([%-%d]*):") do
        n = n + 1
        fields[n] = v
    end

    local id = tonumber(fields[1])
    if not id then return nil end
    return id, tonumber(fields[7]) or 0
end

-- =========================================================
-- Index: ItemID -> { { name = Setname, suffix = n }, ... }
--
-- Gilt nur fuer diesen Frame, danach wird er verworfen. Dasselbe
-- Muster wie getAvailIndex() im Set-Modul, und aus demselben Grund:
-- so ist jede Aenderung an den Sets sofort im Tooltip zu sehen, ohne
-- dass an jeder Speicher-, Loesch- und Umbenennstelle eine
-- Invalidierung nachgezogen werden muss. Zwanzig Sets mit je siebzehn
-- Teilen sind 340 Durchlaeufe - einmal je Frame, in dem ueberhaupt
-- ein Tooltip erscheint.
-- =========================================================
local index

local function buildIndex()
    local idx = {}
    local sets = ns:GetCharDB().sets
    if type(sets) ~= "table" then return idx end

    for name, set in pairs(sets) do
        if type(name) == "string" and type(set) == "table" and type(set.slots) == "table" then
            for _, link in pairs(set.slots) do
                local id, suffix = parseLink(link)
                if id then
                    local bucket = idx[id]
                    if not bucket then
                        bucket = {}
                        idx[id] = bucket
                    end
                    -- Dasselbe Teil in zwei Slots desselben Sets (Ringe,
                    -- Schmuck) soll den Namen nicht doppelt eintragen.
                    local known = false
                    for _, e in ipairs(bucket) do
                        if e.name == name and e.suffix == suffix then
                            known = true
                            break
                        end
                    end
                    if not known then
                        bucket[#bucket + 1] = { name = name, suffix = suffix }
                    end
                end
            end
        end
    end
    return idx
end

local function getIndex()
    if index then return index end
    local built = buildIndex()
    -- Ohne Timer wird gar nicht erst gemerkt: lieber jedes Mal neu bauen
    -- als eine veraltete Liste anzeigen.
    if C_Timer and C_Timer.After then
        index = built
        C_Timer.After(0, function() index = nil end)
    end
    return built
end

-- Setnamen zu einem Link, alphabetisch. nil, wenn das Teil in keinem Set steckt.
local function setsForLink(link)
    local id, suffix = parseLink(link)
    if not id then return nil end

    local bucket = getIndex()[id]
    if not bucket then return nil end

    local names, seen = {}, {}
    for _, e in ipairs(bucket) do
        -- Der Suffix trennt nur, wenn BEIDE Seiten einen tragen. Ein Set
        -- aus einer Zeit ohne Suffix im Link soll weiter passen.
        local mismatch = (suffix ~= 0 and e.suffix ~= 0 and suffix ~= e.suffix)
        if not mismatch and not seen[e.name] then
            seen[e.name] = true
            names[#names + 1] = e.name
        end
    end

    if #names == 0 then return nil end
    -- Dieselbe Reihenfolge wie in der Set-Leiste (vom Spieler sortiert),
    -- Rueckfall alphabetisch, falls das Set-Modul nicht geladen ist.
    if ns.SortedSetNames then
        local rank = {}
        for i, n in ipairs(ns.SortedSetNames()) do rank[n] = i end
        table.sort(names, function(a, b)
            return (rank[a] or math.huge) < (rank[b] or math.huge)
                or ((rank[a] or math.huge) == (rank[b] or math.huge) and a < b)
        end)
    else
        table.sort(names)
    end
    return names
end

-- =========================================================
-- Die Zeile
-- =========================================================
local guarded = setmetatable({}, { __mode = "k" })
-- Fuer welchen Link die Zeile schon steht, je Tooltip. Bewusst eine eigene
-- Tabelle statt eines Feldes am Tooltip: ein von einem Addon geschriebenes
-- Feld verseucht Blizzards Frame (Taint), und auf Forever stolpert der
-- Tooltip danach ueber seine eigenen geschuetzten Werte.
local shownFor = setmetatable({}, { __mode = "k" })

-- Der Hook feuert bei Taschen-Items auf manchen Clients zweimal. Gemerkt
-- wird, fuer welchen Link die Zeile schon steht; das Aufraeumen des
-- Tooltips setzt den Merker zurueck, damit dasselbe Teil beim naechsten
-- Ueberfahren wieder eine bekommt.
local function alreadyShown(tt, link)
    if shownFor[tt] == link then return true end
    shownFor[tt] = link
    if not guarded[tt] and tt.HookScript then
        guarded[tt] = true
        local clear = function(self) shownFor[self] = nil end
        pcall(tt.HookScript, tt, "OnHide", clear)
        pcall(tt.HookScript, tt, "OnTooltipCleared", clear)
    end
    return false
end

local function plainString(v)
    return type(v) == "string" and not (issecretvalue and issecretvalue(v))
end

local function linkFromTooltip(tt, data)
    if type(data) == "table" then
        if plainString(data.hyperlink) then return data.hyperlink end
        if type(data.id) == "number" and not (issecretvalue and issecretvalue(data.id)) then
            return "item:" .. tostring(data.id)
        end
    end
    if tt and tt.GetItem then
        local ok, _, link = pcall(tt.GetItem, tt)
        if ok and plainString(link) then return link end
    end
    return nil
end

-- Sets, die Blizzards eigene Zeile schon nennt ("Ausruestungssets: X").
-- Auf Forever spiegelt BlizzardSets.lua die Sets in Blizzards
-- Ausruestungsmanager, und der Client schreibt dann selbst eine Zeile
-- dazu. Nur was dort NICHT steht, bekommt unsere Zeile - so steht kein
-- Set doppelt im Tooltip, und ein nicht gespiegeltes fehlt auch nicht.
local function namesInBlizzardLine(data)
    local fmt = _G.EQUIPMENT_SETS
    if type(data) ~= "table" or type(data.lines) ~= "table" or type(fmt) ~= "string" then
        return nil
    end
    -- Das Format traegt selbst Farbcodes ("...: |cFFFFFFFF%s|r"); vor dem
    -- Vergleich auf beiden Seiten entfernen.
    local prefix = fmt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^(.-)%%s")
    if not prefix or prefix == "" then return nil end
    for _, line in ipairs(data.lines) do
        local text = type(line) == "table" and line.leftText
        if plainString(text) then
            text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if text:sub(1, #prefix) == prefix then
                local listed = {}
                for n in (text:sub(#prefix + 1) .. ","):gmatch("%s*(.-)%s*,") do
                    if n ~= "" then listed[n] = true end
                end
                return listed
            end
        end
    end
    return nil
end

-- remeasure: nur fuer den alten Hook ohne TooltipDataProcessor. Der
-- Prozessor ruft nach allen Rueckrufen selbst Show() auf; ein eigenes
-- Show() mittendrin loeste dort nur einen zweiten Aufbau aus.
local function addSetLine(tt, data, remeasure)
    -- Der Schalter wird HIER geprueft, nicht beim Setzen des Hooks: ein
    -- Hook laesst sich nicht wieder loesen.
    if not ns:IsModuleEnabled("itemtooltip") then return end
    if not (tt and tt.AddLine) then return end

    local link = linkFromTooltip(tt, data)
    if not link then return end

    local names = setsForLink(link)
    if not names then return end
    local listed = namesInBlizzardLine(data)
    if listed then
        for i = #names, 1, -1 do
            if listed[names[i]] then table.remove(names, i) end
        end
        if #names == 0 then return end
    end
    if alreadyShown(tt, link) then return end

    tt:AddLine(" ")
    tt:AddLine(string.format("|cff9b6cff%s|r %s", L["Sets:"], table.concat(names, ", ")),
        1, 1, 1)
    -- Neu vermessen, sonst reicht der Rahmen nicht bis zur neuen Zeile.
    if remeasure and tt.Show then tt:Show() end
end

-- =========================================================
-- Hooks
--
-- Kein Versionstest, nur proben und zurueckfallen. Der neue
-- TooltipDataProcessor deckt jeden Item-Tooltip des Clients ab
-- (Taschen, Bank, angelegtes, Haendler, Chat-Links). Wo es ihn nicht
-- gibt, tun es die beiden alten Skripte.
-- =========================================================
local function installHooks()
    local TDP = _G.TooltipDataProcessor
    local itemType = _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Item
    if TDP and TDP.AddTooltipPostCall and itemType then
        -- Sofort anhaengen, auf allen Clients. Frueher kam die Zeile auf
        -- Forever einen Frame spaeter (Vorsicht wegen Taint). Haendler-
        -- und Taschen-Tooltips bauen sich aber alle 0,2 s neu auf - dann
        -- stand der Tooltip jedes Mal einen Frame ohne Zeile da und
        -- flackerte. Die Vorsicht ist unnoetig: Forever ruft Rueckrufe von
        -- Addons ueber einen abgeschotteten Frame auf (TooltipDataHandler,
        -- InsecureTooltipPostCalls), Taint laeuft nicht in den Aufbau zurueck.
        TDP.AddTooltipPostCall(itemType, function(tt, data) addSetLine(tt, data, false) end)
        return
    end

    for _, tt in ipairs({ _G.GameTooltip, _G.ItemRefTooltip }) do
        if tt and tt.HookScript then
            tt:HookScript("OnTooltipSetItem", function(self) addSetLine(self, nil, true) end)
        end
    end
end

-- =========================================================
-- Modul-Lebenszyklus
-- =========================================================
function mod:OnEnable()
    -- Genau einmal: Hooks bleiben liegen, ein zweiter Satz haenge die
    -- Zeile doppelt an.
    if self._hooked then return end
    self._hooked = true
    installHooks()
end

function mod:OnDisable()
    -- Der Hook bleibt liegen und fragt ns:IsModuleEnabled - das genuegt.
end

-- =========================================================
-- Optionen
--
-- Bewusst KEIN mod:GetOptions(): das Modul ist versteckt
-- (group = "_hidden"). Der Schalter steht auf der Seite des
-- Set-Moduls.
-- =========================================================
