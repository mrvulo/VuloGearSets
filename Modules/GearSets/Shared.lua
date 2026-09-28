-- =========================================================
-- VuloGearSets / Modules / GearSets / Shared
-- Equipment set manager.
-- Save current gear as a named "loadout" and quickly swap between sets.
--
-- Equipping in Anniversary is restricted (AutoEquipCursorItem is protected),
-- so we use UseContainerItem(bag, slot) which acts as a normal "use" on
-- equipable items → swap works out-of-combat for items located in bags.
--
-- Das Modul ist auf mehrere Dateien verteilt, geladen in dieser Reihenfolge:
--   Shared      Modul, Speicher, Konstanten, Item-/Taschen-/Bank-Helfer
--   Sets        Wechsel-Logik: Status, Speichern, Anlegen, Zurueck, Bank,
--               Popups, Slash-Befehle
--   AutoSwitch  Haltung/Gestalt, Reitgerte, Spec
--   Minimap     Minimap-Knopf und sein Menue
--   Pickers     Slot- und Symbolauswahl
--   Sidebar     die Leiste am Charakterfenster
--   Lifecycle   OnEnable/OnDisable
--   Options     Einstellungen
-- Geteilt wird ueber die private Tabelle ns.GS: jede Datei legt dort am
-- Ende ab, was spaetere Dateien brauchen, und holt sich oben, was
-- frueher geladene bereitstellen. Wer etwas aus einer SPAETER geladenen
-- Datei braucht, ruft es zur Laufzeit ueber GS auf.
-- =========================================================
local _, ns = ...
local L = ns.L

local mod = ns:RegisterModule("gearsets", {
    name        = "Equipment Sets",
    -- Nur kontoweite Darstellungsoptionen. Die Sets selbst und ihre
    -- Bindungen liegen pro Charakter (siehe charDB weiter unten), ebenso
    -- die Position der Seitenleiste.
    defaults = {
        enabled       = true,
        confirmDelete = true,
        -- Minimap button
        minimap = { hidden = false, angle = 45 },
        -- Auto-switch on stance/form change
        autoSwitchEnabled = true,
        -- Auto-switch on talent spec (dominant talent tab)
        specSwitchEnabled = true,
        -- Reitgerte automatisch anlegen. Bewusst aus: das Addon fasst
        -- ungefragt keine getragene Ausruestung an.
        ridingCropEnabled = false,
        -- Character-frame sidebar
        sidebarEnabled      = true,
        -- Feinjustierung gegenueber dem Charakterfenster. Blizzards Frame
        -- ist breiter und hoeher als sein sichtbarer Rahmen, deshalb sind
        -- die Standardwerte nicht 0. Nachstellbar mit /gearset tune.
        -- Auf Forever ist das Charakterfenster so gross wie sein Rahmen
        -- und traegt seine Reiter rechts, nicht unten (siehe
        -- sideTabsShift) - dort starten alle drei Werte nahe 0.
        sidebarTopOffset    = ns.isForever and 0 or -12,   -- Oberkante nach unten
        sidebarBottomOffset = ns.isForever and 0 or 76,    -- Unterkante nach oben (ueber die Reiter)
        sidebarXOffset      = ns.isForever and 3 or -34,   -- nach links, an den sichtbaren Rand
        -- Luecke zur fremden Statistikspalte, falls eine da ist. Deren
        -- sichtbarer Rahmen ragt ueber ihren Frame hinaus; das ist der
        -- Ausgleich dafuer. Ebenfalls mit /gearset tune nachstellbar.
        sidebarStatsGap     = 12,
    },
})

-- Private Tabelle fuer die Dateien dieses Moduls (siehe oben).
local GS = {}
ns.GS  = GS
GS.mod = mod

-- =========================================================
-- Speicherung pro Charakter. Sets und ihre Spec-/Form-Bindungen beziehen
-- sich auf die Ausruestung DIESES Charakters und liegen deshalb in der
-- Charakter-Datenbank, nicht in mod.db (kontoweit).
--
-- Bestehende Sets aus VuloClassicUI holt Core/Coexistence.lua einmalig
-- beim ersten Start ab.
-- =========================================================
local function charDB()
    return ns:GetCharDB()
end
local function LO()
    local c = charDB(); c.sets = c.sets or {}; return c.sets
end
local function specMap()
    local c = charDB(); c.specMapping = c.specMapping or {}; return c.specMapping
end
local function formMap()
    local c = charDB(); c.formMapping = c.formMapping or {}; return c.formMapping
end

-- =========================================================
-- API compat (Anniversary uses C_Container namespace)
-- =========================================================
local GetContainerItemID    = (C_Container and C_Container.GetContainerItemID)    or _G.GetContainerItemID
local GetContainerNumSlots  = (C_Container and C_Container.GetContainerNumSlots)  or _G.GetContainerNumSlots
local UseContainerItem      = (C_Container and C_Container.UseContainerItem)      or _G.UseContainerItem
local ContainerIDToInventoryID = (C_Container and C_Container.ContainerIDToInventoryID) or _G.ContainerIDToInventoryID
local GetContainerNumFreeSlots = (C_Container and C_Container.GetContainerNumFreeSlots) or _G.GetContainerNumFreeSlots

-- Forever kennt nur noch die C_Item-/C_Spell-Fassungen. Das Global zuerst,
-- damit sich auf den Classic-Clients nichts aendert.
local GetItemCount       = _G.GetItemCount       or (C_Item and C_Item.GetItemCount)
local GetItemInfoInstant = _G.GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)

-- Nur der Name eines Zaubers. GetSpellInfo liefert ihn als ersten Wert,
-- C_Spell.GetSpellInfo dagegen eine Tabelle - deshalb GetSpellName.
local function spellName(spellID)
    if not spellID then return nil end
    local fn = _G.GetSpellInfo or (C_Spell and C_Spell.GetSpellName)
    if not fn then return nil end
    local ok, name = pcall(fn, spellID)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

-- Equipment slots we capture (skip shirt=4 and tabard=19)
local EQUIP_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

-- Slot display names (for UI / pickers)
local SLOT_NAMES = {
    [1]  = L["Head"],    [2]  = L["Neck"],     [3]  = L["Shoulder"],
    [5]  = L["Chest"],   [6]  = L["Waist"],    [7]  = L["Legs"],
    [8]  = L["Feet"],    [9]  = L["Wrist"],    [10] = L["Hands"],
    [11] = L["Finger 1"], [12] = L["Finger 2"],
    [13] = L["Trinket 1"], [14] = L["Trinket 2"],
    [15] = L["Back"],
    [16] = L["Main Hand"], [17] = L["Off Hand"], [18] = L["Ranged"],
}
-- Der SlotPicker beschriftet sein Fenster damit. Ohne die gemeinsame Tabelle
-- stuenden dort die internen Framenamen ("SecondaryHand", "Finger0").
ns.SLOT_NAMES = SLOT_NAMES

-- Pre-defined slot groups for quick-save
local SLOT_GROUPS = {
    trinkets = { 13, 14 },
    weapons  = { 16, 17, 18 },
    rings    = { 11, 12 },
    armor    = { 1, 3, 5, 6, 7, 8, 9, 10, 15 },
}

-- =========================================================
-- Helpers
-- =========================================================
local function getItemIDFromLink(link)
    if not link then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- Kennung eines EXEMPLARS: Item-ID plus Verzauberung, die vier Sockel und
-- der Zufallswert-Suffix. Zwei Teile mit gleicher ID, aber verschiedenen
-- Steinen oder Verzauberungen (die T5-Schultern einmal mit Zaubermacht,
-- einmal mit Widerstand) bekommen so verschiedene Schluessel. Die uebrigen
-- Linkfelder (uniqueID, Levelangabe) bleiben bewusst draussen - sie aendern
-- sich, ohne dass das Teil ein anderes wird.
local function variantKey(link)
    if not link then return nil end
    local payload = link:match("item:([%-%d:]+)")
    if not payload then return nil end
    local fields = {}
    for f in (payload .. ":"):gmatch("(.-):") do
        fields[#fields + 1] = (f ~= "" and f) or "0"
        if #fields == 7 then break end
    end
    for i = #fields + 1, 7 do fields[i] = "0" end
    return table.concat(fields, ":")
end

local function captureCurrentEquipment(slotList)
    slotList = slotList or EQUIP_SLOTS
    local set = {}
    for _, slot in ipairs(slotList) do
        local link = GetInventoryItemLink("player", slot)
        if link then set[slot] = link end
    end
    return set
end

-- =========================================================
-- Die Bank zaehlt mit, solange ihr Fenster offen ist
--
-- Der Client behandelt Bankfaecher dann wie Taschenfaecher: was sich von
-- Hand auf einen Ausruestungsslot ziehen laesst, laesst sich auch ueber
-- EquipCursorItem anlegen. Ist das Fenster zu, liefert jeder Zugriff auf
-- die Faecher nichts - deshalb wird nicht einmal danach gesucht.
-- =========================================================
local BANK_CONTAINER_ID = _G.BANK_CONTAINER or -1

local function bankIsOpen()
    local bf = _G.BankFrame
    return (bf and bf.IsShown and bf:IsShown()) and true or false
end

local function isBankContainer(bag)
    return bag < 0 or bag > (NUM_BAG_SLOTS or 4)
end

-- Taschen zuerst, dann Bankhauptfach und Bankbeutel: ein Teil aus der
-- Tasche bleibt dem gleichen Teil an der Bank vorgezogen.
local function containerIDs(includeBank)
    local list = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do list[#list + 1] = bag end
    -- Forever hat statt Bankfach und Bankbeuteln nummerierte Bankreiter
    -- (neun auf 1.60.1) mit eigenen Container-IDs.
    local bagIndex = _G.Enum and _G.Enum.BagIndex
    if includeBank and bagIndex and bagIndex.CharacterBankTab_1 then
        local inv = _G.Constants and _G.Constants.InventoryConstants
        local n = (inv and inv.NumCharacterBankSlots) or 9
        for i = 1, n do
            local id = bagIndex["CharacterBankTab_" .. i]
            if id then list[#list + 1] = id end
        end
    elseif includeBank then
        list[#list + 1] = BANK_CONTAINER_ID
        local first = (NUM_BAG_SLOTS or 4) + 1
        -- Ein Beutel zu viel schadet nicht: den gibt es dann schlicht
        -- nicht und er meldet null Faecher.
        for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do
            list[#list + 1] = bag
        end
    end
    return list
end

local function findItemInBags(targetItemID, includeBank)
    if not GetContainerItemID or not GetContainerNumSlots then return nil end
    for _, bag in ipairs(containerIDs(includeBank)) do
        local slots = GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            if GetContainerItemID(bag, slot) == targetItemID then
                return bag, slot, isBankContainer(bag)
            end
        end
    end
    return nil
end

-- Wie findItemInBags, aber fuer ein bestimmtes EXEMPLAR (per Link).
-- Rueckgabe: zuerst der Fundort des exakten Exemplars, dahinter der erste
-- Fund mit nur passender ID als Rueckfallebene - der Aufrufer entscheidet,
-- ob er den noch braucht.
local GetContainerItemLink = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink

local function findVariantInBags(wantLink, includeBank)
    if not GetContainerItemID or not GetContainerNumSlots then return nil end
    local wantID  = getItemIDFromLink(wantLink)
    local wantKey = variantKey(wantLink)
    local idBag, idSlot, idFromBank
    for _, bag in ipairs(containerIDs(includeBank)) do
        local slots = GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            if GetContainerItemID(bag, slot) == wantID then
                local key = GetContainerItemLink
                    and variantKey(GetContainerItemLink(bag, slot))
                if wantKey and key == wantKey then
                    return bag, slot, isBankContainer(bag),
                           idBag, idSlot, idFromBank
                end
                if not idBag then
                    idBag, idSlot, idFromBank = bag, slot, isBankContainer(bag)
                end
            end
        end
    end
    return nil, nil, nil, idBag, idSlot, idFromBank
end

-- =========================================================
-- Equip a bag item into a SPECIFIC inventory slot.
-- UseContainerItem ignores the destination slot and always picks the first
-- valid one — that's why paired slots (rings 11/12, trinkets 13/14) always
-- ended up in the upper slot. EquipCursorItem(slot) is the only reliable API
-- that honours the exact target slot: pick the item onto the cursor, then
-- equip the cursor into the requested slot.
-- Shared with SlotPicker via ns:EquipBagItemToSlot.
-- =========================================================
local _PickupContainerItem = (C_Container and C_Container.PickupContainerItem) or _G.PickupContainerItem

function ns:EquipBagItemToSlot(bag, bagSlot, equipSlot)
    if InCombatLockdown() then return false, "combat" end
    if not _PickupContainerItem or not _G.EquipCursorItem then return false, "noapi" end

    ClearCursor()
    _PickupContainerItem(bag, bagSlot)
    -- Verify the pickup actually grabbed something
    if CursorHasItem and not CursorHasItem() then
        return false, "pickup"
    end
    -- EquipCursorItem honours the explicit slot (unlike UseContainerItem)
    local ok = pcall(_G.EquipCursorItem, equipSlot)
    -- Only clear if something is still stuck on the cursor (e.g. equip failed).
    -- A BoE-confirm popup leaves the item reserved — don't yank it back, let
    -- the player confirm. If equip succeeded the cursor is already empty.
    if CursorHasItem and CursorHasItem() then
        ClearCursor()
    end
    return ok
end

-- =========================================================
-- Ein bereits GETRAGENES Teil in einen anderen Slot verschieben.
-- Faelle: Ringe oder Schmuckstuecke ueber Kreuz angelegt, oder ein Set
-- will die Waffe im jeweils anderen Haendchen-Slot. Vom Quell-Slot auf
-- den Cursor, in den Ziel-Slot anlegen; das dabei verdraengte Teil
-- landet auf dem Cursor und geht zurueck in den Quell-Slot (bei Paar-
-- Slots immer gueltig) - passt es dort nicht, in die Taschen.
-- =========================================================
local function swapWornItem(fromSlot, toSlot)
    if InCombatLockdown() then return false end
    if not (_G.PickupInventoryItem and _G.EquipCursorItem) then return false end

    ClearCursor()
    PickupInventoryItem(fromSlot)
    if CursorHasItem and not CursorHasItem() then return false end
    local ok = pcall(EquipCursorItem, toSlot)

    -- Verdraengtes Teil zuerst in den freigewordenen Quell-Slot.
    if CursorHasItem and CursorHasItem() then
        pcall(EquipCursorItem, fromSlot)
    end
    -- Passt es dort nicht (z. B. Zweihaender in die Schildhand), in die
    -- Taschen damit.
    if CursorHasItem and CursorHasItem() then
        if PutItemInBackpack then pcall(PutItemInBackpack) end
        if CursorHasItem() and PutItemInBag and ContainerIDToInventoryID then
            for bag = 1, (NUM_BAG_SLOTS or 4) do
                if not CursorHasItem() then break end
                pcall(PutItemInBag, ContainerIDToInventoryID(bag))
            end
        end
    end
    -- Immer noch belegt: Abbruch der Aktion, das Teil kehrt an seinen
    -- Ursprung zurueck.
    if CursorHasItem and CursorHasItem() then
        ClearCursor()
    end
    return ok
end

-- Erster freier Platz in einer normalen Tasche. Spezialtaschen (Koecher,
-- Seelensplitter, Kraeuter) melden eine eigene Familie und nehmen kein
-- Schmuckstueck - die ueberspringen wir, sonst zeigten wir auf einen Platz,
-- in den der Client nichts ablegt.
local function findFreeBagSlot()
    if not GetContainerNumSlots or not GetContainerItemID then return nil end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local family = 0
        if GetContainerNumFreeSlots then
            local ok, _free, fam = pcall(GetContainerNumFreeSlots, bag)
            if ok then family = fam or 0 end
        end
        if family == 0 then
            for slot = 1, (GetContainerNumSlots(bag) or 0) do
                if not GetContainerItemID(bag, slot) then return bag, slot end
            end
        end
    end
    return nil
end

-- Cursor leerraeumen. Rueckgabe: true = das Teil liegt in einer Tasche.
--
-- Wir suchen den freien Platz selbst und legen gezielt dort ab, statt uns
-- auf PutItemInBackpack zu verlassen. Das trifft naemlich nur den Rucksack
-- - ist der voll, sagt es nichts, und das Teil fiel ueber ClearCursor
-- zurueck in den Slot. Genau so blieb die Reitgerte angelegt.
-- PutItemInBackpack/PutItemInBag bleiben als Rueckfallebene stehen.
local function stowCursorItem()
    if CursorHasItem and not CursorHasItem() then return true end

    local bag, bagSlot = findFreeBagSlot()
    if bag and _PickupContainerItem then
        pcall(_PickupContainerItem, bag, bagSlot)
    end
    if CursorHasItem and CursorHasItem() and PutItemInBackpack then
        pcall(PutItemInBackpack)
    end
    if CursorHasItem and CursorHasItem() and PutItemInBag and ContainerIDToInventoryID then
        for b = 1, (NUM_BAG_SLOTS or 4) do
            if not CursorHasItem() then break end
            pcall(PutItemInBag, ContainerIDToInventoryID(b))
        end
    end

    -- Alles voll: das Teil wandert dorthin zurueck, wo es herkam. Das
    -- melden wir als Misserfolg, damit es spaeter noch einmal versucht wird.
    if CursorHasItem and CursorHasItem() then
        ClearCursor()
        return false
    end
    return true
end

-- Slot suchen, der das gewuenschte Teil gerade traegt - aber keinen
-- anpacken, der laut Set schon richtig bestueckt ist (zwei Exemplare
-- derselben ID: das korrekt sitzende bleibt, wo es ist).
-- Mit byVariant=true zaehlt nur das exakte Exemplar (gleiche Sockel und
-- Verzauberung), sonst wie bisher die Item-ID.
local function findWornElsewhere(wantLink, targetSlot, loadout, byVariant)
    local wantID  = getItemIDFromLink(wantLink)
    local wantKey = byVariant and variantKey(wantLink) or nil
    for _, s in ipairs(EQUIP_SLOTS) do
        if s ~= targetSlot then
            local wornLink = GetInventoryItemLink("player", s)
            local hit
            if byVariant then
                hit = wornLink and wantKey and variantKey(wornLink) == wantKey
            else
                hit = getItemIDFromLink(wornLink) == wantID
            end
            if hit then
                local wantedLink = loadout.slots and loadout.slots[s]
                local sitsRight
                if byVariant then
                    sitsRight = wantedLink
                        and variantKey(wantedLink) == variantKey(wornLink)
                else
                    sitsRight = wantedLink
                        and getItemIDFromLink(wantedLink) == getItemIDFromLink(wornLink)
                end
                if not sitsRight then return s end
            end
        end
    end
    return nil
end

local function countSlots(loadout)
    local n = 0
    if loadout and loadout.slots then
        for _ in pairs(loadout.slots) do n = n + 1 end
    end
    return n
end
-- Fuer die spaeter geladenen Dateien (siehe Shared.lua).
GS.EQUIP_SLOTS              = EQUIP_SLOTS
GS.GetContainerItemID       = GetContainerItemID
GS.GetContainerItemLink     = GetContainerItemLink
GS.GetContainerNumFreeSlots = GetContainerNumFreeSlots
GS.GetContainerNumSlots     = GetContainerNumSlots
GS.GetItemCount             = GetItemCount
GS.GetItemInfoInstant       = GetItemInfoInstant
GS.LO                       = LO
GS.SLOT_GROUPS              = SLOT_GROUPS
GS.SLOT_NAMES               = SLOT_NAMES
GS.UseContainerItem         = UseContainerItem
GS._PickupContainerItem     = _PickupContainerItem
GS.bankIsOpen               = bankIsOpen
GS.captureCurrentEquipment  = captureCurrentEquipment
GS.charDB                   = charDB
GS.containerIDs             = containerIDs
GS.countSlots               = countSlots
GS.findItemInBags           = findItemInBags
GS.findVariantInBags        = findVariantInBags
GS.findWornElsewhere        = findWornElsewhere
GS.formMap                  = formMap
GS.getItemIDFromLink        = getItemIDFromLink
GS.isBankContainer          = isBankContainer
GS.specMap                  = specMap
GS.spellName                = spellName
GS.stowCursorItem           = stowCursorItem
GS.swapWornItem             = swapWornItem
GS.variantKey               = variantKey
