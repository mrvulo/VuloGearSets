-- =========================================================
-- VuloGearSets / Modules / GearSets / Share
-- Sets weitergeben: als Text (Export/Import, F056) und zwischen den
-- Charakteren desselben Kontos (F072).
--
-- Ein Set ohne Bezug auf den Charakter heisst hier "Abbild": Teile als
-- Exemplar-Schluessel (variantKey: ID, Verzauberung, vier Steine,
-- Suffix), Maske, Symbol, Munition, Helm/Umhang. Ein importiertes Teil
-- steht danach als "item:..." im Set statt als voller Link - Anlegen,
-- Statuspunkt und Tooltip arbeiten mit beidem (getItemIDFromLink,
-- variantKey, SetHyperlink).
--
-- Kontoweite Ablage der Charakter-Abbilder: VuloGearSetsDB.charSets,
-- geschrieben beim Einloggen und Ausloggen. Gelesen wird nur, nie in den
-- Daten eines anderen Charakters geschrieben.
-- =========================================================
local _, ns = ...
local L   = ns.L
local GS  = ns.GS
local mod = GS.mod

local EQUIP_SLOTS = GS.EQUIP_SLOTS
local LO          = GS.LO
local variantKey  = GS.variantKey

local FORMAT = "!VGS1!"

-- Forever (Mainline-Familie) fuehrt GetItemInfo womoeglich nur unter C_Item.
local GetItemInfo = _G.GetItemInfo or (C_Item and C_Item.GetItemInfo)

-- =========================================================
-- Abbild eines Sets
-- =========================================================
local VALID_SLOT = {}
for _, s in ipairs(EQUIP_SLOTS) do VALID_SLOT[s] = true end

local function snapshotSet(set)
    local out = { slots = {}, slotMask = {} }
    for _, s in ipairs(set.slotMask or {}) do
        if VALID_SLOT[s] then out.slotMask[#out.slotMask + 1] = s end
    end
    for s, link in pairs(set.slots or {}) do
        local key = VALID_SLOT[s] and variantKey(link)
        if key then out.slots[s] = key end
    end
    out.iconOverride = set.iconOverride
    out.ammo         = tonumber(set.ammo)
    out.showHelm     = set.showHelm
    out.showCloak    = set.showCloak
    return out
end

-- Neuer Name, falls der gewuenschte schon vergeben ist: "Tank (2)" usw.
local function uniqueName(name)
    -- Wie beim Speichern hoechstens 32 Zeichen (Bytes; ein angeschnittenes
    -- Mehrbyte-Zeichen am Ende faellt weg) und kein "|" - das kaeme nach
    -- Kopieren und Einfuegen als Steuerzeichen oder doppelt an.
    name = tostring(name or ""):gsub("|", "")
    if #name > 32 then
        name = name:sub(1, 32):gsub("[\192-\255][\128-\191]*$", "")
    end
    name = name:match("^%s*(.-)%s*$")
    if name == "" then name = L["Imported set"] end
    if not LO()[name] then return name end
    for i = 2, 99 do
        local n = string.format("%s (%d)", name, i)
        if not LO()[n] then return n end
    end
    return name .. " " .. time()
end

-- =========================================================
-- Rohe Teile ("item:...") zu vollen Links machen
--
-- Menues und Tooltips zeigen den Namen aus dem Link; ein roher Eintrag
-- stuende dort als "item:12345:...". Der Client kennt fremde Teile oft
-- noch nicht - dann wird nachgeladen und bei GET_ITEM_INFO_RECEIVED erneut
-- versucht. Ersetzt wird nur, wenn der volle Link dasselbe Exemplar ist.
-- =========================================================
-- Hoechstens so viele Ladeversuche je Item-ID und Sitzung: eine ID, die
-- es nicht gibt (oder deren Link der Client anders baut), bliebe sonst
-- fuer immer offen und loeste jede halbe Sekunde einen neuen Lauf aus.
local MAX_TRIES = 3
local _tries = {}

local upgradeFrame = CreateFrame("Frame")
local function upgradeLinks()
    local pending, changed = false, false
    for _, set in pairs(LO() or {}) do
        for s, link in pairs((type(set) == "table" and set.slots) or {}) do
            if type(link) == "string" and link:sub(1, 5) == "item:" then
                local full = GetItemInfo and select(2, GetItemInfo(link))
                if full and variantKey(full) == variantKey(link) then
                    set.slots[s] = full
                    changed = true
                else
                    local id = tonumber(link:match("^item:(%d+)"))
                    if id and (_tries[id] or 0) < MAX_TRIES then
                        _tries[id] = (_tries[id] or 0) + 1
                        pending = true
                        local CI = _G.C_Item
                        if CI and CI.RequestLoadItemDataByID then
                            pcall(CI.RequestLoadItemDataByID, id)
                        end
                    end
                end
            end
        end
    end
    if pending then
        upgradeFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    else
        upgradeFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    end
    if changed and GS.refreshSidebar then GS.refreshSidebar() end
end
local _upgradeQueued = false
upgradeFrame:SetScript("OnEvent", function()
    -- Das Ereignis kommt je Teil; gesammelt einmal nacharbeiten.
    if _upgradeQueued or not (C_Timer and C_Timer.After) then return end
    _upgradeQueued = true
    C_Timer.After(0.5, function()
        _upgradeQueued = false
        upgradeLinks()
    end)
end)

-- Abbild als neues Set dieses Charakters anlegen. Rueckgabe: der Name.
local function addFromSnapshot(name, snap)
    name = uniqueName(name)
    local set = { createdAt = time(), slots = {}, slotMask = {} }
    local seen = {}
    for _, s in ipairs(snap.slotMask or {}) do
        if VALID_SLOT[s] and not seen[s] then
            seen[s] = true
            set.slotMask[#set.slotMask + 1] = s
        end
    end
    for s, key in pairs(snap.slots or {}) do
        if VALID_SLOT[s] and type(key) == "string" then
            set.slots[s] = "item:" .. key
        end
    end
    -- Ein Set ohne Maske fiele auf die Altdaten-Rueckfaelle; die belegten
    -- Slots sind dann die Maske.
    if #set.slotMask == 0 then
        for s in pairs(set.slots) do set.slotMask[#set.slotMask + 1] = s end
        table.sort(set.slotMask)
    end
    set.iconOverride = snap.iconOverride
    set.ammo         = snap.ammo
    set.showHelm     = snap.showHelm
    set.showCloak    = snap.showCloak
    LO()[name] = set
    upgradeLinks()

    if GS.sidebarAfterSave then GS.sidebarAfterSave(name) end
    if ns.MirrorSetSaved then ns:MirrorSetSaved(name) end
    if ns.RefreshOptions then ns:RefreshOptions() end
    return name
end

-- =========================================================
-- Text (F056)
--
-- !VGS1!Name!Symbol!Munition!Helm!Umhang!Maske!Slot=Schluessel;...!END
-- Die Endmarke beweist, dass der Text vollstaendig ist: eine Chatzeile
-- fasst 255 Zeichen, ein Export ist laenger. Ohne sie wuerden die Slots
-- hinter dem Schnitt als "leer anlegen" gelten und beim Anlegen
-- ausgezogen.
-- Name und Symbol prozentkodiert, damit "!" und ";" darin nichts stoeren.
-- Helm/Umhang: leer = lassen, 1 = zeigen, 0 = verbergen.
-- =========================================================
local function enc(s)
    return (tostring(s or ""):gsub("[%%!;=,]", function(c)
        return string.format("%%%02X", c:byte())
    end))
end

local function dec(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function triState(v)
    if v == true then return "1" elseif v == false then return "0" end
    return ""
end

local function parseTriState(s)
    if s == "1" then return true elseif s == "0" then return false end
    return nil
end

local function exportString(name)
    local set = LO()[name]
    if not set then return nil end
    local snap = snapshotSet(set)
    local slotParts = {}
    local slots = {}
    for s in pairs(snap.slots) do slots[#slots + 1] = s end
    table.sort(slots)
    for _, s in ipairs(slots) do
        slotParts[#slotParts + 1] = s .. "=" .. snap.slots[s]
    end
    local mask = {}
    for i, s in ipairs(snap.slotMask) do mask[i] = tostring(s) end
    return FORMAT .. table.concat({
        enc(name),
        enc(snap.iconOverride),
        tostring(snap.ammo or ""),
        triState(snap.showHelm),
        triState(snap.showCloak),
        table.concat(mask, ","),
        table.concat(slotParts, ";"),
        "END",
    }, "!")
end

-- Rueckgabe: Name des neuen Sets oder nil und eine Fehlermeldung.
local function importString(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text:sub(1, #FORMAT) ~= FORMAT then
        return nil, L["This is not a VuloGearSets export."]
    end
    local fields = {}
    for f in (text:sub(#FORMAT + 1) .. "!"):gmatch("(.-)!") do
        fields[#fields + 1] = f
    end
    if #fields < 8 or fields[8] ~= "END" then
        return nil, L["The text is incomplete - copy the whole line."]
    end

    local snap = { slots = {}, slotMask = {} }
    local name = dec(fields[1])
    local icon = dec(fields[2])
    snap.iconOverride = (icon ~= "") and (tonumber(icon) or icon) or nil
    snap.ammo         = tonumber(fields[3])
    snap.showHelm     = parseTriState(fields[4])
    snap.showCloak    = parseTriState(fields[5])
    for s in fields[6]:gmatch("(%d+)") do
        s = tonumber(s)
        if VALID_SLOT[s] then snap.slotMask[#snap.slotMask + 1] = s end
    end
    local count = 0
    for s, key in fields[7]:gmatch("(%d+)=([%-%d:]+)") do
        s = tonumber(s)
        if VALID_SLOT[s] and key:match("^%d+") then
            snap.slots[s] = key
            count = count + 1
        end
    end
    if count == 0 and #snap.slotMask == 0 then
        return nil, L["The text contains no items."]
    end
    return addFromSnapshot(name, snap)
end

StaticPopupDialogs["VGS_SET_EXPORT"] = {
    text = L["Gear set '%s' as text. Copy it with Ctrl+C and send it to someone:"],
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 360,
    maxLetters = 0,
    OnShow = function(self)
        local eb = ns.PopupEditBox(self)
        if not eb then return end
        eb:SetText(self.data or "")
        eb:HighlightText()
        eb:SetFocus()
    end,
    -- Nur zum Kopieren: Tippen setzt den Text zurueck.
    EditBoxOnTextChanged = function(self, data)
        if self:GetText() ~= (data or "") then
            self:SetText(data or "")
            self:HighlightText()
        end
    end,
    EditBoxOnEscapePressed = function() StaticPopup_Hide("VGS_SET_EXPORT") end,
    EditBoxOnEnterPressed  = function() StaticPopup_Hide("VGS_SET_EXPORT") end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function doImport(text)
    local name, err = importString(text)
    if name then
        ns:Print(string.format(L["Gear set '%s' imported."], name))
    else
        ns:Print(err)
    end
end

StaticPopupDialogs["VGS_SET_IMPORT"] = {
    text = L["Paste a gear set exported from VuloGearSets (Ctrl+V):"],
    button1 = L["Import"],
    button2 = CANCEL or L["Cancel"],
    hasEditBox = true,
    editBoxWidth = 360,
    maxLetters = 0,
    OnShow = function(self)
        local eb = ns.PopupEditBox(self)
        if eb then eb:SetText(""); eb:SetFocus() end
    end,
    OnAccept = function(self)
        local eb = ns.PopupEditBox(self)
        doImport(eb and eb:GetText())
    end,
    EditBoxOnEnterPressed = function(self)
        doImport(self:GetText())
        StaticPopup_Hide("VGS_SET_IMPORT")
    end,
    EditBoxOnEscapePressed = function() StaticPopup_Hide("VGS_SET_IMPORT") end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function showExport(name)
    local text = exportString(name)
    if not text then
        ns:Print(string.format(L["Gear set '%s' does not exist."], tostring(name)))
        return
    end
    local dlg = StaticPopup_Show("VGS_SET_EXPORT", name, nil, text)
    -- data kommt je nach Client nicht als Argument durch.
    if dlg then
        dlg.data = text
        local eb = ns.PopupEditBox(dlg)
        if eb then eb:SetText(text); eb:HighlightText() end
    end
end

local function showImport()
    StaticPopup_Show("VGS_SET_IMPORT")
end

-- =========================================================
-- Andere Charaktere (F072)
-- =========================================================
local function charKey()
    local name  = UnitName("player")
    local realm = GetRealmName and GetRealmName() or ""
    if not name then return nil end
    return name .. "-" .. realm
end

local function charStore()
    local db = ns.db or _G.VuloGearSetsDB
    if not db then return {} end
    db.charSets = db.charSets or {}
    return db.charSets
end

-- Abbild dieses Charakters ins Konto schreiben.
local function publishOwnSets()
    local key = charKey()
    if not key or not mod.db then return end
    local copy = {}
    for name, set in pairs(LO() or {}) do
        if type(set) == "table" then copy[name] = snapshotSet(set) end
    end
    local _, classFile = UnitClass("player")
    charStore()[key] = { class = classFile, sets = copy, updated = time() }
end

-- Andere Charaktere mit mindestens einem Set, alphabetisch.
local function otherCharacters()
    local own, list = charKey(), {}
    for key, entry in pairs(charStore()) do
        if key ~= own and type(entry) == "table" and next(entry.sets or {}) then
            list[#list + 1] = key
        end
    end
    table.sort(list)
    return list
end

local function setsOfCharacter(key)
    local entry = charStore()[key]
    local names = {}
    for n in pairs((entry and entry.sets) or {}) do names[#names + 1] = n end
    table.sort(names)
    return names
end

local function copyFromCharacter(key, setName)
    local entry = charStore()[key]
    local snap = entry and entry.sets and entry.sets[setName]
    if not snap then return end
    local name = addFromSnapshot(setName, snap)
    ns:Print(string.format(L["Gear set '%s' copied from %s."], name, key))
end

local function forgetCharacter(key)
    charStore()[key] = nil
    if ns.RefreshOptions then ns:RefreshOptions() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event)
    -- Beim Login eine Sekunde warten: Core/Init.lua steht am TOC-Ende und
    -- ruft InitDB im selben PLAYER_LOGIN erst NACH diesem Handler auf.
    if event == "PLAYER_LOGIN" and C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            publishOwnSets()
            -- Noch rohe Teile aus einer frueheren Sitzung nachziehen.
            upgradeLinks()
        end)
    else
        publishOwnSets()
    end
end)

-- Fuer die spaeter geladenen Dateien und /vgs (siehe Shared.lua).
GS.exportString      = exportString
GS.importString      = importString
GS.showExport        = showExport
GS.showImport        = showImport
GS.otherCharacters   = otherCharacters
GS.setsOfCharacter   = setsOfCharacter
GS.copyFromCharacter = copyFromCharacter
GS.forgetCharacter   = forgetCharacter
