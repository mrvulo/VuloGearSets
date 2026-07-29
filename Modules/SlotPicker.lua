-- =========================================================
-- VuloGearSets / Modules / SlotPicker
-- Ueberfahren eines Ausruestungsslots zeigt die passenden Teile aus den
-- Taschen kompakt daneben; der eingestellte Klick oeffnet das grosse
-- Fenster mit allen. Klick auf ein Teil legt es an.
--
-- Equipping uses UseContainerItem (works out-of-combat in Anniversary,
-- same approach as the gear set module).
-- =========================================================
local _, ns = ...
local L = ns.L

-- Verstecktes Modul: die Einstellungen stehen auf der Seite des
-- Ausruestungsset-Moduls, nicht als eigener Eintrag. Das Modul laeuft
-- trotzdem - es hookt die Slots und stellt ns:ScanBagsForSlot bereit.
local mod = ns:RegisterModule("slotpicker", {
    name        = "Slot Picker",
    group       = "_hidden",
    defaults = {
        enabled  = true,
        -- Steuert nur den KLICK-Weg. Das Ueberfahren zeigt die kompakte
        -- Auswahl immer, unabhaengig davon.
        -- "right" | "shift-right" | "alt-right" | "ctrl-right"
        modifier = "right",
        cols     = 8,
    },
})

-- =========================================================
-- API compat
-- =========================================================
local GetContainerItemID    = (C_Container and C_Container.GetContainerItemID)    or _G.GetContainerItemID
local GetContainerItemLink  = (C_Container and C_Container.GetContainerItemLink)  or _G.GetContainerItemLink
local GetContainerNumSlots  = (C_Container and C_Container.GetContainerNumSlots)  or _G.GetContainerNumSlots
local UseContainerItem      = (C_Container and C_Container.UseContainerItem)      or _G.UseContainerItem
local GetItemInfoInstant    = _G.GetItemInfoInstant

-- =========================================================
-- Slot → INVTYPE mapping
-- =========================================================
-- For each character slot ID, which INVTYPEs are valid?
local SLOT_INVTYPES = {
    [1]  = { INVTYPE_HEAD     = true },
    [2]  = { INVTYPE_NECK     = true },
    [3]  = { INVTYPE_SHOULDER = true },
    [5]  = { INVTYPE_CHEST    = true, INVTYPE_ROBE = true },
    [6]  = { INVTYPE_WAIST    = true },
    [7]  = { INVTYPE_LEGS     = true },
    [8]  = { INVTYPE_FEET     = true },
    [9]  = { INVTYPE_WRIST    = true },
    [10] = { INVTYPE_HAND     = true },
    [11] = { INVTYPE_FINGER   = true },
    [12] = { INVTYPE_FINGER   = true },
    [13] = { INVTYPE_TRINKET  = true },
    [14] = { INVTYPE_TRINKET  = true },
    [15] = { INVTYPE_CLOAK    = true },
    [16] = { INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true },
    [17] = { INVTYPE_WEAPONOFFHAND  = true, INVTYPE_WEAPON = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true },
    [18] = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true },
}

-- Map slot ID → character-frame name suffix (so we can hook the right button)
local SLOT_FRAME_NAMES = {
    [1]  = "Head",    [2]  = "Neck",     [3]  = "Shoulder", [15] = "Back",
    [5]  = "Chest",   [9]  = "Wrist",    [10] = "Hands",    [6]  = "Waist",
    [7]  = "Legs",    [8]  = "Feet",
    [11] = "Finger0", [12] = "Finger1",
    [13] = "Trinket0",[14] = "Trinket1",
    [16] = "MainHand", [17] = "SecondaryHand", [18] = "Ranged",
}

-- =========================================================
-- Modifier check
-- =========================================================
local function checkModifier(button)
    local mode = mod.db.modifier or "right"
    if mode == "right" then
        return button == "RightButton"
    elseif mode == "shift-right" then
        return button == "RightButton" and IsShiftKeyDown()
    elseif mode == "alt-right" then
        return button == "RightButton" and IsAltKeyDown()
    elseif mode == "ctrl-right" then
        return button == "RightButton" and IsControlKeyDown()
    end
    return false
end

-- =========================================================
-- Scan bags for items matching a slot
-- Exposed as ns:ScanBagsForSlot so other modules (Loadouts) can reuse it
-- =========================================================
local function scanBagsForSlot(slotID)
    local validTypes = SLOT_INVTYPES[slotID]
    if not validTypes or not GetContainerNumSlots or not GetItemInfoInstant then
        return {}
    end

    local results = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local numSlots = GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local itemID
            if GetContainerItemID then
                itemID = GetContainerItemID(bag, slot)
            elseif GetContainerItemLink then
                local link = GetContainerItemLink(bag, slot)
                if link then itemID = tonumber(link:match("item:(%d+)")) end
            end
            if itemID then
                local _, _, _, equipLoc, icon = GetItemInfoInstant(itemID)
                if equipLoc and validTypes[equipLoc] then
                    table.insert(results, {
                        bag    = bag,
                        slot   = slot,
                        itemID = itemID,
                        icon   = icon,
                    })
                end
            end
        end
    end
    return results
end

-- =========================================================
-- Popup with item grid
-- =========================================================
local popup
local itemButtons = {}
local BTN_SIZE = 36

local function createPopup()
    if popup then return popup end
    popup = CreateFrame("Frame", "VGS_SlotPickerPopup", UIParent,
        BackdropTemplateMixin and "BackdropTemplate")
    popup:SetFrameStrata("DIALOG")
    popup:SetSize(360, 80)
    popup:Hide()
    popup:EnableMouse(true)
    popup:SetClampedToScreen(true)
    popup:SetMovable(true)
    ns.UI:SkinFrame(popup, "window")
    tinsert(UISpecialFrames, "VGS_SlotPickerPopup")

    -- Draggable via title bar
    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.titleAnchor = function()
        local i = ns:FrameInset()
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", popup, "TOPLEFT", 8 + i, -6 - i)
    end
    popup.titleAnchor()
    title:SetTextColor(1, 0.82, 0)
    popup.title = title

    -- Close button (X)
    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    popup.closeAnchor = function()
        local i = ns:FrameInset()
        closeBtn:ClearAllPoints()
        closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -i, -i)
    end
    popup.closeAnchor()
    closeBtn:SetScript("OnClick", function() popup:Hide() end)
    popup.closeBtn = closeBtn   -- im kompakten Hover-Modus ausgeblendet

    -- Drag area = title bar (top 24px)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)

    return popup
end

local function getItemButton(idx)
    local btn = itemButtons[idx]
    if btn then return btn end
    btn = CreateFrame("Button", nil, popup, "ItemButtonTemplate")
    if not btn.icon then
        -- Fallback in case ItemButtonTemplate doesn't expose .icon
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints(btn)
    end
    btn:SetSize(BTN_SIZE, BTN_SIZE)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnEnter", function(self)
        if self.bag and self.slot then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(self.bag, self.slot)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self, button)
        if InCombatLockdown() then
            ns:Print(L["Cannot change equipment in combat."])
            return
        end
        if button == "LeftButton" and self.bag and self.slot then
            -- Use the slot-aware equip helper (honours the exact target slot,
            -- so picking for the lower ring/trinket slot works correctly).
            if self.equipSlot and ns.EquipBagItemToSlot then
                ns:EquipBagItemToSlot(self.bag, self.slot, self.equipSlot)
            elseif UseContainerItem then
                pcall(UseContainerItem, self.bag, self.slot)
            end
            popup:Hide()
        end
    end)
    itemButtons[idx] = btn
    return btn
end

-- anchorBtn gesetzt = kompakter Modus: direkt am Slot, ohne Titelleiste
-- und Schliessen-Knopf, Breite passt sich der Anzahl der Teile an.
local function showSlotPicker(slotID, anchorBtn)
    if not GetItemInfoInstant then
        ns:Print(L["Item scanning API not available on this client."])
        return
    end

    createPopup()

    local results = scanBagsForSlot(slotID)
    local compact = anchorBtn ~= nil
    -- Merken, wie das Fenster geoeffnet wurde: der Hover-Timer darf nur
    -- die kompakte Anzeige wieder schliessen, nie ein per Klick geoeffnetes.
    popup._vgsCompact = compact

    -- Im kompakten Modus nichts zeigen, wenn es nichts zu wechseln gibt -
    -- sonst poppt beim Ueberfahren staendig "keine Teile" auf.
    if compact and #results == 0 then
        popup:Hide()
        return
    end

    -- SLOT_FRAME_NAMES sind Framenamen-Endungen, keine Beschriftungen: dort
    -- stand vorher "SecondaryHand" oder "Finger0" im Titel, und uebersetzt
    -- war es auch nicht. Die lesbaren Namen kommen aus dem Set-Modul.
    local slotName = (ns.SLOT_NAMES and ns.SLOT_NAMES[slotID])
        or SLOT_FRAME_NAMES[slotID] or string.format("Slot %d", slotID)
    popup.title:SetText(string.format(L["Items for: %s"], slotName)
        .. string.format(" |cff888888(%d)|r", #results))
    popup.title:SetShown(not compact)
    if popup.closeBtn then popup.closeBtn:SetShown(not compact) end
    -- Bei jedem Oeffnen neu ansetzen: der noetige Innenabstand haengt
    -- am Stil und kann sich zwischendurch geaendert haben.
    if popup.titleAnchor then popup.titleAnchor() end
    if popup.closeAnchor then popup.closeAnchor() end

    -- Hide leftover buttons
    for _, b in ipairs(itemButtons) do b:Hide() end

    if #results == 0 then
        popup:SetSize(280, 60)
        -- Show "no items" message inline
        if not popup.noItemsText then
            popup.noItemsText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            popup.noItemsText:SetPoint("CENTER", popup, "CENTER", 0, -8)
            popup.noItemsText:SetTextColor(0.7, 0.7, 0.7)
        end
        popup.noItemsText:SetText(L["No matching items in your bags."])
        popup.noItemsText:Show()
    else
        if popup.noItemsText then popup.noItemsText:Hide() end

        -- Kompakt: nur so viele Spalten wie noetig, kein Platz fuer die
        -- Titelleiste, keine Mindestbreite.
        local cols = mod.db.cols or 8
        if compact then cols = math.min(cols, #results) end
        local rows = math.ceil(#results / cols)
        -- Der Classic-Rahmen ist breiter und braucht mehr Innenabstand,
        -- sonst sitzen die Symbole im Rahmen.
        local inset     = ns:FrameInset()
        local padding   = (compact and 6 or 8) + inset
        local gridStart = (compact and 6 or 28) + inset
        local btnPad    = 4

        local width  = cols * (BTN_SIZE + btnPad) - btnPad + padding * 2
        local height = gridStart + rows * (BTN_SIZE + btnPad) - btnPad + padding

        popup:SetSize(compact and width or math.max(width, 180), height)

        for i, entry in ipairs(results) do
            local btn = getItemButton(i)
            btn:Show()
            btn.bag      = entry.bag
            btn.slot     = entry.slot
            btn.itemID   = entry.itemID
            btn.equipSlot = slotID  -- the character slot this picker is for

            -- Set icon
            local iconTex = entry.icon
            if not iconTex then
                local _, _, _, _, ic = GetItemInfoInstant(entry.itemID)
                iconTex = ic
            end
            if btn.icon and iconTex then
                btn.icon:SetTexture(iconTex)
            end
            -- Der Umweg ueber _G["<Name>IconTexture"] entfaellt: die Knoepfe
            -- werden ohne Namen erzeugt, der Zweig war nie erreichbar.
            if SetItemButtonTexture then
                pcall(SetItemButtonTexture, btn, iconTex)
            end

            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", popup, "TOPLEFT",
                padding + col * (BTN_SIZE + btnPad),
                -(gridStart + row * (BTN_SIZE + btnPad)))
        end
    end

    popup:ClearAllPoints()
    if compact then
        -- Zur Fensteraussenseite hin oeffnen, damit das Charaktermodell
        -- frei bleibt: linke Slotspalte nach links, rechte nach rechts.
        local toLeft = false
        local sx = anchorBtn:GetCenter()
        local cx = CharacterFrame and CharacterFrame:GetCenter()
        if sx and cx then toLeft = sx < cx end

        -- Nur kippen, wenn auf der bevorzugten Seite nachweislich kein
        -- Platz ist. Die Kantenabfragen koennen nil liefern; ein
        -- unbekannter Wert ist KEIN Platzmangel und darf nicht wie einer
        -- behandelt werden - sonst kippt die Auswahl immer.
        local need    = (popup:GetWidth() or 0) + 12
        local edgeL   = anchorBtn:GetLeft()
        local edgeR   = anchorBtn:GetRight()
        local screenR = UIParent:GetRight()
        if toLeft then
            if edgeL and edgeL < need then toLeft = false end
        else
            if edgeR and screenR and (screenR - edgeR) < need then toLeft = true end
        end

        if toLeft then
            popup:SetPoint("RIGHT", anchorBtn, "LEFT", -6, 0)
        else
            popup:SetPoint("LEFT", anchorBtn, "RIGHT", 6, 0)
        end
    elseif CharacterFrame and CharacterFrame:IsShown() then
        popup:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 4, 0)
    else
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    popup:Show()
end

-- Public API — Loadouts uses this to populate its expandable item picker
function ns:ScanBagsForSlot(slotID)
    return scanBagsForSlot(slotID)
end

-- =========================================================
-- Hook character slot buttons
-- =========================================================
local _hooked = false

-- =========================================================
-- Hover-Modus
--
-- Oeffnen mit kurzer Verzoegerung, damit das Popup nicht bei jedem
-- Ueberfahren des Charakterfensters aufspringt. Schliessen mit Nachlauf,
-- damit die Maus vom Slot ins Popup wandern kann - sonst klappt es genau
-- dann zu, wenn man zugreifen will.
--
-- Statt Timer abzubrechen (C_Timer.NewTimer gibt es nicht ueberall) laeuft
-- das ueber Generationszaehler: ein spaeterer Aufruf entwertet den frueheren.
-- =========================================================
-- Oeffnen bewusst kurz: die Anzeige soll dem Blick folgen, nicht
-- hinterherhinken. Der Nachlauf beim Schliessen bleibt laenger,
-- damit die Maus vom Slot ins Fenster wandern kann.
local OPEN_DELAY, CLOSE_DELAY = 0.10, 0.45
local _openGen, _closeGen = 0, 0
local _hoverSlotBtn

local function mouseIsOnPopupOrSlot()
    if popup and popup:IsShown() and popup:IsMouseOver() then return true end
    if _hoverSlotBtn and _hoverSlotBtn:IsMouseOver() then return true end
    return false
end

local function scheduleClose()
    if not (C_Timer and C_Timer.After) then return end
    _closeGen = _closeGen + 1
    local myGen = _closeGen
    C_Timer.After(CLOSE_DELAY, function()
        if myGen ~= _closeGen then return end          -- ueberholt
        if not (popup and popup:IsShown()) then return end
        if not popup._vgsCompact then return end       -- per Klick geoeffnet: stehen lassen
        if mouseIsOnPopupOrSlot() then
            scheduleClose()                             -- noch drueber: erneut pruefen
            return
        end
        popup:Hide()
    end)
end

local function scheduleOpen(slotID, slotBtn)
    if not (C_Timer and C_Timer.After) then return end
    _openGen = _openGen + 1
    local myGen = _openGen
    C_Timer.After(OPEN_DELAY, function()
        if myGen ~= _openGen then return end            -- Maus schon weiter
        if not mod._enabled then return end
        if not slotBtn:IsMouseOver() then return end
        -- Ein per Klick geoeffnetes Fenster nicht ueberschreiben.
        if popup and popup:IsShown() and not popup._vgsCompact then return end
        _hoverSlotBtn = slotBtn
        showSlotPicker(slotID, slotBtn)   -- kompakt, am Slot verankert

        -- Das Popup entsteht erst beim ersten Oeffnen, deshalb wird die
        -- Haltelogik hier angehaengt und nicht in hookSlots.
        if popup and not popup._vgsHoverHooked then
            popup._vgsHoverHooked = true
            popup:HookScript("OnEnter", function() _closeGen = _closeGen + 1 end)
            popup:HookScript("OnLeave", function() scheduleClose() end)
        end
    end)
end

local function hookSlots()
    if _hooked then return end
    for slotID, frameName in pairs(SLOT_FRAME_NAMES) do
        local slotBtn = _G["Character" .. frameName .. "Slot"]
        if slotBtn then
            slotBtn:HookScript("OnClick", function(self, button)
                if not mod._enabled then return end
                if checkModifier(button) then
                    showSlotPicker(slotID)
                end
            end)
            slotBtn:HookScript("OnEnter", function(self)
                if not mod._enabled then return end
                _closeGen = _closeGen + 1               -- geplantes Schliessen verwerfen
                scheduleOpen(slotID, self)
            end)
            slotBtn:HookScript("OnLeave", function()
                if not mod._enabled then return end
                _openGen = _openGen + 1                 -- geplantes Oeffnen verwerfen
                scheduleClose()
            end)
        end
    end

    _hooked = true
end

-- =========================================================
-- Lifecycle
-- =========================================================
function mod:OnEnable()
    if not mod.db then return end

    -- Einmalige Umstellung: frueher war "shift-right" die Voreinstellung,
    -- dann "right", jetzt "hover". Wer noch auf dem jeweils alten Standard
    -- steht, wird mitgenommen; eine bewusst gewaehlte Einstellung bleibt.
    if not mod.db._defaultMigrated_v2 then
        if mod.db.modifier == "shift-right" then
            mod.db.modifier = "right"
        end
        mod.db._defaultMigrated_v2 = true
    end
    -- Das Ueberfahren ist inzwischen fest eingebaut; "hover" ist als
    -- Klick-Einstellung ungueltig geworden.
    if mod.db.modifier == "hover" then
        mod.db.modifier = "right"
    end
    mod.db._defaultMigrated_v3 = nil

    hookSlots()
end

function mod:OnDisable()
    -- Die Hooks bleiben liegen: ein HookScript laesst sich nicht loesen. Sie
    -- pruefen mod._enabled, das genuegt.
    --
    -- Was aber weg muss, ist alles gerade Offene und Eingeplante. SafeDisable
    -- setzt _enabled erst NACH diesem Aufruf, ein bereits laufender
    -- Oeffnen-Timer wuerde also noch feuern und ein Fenster aufziehen, das
    -- niemand mehr schliesst. Die Generationszaehler entwerten ihn.
    _openGen  = _openGen  + 1
    _closeGen = _closeGen + 1
    if popup then popup:Hide() end
end

-- =========================================================
-- Optionen
--
-- Bewusst KEIN mod:GetOptions(): das Modul ist versteckt (group = "_hidden"),
-- das Optionsfenster rendert nur die Seite des Set-Moduls. Die Einstellungen
-- des Slot-Pickers stehen dort im Abschnitt "Slot Picker" und schreiben ueber
-- ns.modules.slotpicker.db direkt hierher. Eine eigene Seite waere nie
-- aufgerufen worden und haette die Texte nur doppelt gefuehrt.
-- =========================================================
