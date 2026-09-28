-- =========================================================
-- VuloGearSets / Modules / GearSets / Pickers
-- Auswahlfenster: ein Teil aus den Taschen fuer einen Slot, und das
-- Symbol eines Sets.
-- =========================================================
local _, ns = ...
local L   = ns.L
local GS  = ns.GS
local mod = GS.mod

-- Aus frueher geladenen Dateien (siehe Shared.lua).
local GetItemInfoInstant = GS.GetItemInfoInstant
local LO                 = GS.LO
local SLOT_NAMES         = GS.SLOT_NAMES

-- Die Leiste wird erst nach dieser Datei geladen - deshalb zur Laufzeit.
local function refreshSidebar()
    if GS.refreshSidebar then GS.refreshSidebar() end
end


-- =========================================================
-- Bag-item picker for replacing a slot in a loadout (uses SlotPicker's scan API)
-- =========================================================
local function showSlotReplacePicker(loadoutName, targetSlot, anchor)
    if not ns.ScanBagsForSlot then
        ns:Print(L["SlotPicker module is required for editing item slots."])
        return
    end

    local GetContainerItemLink_ = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink

    -- Build a unified candidate list:
    --   1) Currently equipped item in that slot (if any) — common case where
    --      the desired item is on the character, not in a bag
    --   2) For Trinkets/Rings (paired slots), the OTHER slot's equipped item too
    --      (you may want trinket1 to be what's currently in trinket2)
    --   3) All compatible items found in bags by ns:ScanBagsForSlot
    -- De-dupes by itemID so we don't show the same physical item twice.
    local candidates = {}  -- ordered list of { link, label, sourceTag }
    local seenItemID = {}

    local function addCandidate(link, label)
        if not link then return end
        local itemID = tonumber(link:match("item:(%d+)"))
        if not itemID or seenItemID[itemID] then return end
        seenItemID[itemID] = true
        table.insert(candidates, { link = link, label = label })
    end

    -- 1) Currently equipped at this slot
    local currentLink = GetInventoryItemLink("player", targetSlot)
    if currentLink then
        local name = currentLink:match("|h%[(.-)%]|h") or currentLink
        addCandidate(currentLink, name .. " |cff66ff66" .. L["(equipped)"] .. "|r")
    end

    -- 2) Paired slot for symmetric pairs (rings 11/12, trinkets 13/14)
    local PAIRS = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }
    local pairedSlot = PAIRS[targetSlot]
    if pairedSlot then
        local pairedLink = GetInventoryItemLink("player", pairedSlot)
        if pairedLink then
            local name = pairedLink:match("|h%[(.-)%]|h") or pairedLink
            addCandidate(pairedLink, name .. " |cff8888ffin " .. (SLOT_NAMES[pairedSlot] or "?") .. "|r")
        end
    end

    -- 3) Bag scan
    local bagResults = ns:ScanBagsForSlot(targetSlot)
    for _, entry in ipairs(bagResults) do
        local link = GetContainerItemLink_ and GetContainerItemLink_(entry.bag, entry.slot)
        if link then
            local name = link:match("|h%[(.-)%]|h") or link
            addCandidate(link, name)
        end
    end

    local slotName = SLOT_NAMES[targetSlot] or ("Slot " .. targetSlot)
    local entries  = {
        { title = true, text = string.format(L["Replace: %s"], slotName) },
    }

    if #candidates == 0 then
        table.insert(entries, { text = L["No matching items in your bags."], disabled = true })
    else
        for _, c in ipairs(candidates) do
            local capturedLink = c.link
            table.insert(entries, {
                text = "  " .. c.label,
                func = function()
                    if LO()[loadoutName] then
                        LO()[loadoutName].slots[targetSlot] = capturedLink
                        refreshSidebar()
                        ns:Print(string.format(L["Gear set '%s': slot updated."], loadoutName))
                    end
                end,
            })
        end
    end

    table.insert(entries, { separator = true })
    table.insert(entries, { text = L["Remove from set"], func = function()
        if LO()[loadoutName] then
            LO()[loadoutName].slots[targetSlot] = nil
            refreshSidebar()
        end
    end })

    ns:ShowPopupMenu(entries, anchor)
end

local function getSetIcon(name)
    local loadout = mod.db and LO() and LO()[name]
    if not loadout or not loadout.slots then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    if loadout.iconOverride then return loadout.iconOverride end
    -- Automatisch: das Symbol des ersten Teils nach Slot-Reihenfolge. Nicht
    -- per pairs - dessen Reihenfolge ist zufaellig, und die Leiste zeigte
    -- dann ein anderes Symbol als Makro und Blizzards Kopie des Sets.
    if GetItemInfoInstant then
        local slots = {}
        for s in pairs(loadout.slots) do slots[#slots + 1] = s end
        table.sort(slots)
        for _, s in ipairs(slots) do
            local _, _, _, _, icon = GetItemInfoInstant(loadout.slots[s])
            if icon then return icon end
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- =========================================================
-- Set-icon picker popup
-- Grid of: [Auto] + every item icon in the set + a few generic role icons.
-- Click sets loadout.iconOverride (or clears it for Auto).
-- =========================================================
local _iconPicker
local _iconBtns = {}
local ICON_SIZE = 30
local ICON_COLS = 8
local ICON_PAD  = 3
-- Sichtbare Zeilen des Auswahlfensters; alles darueber hinaus scrollt.
local ICON_VISIBLE_ROWS = 8
local ICON_SCROLLBAR_W  = 4

-- Der zerlegte Symbolbogen: Media/Icons/sets/set_1.tga .. set_N.tga.
-- Die Zahl muss zur Anzahl der Dateien im Ordner passen.
local SHEET_ICON_COUNT = 209
local SHEET_ICON_PATH  = "Interface\\AddOns\\VuloGearSets\\Media\\Icons\\sets\\set_"

-- A few hand-picked generic icons (roles/specs) so a set can use a symbol
-- that isn't one of its items.
local GENERIC_ICONS = {
    "Interface\\Icons\\Spell_Holy_PowerWordShield",
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    "Interface\\Icons\\Spell_Holy_HolyBolt",
    "Interface\\Icons\\Spell_Nature_Lightning",
    "Interface\\Icons\\Ability_Warrior_OffensiveStance",
    "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    "Interface\\Icons\\Ability_Rogue_Sprint",
    "Interface\\Icons\\Spell_Frost_FrostBolt02",
    "Interface\\Icons\\Spell_Fire_FlameBolt",
    "Interface\\Icons\\Spell_Nature_HealingTouch",
    "Interface\\Icons\\INV_Sword_27",
    "Interface\\Icons\\INV_Shield_06",
    "Interface\\Icons\\INV_Misc_Gem_Diamond_03",
    "Interface\\Icons\\Achievement_PVP_A_A",
}

local function getIconPickerButton(idx)
    local b = _iconBtns[idx]
    if b then return b end
    -- Die Knoepfe liegen im Scroll-Kind, damit der ScrollFrame sie am
    -- Rand des Sichtfensters abschneidet.
    b = CreateFrame("Button", nil, _iconPicker.scrollChild)
    b:SetSize(ICON_SIZE, ICON_SIZE)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints(b)
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.hl:SetColorTexture(ns:HoverColor())
    b:RegisterForClicks("LeftButtonUp")
    _iconBtns[idx] = b
    return b
end

local function showIconPicker(loadoutName, anchor)
    local loadout = LO()[loadoutName]
    if not loadout then return end

    if not _iconPicker then
        _iconPicker = CreateFrame("Frame", "VGS_GearSetIconPicker", UIParent,
            BackdropTemplateMixin and "BackdropTemplate")
        _iconPicker:SetFrameStrata("FULLSCREEN_DIALOG")
        _iconPicker:Hide()
        _iconPicker:EnableMouse(true)
        _iconPicker:SetClampedToScreen(true)
        ns.UI:SkinFrame(_iconPicker, "window")
        tinsert(UISpecialFrames, "VGS_GearSetIconPicker")
        _iconPicker.title = _iconPicker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        _iconPicker.title:SetPoint("TOPLEFT", _iconPicker, "TOPLEFT", 8, -6)
        _iconPicker.title:SetTextColor(1, 0.82, 0)

        _iconPicker.close = ns.UI:CreateButton(_iconPicker, "X", 18, 18)
        _iconPicker.close:SetOnClick(function() _iconPicker:Hide() end)

        -- Scrollbereich: mit dem Symbolbogen sind es weit ueber 200
        -- Symbole - als starres Gitter waere das Fenster bildschirmhoch.
        -- Mausrad plus schmaler Balken, gleiche Machart wie die
        -- Seitenleiste.
        local scroll = CreateFrame("ScrollFrame", nil, _iconPicker)
        local child  = CreateFrame("Frame", nil, scroll)
        child:SetSize(1, 1)
        scroll:SetScrollChild(child)
        scroll:EnableMouseWheel(true)

        local sbar = CreateFrame("Frame", nil, _iconPicker)
        sbar:SetWidth(ICON_SCROLLBAR_W)
        sbar:Hide()
        local track = sbar:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints(sbar)
        track:SetColorTexture(0, 0, 0, 0.25)
        local thumb = sbar:CreateTexture(nil, "ARTWORK")
        thumb:SetWidth(ICON_SCROLLBAR_W)

        local function updateThumb()
            local viewH    = scroll:GetHeight() or 0
            local contentH = scroll._contentH or 0
            local maxS     = scroll._maxScroll or 0
            if maxS <= 0 or viewH <= 0 or contentH <= 0 then return end
            local thumbH = math.min(viewH, math.max(16, viewH * (viewH / contentH)))
            local frac   = scroll:GetVerticalScroll() / maxS
            thumb:SetHeight(thumbH)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", sbar, "TOP", 0, -(frac * (viewH - thumbH)))
        end
        scroll:SetScript("OnVerticalScroll", updateThumb)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local maxS = self._maxScroll or 0
            if maxS <= 0 then return end
            local new = self:GetVerticalScroll() - delta * (ICON_SIZE + ICON_PAD) * 2
            if new < 0 then new = 0 elseif new > maxS then new = maxS end
            self:SetVerticalScroll(new)
        end)

        _iconPicker.scroll, _iconPicker.scrollChild = scroll, child
        _iconPicker.sbar, _iconPicker.thumb = sbar, thumb
        _iconPicker.updateThumb = updateThumb
    end

    _iconPicker.title:SetText(string.format(L["Icon for: %s"], loadoutName))

    -- Build the icon list: Auto first, then set items, then generics (de-duped)
    local icons = {}           -- { tex = path or nil (=auto), isAuto = bool }
    local seen  = {}
    table.insert(icons, { isAuto = true })
    if GetItemInfoInstant and loadout.slots then
        -- stable order by slot
        local slots = {}
        for s in pairs(loadout.slots) do table.insert(slots, s) end
        table.sort(slots)
        for _, s in ipairs(slots) do
            local _, _, _, _, ic = GetItemInfoInstant(loadout.slots[s])
            if ic and not seen[ic] then
                seen[ic] = true
                table.insert(icons, { tex = ic })
            end
        end
    end
    for _, ic in ipairs(GENERIC_ICONS) do
        if not seen[ic] then
            seen[ic] = true
            table.insert(icons, { tex = ic })
        end
    end
    -- Zum Schluss der zerlegte Symbolbogen.
    for i = 1, SHEET_ICON_COUNT do
        local path = SHEET_ICON_PATH .. i
        if not seen[path] then
            seen[path] = true
            table.insert(icons, { tex = path })
        end
    end

    -- Hide leftover buttons
    for _, b in ipairs(_iconBtns) do b:Hide() end

    for i, entry in ipairs(icons) do
        local b = getIconPickerButton(i)
        b:Show()
        if entry.isAuto then
            b.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            b.tex:SetVertexColor(0.7, 0.7, 0.7)
            b._iconValue = nil  -- nil = auto
        else
            b.tex:SetTexture(entry.tex)
            b.tex:SetVertexColor(1, 1, 1)
            b._iconValue = entry.tex
        end
        b:SetScript("OnClick", function(self)
            loadout.iconOverride = self._iconValue  -- nil → auto
            if ns.MirrorSetIconChanged then ns:MirrorSetIconChanged(loadoutName) end
            if ns.UpdateSetMacroIcon then ns:UpdateSetMacroIcon(loadoutName) end
            _iconPicker:Hide()
            refreshSidebar()
        end)
        local col = (i - 1) % ICON_COLS
        local row = math.floor((i - 1) / ICON_COLS)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", _iconPicker.scrollChild, "TOPLEFT",
            col * (ICON_SIZE + ICON_PAD),
            -(row * (ICON_SIZE + ICON_PAD)))
    end

    -- Layout: das Sichtfenster zeigt hoechstens ICON_VISIBLE_ROWS Zeilen,
    -- der Rest scrollt. Der Innenabstand haengt am Stil (Classic-Rahmen
    -- ist breiter), deshalb wird hier bei jedem Oeffnen neu verankert.
    local inset    = ns:FrameInset()
    local pad      = 6 + inset
    local startY   = 24 + inset
    local numRows  = math.ceil(#icons / ICON_COLS)
    local visRows  = math.min(numRows, ICON_VISIBLE_ROWS)
    local gridW    = ICON_COLS * (ICON_SIZE + ICON_PAD) - ICON_PAD
    local viewH    = visRows * (ICON_SIZE + ICON_PAD) - ICON_PAD
    local contentH = numRows * (ICON_SIZE + ICON_PAD) - ICON_PAD

    local scroll, child, sbar = _iconPicker.scroll, _iconPicker.scrollChild, _iconPicker.sbar
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", _iconPicker, "TOPLEFT", pad, -startY)
    scroll:SetSize(gridW, viewH)
    child:SetSize(gridW, math.max(contentH, viewH))

    sbar:ClearAllPoints()
    sbar:SetPoint("TOPLEFT",    scroll, "TOPRIGHT", 3, 0)
    sbar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 3, 0)

    local maxS = math.max(0, contentH - viewH)
    scroll._contentH, scroll._maxScroll = contentH, maxS
    scroll:SetVerticalScroll(0)
    _iconPicker.thumb:SetColorTexture(ns:AccentColor())
    sbar:SetShown(maxS > 0)
    _iconPicker.updateThumb()

    _iconPicker.title:ClearAllPoints()
    _iconPicker.title:SetPoint("TOPLEFT", _iconPicker, "TOPLEFT", 8 + inset, -6 - inset)

    _iconPicker.close:ClearAllPoints()
    _iconPicker.close:SetPoint("TOPRIGHT", _iconPicker, "TOPRIGHT", -(3 + inset), -(3 + inset))
    -- Lange Set-Namen duerfen nicht unter den X-Button laufen.
    _iconPicker.title:SetPoint("RIGHT", _iconPicker.close, "LEFT", -4, 0)
    _iconPicker.title:SetWordWrap(false)
    _iconPicker.title:SetJustifyH("LEFT")

    _iconPicker:SetSize(
        pad * 2 + gridW + ((maxS > 0) and (ICON_SCROLLBAR_W + 3) or 0),
        startY + viewH + pad)

    _iconPicker:ClearAllPoints()
    if anchor and anchor.GetLeft then
        _iconPicker:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
    else
        _iconPicker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    _iconPicker:Show()
end

-- Fuer OnDisable (Lifecycle.lua).
function GS.hideIconPicker()
    if _iconPicker then _iconPicker:Hide() end
end

-- Fuer die spaeter geladenen Dateien (siehe Shared.lua).
GS.getSetIcon            = getSetIcon
GS.showIconPicker        = showIconPicker
GS.showSlotReplacePicker = showSlotReplacePicker
