-- =========================================================
-- VuloGearSets / Modules / GearSets / Sets
-- Wechsel-Logik: Zustand eines Sets, Reihenfolge, Speichern, Anlegen,
-- zurueck zur vorherigen Ausruestung, Einlagern in die Bank, Popups und
-- Slash-Befehle.
-- =========================================================
local _, ns = ...
local L   = ns.L
local GS  = ns.GS
local mod = GS.mod

-- Aus frueher geladenen Dateien (siehe Shared.lua).
local EQUIP_SLOTS              = GS.EQUIP_SLOTS
local GetContainerItemID       = GS.GetContainerItemID
local GetContainerItemLink     = GS.GetContainerItemLink
local GetContainerNumFreeSlots = GS.GetContainerNumFreeSlots
local GetContainerNumSlots     = GS.GetContainerNumSlots
local GetItemCount             = GS.GetItemCount
local LO                       = GS.LO
local UseContainerItem         = GS.UseContainerItem
local _PickupContainerItem     = GS._PickupContainerItem
local bankIsOpen               = GS.bankIsOpen
local captureCurrentEquipment  = GS.captureCurrentEquipment
local charDB                   = GS.charDB
local containerIDs             = GS.containerIDs
local countSlots               = GS.countSlots
local findVariantInBags        = GS.findVariantInBags
local findWornElsewhere        = GS.findWornElsewhere
local formMap                  = GS.formMap
local getItemIDFromLink        = GS.getItemIDFromLink
local isBankContainer          = GS.isBankContainer
local specMap                  = GS.specMap
local stowCursorItem           = GS.stowCursorItem
local swapWornItem             = GS.swapWornItem
local variantKey               = GS.variantKey


-- =========================================================
-- Zustand eines Sets
--
--   equipped   alles angelegt
--   ready      alles vorhanden, aber nicht angelegt (Taschen/Bank)
--   missing    mindestens ein Teil nirgends auffindbar
--
-- WICHTIG: "nicht auffindbar" heisst nicht "existiert nicht mehr". Der
-- Client kennt nur Taschen, angelegte Ausruestung und - sofern schon
-- einmal geoeffnet - die Bank. Ein Teil bei einem anderen Charakter oder
-- in der Post ist von hier aus nicht von einem verkauften zu unterscheiden.
--
-- Verglichen wird das Exemplar (variantKey: ID plus Sockel, Verzauberung,
-- Suffix), mit Rueckfall auf die Item-ID, wenn das exakte Exemplar nirgends
-- greifbar ist - dann ist der gespeicherte Link veraltet.
-- =========================================================
-- Ausruestung und Taschen einmal indizieren statt jedes Teil einzeln
-- abzufragen. Bei mehreren Sets mit je bis zu 17 Teilen macht das den
-- Unterschied. Der Index gilt nur fuer diesen Frame - Taschen und
-- Ausruestung koennen sich unmittelbar danach aendern.
-- Der Index zaehlt EXEMPLARE, nicht nur IDs: zwei gleiche Ringe oder
-- Schmuckstuecke im Set verbrauchen zwei Kopien aus dem Bestand. Vorher
-- galt das zweite Exemplar als "angelegt", sobald das erste getragen
-- wurde - auch wenn es in der Tasche lag oder ganz fehlte.
local availIndex
local function buildAvailIndex()
    -- wornKeys/bagKeys zaehlen EXEMPLARE (variantKey) getrennt nach
    -- Ausruestung und Taschen. Damit erkennt der Status, ob ein bestimmtes
    -- Exemplar - nicht nur irgendeines mit der ID - greifbar ist, und wo.
    local idx = { wornBySlot = {}, wornKeyBySlot = {}, worn = {}, bags = {},
                  wornKeys = {}, bagKeys = {} }
    for _, s in ipairs(EQUIP_SLOTS) do
        local link = GetInventoryItemLink("player", s)
        local id = getItemIDFromLink(link)
        if id then
            idx.wornBySlot[s] = id
            idx.worn[id] = (idx.worn[id] or 0) + 1
            local key = variantKey(link)
            if key then
                idx.wornKeyBySlot[s] = key
                idx.wornKeys[key] = (idx.wornKeys[key] or 0) + 1
            end
        end
    end
    if GetContainerItemID and GetContainerNumSlots then
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            for slot = 1, (GetContainerNumSlots(bag) or 0) do
                local id = GetContainerItemID(bag, slot)
                if id then
                    idx.bags[id] = (idx.bags[id] or 0) + 1
                    local key = GetContainerItemLink
                        and variantKey(GetContainerItemLink(bag, slot))
                    if key then idx.bagKeys[key] = (idx.bagKeys[key] or 0) + 1 end
                end
            end
        end
    end
    return idx
end

local function getAvailIndex()
    if not availIndex then
        availIndex = buildAvailIndex()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() availIndex = nil end)
        end
    end
    return availIndex
end

local function getSetStatus(name)
    local set = LO()[name]
    if not set or not set.slots then return nil end

    local idx = getAvailIndex()
    local worn, inBags, inBank, missing = {}, {}, {}, {}
    local total = 0

    -- Verbleibende Exemplare je ID und je Exemplar-Schluessel, nur fuer
    -- dieses Set. Jeder Verbrauch ist lokal fuer diesen Aufruf - der Index
    -- bleibt unberuehrt, damit das naechste Set mit vollem Bestand rechnet.
    local wornLeft, bagLeft, bankLeft = {}, {}, {}
    local wornKeyLeft, bagKeyLeft = {}, {}
    local entries = {}

    for slot, link in pairs(set.slots) do
        total = total + 1
        local id = getItemIDFromLink(link)
        local itemName = (link:match("|h%[(.-)%]|h")) or link
        local entry = { slot = slot, name = itemName, link = link, id = id,
                        key = variantKey(link) }
        entries[#entries + 1] = entry
        if id and wornLeft[id] == nil then
            wornLeft[id] = idx.worn[id] or 0
            bagLeft[id]  = idx.bags[id] or 0
        end
        if entry.key and wornKeyLeft[entry.key] == nil then
            wornKeyLeft[entry.key] = idx.wornKeys[entry.key] or 0
            bagKeyLeft[entry.key]  = idx.bagKeys[entry.key] or 0
        end
    end

    -- Durchgang 1: im vorgesehenen Slot getragen. Zuerst, damit ein im
    -- richtigen Slot sitzendes Teil sein Exemplar sicher bekommt und nicht
    -- ein anderes Set-Teil mit gleicher ID es ihm wegnimmt.
    -- "Getragen" heisst: das exakte Exemplar (variantKey). Erst nachdem alle
    -- echten Exemplar-Treffer ihre Kopie verbraucht haben, kommt der
    -- Rueckfall: sitzt im Slot nur ein Geschwister-Teil mit gleicher ID,
    -- zaehlt das dann, wenn das gewuenschte Exemplar nirgends greifbar ist -
    -- der gespeicherte Link ist veraltet (umgesockelt/umverzaubert) und die
    -- ID entscheidet wie frueher. Dieselbe Logik wie beim Anlegen, damit
    -- Punkt und Knopf dasselbe sagen.
    local exact = 0
    for _, e in ipairs(entries) do
        if e.id and idx.wornBySlot[e.slot] == e.id and wornLeft[e.id] > 0
           and (not e.key or idx.wornKeyBySlot[e.slot] == e.key) then
            wornLeft[e.id] = wornLeft[e.id] - 1
            if e.key and wornKeyLeft[e.key] > 0 then
                wornKeyLeft[e.key] = wornKeyLeft[e.key] - 1
            end
            e.where = "worn"
            exact = exact + 1
        end
    end
    for _, e in ipairs(entries) do
        if not e.where and e.key and idx.wornBySlot[e.slot] == e.id
           and wornLeft[e.id] > 0 then
            local reachable = wornKeyLeft[e.key] > 0 or bagKeyLeft[e.key] > 0
            if not reachable and GetItemCount then
                -- An der Bank koennte das richtige Exemplar liegen; von
                -- hier aus ist nur die Stueckzahl je ID sichtbar.
                reachable = ((GetItemCount(e.id, true) or 0)
                           - (GetItemCount(e.id) or 0)) > 0
            end
            if not reachable then
                wornLeft[e.id] = wornLeft[e.id] - 1
                e.where = "worn"
                exact = exact + 1
            end
        end
    end

    -- Durchgang 2: Rest zuerst als exaktes Exemplar aus Taschen oder
    -- anderswo angelegt (z. B. vertauschte Ringe), dann ueber die ID,
    -- zuletzt Bank.
    for _, e in ipairs(entries) do
        local id = e.id
        if not e.where and id then
            local siblingInSlot = e.key and idx.wornBySlot[e.slot] == id
                and idx.wornKeyBySlot[e.slot] ~= e.key
            if e.key and bagKeyLeft[e.key] > 0 then
                bagKeyLeft[e.key] = bagKeyLeft[e.key] - 1
                if bagLeft[id] > 0 then bagLeft[id] = bagLeft[id] - 1 end
                e.where = "bags"
            elseif e.key and wornKeyLeft[e.key] > 0 then
                wornKeyLeft[e.key] = wornKeyLeft[e.key] - 1
                if wornLeft[id] > 0 then wornLeft[id] = wornLeft[id] - 1 end
                e.where = "worn"
            elseif not siblingInSlot and bagLeft[id] > 0 then
                bagLeft[id] = bagLeft[id] - 1
                e.where = "bags"
            elseif not siblingInSlot and wornLeft[id] > 0 then
                wornLeft[id] = wornLeft[id] - 1
                e.where = "worn"
            elseif GetItemCount then
                -- Sitzt im Ziel-Slot ein Geschwister-Exemplar (siblingInSlot),
                -- wuerde der ID-Rueckfall oben genau dieses faelschlich
                -- zaehlen - dann bleibt nur die Bank. Auch das Anlegen
                -- verweist in dem Fall auf die Bank.
                if bankLeft[id] == nil then
                    -- Die Bank kennt der Client nur, wenn sie schon einmal
                    -- offen war. Sie ist die Differenz der beiden Zaehlungen;
                    -- ob GetItemCount Angelegtes mitzaehlt, kuerzt sich
                    -- dabei heraus.
                    bankLeft[id] = (GetItemCount(id, true) or 0)
                                 - (GetItemCount(id) or 0)
                end
                if bankLeft[id] > 0 then
                    bankLeft[id] = bankLeft[id] - 1
                    e.where = "bank"
                end
            end
        end
    end

    for _, e in ipairs(entries) do
        if e.where == "worn" then
            worn[#worn + 1] = e
        elseif e.where == "bags" then
            inBags[#inBags + 1] = e
        elseif e.where == "bank" then
            inBank[#inBank + 1] = e
        else
            missing[#missing + 1] = e
        end
    end

    -- Slots, die laut Maske leer gehoeren, muessen auch leer sein - das
    -- Anlegen wuerde sie freiraeumen, also darf der Punkt vorher nicht
    -- gruen sein. Alt-Daten ohne echte Maske kennen keine Leer-Slots.
    local extraWorn = 0
    if set.slotMask then
        for _, slot in ipairs(set.slotMask) do
            if not set.slots[slot] and idx.wornBySlot[slot] then
                extraWorn = extraWorn + 1
            end
        end
    end

    -- Ein Set ganz ohne Teile ist gueltig, solange es eine Maske hat: es
    -- bedeutet "diese Slots frei". Ohne beides gibt es nichts zu melden.
    if total == 0 and #(set.slotMask or {}) == 0 then return nil end
    -- "Angelegt" heisst: jedes Teil sitzt in SEINEM Slot und die
    -- Leer-Slots sind frei. Vertauschte Ringe oder Schmuckstuecke zaehlen
    -- als "bereit" - das Anlegen kann sie inzwischen umsortieren
    -- (swapWornItem), und der Punkt soll dasselbe sagen wie der Knopf.
    local state = "ready"
    if #missing > 0 then
        state = "missing"
    elseif exact == total and extraWorn == 0 then
        state = "equipped"
    end
    return {
        state = state, total = total, extraWorn = extraWorn,
        worn = worn, inBags = inBags, inBank = inBank, missing = missing,
    }
end

-- Reihenfolge der Sets: solange der Spieler nichts verschoben hat, sind alle
-- Eintraege ohne `order` und die Liste ist alphabetisch. Sobald er einmal
-- verschiebt, tragen alle Sets eine Nummer (siehe moveLoadout). Neue Sets
-- ohne Nummer haengen sich hinten an - alphabetisch untereinander.
local function sortedLoadoutNames()
    local names = {}
    if mod.db and LO() then
        local sets = LO()
        for name in pairs(sets) do
            table.insert(names, name)
        end
        table.sort(names, function(a, b)
            local oa = tonumber(sets[a].order) or math.huge
            local ob = tonumber(sets[b].order) or math.huge
            if oa ~= ob then return oa < ob end
            return a < b
        end)
    end
    return names
end
ns.SortedSetNames = sortedLoadoutNames
-- Das Spiegeln in Blizzards Ausruestungsmanager (BlizzardSets.lua) zieht
-- nur nach, wenn ein Set vollstaendig getragen wird.
ns.GetSetStatus = getSetStatus

-- Set an Position `newPos` der Liste stellen (1 = ganz oben). Danach tragen
-- ALLE Sets ihre Position als `order`, damit die bisher alphabetische
-- Reihenfolge der anderen erhalten bleibt und nicht ploetzlich ein einzelnes
-- nummeriertes Set vor allen anderen steht.
local function moveLoadoutTo(name, newPos)
    local sets = LO()
    if not sets[name] then return false end
    local names = sortedLoadoutNames()
    local idx
    for i, n in ipairs(names) do
        if n == name then idx = i; break end
    end
    if not idx then return false end
    if newPos < 1 then newPos = 1 elseif newPos > #names then newPos = #names end
    if newPos == idx then return false end
    table.remove(names, idx)
    table.insert(names, newPos, name)
    for i, n in ipairs(names) do
        sets[n].order = i
    end
    return true
end

-- Set um `delta` Plaetze verschieben (-1 = nach oben, +1 = nach unten).
local function moveLoadout(name, delta)
    local names = sortedLoadoutNames()
    for i, n in ipairs(names) do
        if n == name then return moveLoadoutTo(name, i + delta) end
    end
    return false
end

-- =========================================================
-- Core operations
-- =========================================================
-- Copy a slot-id list (used as the intended mask)
local function copySlotList(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    return out
end

local function saveAs(name, slotList)
    -- Leerzeichen am Rand abschneiden wie beim Umbenennen: "Tank " und
    -- "Tank" waeren sonst zwei Sets, die gleich aussehen.
    name = name and name:match("^%s*(.-)%s*$")
    if not name or name == "" then
        ns:Print(L["Please provide a name for the gear set."])
        return
    end
    -- Vorhandenen Eintrag AKTUALISIEREN statt ersetzen. Sonst gehen alle
    -- Felder verloren, die nicht hier stehen - allen voran das selbst
    -- gewaehlte Symbol (iconOverride).
    local set = LO()[name]
    if not set then
        set = { createdAt = time() }
        LO()[name] = set
    end
    set.slots    = captureCurrentEquipment(slotList)
    set.slotMask = copySlotList(slotList or EQUIP_SLOTS)

    ns:Print(string.format(L["Gear set '%s' saved (%d items)."],
        name, countSlots(set)))
    if ns.MirrorSetSaved then ns:MirrorSetSaved(name) end
end

-- Pending slot list for the StaticPopup (popups have no parameter passing on Show)
local _pendingSaveSlots = nil

local function promptSaveWithSlots(slotList)
    _pendingSaveSlots = slotList
    StaticPopup_Show("VGS_GEARSET_SAVE")
end

-- Overwrite an existing loadout with current gear, preserving the original
-- slot mask. THIS IS THE KEY HELPER — previously every "save current as ..."
-- button iterated over loadout.slots which only has slots that had an item
-- at the time of the original save, so missing items (e.g. Head/Neck/Shoulder
-- not equipped at save time) would never be re-captured.
local function overwriteLoadout(name)
    local loadout = LO()[name]
    if not loadout then return end
    -- Prefer slotMask (intended slots, set at save time). Fall back to existing
    -- slots keys for legacy data without a mask.
    local slotList = loadout.slotMask
    if not slotList or #slotList == 0 then
        slotList = {}
        for s in pairs(loadout.slots or {}) do table.insert(slotList, s) end
    end
    if #slotList == 0 then slotList = EQUIP_SLOTS end  -- ultimate fallback: all slots
    -- Nur Ausruestung und Maske erneuern. Symbol, Erstellungsdatum und
    -- alles weitere bleiben am Eintrag haengen.
    loadout.slots    = captureCurrentEquipment(slotList)
    loadout.slotMask = copySlotList(slotList)
    ns:Print(string.format(L["Gear set '%s' updated with current gear."], name))
    if ns.MirrorSetSaved then ns:MirrorSetSaved(name) end
end

local function deleteLoadout(name)
    if not LO()[name] then
        ns:Print(string.format(L["Gear set '%s' does not exist."], name))
        return
    end
    LO()[name] = nil
    -- Still: der Spieler hat das Set geloescht, nicht die Taste.
    if ns.ClearSetKeybind then ns:ClearSetKeybind(name, true) end
    if ns.MirrorSetDeleted then ns:MirrorSetDeleted(name) end
    if ns.DeleteSetMacro then ns:DeleteSetMacro(name) end
    ns:Print(string.format(L["Gear set '%s' deleted."], name))
end

-- Umbenennen = Eintrag unter neuem Schluessel weiterfuehren. Spec-, Gestalt-
-- und Tastenbindung haengen ebenfalls am Namen und muessen mitziehen, sonst
-- zeigen sie nach dem Umbenennen ins Leere. Gibt bei Erfolg den endgueltigen
-- (getrimmten) Namen zurueck, damit der Aufrufer die Auswahl nachfuehren kann.
local function renameLoadout(oldName, newName)
    newName = newName and newName:match("^%s*(.-)%s*$") or ""
    if newName == "" then
        ns:Print(L["Please provide a name for the gear set."])
        return
    end
    local sets = LO()
    if not sets[oldName] then
        ns:Print(string.format(L["Gear set '%s' does not exist."], oldName))
        return
    end
    if newName == oldName then return end
    if sets[newName] then
        ns:Print(string.format(L["A gear set named '%s' already exists."], newName))
        return
    end
    sets[newName] = sets[oldName]
    sets[oldName] = nil
    if specMap()[oldName] then
        specMap()[newName] = specMap()[oldName]
        specMap()[oldName] = nil
    end
    if formMap()[oldName] then
        formMap()[newName] = formMap()[oldName]
        formMap()[oldName] = nil
    end
    if ns.RenameSetKeybind then ns:RenameSetKeybind(oldName, newName) end
    if ns.MirrorSetRenamed then ns:MirrorSetRenamed(oldName, newName) end
    if ns.RenameSetMacro then ns:RenameSetMacro(oldName, newName) end
    ns:Print(string.format(L["Gear set '%s' renamed to '%s'."], oldName, newName))
    return newName
end

-- =========================================================
-- Helm und Umhang sichtbar oder nicht - je Set
--
-- Am Set haengen `showHelm` und `showCloak` mit drei Zustaenden:
--   nil   = nicht anfassen (Standard, wie vor diesem Feature)
--   true  = beim Anlegen einblenden
--   false = beim Anlegen ausblenden
-- Angewendet wird beim Anlegen, auch wenn nichts zu wechseln war - der
-- Spieler will das Set so sehen, wie er es eingestellt hat.
-- =========================================================
local VISIBILITY_FIELDS = {
    { key = "showHelm",  show = ShowHelm,  label = L["Helmet"] },
    { key = "showCloak", show = ShowCloak, label = L["Cloak"]  },
}

local function applySetVisibility(loadout)
    if not loadout or InCombatLockdown() then return end
    for _, f in ipairs(VISIBILITY_FIELDS) do
        local want = loadout[f.key]
        if want ~= nil and f.show then f.show(want) end
    end
end

-- Menuetext fuer den aktuellen Zustand, z. B. "Helm: anzeigen".
local function visibilityText(loadout, f)
    local v = loadout and loadout[f.key]
    local state
    if v == true then state = L["shown"]
    elseif v == false then state = L["hidden"]
    else state = L["as is"] end
    return string.format("%s: %s", f.label, state)
end

-- Ein Klick schaltet weiter: nicht aendern -> anzeigen -> verbergen -> ...
local function cycleVisibility(loadout, f)
    local v = loadout[f.key]
    if v == nil then loadout[f.key] = true
    elseif v == true then loadout[f.key] = false
    else loadout[f.key] = nil end
end

-- Der zuletzt gemeldete Ausgang eines Anlegens, das nichts bewegt hat.
-- Siehe unten am Ende von equipLoadout.
local _lastEquipOutcome

-- Vorher-Stand fuer "Zurueck": alle Slots, die ein Anlegen beruehren kann.
-- Das sind die des Sets und jeweils ihr Partner-Slot - Ringe und Schmuck
-- werden ueber Kreuz getauscht, und eine Zweihandwaffe raeumt die
-- Schildhand, ohne dass das Set die Schildhand nennt.
local PARTNER_SLOT = { [11] = 12, [12] = 11, [13] = 14, [14] = 13, [16] = 17, [17] = 16 }

local function touchedSlots(loadout)
    local seen, list = {}, {}
    local function add(s)
        if s and not seen[s] then seen[s] = true; list[#list + 1] = s end
    end
    for _, s in ipairs(loadout.slotMask or {}) do add(s); add(PARTNER_SLOT[s]) end
    for s in pairs(loadout.slots or {}) do add(s); add(PARTNER_SLOT[s]) end
    table.sort(list)
    return list
end

-- `loadout` ist nur fuer "Zurueck" gesetzt: der Vorher-Stand ist kein
-- gespeichertes Set und hat keinen Eintrag in LO(). `name` ist dann nur
-- der Text fuer die Chatzeilen.
local function equipLoadout(name, loadout)
    if InCombatLockdown() then
        -- Dieselbe Sperre wie am Ende der Funktion: eine Taste ist im Kampf
        -- schnell mehrfach gedrueckt, und die Absage aendert sich dabei nicht.
        local outcome = tostring(name) .. "\1combat"
        if outcome ~= _lastEquipOutcome then
            _lastEquipOutcome = outcome
            ns:Print(L["Cannot change equipment in combat."])
        end
        return
    end
    loadout = loadout or LO()[name]
    if not loadout then
        ns:Print(string.format(L["Gear set '%s' does not exist."], name))
        return
    end
    if not _PickupContainerItem and not UseContainerItem then
        ns:Print(L["Equipment swap API not available on this client."])
        return
    end

    -- Was diese Slots jetzt tragen. Gespeichert wird es erst am Ende und
    -- nur, wenn sich wirklich etwas bewegt hat - sonst ueberschriebe ein
    -- zweiter Klick auf ein angelegtes Set den Stand von davor.
    local touched = touchedSlots(loadout)
    local before  = { slots = captureCurrentEquipment(touched), slotMask = touched }

    applySetVisibility(loadout)

    local swapped, missing, atBank = 0, 0, 0

    -- Einmal am Anfang festgehalten: waehrend des Anlegens soll sich der
    -- Suchraum nicht aendern.
    local useBank = bankIsOpen()

    -- Wie viele Exemplare an der Bank liegen, aber gerade nicht erreichbar
    -- sind. Die Bank kennt der Client nur als Differenz zweier Zaehlungen
    -- (siehe getSetStatus); jedes gemeldete Teil wird abgezogen, damit ein
    -- einzelnes Exemplar nicht fuer zwei Slots gemeldet wird.
    local bankLeft = {}
    local function bankStock(id)
        if bankLeft[id] == nil then
            bankLeft[id] = GetItemCount
                and ((GetItemCount(id, true) or 0) - (GetItemCount(id) or 0))
                or 0
        end
        return bankLeft[id]
    end

    -- Sorted ascending so paired slots resolve predictably (11 before 12,
    -- 13 before 14). We equip via ns:EquipBagItemToSlot which uses
    -- EquipCursorItem(slot) — that honours the exact destination slot, so
    -- ring2/trinket2 land in slot 12/14 instead of always the upper slot.
    local sortedSlots = {}
    for slot in pairs(loadout.slots) do table.insert(sortedSlots, slot) end
    table.sort(sortedSlots)

    for _, slot in ipairs(sortedSlots) do
        local link = loadout.slots[slot]
        -- Verglichen wird das EXEMPLAR (ID plus Sockel/Verzauberung/Suffix,
        -- siehe variantKey), nicht der rohe Link: dessen uebrige Felder
        -- aendern sich, ohne dass das Teil ein anderes wird. Zwei Teile mit
        -- gleicher ID, aber verschiedenen Steinen - die T5-Schultern einmal
        -- fuer Schaden, einmal fuer Widerstand gesockelt - werden so beim
        -- Wechseln tatsaechlich getauscht. Ist das exakte Exemplar nirgends
        -- greifbar (nachtraeglich umgesockelt: der gespeicherte Link ist
        -- veraltet), gilt wie bisher die Item-ID, damit nichts faelschlich
        -- als fehlend gemeldet wird.
        local itemID   = getItemIDFromLink(link)
        local wornLink = GetInventoryItemLink("player", slot)
        local wantKey  = variantKey(link)
        if itemID and wantKey ~= variantKey(wornLink) then
            local wornID = getItemIDFromLink(wornLink)
            local bag, bagSlot, fromBank, idBag, idSlot, idFromBank =
                findVariantInBags(link, useBank)
            -- Rueckfallebene "gleiche ID reicht" nur, wenn im Slot nicht
            -- schon ein Exemplar dieser ID sitzt - sonst wuerde das
            -- Schwester-Teil aus der Tasche sinnlos hin- und hergetauscht.
            if not bag and wornID ~= itemID then
                bag, bagSlot, fromBank = idBag, idSlot, idFromBank
            end
            if bag and bagSlot then
                local ok = ns:EquipBagItemToSlot(bag, bagSlot, slot)
                -- Fallback for non-paired slots if cursor method failed.
                -- Auf ein Bankfach angewandt legt UseContainerItem aber
                -- nichts an, es schiebt das Teil nur in die Taschen - und
                -- das haette hier als angelegt gezaehlt. Also nur fuer
                -- Taschen.
                if not ok and not fromBank and UseContainerItem then
                    ok = pcall(UseContainerItem, bag, bagSlot)
                end
                if ok then swapped = swapped + 1 else missing = missing + 1 end
            else
                -- Nicht in den Taschen: vielleicht schon angelegt, nur im
                -- falschen Slot (Ringe/Schmuck ueber Kreuz). Dann von dort
                -- herueberholen - das tauscht bei Paar-Slots beide in einem
                -- Zug, der zweite Slot stimmt danach von selbst. Zuerst das
                -- exakte Exemplar, sonst eines mit gleicher ID.
                local srcSlot = findWornElsewhere(link, slot, loadout, true)
                if not srcSlot and wornID ~= itemID then
                    srcSlot = findWornElsewhere(link, slot, loadout)
                end
                if srcSlot and swapWornItem(srcSlot, slot) then
                    swapped = swapped + 1
                elseif wornID == itemID then
                    -- Gleiche ID sitzt schon im Slot, das exakte Exemplar ist
                    -- aber nicht greifbar. Liegt es an der (geschlossenen)
                    -- Bank, sagen wir das; sonst ist der gespeicherte Link
                    -- veraltet und das getragene Teil zaehlt als angelegt.
                    if not useBank and bankStock(itemID) > 0 then
                        bankLeft[itemID] = bankLeft[itemID] - 1
                        atBank = atBank + 1
                    end
                elseif not useBank and bankStock(itemID) > 0 then
                    -- Nicht verloren, nur unerreichbar: es liegt an der
                    -- Bank und die ist zu.
                    bankLeft[itemID] = bankLeft[itemID] - 1
                    atBank = atBank + 1
                else
                    missing = missing + 1
                end
            end
        end
    end

    -- Slots, die beim Speichern LEER waren, werden beim Anlegen geleert:
    -- die Maske nennt alle damals gemeinten Slots, und wofuer dort kein
    -- Teil hinterlegt ist, gehoert frei. So laesst sich ein Set anlegen,
    -- das bewusst wenig (oder nichts) traegt. Alt-Daten ohne echte Maske
    -- bekommen sie von der Migration aus den BELEGTEN Slots abgeleitet -
    -- die kennen keine Leer-Slots und verhalten sich wie bisher.
    -- Nach dem Tauschen, nicht davor: eine Zweihandwaffe raeumt die
    -- Schildhand von selbst, das Teil liegt dann schon in der Tasche.
    local removed, bagsFull = 0, 0
    if loadout.slotMask and PickupInventoryItem then
        for _, slot in ipairs(loadout.slotMask) do
            if not loadout.slots[slot]
               and GetInventoryItemLink("player", slot) then
                ClearCursor()
                PickupInventoryItem(slot)
                if CursorHasItem and not CursorHasItem() then
                    -- nichts aufgenommen - dann gibt es nichts abzulegen
                elseif stowCursorItem() then
                    removed = removed + 1
                else
                    bagsFull = bagsFull + 1
                end
            end
        end
    end

    -- Auch "Zurueck" selbst landet hier: der Stand vor dem Zuruecklegen
    -- wird der neue Vorher-Stand, ein zweites "Zurueck" wechselt also
    -- wieder hin.
    if swapped + removed > 0 then
        charDB().previousGear = before
    end

    -- Hat der Aufruf nichts bewegt, wird dieselbe Meldung nicht wiederholt:
    -- wer ein angelegtes Set noch einmal anklickt oder seine Taste zweimal
    -- drueckt, hat beim ersten Mal gelesen, warum nichts passiert. Gemerkt
    -- wird der ganze Ausgang, nicht nur der Name - aendert sich etwas an der
    -- Lage (ein fehlendes Teil taucht auf), kommt die Meldung wieder.
    --
    -- Sobald wirklich getauscht oder abgelegt wurde, faellt der Merker weg:
    -- dann ist die naechste "ist schon angelegt"-Meldung eine neue Auskunft.
    local outcome = (swapped + removed == 0)
        and string.format("%s\1%d\1%d\1%d", name, missing, atBank, bagsFull)
        or nil
    local repeated = (outcome ~= nil and outcome == _lastEquipOutcome)
    _lastEquipOutcome = outcome
    if repeated then return end

    if swapped > 0 then
        if missing > 0 then
            ns:Print(string.format(L["Gear set '%s' equipped (%d swapped, %d missing from bags)."],
                name, swapped, missing))
        else
            ns:Print(string.format(L["Gear set '%s' equipped (%d items swapped)."], name, swapped))
        end
    elseif missing > 0 then
        ns:Print(string.format(L["Gear set '%s': %d items missing from bags, nothing swapped."],
            name, missing))
    elseif atBank == 0 and removed == 0 and bagsFull == 0 then
        ns:Print(string.format(L["Gear set '%s' already equipped."], name))
    end

    -- Eigene Zeilen fuer das Ablegen: das ist die Haelfte der Wahrheit, die
    -- in "gewechselt" nicht steckt.
    if removed > 0 then
        ns:Print(string.format(L["%d items taken off."], removed))
    end
    if bagsFull > 0 then
        ns:Print(string.format(
            L["%d items stayed on — no free bag space to take them off."], bagsFull))
    end

    -- Eigene Zeile statt "fehlt": das Teil ist nicht weg, es ist nur gerade
    -- nicht erreichbar. Mit offenem Bankfenster kaeme es von selbst mit.
    if atBank > 0 then
        ns:Print(string.format(
            L["%d items are in the bank — open the bank window to equip them."], atBank))
    end
end

-- Fuer das Tasten-Modul: es haengt an einem Setnamen und braucht genau
-- diesen einen Weg hinein. equipLoadout bleibt lokal.
function ns:EquipGearSet(name)
    equipLoadout(name)
end

-- =========================================================
-- Zurueck zur vorherigen Ausruestung
--
-- Jedes Anlegen, das etwas bewegt, merkt sich vorher, was in den
-- betroffenen Slots sass (siehe equipLoadout). Dieser Stand wird wie ein
-- Set angelegt - Slots, die vorher leer waren, werden also wieder
-- geleert. Er liegt in der Charakter-Datenbank und uebersteht /reload.
-- =========================================================
local function equipPrevious()
    local prev = charDB().previousGear
    if not (type(prev) == "table" and type(prev.slotMask) == "table"
            and #prev.slotMask > 0) then
        ns:Print(L["Nothing to go back to yet — equip a set first."])
        return
    end
    prev.slots = prev.slots or {}
    equipLoadout(L["Previous gear"], prev)
end

function ns:EquipPreviousGear()
    equipPrevious()
end

local function hasPreviousGear()
    local prev = charDB().previousGear
    return type(prev) == "table" and type(prev.slotMask) == "table"
        and #prev.slotMask > 0
end

-- Blizzards Tastenbelegung (Bindings.xml) ruft ein Global auf.
_G.BINDING_HEADER_VULOGEARSETS   = "VuloGearSets"
_G.BINDING_NAME_VGS_PREVIOUS_GEAR = L["Back to previous gear"]
function VuloGearSets_EquipPrevious()
    equipPrevious()
end

-- =========================================================
-- Ein Set in die Bank legen
--
-- Nur was in den Taschen liegt; Angelegtes bleibt, wo es ist. Bewegt wird
-- per Aufnehmen und Ablegen auf ein freies Bankfach - so wie der Spieler
-- es von Hand zieht. UseContainerItem taete es bei offener Bank auch, ist
-- auf Forever aber nicht mehr frei aufrufbar.
-- =========================================================
local function freeBankSlots()
    local list = {}
    for _, bag in ipairs(containerIDs(true)) do
        if isBankContainer(bag) then
            -- Spezialbeutel in der Bank (Koecher, Kraeuter) nehmen keine
            -- Ausruestung.
            local family = 0
            if GetContainerNumFreeSlots then
                local ok, _free, fam = pcall(GetContainerNumFreeSlots, bag)
                if ok then family = fam or 0 end
            end
            if family == 0 then
                for slot = 1, (GetContainerNumSlots(bag) or 0) do
                    if not GetContainerItemID(bag, slot) then
                        list[#list + 1] = { bag, slot }
                    end
                end
            end
        end
    end
    return list
end

local function depositLoadout(name)
    local loadout = LO()[name]
    if not loadout then
        ns:Print(string.format(L["Gear set '%s' does not exist."], name))
        return
    end
    if not bankIsOpen() then
        ns:Print(L["Open the bank window first."])
        return
    end
    if not (_PickupContainerItem and GetContainerItemID and GetContainerNumSlots) then
        ns:Print(L["Equipment swap API not available on this client."])
        return
    end

    -- Getragene Exemplare zaehlen: steckt das Teil des Sets schon an der
    -- Figur, liegt ein gleiches in der Tasche nicht fuer dieses Set dort.
    local wornLeft = {}
    for _, s in ipairs(EQUIP_SLOTS) do
        local key = variantKey(GetInventoryItemLink("player", s))
        if key then wornLeft[key] = (wornLeft[key] or 0) + 1 end
    end
    -- Exemplare, die exakt zu einem ANDEREN Set gehoeren. Die nimmt die
    -- Rueckfallebene "gleiche ID reicht" nicht mit - sonst wanderten die
    -- anders gesockelten Schultern des Nachbarsets in die Bank.
    local otherKeys = {}
    for other, lo in pairs(LO()) do
        if other ~= name then
            for _, l in pairs(lo.slots or {}) do
                local key = variantKey(l)
                if key then otherKeys[key] = true end
            end
        end
    end

    local taken = {}
    local function findBagCopy(link, exact)
        local wantID, wantKey = getItemIDFromLink(link), variantKey(link)
        for _, bag in ipairs(containerIDs(false)) do
            for slot = 1, (GetContainerNumSlots(bag) or 0) do
                if not taken[bag .. ":" .. slot]
                   and GetContainerItemID(bag, slot) == wantID then
                    local key = GetContainerItemLink
                        and variantKey(GetContainerItemLink(bag, slot))
                    if (exact and key == wantKey)
                       or (not exact and not otherKeys[key]) then
                        return bag, slot
                    end
                end
            end
        end
    end

    local free = freeBankSlots()
    local moved, noRoom, nextFree = 0, 0, 1
    local sortedSlots = {}
    for slot in pairs(loadout.slots or {}) do sortedSlots[#sortedSlots + 1] = slot end
    table.sort(sortedSlots)

    for _, slot in ipairs(sortedSlots) do
        local link = loadout.slots[slot]
        local key  = variantKey(link)
        if key and (wornLeft[key] or 0) > 0 then
            wornLeft[key] = wornLeft[key] - 1
        else
            local bag, bagSlot = findBagCopy(link, true)
            if not bag then bag, bagSlot = findBagCopy(link, false) end
            if bag then
                taken[bag .. ":" .. bagSlot] = true
                local target = free[nextFree]
                if not target then
                    noRoom = noRoom + 1
                else
                    -- Ein gesperrtes Teil (noch unterwegs) laesst sich
                    -- nicht aufnehmen - das zaehlt dann gar nicht.
                    ClearCursor()
                    _PickupContainerItem(bag, bagSlot)
                    if CursorHasItem and CursorHasItem() then
                        _PickupContainerItem(target[1], target[2])
                        nextFree = nextFree + 1
                        if CursorHasItem() then
                            ClearCursor()
                        else
                            moved = moved + 1
                        end
                    end
                end
            end
        end
    end

    if moved == 0 and noRoom == 0 then
        ns:Print(string.format(L["Gear set '%s': nothing in your bags to put in the bank."], name))
        return
    end
    if moved > 0 then
        ns:Print(string.format(L["Gear set '%s': %d items put in the bank."], name, moved))
    end
    if noRoom > 0 then
        ns:Print(string.format(L["%d items stayed in your bags — the bank is full."], noRoom))
    end
end

local function listLoadouts()
    local names = sortedLoadoutNames()
    if #names == 0 then
        ns:Print(L["No gear sets saved yet."])
        return
    end
    ns:Print(L["Saved gear sets:"])
    for _, name in ipairs(names) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  |cffffd100%s|r (%d %s)",
            name, countSlots(LO()[name]), L["items"]))
    end
end

-- =========================================================
-- StaticPopups
-- =========================================================
StaticPopupDialogs["VGS_GEARSET_SAVE"] = {
    text = L["Save current equipment as a new gear set. Enter name:"],
    button1 = SAVE or L["Save"],
    button2 = CANCEL or L["Cancel"],
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(self)
        local eb = ns.PopupEditBox(self)
        if not eb then
            ns:Print(L["Could not read the name field on this client."])
            return
        end
        saveAs(eb:GetText(), _pendingSaveSlots)
        _pendingSaveSlots = nil
    end,
    EditBoxOnEnterPressed = function(self)
        saveAs(self:GetText(), _pendingSaveSlots)
        _pendingSaveSlots = nil
        -- Ueber den Namen schliessen: GetParent ist im neuen GameDialog
        -- nicht zwingend der Dialog selbst.
        StaticPopup_Hide("VGS_GEARSET_SAVE")
    end,
    OnCancel = function() _pendingSaveSlots = nil end,
    EditBoxOnEscapePressed = function(self)
        _pendingSaveSlots = nil
        StaticPopup_Hide("VGS_GEARSET_SAVE")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Alter Name fuer den Umbenennen-Dialog (Popups reichen beim Show nichts durch)
local _pendingRenameName = nil

StaticPopupDialogs["VGS_GEARSET_RENAME"] = {
    text = L["Rename gear set '%s'. Enter new name:"],
    button1 = L["Rename"],
    button2 = CANCEL or L["Cancel"],
    hasEditBox = true,
    maxLetters = 32,
    OnShow = function(self)
        -- Alten Namen vorbelegen und markieren - meist will man ihn nur anpassen.
        local eb = ns.PopupEditBox(self)
        if eb and _pendingRenameName then
            eb:SetText(_pendingRenameName)
            eb:HighlightText()
        end
    end,
    OnAccept = function(self)
        local eb = ns.PopupEditBox(self)
        if not eb then
            ns:Print(L["Could not read the name field on this client."])
            return
        end
        renameLoadout(_pendingRenameName, eb:GetText())
        _pendingRenameName = nil
    end,
    EditBoxOnEnterPressed = function(self)
        renameLoadout(_pendingRenameName, self:GetText())
        _pendingRenameName = nil
        -- Ueber den Namen schliessen: GetParent ist im neuen GameDialog
        -- nicht zwingend der Dialog selbst.
        StaticPopup_Hide("VGS_GEARSET_RENAME")
    end,
    OnCancel = function() _pendingRenameName = nil end,
    EditBoxOnEscapePressed = function()
        _pendingRenameName = nil
        StaticPopup_Hide("VGS_GEARSET_RENAME")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function promptRename(name)
    _pendingRenameName = name
    StaticPopup_Show("VGS_GEARSET_RENAME", name)
end

StaticPopupDialogs["VGS_GEARSET_DELETE"] = {
    text = L["Delete gear set '%s'?"],
    button1 = YES or L["Yes"],
    button2 = NO  or L["No"],
    -- data kommt je nach Client als Argument oder haengt am Dialog.
    OnAccept = function(self, data)
        local name = data or (self and self.data)
        if name then deleteLoadout(name) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- =========================================================
-- Slash commands
-- =========================================================
_G.SLASH_VGSGEARSET1 = "/gearset"
_G.SLASH_VGSGEARSET2 = "/vgs"
_G.SlashCmdList["VGSGEARSET"] = function(msg)
    msg = msg or ""
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "save" then
        saveAs(arg)
    elseif cmd == "equip" or cmd == "" then
        if arg ~= "" then
            equipLoadout(arg)
        else
            ns:Print(L["Usage: /gearset equip <name> | save <name> | delete <name> | back | bank <name> | list | config | unlock"])
        end
    elseif cmd == "spec" then
        -- Debug: show dual-spec state
        local active = mod._getActiveSpecGroup and mod._getActiveSpecGroup() or "?"
        local numG   = mod._getNumSpecGroups and mod._getNumSpecGroups() or "?"
        DEFAULT_CHAT_FRAME:AddMessage("|cff9b6cff[Gear Sets spec debug]|r")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  active spec group = %s", tostring(active)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  spec groups       = %s", tostring(numG)))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  specSwitchEnabled      = %s", tostring(mod.db.specSwitchEnabled)))
        local anyMap = false
        for name, g in pairs(specMap() or {}) do
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  mapping: '%s' -> spec %d", name, g))
            anyMap = true
        end
        if not anyMap then
            DEFAULT_CHAT_FRAME:AddMessage("  |cffff8800No spec bindings set — bind a set to a spec in the settings.|r")
        end
        if mod._forceSpecCheck then mod._forceSpecCheck() end
    elseif cmd == "delete" or cmd == "del" or cmd == "remove" or cmd == "rm" then
        if arg == "" then
            ns:Print(L["Usage: /gearset delete <name>"])
        elseif mod.db.confirmDelete then
            local dlg = StaticPopup_Show("VGS_GEARSET_DELETE", arg)
            if dlg then dlg.data = arg end
        else
            deleteLoadout(arg)
        end
    elseif cmd == "back" or cmd == "undo" then
        equipPrevious()
    elseif cmd == "bank" or cmd == "deposit" then
        if arg == "" then
            ns:Print(L["Usage: /gearset bank <name>"])
        else
            depositLoadout(arg)
        end
    elseif cmd == "list" or cmd == "ls" then
        listLoadouts()
    elseif cmd == "config" or cmd == "options" then
        ns:ToggleOptions()
    elseif cmd == "status" then
        -- Diagnose: zeigt, was die Statuspunkte ermitteln.
        local names = sortedLoadoutNames()
        if #names == 0 then ns:Print(L["No gear sets saved yet."]) return end
        for _, n in ipairs(names) do
            local st = getSetStatus(n)
            if not st then
                ns:Print("%s: |cffff5555no status|r (empty set?)", n)
            else
                ns:Print("%s: %s  (%d items: %d worn, %d bags, %d bank, %d missing)",
                    n, st.state, st.total, #st.worn, #st.inBags, #st.inBank, #st.missing)
            end
        end
    elseif cmd == "unlock" then
        -- Ersetzt das UnlockMode-Modul, das es im Standalone nicht gibt.
        ns:SetMoversEditMode(not ns:IsMoverEditMode())
    elseif cmd == "debug" then
        if mod._debugSizes then mod._debugSizes() else ns:Print("Sidebar not created yet.") end
    elseif cmd == "tune" then
        -- Blizzards CharacterFrame ist groesser als sein sichtbarer Rahmen.
        -- Diese drei Werte richten die Leiste am sichtbaren Fenster aus.
        local which, valStr = arg:match("^(%S+)%s*(%-?%d*)$")
        local val = tonumber(valStr)
        if which == "top" and val then
            mod.db.sidebarTopOffset = val
            if mod._reanchorSidebar then mod._reanchorSidebar() end
            ns:Print(string.format("Sidebar top offset = %d", val))
        elseif which == "bottom" and val then
            mod.db.sidebarBottomOffset = val
            if mod._reanchorSidebar then mod._reanchorSidebar() end
            ns:Print(string.format("Sidebar bottom offset = %d", val))
        elseif (which == "left" or which == "x") and val then
            mod.db.sidebarXOffset = val
            if mod._reanchorSidebar then mod._reanchorSidebar() end
            ns:Print(string.format("Sidebar left offset = %d", val))
        elseif which == "stats" and val then
            -- Nur wirksam, solange rechts am Charakterfenster eine fremde
            -- Statistikspalte haengt.
            mod.db.sidebarStatsGap = val
            if mod._reanchorSidebar then mod._reanchorSidebar() end
            ns:Print(string.format("Sidebar stats-column gap = %d", val))
        elseif which == "show" then
            ns:Print(string.format("top=%d bottom=%d left=%d stats=%d",
                mod.db.sidebarTopOffset or 0, mod.db.sidebarBottomOffset or 0,
                mod.db.sidebarXOffset or 0, mod.db.sidebarStatsGap or 0))
        elseif which == "reset" then
            local d = mod.defaults or {}
            mod.db.sidebarTopOffset    = d.sidebarTopOffset    or -12
            mod.db.sidebarBottomOffset = d.sidebarBottomOffset or 76
            mod.db.sidebarXOffset      = d.sidebarXOffset      or -34
            mod.db.sidebarStatsGap     = d.sidebarStatsGap     or 12
            if mod._reanchorSidebar then mod._reanchorSidebar() end
            ns:Print("Sidebar offsets reset to defaults.")
        else
            ns:Print("Usage: /gearset tune top <n> | bottom <n> | left <n> | stats <n> | show | reset")
        end
    else
        -- Treat unknown first word as a loadout name to equip
        if LO()[msg] then
            equipLoadout(msg)
        else
            ns:Print(L["Usage: /gearset equip <name> | save <name> | delete <name> | back | bank <name> | list | config | unlock"])
        end
    end
end


-- Refresh sidebar after save/delete operations
--
-- Die Leiste wird erst nach dieser Datei geladen; was sie dabei tut, steht
-- in Sidebar.lua (GS.sidebarAfterSave usw.). Die Huellen muessen aber HIER
-- liegen: nur so sehen auch die Popups und Slash-Befehle dieser Datei die
-- umhuellte Fassung.
local _origSaveAs    = saveAs
local _origDelete    = deleteLoadout
-- Das Optionsfenster listet die Sets ebenfalls auf. Ohne das Neuzeichnen
-- blieb dort ein geloeschtes Set stehen, bis man das Fenster neu oeffnet -
-- mit Knoepfen, die dann ins Leere laufen.
saveAs = function(name, slotList)
    _origSaveAs(name, slotList)
    if GS.sidebarAfterSave then GS.sidebarAfterSave(name) end
    if ns.RefreshOptions then ns:RefreshOptions() end
end
deleteLoadout = function(name)
    _origDelete(name)
    if GS.sidebarAfterDelete then GS.sidebarAfterDelete(name) end
    if ns.RefreshOptions then ns:RefreshOptions() end
end
local _origRename = renameLoadout
renameLoadout = function(oldName, newName)
    local finalName = _origRename(oldName, newName)
    if not finalName then return end
    if GS.sidebarAfterRename then GS.sidebarAfterRename(oldName, finalName) end
    if ns.RefreshOptions then ns:RefreshOptions() end
    return finalName
end

-- Fuer die spaeter geladenen Dateien (siehe Shared.lua).
GS.VISIBILITY_FIELDS   = VISIBILITY_FIELDS
GS.cycleVisibility     = cycleVisibility
GS.deleteLoadout       = deleteLoadout
GS.depositLoadout      = depositLoadout
GS.equipLoadout        = equipLoadout
GS.equipPrevious       = equipPrevious
GS.getSetStatus        = getSetStatus
GS.hasPreviousGear     = hasPreviousGear
GS.moveLoadout         = moveLoadout
GS.moveLoadoutTo       = moveLoadoutTo
GS.overwriteLoadout    = overwriteLoadout
GS.promptRename        = promptRename
GS.promptSaveWithSlots = promptSaveWithSlots
GS.sortedLoadoutNames  = sortedLoadoutNames
GS.visibilityText      = visibilityText
