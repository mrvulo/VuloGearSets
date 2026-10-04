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
-- Gitter aus: [Auto] + die Symbole der Teile im Set + alle Symbole, die
-- auch Blizzards eigene Symbolauswahl (Makros, Ausruestungsmanager)
-- anbietet. Klick setzt loadout.iconOverride (Auto loescht es).
--
-- Das sind tausende Symbole. Es gibt deshalb nur so viele Knoepfe, wie
-- sichtbar sind; beim Scrollen bekommen sie neue Symbole.
-- =========================================================
local _iconPicker
local _iconBtns = {}
local ICON_COLS = 10
-- Sichtbare Zeilen des Auswahlfensters; alles darueber hinaus scrollt.
local ICON_VISIBLE_ROWS = 8
local ICON_SCROLLBAR_W  = 4
local ICON_WHEEL_ROWS   = 3
local FILTER_H          = 18
local FILTER_GAP        = 4

-- Zwei Aussehen. Im Forever-Stil mit den Blizzard-Themes wie Blizzards
-- Symbolauswahl: Blizzards Rahmen, groessere Symbole auf leeren
-- Taschenplaetzen, Blizzards Auswahlliste und Scrollbalken. Sonst flach
-- wie die Set-Leiste.
local FLAT  = { size = 30, pad = 3, rowH = FILTER_H }
local BLIZZ = { size = 36, pad = 9, rowH = 26 }

-- Platzhalter fuer "Auto" in der Symbolliste.
local AUTO_ICON = {}

-- Filter wie in Blizzards Symbolauswahl.
local FILTERS = { "all", "spell", "item" }
local function filterText(key)
    if key == "spell" then return L["Spells"] end
    if key == "item"  then return L["Items"] end
    return L["All icons"]
end

-- Blizzards Symbolliste: dieselben vier Aufrufe, aus denen Blizzards
-- Symbolauswahl ihre Liste fuellt - Zaubersymbole und Gegenstandssymbole.
-- Bewusst nicht ueber Blizzards IconDataProviderMixin: dessen
-- Zwischenspeicher teilen sich alle Fenster, die ihn benutzen, und ein
-- Zugriff aus Addon-Code kann Blizzards Ausruestungsmanager und
-- Makrofenster mit Taint belegen.
local function loadGameIcons()
    local spells, items = {}, {}
    if GetLooseMacroIcons     then GetLooseMacroIcons(spells)    end
    if GetLooseMacroItemIcons then GetLooseMacroItemIcons(items) end
    if GetMacroIcons          then GetMacroIcons(spells)         end
    if GetMacroItemIcons      then GetMacroItemIcons(items)      end
    -- Wie bei Blizzard: Datei-IDs, auf manchen Builds aber Dateinamen
    -- ohne Pfad.
    for _, list in ipairs({ spells, items }) do
        for i = 1, #list do
            list[i] = tonumber(list[i]) or ("Interface\\Icons\\" .. list[i])
        end
    end
    return spells, items
end

-- Die Abschnitte der Liste je Filter, in Blizzards Reihenfolge: erst die
-- eigenen Symbole, dann Zauber, dann Gegenstaende.
local function buildIconSections(p)
    local f = p.filter
    local s = { { AUTO_ICON } }
    if f ~= "spell" then s[#s + 1] = p.setIcons end
    if f ~= "item"  then s[#s + 1] = p.spells   end
    if f ~= "spell" then s[#s + 1] = p.items    end
    local total = 0
    for _, list in ipairs(s) do total = total + #list end
    p.sections, p.total = s, total
end

local function iconAt(idx)
    for _, list in ipairs(_iconPicker.sections) do
        local n = #list
        if idx <= n then return list[idx] end
        idx = idx - n
    end
    return nil
end

local function indexOfIcon(icon)
    if icon == nil then return 1 end  -- Auto
    local base = 0
    for _, list in ipairs(_iconPicker.sections) do
        for i = 1, #list do
            if list[i] == icon then return base + i end
        end
        base = base + #list
    end
    return nil
end

local function refreshIconGrid()
    local p = _iconPicker
    local first = p.offset * ICON_COLS
    for k, b in ipairs(_iconBtns) do
        local idx  = first + k
        local icon = iconAt(idx)
        if icon == nil then
            b:Hide()
        else
            if icon == AUTO_ICON then
                b.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                b.tex:SetVertexColor(0.7, 0.7, 0.7)
                b._iconValue = nil  -- nil = auto
            else
                b.tex:SetTexture(icon)
                b.tex:SetVertexColor(1, 1, 1)
                b._iconValue = icon
            end
            b.sel:SetShown(idx == p.selected)
            b:Show()
        end
    end

    if p.useBlizzBar then
        -- Kam die Aenderung vom Balken selbst, ihn nicht zuruecksetzen:
        -- sonst rastete der gezogene Griff bei jeder Zeile ein.
        if not p.fromBar then
            p.blizzBar:SetScrollPercentage(p.maxOffset > 0 and p.offset / p.maxOffset or 0, true)
        end
    elseif p.maxOffset > 0 then
        local thumbH = math.max(16, p.viewH * ICON_VISIBLE_ROWS / p.numRows)
        p.thumb:SetHeight(thumbH)
        p.thumb:ClearAllPoints()
        p.thumb:SetPoint("TOP", p.sbar, "TOP", 0,
            -(p.offset / p.maxOffset) * (p.viewH - thumbH))
    end
end

local function setIconOffset(row)
    local p = _iconPicker
    if row < 0 then row = 0 elseif row > p.maxOffset then row = p.maxOffset end
    if row == p.offset then return end
    p.offset = row
    refreshIconGrid()
end

local function applyIconFilter(key)
    local p = _iconPicker
    p.filter = key
    buildIconSections(p)
    p.numRows   = math.ceil(p.total / ICON_COLS)
    p.maxOffset = math.max(0, p.numRows - ICON_VISIBLE_ROWS)
    p.selected  = indexOfIcon(p.current)
    -- Das gewaehlte Symbol in die Mitte holen, wie Blizzards Auswahl es
    -- beim Oeffnen tut.
    local row = p.selected and math.floor((p.selected - 1) / ICON_COLS) or 0
    p.offset = math.max(0, math.min(p.maxOffset, row - math.floor(ICON_VISIBLE_ROWS / 2)))
    if p.useBlizzBar then
        p.blizzBar:SetVisibleExtentPercentage(
            p.numRows > 0 and math.min(1, ICON_VISIBLE_ROWS / p.numRows) or 1)
        p.blizzBar:SetPanExtentPercentage(p.maxOffset > 0 and 1 / p.maxOffset or 1)
    else
        p.sbar:SetShown(p.maxOffset > 0)
    end
    for _, fb in ipairs(p.filterBtns) do
        fb.mark:SetColorTexture(ns:AccentColor())
        fb.mark:SetShown(fb.key == key)
    end
    refreshIconGrid()
end

local function onIconClick(self)
    local name    = _iconPicker.setName
    local loadout = LO()[name]
    if loadout then
        loadout.iconOverride = self._iconValue  -- nil → auto
        if ns.MirrorSetIconChanged then ns:MirrorSetIconChanged(name) end
        if ns.UpdateSetMacroIcon then ns:UpdateSetMacroIcon(name) end
    end
    _iconPicker:Hide()
    refreshSidebar()
end

-- Blizzards Bedienelemente fuer den Forever-Look, erst bei Bedarf und
-- jedes einzeln abgesichert: fehlt eine Vorlage, bleibt das flache
-- Gegenstueck stehen.
local function createBlizzWidgets(p)
    if p.blizzTried then return end
    p.blizzTried = true

    local ok, dd = pcall(CreateFrame, "DropdownButton", nil, p, "WowStyle1DropdownTemplate")
    if ok and dd and dd.SetupMenu then
        dd:SetWidth(150)
        dd:SetupMenu(function(_, root)
            for _, key in ipairs(FILTERS) do
                root:CreateRadio(filterText(key),
                    function(k) return p.filter == k end,
                    function(k) applyIconFilter(k) end,
                    key)
            end
        end)
        p.dropdown = dd
        if type(_G.MACRO_POPUP_CHOOSE_ICON) == "string" then
            p.chooseText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            p.chooseText:SetText(_G.MACRO_POPUP_CHOOSE_ICON)
        end
    elseif ok and dd then
        dd:Hide()
    end

    local okBar, bar = pcall(CreateFrame, "EventFrame", nil, p, "MinimalScrollBar")
    if okBar and bar and bar.SetScrollPercentage and bar.RegisterCallback then
        bar:RegisterCallback("OnScroll", function(_, pct)
            if p.maxOffset <= 0 then return end
            p.fromBar = true
            setIconOffset(math.floor(pct * p.maxOffset + 0.5))
            p.fromBar = false
        end, p)
        p.blizzBar = bar
    elseif okBar and bar then
        bar:Hide()
    end

    local okClose, close = pcall(CreateFrame, "Button", nil, p, "UIPanelCloseButton")
    if okClose and close then
        close:SetScript("OnClick", function() p:Hide() end)
        p.blizzClose = close
    end
end

local function createIconPicker()
    local p = CreateFrame("Frame", "VGS_GearSetIconPicker", UIParent,
        BackdropTemplateMixin and "BackdropTemplate")
    _iconPicker = p
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:Hide()
    p:EnableMouse(true)
    p:SetClampedToScreen(true)
    ns.UI:SkinFrame(p, "selector")
    tinsert(UISpecialFrames, "VGS_GearSetIconPicker")
    -- Blizzards Liste nur halten, solange das Fenster offen ist.
    p:SetScript("OnHide", function(self)
        self.spells, self.items, self.sections = nil, nil, nil
    end)

    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.title:SetTextColor(1, 0.82, 0)

    p.close = ns.UI:CreateButton(p, "X", 18, 18)
    p.close:SetOnClick(function() p:Hide() end)

    p.filterBtns = {}
    for i, key in ipairs(FILTERS) do
        local fb = ns.UI:CreateButton(p, filterText(key), 100, FILTER_H)
        fb.key = key
        fb.mark = fb:CreateTexture(nil, "OVERLAY")
        fb.mark:SetHeight(2)
        fb.mark:SetPoint("BOTTOMLEFT", fb, "BOTTOMLEFT", 3, 1)
        fb.mark:SetPoint("BOTTOMRIGHT", fb, "BOTTOMRIGHT", -3, 1)
        fb:SetOnClick(function() applyIconFilter(key) end)
        p.filterBtns[i] = fb
    end

    p.grid = CreateFrame("Frame", nil, p)
    p.grid:EnableMouseWheel(true)
    local function onWheel(_, delta)
        setIconOffset(p.offset - delta * ICON_WHEEL_ROWS)
    end
    p.grid:SetScript("OnMouseWheel", onWheel)

    for k = 1, ICON_COLS * ICON_VISIBLE_ROWS do
        local b = CreateFrame("Button", nil, p.grid)
        -- Leerer Taschenplatz hinter dem Symbol, wie bei Blizzard.
        b.slot = b:CreateTexture(nil, "BACKGROUND")
        b.slot:SetTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
        b.slot:SetTexCoord(0.140625, 0.84375, 0.140625, 0.84375)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints(b)
        b.sel = b:CreateTexture(nil, "OVERLAY")
        b.sel:SetAllPoints(b)
        b.sel:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        b.sel:SetBlendMode("ADD")
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints(b)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", onIconClick)
        _iconBtns[k] = b
    end

    -- Schmaler Balken, gleiche Machart wie die Seitenleiste. Bei tausenden
    -- Symbolen kaeme man mit dem Mausrad allein kaum ans Ende: ein Klick
    -- auf den Balken springt dorthin, Gedrueckthalten zieht mit.
    local sbar = CreateFrame("Frame", nil, p)
    sbar:SetWidth(ICON_SCROLLBAR_W)
    sbar:SetHitRectInsets(-4, -4, 0, 0)
    sbar:EnableMouse(true)
    sbar:EnableMouseWheel(true)
    sbar:SetScript("OnMouseWheel", onWheel)
    local track = sbar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(sbar)
    track:SetColorTexture(0, 0, 0, 0.25)
    p.thumb = sbar:CreateTexture(nil, "ARTWORK")
    p.thumb:SetWidth(ICON_SCROLLBAR_W)

    local function dragTo(self)
        if not IsMouseButtonDown("LeftButton") then
            self:SetScript("OnUpdate", nil)
            return
        end
        local _, y   = GetCursorPosition()
        local top    = self:GetTop()
        local thumbH = p.thumb:GetHeight() or 0
        if not top or p.viewH <= thumbH then return end
        y = y / self:GetEffectiveScale()
        local frac = (top - y - thumbH / 2) / (p.viewH - thumbH)
        setIconOffset(math.floor(frac * p.maxOffset + 0.5))
    end
    sbar:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self:SetScript("OnUpdate", dragTo)
        dragTo(self)
    end)
    sbar:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    sbar:SetScript("OnHide",    function(self) self:SetScript("OnUpdate", nil) end)
    p.sbar = sbar
end

local function showIconPicker(loadoutName, anchor)
    local loadout = LO()[loadoutName]
    if not loadout then return end

    if not _iconPicker then createIconPicker() end
    local p = _iconPicker
    p.setName = loadoutName
    p.current = loadout.iconOverride
    p.title:SetText(string.format(L["Icon for: %s"], loadoutName))

    -- Symbole der Teile im Set, stabil nach Slot sortiert, ohne Doppelte.
    local setIcons, seen = {}, {}
    if GetItemInfoInstant and loadout.slots then
        local slots = {}
        for s in pairs(loadout.slots) do slots[#slots + 1] = s end
        table.sort(slots)
        for _, s in ipairs(slots) do
            local _, _, _, _, ic = GetItemInfoInstant(loadout.slots[s])
            if ic and not seen[ic] then
                seen[ic] = true
                setIcons[#setIcons + 1] = ic
            end
        end
    end
    p.setIcons = setIcons
    if not p.spells then p.spells, p.items = loadGameIcons() end

    -- Aussehen bei jedem Oeffnen neu bestimmen: Stil und Theme koennen
    -- sich zwischendurch geaendert haben.
    local blizz = ns:UsesSelectorArt()
    if blizz then createBlizzWidgets(p) end
    local look     = blizz and BLIZZ or FLAT
    local dropdown = blizz and p.dropdown
    local close    = (blizz and p.blizzClose) or p.close
    p.useBlizzBar  = (blizz and p.blizzBar) and true or false

    -- Layout: der Innenabstand haengt am Stil (Classic-Rahmen ist
    -- breiter), deshalb wird hier bei jedem Oeffnen neu verankert.
    local inset   = ns:FrameInset("selector")
    local pad     = (blizz and 4 or 6) + inset
    local filterY = (blizz and 22 or 24) + inset
    local gridY   = filterY + look.rowH + (blizz and 10 or 6)
    local pitch   = look.size + look.pad
    local gridW   = ICON_COLS * pitch - look.pad
    p.viewH       = ICON_VISIBLE_ROWS * pitch - look.pad
    local barW    = p.useBlizzBar and 8 or ICON_SCROLLBAR_W
    local barGap  = p.useBlizzBar and 10 or 3

    p.title:ClearAllPoints()
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", (blizz and 4 or 8) + inset, -(blizz and 4 or 6) - inset)

    p.close:SetShown(close == p.close)
    if p.blizzClose then p.blizzClose:SetShown(close == p.blizzClose) end
    close:ClearAllPoints()
    if close == p.blizzClose then
        -- Ueber Blizzards Rahmen, der selbst ueber dem Inhalt liegt.
        close:SetFrameLevel(p:GetFrameLevel() + 40)
        close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -2, -2)
    else
        close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(3 + inset), -(3 + inset))
    end
    -- Lange Set-Namen duerfen nicht unter den X-Button laufen.
    p.title:SetPoint("RIGHT", close, "LEFT", -4, 0)
    p.title:SetWordWrap(false)
    p.title:SetJustifyH("LEFT")

    -- Filter: Blizzards Auswahlliste oder die drei flachen Knoepfe.
    for _, fb in ipairs(p.filterBtns) do fb:SetShown(not dropdown) end
    if p.dropdown then p.dropdown:SetShown(dropdown and true or false) end
    if p.chooseText then p.chooseText:SetShown(dropdown and true or false) end
    if dropdown then
        dropdown:ClearAllPoints()
        dropdown:SetPoint("TOPRIGHT", p, "TOPLEFT", pad + gridW + barGap + barW, -filterY)
        if p.chooseText then
            p.chooseText:ClearAllPoints()
            p.chooseText:SetPoint("LEFT", p, "TOPLEFT", pad, -filterY - look.rowH / 2)
        end
    else
        local fbW = (gridW - FILTER_GAP * (#p.filterBtns - 1)) / #p.filterBtns
        for i, fb in ipairs(p.filterBtns) do
            fb:ClearAllPoints()
            fb:SetSize(fbW, FILTER_H)
            fb:SetPoint("TOPLEFT", p, "TOPLEFT", pad + (i - 1) * (fbW + FILTER_GAP), -filterY)
        end
    end

    p.grid:ClearAllPoints()
    p.grid:SetPoint("TOPLEFT", p, "TOPLEFT", pad, -gridY)
    p.grid:SetSize(gridW, p.viewH)

    for k, b in ipairs(_iconBtns) do
        b:SetSize(look.size, look.size)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", p.grid, "TOPLEFT",
            ((k - 1) % ICON_COLS) * pitch,
            -(math.floor((k - 1) / ICON_COLS) * pitch))
        if blizz then
            -- Wie bei Blizzard: ganzes Symbol, Taschenplatz dahinter,
            -- Blizzards Leuchten beim Ueberfahren.
            b.slot:SetSize(look.size * 1.25, look.size * 1.25)
            b.slot:SetPoint("CENTER", b, "CENTER", 0, -1)
            b.slot:Show()
            b.tex:SetTexCoord(0, 1, 0, 1)
            b.hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
            b.hl:SetBlendMode("ADD")
        else
            b.slot:Hide()
            b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b.hl:SetColorTexture(ns:HoverColor())
            b.hl:SetBlendMode("BLEND")
        end
    end

    p.sbar:SetShown(not p.useBlizzBar)
    if p.blizzBar then p.blizzBar:SetShown(p.useBlizzBar) end
    local bar = p.useBlizzBar and p.blizzBar or p.sbar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT",    p.grid, "TOPRIGHT", barGap, 0)
    bar:SetPoint("BOTTOMLEFT", p.grid, "BOTTOMRIGHT", barGap, 0)
    p.thumb:SetColorTexture(ns:AccentColor())

    p:SetSize(pad * 2 + gridW + barGap + barW, gridY + p.viewH + pad)

    -- Wie Blizzard: beim Oeffnen immer alle Symbole.
    applyIconFilter("all")
    if dropdown and dropdown.GenerateMenu then dropdown:GenerateMenu() end

    p:ClearAllPoints()
    if anchor and anchor.GetLeft then
        p:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
    else
        p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    p:Show()
end

-- Fuer OnDisable (Lifecycle.lua).
function GS.hideIconPicker()
    if _iconPicker then _iconPicker:Hide() end
end

-- Fuer die spaeter geladenen Dateien (siehe Shared.lua).
GS.getSetIcon            = getSetIcon
GS.showIconPicker        = showIconPicker
GS.showSlotReplacePicker = showSlotReplacePicker
