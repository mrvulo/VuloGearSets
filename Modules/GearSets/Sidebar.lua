-- =========================================================
-- VuloGearSets / Modules / GearSets / Sidebar
-- Die Leiste am Charakterfenster: Set-Zeilen, Umsortieren per Ziehen,
-- aufgeklappte Teile, Statuspunkte.
-- =========================================================
local _, ns = ...
local L   = ns.L
local GS  = ns.GS
local mod = GS.mod

-- Aus frueher geladenen Dateien (siehe Shared.lua).
local GetItemInfoInstant    = GS.GetItemInfoInstant
local LO                    = GS.LO
local SLOT_NAMES            = GS.SLOT_NAMES
local VISIBILITY_FIELDS     = GS.VISIBILITY_FIELDS
local bankIsOpen            = GS.bankIsOpen
local charDB                = GS.charDB
local countSlots            = GS.countSlots
local cycleVisibility       = GS.cycleVisibility
local deleteLoadout         = GS.deleteLoadout
local depositLoadout        = GS.depositLoadout
local equipLoadout          = GS.equipLoadout
local getNumSpecGroups      = GS.getNumSpecGroups
local getSetIcon            = GS.getSetIcon
local getSetStatus          = GS.getSetStatus
local getSpecGroupLabel     = GS.getSpecGroupLabel
local moveLoadout           = GS.moveLoadout
local moveLoadoutTo         = GS.moveLoadoutTo
local overwriteLoadout      = GS.overwriteLoadout
local promptRename          = GS.promptRename
local promptSaveWithSlots   = GS.promptSaveWithSlots
local showIconPicker        = GS.showIconPicker
local showSlotReplacePicker = GS.showSlotReplacePicker
local sortedLoadoutNames    = GS.sortedLoadoutNames
local specMap               = GS.specMap
local visibilityText        = GS.visibilityText


-- =========================================================
-- Character-frame sidebar (loadout buttons)
-- =========================================================
local sidebar
local sidebarSetButtons = {}
local sidebarItemRows   = {}    -- pool of expanded-item-row frames
-- Set-Zeilen, deren Farben beim Stilwechsel nachgezogen werden muessen.
local _setRowTextures   = {}

ns:OnStyleChanged(function()
    for _, btn in ipairs(_setRowTextures) do
        if btn.selection then btn.selection:SetColorTexture(ns:SelectionColor()) end
        if btn.hl        then btn.hl:SetColorTexture(ns:HoverColor()) end
    end
    -- Der Innenabstand haengt am Stil: neu aufbauen, damit Zeilen und
    -- Knoepfe nicht ueber den Rahmen laufen.
    if mod._layoutSidebarButtons then mod._layoutSidebarButtons() end
    if _G.VGS_GearSetsSidebar and _G.VGS_GearSetsSidebar:IsShown() then
        if mod._reanchorSidebar then mod._reanchorSidebar() end
        if mod._refreshSidebar  then mod._refreshSidebar()  end
    end
end)
local sidebarSelected           -- currently highlighted loadout name
local sidebarExpanded           -- name of currently expanded loadout (only one at a time)
local refreshSidebar            -- forward declaration


-- =========================================================
-- Sets in der Leiste per Ziehen umsortieren
--
-- Beim Ziehen haengt ein Schatten der Zeile (Symbol + Name) am Mauszeiger,
-- und ein Strich in der Liste zeigt, wo das Set beim Loslassen landet.
-- Die Zielposition wird ueber die Mitte der sichtbaren Zeilen bestimmt:
-- oberhalb der Mitte heisst "davor", unterhalb "danach". Am oberen und
-- unteren Rand des Sichtfensters scrollt die Liste von selbst weiter, damit
-- auch lange Listen ohne Absetzen sortierbar sind.
-- =========================================================
local DRAG_EDGE_SCROLL_ZONE  = 14   -- px vom Rand, ab dem gescrollt wird
local DRAG_EDGE_SCROLL_SPEED = 240  -- px pro Sekunde

local _drag  -- { name = <Set>, insertBefore = <Index in der Liste> }
local _dragGhost, _dragMarker

local function ensureDragWidgets()
    if _dragGhost then return end
    local g = CreateFrame("Frame", nil, UIParent)
    g:SetSize(160, 28)
    g:SetFrameStrata("TOOLTIP")
    g:SetAlpha(0.9)
    g:Hide()
    g.bg = g:CreateTexture(nil, "BACKGROUND")
    g.bg:SetAllPoints(g)
    g.bg:SetColorTexture(0, 0, 0, 0.75)
    g.icon = g:CreateTexture(nil, "ARTWORK")
    g.icon:SetSize(22, 22)
    g.icon:SetPoint("LEFT", g, "LEFT", 3, 0)
    g.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    g.text = g:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    g.text:SetPoint("LEFT", g.icon, "RIGHT", 6, 0)
    g.text:SetPoint("RIGHT", g, "RIGHT", -6, 0)
    g.text:SetJustifyH("LEFT")
    _dragGhost = g

    -- Der Strich lebt im Scroll-Kind: so wird er mit den Zeilen bewegt
    -- und am Rand des Sichtfensters abgeschnitten wie sie.
    local m = sidebar.list:CreateTexture(nil, "OVERLAY")
    m:SetHeight(2)
    m:Hide()
    _dragMarker = m
end

-- Zielindex aus der Mauslage bestimmen und den Strich dorthin setzen.
local function updateDragTarget()
    if not _drag then return end
    local list = sidebar.list
    local _, cy = GetCursorPosition()
    cy = cy / list:GetEffectiveScale()

    local names = sortedLoadoutNames()
    local n = #names
    local insertBefore = n + 1
    for i = 1, n do
        local row = sidebarSetButtons[i]
        if row and row:IsShown() then
            local top, bottom = row:GetTop(), row:GetBottom()
            if top and bottom and cy >= (top + bottom) / 2 then
                insertBefore = i
                break
            end
        end
    end
    _drag.insertBefore = insertBefore

    -- Ein Strich vor oder hinter der eigenen Zeile hiesse "nichts aendern".
    local idx
    for i, nm in ipairs(names) do
        if nm == _drag.name then idx = i; break end
    end
    _dragMarker:ClearAllPoints()
    if idx and (insertBefore == idx or insertBefore == idx + 1) then
        _dragMarker:Hide()
        return
    end
    _dragMarker:SetColorTexture(ns:AccentColor())
    if insertBefore <= n then
        local row = sidebarSetButtons[insertBefore]
        _dragMarker:SetPoint("BOTTOMLEFT",  row, "TOPLEFT",  2, 0)
        _dragMarker:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", -2, 0)
    else
        -- Hinter dem letzten Set - unter seinem aufgeklappten Raster, falls
        -- es eines hat.
        local anchor = sidebarSetButtons[n]
        if sidebarExpanded == names[n] and sidebarItemRows[n]
           and sidebarItemRows[n]:IsShown() then
            anchor = sidebarItemRows[n]
        end
        _dragMarker:SetPoint("TOPLEFT",  anchor, "BOTTOMLEFT",  2, -1)
        _dragMarker:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", -2, -1)
    end
    _dragMarker:Show()
end

local function dragOnUpdate(self, elapsed)
    if not _drag then return end
    -- Schatten am Zeiger halten
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / s + 12, y / s)

    -- Am Rand des Sichtfensters weiterscrollen
    local scroll = sidebar.scroll
    local maxS = scroll and scroll._maxScroll or 0
    if scroll and maxS > 0 then
        local cy  = y / scroll:GetEffectiveScale()
        local top, bottom = scroll:GetTop(), scroll:GetBottom()
        if top and bottom then
            local step = DRAG_EDGE_SCROLL_SPEED * elapsed
            local cur  = scroll:GetVerticalScroll()
            if cy > top - DRAG_EDGE_SCROLL_ZONE and cy <= top + 40 then
                scroll:SetVerticalScroll(math.max(0, cur - step))
            elseif cy < bottom + DRAG_EDGE_SCROLL_ZONE and cy >= bottom - 40 then
                scroll:SetVerticalScroll(math.min(maxS, cur + step))
            end
        end
    end

    updateDragTarget()
end

local function startSetDrag(row)
    if not (row.setName and LO()[row.setName]) then return end
    if #sortedLoadoutNames() < 2 then return end
    ensureDragWidgets()
    _drag = { name = row.setName }
    GameTooltip:Hide()
    row:SetAlpha(0.4)
    _dragGhost.icon:SetTexture(getSetIcon(row.setName))
    _dragGhost.text:SetText(row.setName)
    _dragGhost:SetScript("OnUpdate", dragOnUpdate)
    _dragGhost:Show()
    dragOnUpdate(_dragGhost, 0)
end

local function stopSetDrag(row, cancel)
    if not _drag then return end
    local name, insertBefore = _drag.name, _drag.insertBefore
    _drag = nil
    row:SetAlpha(1)
    _dragGhost:SetScript("OnUpdate", nil)
    _dragGhost:Hide()
    _dragMarker:Hide()

    if cancel or not insertBefore then return end
    local names = sortedLoadoutNames()
    local idx
    for i, nm in ipairs(names) do
        if nm == name then idx = i; break end
    end
    if not idx then return end
    -- Aus "davor einfuegen" die Endposition machen: liegt das Ziel hinter
    -- der eigenen Zeile, rueckt es durch das Herausnehmen um eins auf.
    local newPos = (insertBefore > idx) and (insertBefore - 1) or insertBefore
    if moveLoadoutTo(name, newPos) then
        sidebarSelected = name
        refreshSidebar()
    end
end

local function createSetRow(parent, index)
    local btn = sidebarSetButtons[index]
    if btn then return btn end

    btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(32)

    -- Icon (left)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(26, 26)
    btn.icon:SetPoint("LEFT", btn, "LEFT", 4, 0)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Expand button (right) — toggles inline item view
    btn.expand = CreateFrame("Button", nil, btn)
    btn.expand:SetSize(18, 18)
    btn.expand:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    btn.expand.icon = btn.expand:CreateTexture(nil, "ARTWORK")
    btn.expand.icon:SetAllPoints(btn.expand)
    btn.expand.icon:SetTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Up")
    btn.expand:SetHighlightTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Highlight")
    btn.expand:SetScript("OnClick", function()
        if sidebarExpanded == btn.setName then
            sidebarExpanded = nil
        else
            sidebarExpanded = btn.setName
        end
        refreshSidebar()
    end)

    -- Name text (between icon and expand button). Der Statusmarker haengt
    -- als eingefaerbter Punkt am Namen - wie in VuloClassicUI.
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 8, 0)
    btn.text:SetPoint("RIGHT", btn.expand, "LEFT", -4, 0)
    btn.text:SetJustifyH("LEFT")

    -- Selection background
    -- Etwas eingerueckt statt randfuellend: der Balken soll die Zeile
    -- markieren, nicht dominieren.
    btn.selection = btn:CreateTexture(nil, "BACKGROUND")
    btn.selection:SetPoint("TOPLEFT",     2, -2)
    btn.selection:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.selection:SetColorTexture(ns:SelectionColor())
    btn.selection:Hide()

    -- Hover highlight
    btn.hl = btn:CreateTexture(nil, "BACKGROUND")
    btn.hl:SetPoint("TOPLEFT",     2, -2)
    btn.hl:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.hl:SetColorTexture(ns:HoverColor())
    btn.hl:Hide()
    -- Fuer den Stilwechsel merken: die Farben werden dann neu gesetzt.
    _setRowTextures[#_setRowTextures + 1] = btn

    btn:SetScript("OnEnter", function(self)
        if not self.isSelected then self.hl:Show() end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local loadout = LO()[self.setName]
        if loadout then
            GameTooltip:AddLine(self.setName, 1, 0.82, 0)
            GameTooltip:AddLine(string.format("%d %s", countSlots(loadout), L["items"]),
                0.6, 0.6, 0.6)

            -- Zustand im Klartext, und bei fehlenden Teilen auch welche.
            local st = self.statusInfo
            if st then
                GameTooltip:AddLine(" ")
                if st.state == "equipped" then
                    GameTooltip:AddLine(L["Currently equipped"], 0.2, 0.9, 0.25)
                elseif st.state == "missing" then
                    GameTooltip:AddLine(L["Some items are not on this character"], 0.95, 0.25, 0.2)
                else
                    GameTooltip:AddLine(L["Ready to equip"], 1, 0.65, 0.1)
                end

                local function listPart(entries, label, r, g, b)
                    if #entries == 0 then return end
                    GameTooltip:AddLine(label, r, g, b)
                    for _, e in ipairs(entries) do
                        GameTooltip:AddLine("   " .. e.name, 0.85, 0.85, 0.85)
                    end
                end
                -- Angelegtes nicht aufzaehlen - das sieht man am Charakter.
                listPart(st.inBags,  L["In your bags:"],   0.7, 0.9, 0.7)
                listPart(st.inBank,  L["In the bank:"],    1.0, 0.82, 0.1)
                listPart(st.missing, L["Not found:"],      0.95, 0.4, 0.35)
            end

            -- Nur nennen, was das Set wirklich anfasst.
            local visLines = {}
            for _, f in ipairs(VISIBILITY_FIELDS) do
                if loadout[f.key] ~= nil then
                    visLines[#visLines + 1] = visibilityText(loadout, f)
                end
            end
            if #visLines > 0 then
                GameTooltip:AddLine(" ")
                for _, line in ipairs(visLines) do
                    GameTooltip:AddLine(line, 0.85, 0.85, 0.85)
                end
            end

            GameTooltip:AddLine(" ")
            local key = ns.GetSetKeybind and ns:GetSetKeybind(self.setName)
            if key then
                GameTooltip:AddLine(string.format(L["Key: %s"], ns:KeybindText(key)),
                    1, 0.82, 0)
            end
            GameTooltip:AddLine(L["Left-click: select"], 1, 1, 1)
            GameTooltip:AddLine(L["Double-click / Right-click menu: equip"], 0.7, 0.7, 0.7)
            GameTooltip:AddLine(L["Drag: reorder"], 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self.hl:Hide()
        GameTooltip:Hide()
    end)

    -- Ziehen sortiert um. Ein Klick, der aus einem Ziehen hervorgeht,
    -- darf weder auswaehlen noch als Doppelklick anlegen.
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", startSetDrag)
    btn:SetScript("OnDragStop", function(self)
        self._dragEnded = GetTime()
        stopSetDrag(self)
    end)
    btn:SetScript("OnHide", function(self)
        if _drag and _drag.name == self.setName then stopSetDrag(self, true) end
    end)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if self._dragEnded and (GetTime() - self._dragEnded) < 0.1 then return end
        if button == "RightButton" then
            local setName = self.setName
            local menu = {
                { title = true, text = setName },
                { text = L["Equip"], func = function() equipLoadout(setName) end },
                { text = L["Overwrite"], func = function()
                    overwriteLoadout(setName)
                    refreshSidebar()
                end },
                { text = L["Change icon..."], func = function()
                    showIconPicker(setName, self)
                end },
                { text = L["Rename..."], func = function()
                    promptRename(setName)
                end },
            }
            -- Direkt unter "Anlegen", und nur solange die Bank offen ist -
            -- sonst gibt es kein Ziel.
            if bankIsOpen() then
                table.insert(menu, 3, { text = L["Put in bank"], func = function()
                    depositLoadout(setName)
                end })
            end

            -- Helm/Umhang: der Eintrag zeigt den Zustand, ein Klick schaltet
            -- weiter. Das Menue schliesst danach; die Leiste wird neu
            -- gezeichnet, damit der Tooltip gleich stimmt.
            table.insert(menu, { separator = true })
            for _, f in ipairs(VISIBILITY_FIELDS) do
                local field = f
                table.insert(menu, {
                    text = visibilityText(LO()[setName], field),
                    func = function()
                        local lo = LO()[setName]
                        if not lo then return end
                        cycleVisibility(lo, field)
                        refreshSidebar()
                    end,
                })
            end

            -- Verschieben: nur die Richtungen anbieten, in die es noch geht.
            local order = sortedLoadoutNames()
            local pos
            for i, n in ipairs(order) do
                if n == setName then pos = i; break end
            end
            if pos and #order > 1 then
                table.insert(menu, { separator = true })
                if pos > 1 then
                    table.insert(menu, { text = L["Move up"], func = function()
                        if moveLoadout(setName, -1) then refreshSidebar() end
                    end })
                end
                if pos < #order then
                    table.insert(menu, { text = L["Move down"], func = function()
                        if moveLoadout(setName, 1) then refreshSidebar() end
                    end })
                end
            end

            -- Taste: belegen steht immer da, loeschen nur, wenn es etwas
            -- zu loeschen gibt - und nennt gleich die betroffene Taste.
            local boundKey = ns.GetSetKeybind and ns:GetSetKeybind(setName)
            table.insert(menu, { text = L["Set key..."], func = function()
                ns:PromptSetKeybind(setName)
            end })
            if boundKey then
                table.insert(menu, {
                    text = string.format(L["Clear key (%s)"], ns:KeybindText(boundKey)),
                    func = function()
                        ns:ClearSetKeybind(setName)
                        refreshSidebar()
                    end,
                })
            end

            -- Das Set auf den Mauszeiger legen; der naechste Klick auf einen
            -- Aktionsplatz setzt es dort ab. Auf Forever Blizzards Kopie,
            -- sonst ein Makro (siehe SetMacros.lua).
            if ns.PlaceSetOnActionBar then
                table.insert(menu, { text = L["Place on action bar"], func = function()
                    ns:PlaceSetOnActionBar(setName)
                end })
            end

            -- Spec-binding entries — only when dual spec is active
            if getNumSpecGroups() >= 2 then
                table.insert(menu, { separator = true })
                for g = 1, getNumSpecGroups() do
                    local group = g
                    table.insert(menu, {
                        text    = string.format(L["Bind to %s"], getSpecGroupLabel(group)),
                        checked = function() return specMap() and specMap()[setName] == group end,
                        func    = function()
                            if specMap()[setName] == group then
                                -- toggle off
                                specMap()[setName] = nil
                                ns:Print(string.format(L["'%s' unbound from spec."], setName))
                            else
                                -- 1:1 — clear any other set on this group
                                for other, gi in pairs(specMap()) do
                                    if gi == group and other ~= setName then specMap()[other] = nil end
                                end
                                specMap()[setName] = group
                                ns:Print(string.format(L["'%s' bound to %s."], setName, getSpecGroupLabel(group)))
                            end
                        end,
                    })
                end
            end

            table.insert(menu, { separator = true })
            table.insert(menu, { text = L["Delete"], func = function()
                if mod.db.confirmDelete then
                    local dlg = StaticPopup_Show("VGS_GEARSET_DELETE", setName)
                    if dlg then dlg.data = setName end
                else
                    deleteLoadout(setName)
                    refreshSidebar()
                end
            end })

            ns:ShowPopupMenu(menu, self)
        else
            -- Detect double-click via timestamp
            local now = GetTime()
            if self._lastClick and (now - self._lastClick) < 0.35 then
                equipLoadout(self.setName)
                self._lastClick = 0
            else
                sidebarSelected = self.setName
                self._lastClick = now
                refreshSidebar()
            end
        end
    end)

    sidebarSetButtons[index] = btn
    return btn
end

-- =========================================================
-- Expanded item-row (grid of item icons under a set when expanded)
-- =========================================================
local ITEM_COLS = 6
local ITEM_SIZE = 26
local ITEM_PAD  = 3

local function getItemButton(row, idx)
    local b = row.items[idx]
    if b then return b end
    b = CreateFrame("Button", nil, row)
    b:SetSize(ITEM_SIZE, ITEM_SIZE)
    b.iconTex = b:CreateTexture(nil, "ARTWORK")
    b.iconTex:SetAllPoints(b)
    b.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.iconBorder = b:CreateTexture(nil, "OVERLAY")
    b.iconBorder:SetAllPoints(b)
    b.iconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.iconBorder:SetBlendMode("ADD")
    b.iconBorder:Hide()
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.link then
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
        else
            local slotName = SLOT_NAMES[self.targetSlot] or ("Slot " .. tostring(self.targetSlot))
            GameTooltip:AddLine(string.format(L["Empty: %s"], slotName), 1, 0.82, 0)
            GameTooltip:AddLine(L["Left-click to pick an item from your bags"], 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
        self.iconBorder:Show()
    end)
    b:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self.iconBorder:Hide()
    end)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            -- Quick-remove
            if self.loadoutName and self.targetSlot and LO()[self.loadoutName] then
                LO()[self.loadoutName].slots[self.targetSlot] = nil
                refreshSidebar()
            end
        else
            -- Left-click → bag-item picker for this slot
            if self.loadoutName and self.targetSlot then
                showSlotReplacePicker(self.loadoutName, self.targetSlot, self)
            end
        end
    end)
    row.items[idx] = b
    return b
end

local function getItemRow(parent, index)
    local row = sidebarItemRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, parent)
    row.items = {}
    sidebarItemRows[index] = row
    return row
end

-- Default empty-slot placeholder texture
local EMPTY_SLOT_ICON = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function renderItemRow(row, loadoutName)
    local loadout = LO() and LO()[loadoutName]
    if not loadout then
        row:SetHeight(0)
        return
    end

    -- Hide leftover item buttons
    for _, b in ipairs(row.items) do b:Hide() end

    -- Build display order from slotMask (intended slots) — fall back to slot keys for old data
    local displaySlots = loadout.slotMask
    if not displaySlots or #displaySlots == 0 then
        displaySlots = {}
        for slot in pairs(loadout.slots or {}) do
            table.insert(displaySlots, slot)
        end
    end
    -- Sorted copy so display order is stable
    local sortedSlots = {}
    for _, s in ipairs(displaySlots) do table.insert(sortedSlots, s) end
    table.sort(sortedSlots)

    -- Spaltenzahl aus der tatsaechlichen Zeilenbreite statt fest sechs.
    -- Im Classic-Stil ist die Liste schmaler (breiterer Rahmen plus
    -- Scrollbalken); sechs feste Spalten ragten dort ueber die Zeile
    -- hinaus, und der Scrollbereich schneidet Ueberstehendes jetzt
    -- wirklich ab - die letzte Spalte war halb weg. Setzt voraus, dass
    -- die Zeile beim Rendern bereits verankert ist (macht refreshSidebar).
    -- Die Zeile ist genau so breit wie das Raster (dafuer sorgt
    -- _layoutSidebarButtons). Frame-Breiten sind Gleitkommazahlen, und ein
    -- Rundungsrest von einem Tausendstel darf die letzte Spalte nicht
    -- kosten - daher die halbe Pixel Toleranz.
    local cols = ITEM_COLS
    local w = row:GetWidth() or 0
    if w > 0 then
        cols = math.max(1, math.min(ITEM_COLS,
            math.floor((w + ITEM_PAD + 0.5) / (ITEM_SIZE + ITEM_PAD))))
    end

    for i, slot in ipairs(sortedSlots) do
        local b = getItemButton(row, i)
        local link = loadout.slots and loadout.slots[slot]
        b.loadoutName = loadoutName
        b.targetSlot  = slot
        b.link        = link

        if link then
            local icon
            if GetItemInfoInstant then
                local _, _, _, _, ic = GetItemInfoInstant(link)
                icon = ic
            end
            b.iconTex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            b.iconTex:SetVertexColor(1, 1, 1)
        else
            -- Empty slot: show placeholder + dim color so it reads as "click to fill"
            b.iconTex:SetTexture(EMPTY_SLOT_ICON)
            b.iconTex:SetVertexColor(0.6, 0.6, 0.6)
        end

        local col = (i - 1) % cols
        local rowIdx = math.floor((i - 1) / cols)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", row, "TOPLEFT",
            col * (ITEM_SIZE + ITEM_PAD),
            -(rowIdx * (ITEM_SIZE + ITEM_PAD)))
        b:Show()
    end

    local rows = math.max(1, math.ceil(#sortedSlots / cols))
    row:SetHeight(rows * (ITEM_SIZE + ITEM_PAD) + 2)
end

refreshSidebar = function()
    if not sidebar then return end

    -- Validate selection / expansion
    if sidebarSelected and not (LO() and LO()[sidebarSelected]) then
        sidebarSelected = nil
    end
    if sidebarExpanded and not (LO() and LO()[sidebarExpanded]) then
        sidebarExpanded = nil
    end

    -- Hide leftover buttons + item rows.
    -- Der Item-Row-Pool ist nach Set-Index belegt und damit loechrig: wer
    -- zuerst Set 3 aufklappt, hat nur [3] darin. ipairs wuerde bei der Luecke
    -- auf Index 1 sofort abbrechen und die Zeile nie verstecken - das Set
    -- liesse sich dann nicht mehr zuklappen. Also pairs.
    for _, b in ipairs(sidebarSetButtons) do b:Hide() end
    for _, r in pairs(sidebarItemRows)    do r:Hide() end

    local names = sortedLoadoutNames()
    if not sidebarSelected and #names > 0 then sidebarSelected = names[1] end

    -- Die Zeilen liegen im Scroll-Kind, nicht in der Leiste selbst. Der
    -- Scrollbereich ist bereits zwischen Kopf- und Fussknopf eingepasst,
    -- deshalb faengt die Liste hier bei 0 an und braucht keinen Rand mehr.
    local list = sidebar.list
    if not list then return end

    local y = 0
    for i, name in ipairs(names) do
        local btn = createSetRow(list, i)
        btn.setName = name
        btn.icon:SetTexture(getSetIcon(name))

        -- Statusmarker hinter dem Namen, in absteigender Dringlichkeit:
        -- rot fuer nicht auffindbar, orange fuer Bank, gruen nur wenn
        -- wirklich alles getragen wird.
        local st = getSetStatus(name)
        btn.statusInfo = st
        local marker = ""
        if st then
            if st.state == "missing" then
                marker = " |cffff5555\226\128\162|r"
            elseif #st.inBank > 0 then
                marker = " |cffff9933\226\128\162|r"
            elseif st.state == "equipped" then
                marker = " |cff33ff55\226\128\162|r"
            end
        end
        btn.text:SetText(name .. marker)
        btn.isSelected = (name == sidebarSelected)
        if btn.isSelected then
            btn.selection:Show()
            btn.text:SetTextColor(1, 0.82, 0)
        else
            btn.selection:Hide()
            btn.text:SetTextColor(1, 1, 1)
        end
        -- Expand button icon: up-arrow when expanded (collapse), down-arrow when collapsed
        if sidebarExpanded == name then
            btn.expand.icon:SetTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
        else
            btn.expand.icon:SetTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Up")
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT",  list, "TOPLEFT",  0, y)
        btn:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, y)
        btn:Show()
        y = y - 33

        -- If expanded, render the item icons below this row.
        -- ERST verankern, DANN rendern: renderItemRow liest die Zeilenbreite,
        -- um die Spaltenzahl zu bestimmen - vor dem Verankern waere sie 0.
        if sidebarExpanded == name then
            local row = getItemRow(list, i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",  list, "TOPLEFT",  2, y)
            row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -2, y)
            renderItemRow(row, name)
            row:Show()
            y = y - row:GetHeight() - 4
        end
    end

    -- Scrollhoehe erst NACH dem Auslegen setzen: aufgeklappte Sets aendern
    -- die Gesamthoehe, und ein zu weit gescrollter Bereich muss zurueck.
    if sidebar.updateScroll then sidebar.updateScroll(-y) end

    if #names == 0 then
        if not sidebar.emptyText then
            sidebar.emptyText = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sidebar.emptyText:SetPoint("TOP", sidebar, "TOP", 0, -48)
            sidebar.emptyText:SetTextColor(0.6, 0.6, 0.6)
            sidebar.emptyText:SetText(L["No gear sets saved yet."])
        end
        sidebar.emptyText:Show()
    elseif sidebar.emptyText then
        sidebar.emptyText:Hide()
    end

    -- Enable/disable action buttons
    if sidebar.equipBtn then
        if sidebarSelected then
            sidebar.equipBtn:Enable()
            sidebar.saveBtn:Enable()
        else
            sidebar.equipBtn:Disable()
            sidebar.saveBtn:Disable()
        end
    end
end

-- =========================================================
-- Fremde Statistikspalte am Charakterfenster
--
-- Ein verbreitetes Zusatzfenster haengt eine eigene Werteliste rechts an
-- das Charakterfenster - genau an die Stelle, an der auch unsere Leiste
-- sitzt. Ohne Ruecksicht darauf lagen beide uebereinander.
--
-- Ist diese Spalte da und aufgeklappt, ruecken wir um ihre volle Breite
-- (Inhalt plus Zierrand) nach rechts und haengen uns damit aussen an sie
-- an. Fehlt sie oder ist sie eingeklappt, ist der Versatz 0 und alles
-- bleibt wie bisher. Gemessen wird zur Laufzeit, weil die Spalte je nach
-- Scrollbalken unterschiedlich breit endet.
-- =========================================================
-- Schmalste zulaessige Leiste. Reicht das Symbolraster eines aufgeklappten
-- Sets nicht hinein, waechst die Leiste darueber hinaus (siehe
-- _layoutSidebarButtons).
local SIDEBAR_MIN_WIDTH = 190

local STATS_COLUMN_WIDTH    = 192  -- Rueckfallbreite, falls sich nichts messen laesst
local STATS_COLUMN_GAP      = 12   -- Zierrand rechts der Spalte
local STATS_COLUMN_SCROLL_W = 16   -- Rueckfallbreite ihres Scrollbalkens

local function statsColumnShift()
    local col = _G.DCS_StatScrollFrame
    if not (col and col.IsShown and col:IsShown()) then return 0 end
    local w = col:GetWidth()
    if not w or w <= 0 then w = STATS_COLUMN_WIDTH end
    -- Der Frame der Spalte endet vor ihrem sichtbaren Rahmen; die Luecke
    -- gleicht das aus und laesst sich nachstellen, weil der Ueberstand
    -- vom Rahmenbild abhaengt und sich nicht sauber messen laesst.
    local gap = (mod.db and mod.db.sidebarStatsGap) or STATS_COLUMN_GAP
    -- Ist ihr Scrollbalken eingeblendet, sitzt er noch daneben.
    local bar = col.ScrollBar
    if bar and bar:IsShown() then
        local bw = bar:GetWidth()
        gap = gap + ((bw and bw > 0) and bw or STATS_COLUMN_SCROLL_W)
    end
    return w + gap
end

-- Die Spalte laesst sich im Charakterfenster ein- und ausklappen. Ein
-- einmaliger Hook auf ihr Zeigen/Verstecken schiebt die Leiste dann live
-- mit, statt sie bis zum naechsten Oeffnen falsch stehen zu lassen.
local _statsColumnHooked = false
local function hookStatsColumn(reanchor)
    if _statsColumnHooked then return end
    local col = _G.DCS_StatScrollFrame
    if not (col and col.HookScript) then return end
    _statsColumnHooked = true
    col:HookScript("OnShow", reanchor)
    col:HookScript("OnHide", reanchor)
end

-- Forever haengt die Reiter des Charakterfensters (Charakter, Ruf,
-- Fertigkeiten ...) senkrecht an seine RECHTE Kante - genau dorthin, wo
-- die Leiste sitzt. Gemessen wird, wie weit der breiteste sichtbare
-- Reiter ueber das Fenster hinausragt; um so viel rueckt die Leiste nach
-- rechts. Ohne diese Reiter (Classic-Clients) ist der Versatz 0.
local function readable(v)
    return type(v) == "number" and not (issecretvalue and issecretvalue(v))
end

local function sideTabsShift()
    local cf   = _G.CharacterFrame
    local host = cf and cf.ModeTabs
    if not (host and host.IsShown and host:IsShown() and host.Tabs) then return 0 end
    local cfRight = cf:GetRight()
    if not readable(cfRight) then return 0 end
    local shift = 0
    for _, tab in ipairs(host.Tabs) do
        if tab.IsShown and tab:IsShown() then
            local r = tab:GetRight()
            if readable(r) and r - cfRight > shift then shift = r - cfRight end
        end
    end
    return shift
end

local function createSidebar()
    if sidebar then return sidebar end
    if not CharacterFrame then return end

    sidebar = CreateFrame("Frame", "VGS_GearSetsSidebar", CharacterFrame,
        BackdropTemplateMixin and "BackdropTemplate")
    sidebar:SetWidth(SIDEBAR_MIN_WIDTH)
    sidebar:SetFrameStrata("HIGH")
    sidebar:Hide()

    -- Anchor BOTH corners to CharacterFrame. This makes the sidebar height
    -- track the character window dynamically and exactly — whatever the real
    -- height is (even if another addon resizes CharacterFrame), top and bottom
    -- always line up. No GetHeight() snapshot that can be measured at the wrong
    -- time. The user-tunable offsets compensate if the frame bounds differ from
    -- the visible backdrop on a given client.
    local anchorToCharacterFrame
    anchorToCharacterFrame = function()
        if not sidebar or not CharacterFrame then return end
        hookStatsColumn(anchorToCharacterFrame)
        local pos    = mod.db and mod.db.sidebarPos
        local px     = (pos and pos.x) or 0   -- edit-mode drag offset (x)
        local py     = (pos and pos.y) or 0   -- edit-mode drag offset (y)
        local topOff = ((mod.db and mod.db.sidebarTopOffset)    or 0) + py
        local botOff = ((mod.db and mod.db.sidebarBottomOffset) or 0) + py
        sidebar:ClearAllPoints()
        local xOff = ((mod.db and mod.db.sidebarXOffset) or 0) + px
                     + statsColumnShift() + sideTabsShift()
                     + ns:WindowArtReach()
        sidebar:SetPoint("TOPLEFT",    CharacterFrame, "TOPRIGHT", xOff, topOff)
        sidebar:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMRIGHT", xOff, botOff)
    end
    anchorToCharacterFrame()
    sidebar._reanchor = anchorToCharacterFrame
    mod._reanchorSidebar = anchorToCharacterFrame
    -- Fuer den Stilwechsel: die Zeilen muessen mit neuem Innenabstand
    -- neu gesetzt werden.
    mod._refreshSidebar = refreshSidebar

    -- Debug: print real top/bottom/height of CharacterFrame vs the sidebar
    mod._debugSizes = function()
        local function dump(label, f)
            if not f then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: |cffff5555nil|r", label))
                return
            end
            local top    = f.GetTop    and f:GetTop()
            local bottom = f.GetBottom and f:GetBottom()
            local height = f.GetHeight and f:GetHeight()
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "  %s: top=%s bottom=%s height=%s",
                label,
                top    and string.format("%.0f", top)    or "?",
                bottom and string.format("%.0f", bottom) or "?",
                height and string.format("%.0f", height) or "?"))
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff9b6cff[Gear Sets size debug]|r")
        dump("CharacterFrame",      _G.CharacterFrame)
        dump("CharacterFrameInset", _G.CharacterFrameInset)
        dump("PaperDollFrame",      _G.PaperDollFrame)
        dump("Sidebar",             sidebar)
        dump("StatsColumn",         _G.DCS_StatScrollFrame)
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  Offsets: top=%d bottom=%d x=%d statsColumn=%d",
            mod.db.sidebarTopOffset or 0, mod.db.sidebarBottomOffset or 0,
            mod.db.sidebarXOffset or 0, statsColumnShift()))
    end

    ns.UI:SkinFrame(sidebar, "sidebar")

    -- =========================================================
    -- Scrollbereich fuer die Set-Liste
    --
    -- Vorher lagen die Zeilen direkt in der Leiste und wurden von nichts
    -- begrenzt: ab etwa neun Sets - mit einem aufgeklappten Set frueher -
    -- liefen sie unter den "Neues Set"-Knopf und aus dem Rahmen heraus.
    -- Der ScrollFrame schneidet sein Kind am Rand ab, deshalb bleibt jetzt
    -- alles zwischen Kopf- und Fussknopf.
    --
    -- Kein UIPanelScrollFrameTemplate: dessen Blizzard-Leiste ist fuer 190
    -- Pixel Breite zu breit und passt in keinen der beiden Stile. Stattdessen
    -- Mausrad plus ein schmaler Balken, der nur erscheint, wenn es wirklich
    -- etwas zu scrollen gibt.
    -- =========================================================
    local SCROLLBAR_W = 4
    local ROW_STEP    = 33   -- eine Set-Zeile pro Mausrad-Rastung

    local scroll = CreateFrame("ScrollFrame", nil, sidebar)
    scroll:EnableMouseWheel(true)

    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(1, 1)
    scroll:SetScrollChild(list)

    -- Balken haengt neben dem Scrollbereich, nicht darin - sonst wuerde er
    -- mitscrollen und am Rand abgeschnitten.
    local sbar = CreateFrame("Frame", nil, sidebar)
    sbar:SetWidth(SCROLLBAR_W)
    sbar:Hide()
    local sbarTrack = sbar:CreateTexture(nil, "BACKGROUND")
    sbarTrack:SetAllPoints(sbar)
    sbarTrack:SetColorTexture(0, 0, 0, 0.25)
    local sbarThumb = sbar:CreateTexture(nil, "ARTWORK")
    sbarThumb:SetWidth(SCROLLBAR_W)
    sbarThumb:SetPoint("TOP", sbar, "TOP", 0, 0)

    sidebar.scroll, sidebar.list, sidebar.scrollBar = scroll, list, sbar

    -- Groesse und Lage des Griffs aus Sichtfenster, Inhalt und Position.
    local function updateThumb()
        local viewH   = scroll:GetHeight() or 0
        local contentH = scroll._contentH or 0
        local maxS    = scroll._maxScroll or 0
        if maxS <= 0 or viewH <= 0 or contentH <= 0 then return end
        -- Mindestgriff 16 px, aber nie hoeher als das Sichtfenster: sonst
        -- wuerde der Griff bei einer sehr kurzen Leiste oben herauslaufen.
        local thumbH = math.min(viewH, math.max(16, viewH * (viewH / contentH)))
        local frac   = scroll:GetVerticalScroll() / maxS
        sbarThumb:SetHeight(thumbH)
        sbarThumb:ClearAllPoints()
        sbarThumb:SetPoint("TOP", sbar, "TOP", 0, -(frac * (viewH - thumbH)))
    end

    -- Von refreshSidebar gerufen, sobald die Gesamthoehe feststeht.
    sidebar.updateScroll = function(contentH)
        local viewH = scroll:GetHeight() or 0
        -- Beim allerersten Aufruf steht die Hoehe noch nicht fest (das
        -- Charakterfenster war nie offen). Dann nichts erzwingen - der
        -- naechste Aufruf beim Aufklappen liefert echte Werte.
        if viewH <= 0 then return end

        local maxS = math.max(0, contentH - viewH)
        scroll._contentH  = contentH
        scroll._maxScroll = maxS
        -- Das Kind nie kleiner als das Sichtfenster: sonst rutscht der
        -- Inhalt beim Scrollen ins Leere.
        list:SetHeight(math.max(contentH, viewH))
        if scroll:GetVerticalScroll() > maxS then scroll:SetVerticalScroll(maxS) end

        sbarThumb:SetColorTexture(ns:AccentColor())
        sbar:SetShown(maxS > 0)
        updateThumb()
    end

    scroll:SetScript("OnVerticalScroll", updateThumb)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxS = self._maxScroll or 0
        if maxS <= 0 then return end
        local new = self:GetVerticalScroll() - delta * ROW_STEP
        if new < 0 then new = 0 elseif new > maxS then new = maxS end
        self:SetVerticalScroll(new)
    end)

    -- Action buttons (top row)
    --
    -- Ueber ns.UI:CreateButton, nicht direkt aus dem Blizzard-Template:
    -- nur so kennen die drei Knoepfe beide Stile. Direkt gebaut trugen sie
    -- Blizzards Grafik auch dann noch, wenn alles andere schon modern war.
    local equipBtn = ns.UI:CreateButton(sidebar, L["Equip"], 100, 22)
    equipBtn:SetScript("OnClick", function()
        if sidebarSelected then equipLoadout(sidebarSelected) end
    end)
    sidebar.equipBtn = equipBtn

    local saveBtn = ns.UI:CreateButton(sidebar, L["Save"], 100, 22)
    saveBtn:SetScript("OnClick", function()
        if sidebarSelected then
            overwriteLoadout(sidebarSelected)
            refreshSidebar()
        end
    end)
    sidebar.saveBtn = saveBtn

    -- "Neues Set" unten: eigener Knopf statt ns.UI:CreateButton - dunkle
    -- Flaeche, duenner abgerundeter Goldrand, gruenes Plus und gruene
    -- Schrift, wie Blizzards "Neues Set" im Ausruestungsmanager. Die
    -- Stilknoepfe wuerden Schrift und Grund beim Ueberfahren umfaerben.
    local newBtn = CreateFrame("Button", nil, sidebar,
        BackdropTemplateMixin and "BackdropTemplate")
    newBtn:SetHeight(24)
    if newBtn.SetBackdrop then
        newBtn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
    end
    newBtn.icon = newBtn:CreateTexture(nil, "ARTWORK")
    newBtn.icon:SetTexture("Interface\\AddOns\\VuloGearSets\\Media\\Icons\\plus")
    newBtn.icon:SetSize(15, 15)
    newBtn.icon:SetPoint("LEFT", newBtn, "LEFT", 9, 0)
    newBtn.icon:SetVertexColor(0.15, 0.85, 0.15)
    newBtn.label = newBtn:CreateFontString(nil, "OVERLAY")
    ns.UI.Font(newBtn.label, 12)
    newBtn.label:SetPoint("LEFT", newBtn.icon, "RIGHT", 6, 0)
    newBtn.label:SetPoint("RIGHT", newBtn, "RIGHT", -8, 0)
    newBtn.label:SetJustifyH("LEFT")
    newBtn.label:SetTextColor(0.25, 1, 0.25)

    -- Rand im modernen Stil in dessen Randfarbe, sonst Gold; beim
    -- Ueberfahren heller.
    local function paintNewBtn(hovered)
        if not newBtn.SetBackdropColor then return end
        local shade = hovered and 0.10 or 0.03
        newBtn:SetBackdropColor(shade, shade, shade, 0.95)
        if ns:GetStyle() == "modern" then
            local b = hovered and ns.COLORS.accent or ns.COLORS.border
            newBtn:SetBackdropBorderColor(b.r, b.g, b.b, 1)
        elseif hovered then
            newBtn:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            newBtn:SetBackdropBorderColor(0.78, 0.62, 0.28, 1)
        end
    end
    paintNewBtn(false)
    newBtn:SetScript("OnEnter", function() paintNewBtn(true) end)
    newBtn:SetScript("OnLeave", function() paintNewBtn(false) end)
    newBtn.label:SetText(L["New Set"])
    newBtn:SetScript("OnClick", function() promptSaveWithSlots(nil) end)

    -- Auf Forever gibt es das Original: Blizzards "Neues Set"-Knopf aus dem
    -- Ausruestungsmanager (Vorlage samt eigener Beschriftung) mit dem
    -- gruenen Plus. Er ersetzt den nachgebauten, solange die Leiste die
    -- Ausruestungsmanager-Art traegt (ns:UsesCharacterPaneArt).
    local blizzNewBtn
    if ns.isForever then
        local ok, b = pcall(CreateFrame, "Button", nil, sidebar,
            "PaperDollTertiaryButtonTemplate")
        if ok and b then
            blizzNewBtn = b
            blizzNewBtn:SetHeight(34)
            local plus = blizzNewBtn:CreateTexture(nil, "ARTWORK")
            plus:SetAtlas("UI-Character-Info-Icon-Add", true)
            plus:SetPoint("LEFT", blizzNewBtn, "LEFT", 13, 0)
            blizzNewBtn:SetScript("OnClick", function() promptSaveWithSlots(nil) end)
            blizzNewBtn:Hide()
        end
    end

    -- Blizzards Doppellinie unter der Liste, ebenfalls nur in dieser Art.
    local scrollLine = sidebar:CreateTexture(nil, "BORDER")
    if ns.isForever then scrollLine:SetAtlas("UI-Character-Info-ScrollLine") end
    scrollLine:SetHeight(7)
    scrollLine:Hide()

    -- Welcher "Neues Set"-Knopf gerade gilt.
    local function activeNewBtn()
        if blizzNewBtn and ns:UsesCharacterPaneArt() then return blizzNewBtn end
        return newBtn
    end

    ns:OnStyleChanged(function() paintNewBtn(false) end)

    -- Die drei Knoepfe spannen sich zwischen den Raendern auf, statt eine
    -- feste Breite zu haben - so halten sie in beiden Stilen denselben
    -- Abstand zum Rahmen. Beim Stilwechsel erneut aufgerufen.
    mod._layoutSidebarButtons = function()
        local pad = 4 + ns:FrameInset()
        local gap = 4

        -- Rechts bleibt Platz fuer den Scrollbalken, damit er nicht ueber
        -- dem Aufklapppfeil der Zeilen liegt.
        local rightEdge = pad + SCROLLBAR_W + 2

        -- Die Breite richtet sich nach dem Symbolraster eines aufgeklappten
        -- Sets: alle ITEM_COLS Spalten muessen ganz hineinpassen. Der
        -- Classic-Rahmen ist deutlich breiter als der schlichte, deshalb
        -- blieben bei fester Breite nur fuenf Spalten uebrig und das
        -- letzte Symbol jeder Zeile rutschte in die naechste.
        -- Die 4 sind der Innenabstand, mit dem refreshSidebar die
        -- Symbolzeile in den Scrollbereich setzt (je 2 links und rechts).
        local gridW = ITEM_COLS * (ITEM_SIZE + ITEM_PAD) - ITEM_PAD
        sidebar:SetWidth(math.max(SIDEBAR_MIN_WIDTH,
            gridW + 4 + pad + rightEdge))

        local half = (sidebar:GetWidth() - pad * 2 - gap) / 2

        equipBtn:ClearAllPoints()
        equipBtn:SetWidth(half)
        equipBtn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", pad, -pad)

        saveBtn:ClearAllPoints()
        saveBtn:SetWidth(half)
        saveBtn:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -pad, -pad)

        -- Nur einer der beiden "Neues Set"-Knoepfe ist sichtbar.
        local active = activeNewBtn()
        newBtn:SetShown(active == newBtn)
        if blizzNewBtn then blizzNewBtn:SetShown(active == blizzNewBtn) end
        active:ClearAllPoints()
        active:SetPoint("BOTTOMLEFT",  sidebar, "BOTTOMLEFT",  pad, pad)
        active:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -pad, pad)
        local newH = active:GetHeight() or 24

        -- Der Scrollbereich spannt sich zwischen die beiden Knopfreihen.
        local topEdge = pad + 22 + 6                   -- unter Anlegen/Speichern
        local botEdge = pad + newH + 6                 -- ueber "Neues Set"

        -- Die Doppellinie sitzt in der Luecke ueber "Neues Set".
        scrollLine:ClearAllPoints()
        scrollLine:SetPoint("BOTTOMLEFT",  sidebar, "BOTTOMLEFT",  pad, pad + newH + 1)
        scrollLine:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -pad, pad + newH + 1)
        scrollLine:SetShown(active == blizzNewBtn)

        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT",     sidebar, "TOPLEFT",     pad, -topEdge)
        scroll:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -rightEdge, botEdge)
        -- Das Scroll-Kind braucht eine feste Breite, sonst zeichnet es nichts.
        list:SetWidth(math.max(1, sidebar:GetWidth() - pad - rightEdge))

        sbar:ClearAllPoints()
        sbar:SetPoint("TOPRIGHT",    sidebar, "TOPRIGHT",    -pad, -topEdge)
        sbar:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -pad, botEdge)
    end
    sidebar.newBtn = newBtn
    mod._layoutSidebarButtons()

    -- Edit-mode mover: drag the sidebar to an offset from the character window.
    -- It STAYS anchored to CharacterFrame (keeps tracking the window height and
    -- shows/hides with it), so instead of the default screen-centre drag we store
    -- only an x/y offset and re-anchor live while dragging. Arrow keys + the
    -- right-click popup (incl. reset) work through applyPos = anchorToCharacterFrame.
    -- Die Position haengt am Charakterfenster dieses Charakters und gehoert
    -- deshalb in die Charakter-Datenbank. mod.db.sidebarPos zeigt danach auf
    -- dieselbe Tabelle, damit alle weiteren Zugriffe unveraendert bleiben.
    local charSide = charDB()
    charSide.sidebarPos = charSide.sidebarPos or { x = 0, y = 0 }
    mod.db.sidebarPos = charSide.sidebarPos
    sidebar.mover = ns:CreateMover(sidebar, {
        label    = L["|cffffffffGEAR SETS SIDEBAR|r\n|cffaaaaaaDrag or arrow keys|r"],
        db       = mod.db.sidebarPos,
        width    = 168,
        height   = 44,
        applyPos = anchorToCharacterFrame,
    })
    sidebar.mover:SetFrameLevel((sidebar:GetFrameLevel() or 1) + 20)  -- above the set buttons
    do
        -- Replace the default screen-centre drag with offset tracking so the
        -- two-point anchor (and height tracking) is never broken.
        local mvr = sidebar.mover
        mvr:SetScript("OnDragStart", function(self)
            local cx, cy = GetCursorPosition()
            self._dragX, self._dragY = cx, cy
            self._origX, self._origY = mod.db.sidebarPos.x or 0, mod.db.sidebarPos.y or 0
            self:SetScript("OnUpdate", function()
                local nx, ny = GetCursorPosition()
                local s = UIParent:GetEffectiveScale()
                if s and s > 0 then
                    mod.db.sidebarPos.x = self._origX + (nx - self._dragX) / s
                    mod.db.sidebarPos.y = self._origY + (ny - self._dragY) / s
                    anchorToCharacterFrame()
                end
            end)
        end)
        mvr:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    end

    -- Die Leiste gehoert zum Reiter "Charakter". Auf Ruf, Fertigkeiten oder
    -- PvP hat sie keinen Bezug, deshalb haengt sie an PaperDollFrame - das
    -- ist genau dieser Reiter - und nicht am Charakterfenster insgesamt.
    local function updateVisibility()
        if not (mod._enabled and mod.db and mod.db.sidebarEnabled ~= false) then
            sidebar:Hide()
            return
        end
        local onGearTab = PaperDollFrame and PaperDollFrame:IsShown()
        if CharacterFrame and CharacterFrame:IsShown() and onGearTab then
            sidebar:Show()
            anchorToCharacterFrame()  -- re-sync size in case CharacterFrame changed
            refreshSidebar()
            -- the mover only makes sense while the window is open; sync its state
            if sidebar.mover then
                if ns:IsMoverEditMode() then sidebar.mover:Show() else sidebar.mover:Hide() end
            end
        else
            sidebar:Hide()
        end
    end
    mod._updateSidebarVisibility = updateVisibility

    CharacterFrame:HookScript("OnShow", updateVisibility)
    CharacterFrame:HookScript("OnHide", function() sidebar:Hide() end)
    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", updateVisibility)
        PaperDollFrame:HookScript("OnHide", function() sidebar:Hide() end)
    end

    -- Blizzards Symbolauswahl fuer ein neues Set oeffnet rechts neben dem
    -- Charakterfenster, genau dort, wo die Leiste liegt. Solange sie offen
    -- ist, rutscht die Leiste in deren Schicht und die Auswahl nach oben.
    for _, name in ipairs({ "GearManagerPopupFrame", "GearManagerDialogPopup" }) do
        local popup = _G[name]
        if popup and popup.HookScript then
            popup:HookScript("OnShow", function(self)
                sidebar:SetFrameStrata(self:GetFrameStrata())
                self:Raise()
            end)
            popup:HookScript("OnHide", function()
                sidebar:SetFrameStrata("HIGH")
            end)
        end
    end
    updateVisibility()

    if ns:IsMoverEditMode() then sidebar.mover:Show() end
    return sidebar
end

local function applySidebarVisibility()
    if not sidebar then return end
    -- Entscheidet dieselbe Stelle wie die Frame-Hooks, damit der Reiter
    -- nicht an zwei Orten geprueft wird.
    if mod._updateSidebarVisibility then
        mod._updateSidebarVisibility()
    elseif mod.db.sidebarEnabled == false then
        sidebar:Hide()
    end
end


-- =========================================================
-- Statuspunkte
-- =========================================================
-- Statuspunkte nachziehen, wenn sich Ausruestung oder Taschen aendern.
-- Nur wenn die Leiste sichtbar ist - sonst waere es Arbeit fuer nichts.
--
-- Entprellt: beim Anlegen eines Sets feuert UNIT_INVENTORY_CHANGED einmal
-- pro getauschtem Teil. Ohne Sammelaufruf wuerde die Leiste dann fuer
-- jedes Teil einzeln komplett neu aufgebaut.
--
-- Auf Dateiebene statt in OnEnable, damit An- und Abmelden dieselbe
-- Funktion sehen - ein erneutes OnEnable stapelte sonst immer neue Handler.
local _statusRefreshQueued = false
local function refreshStatusDots()
    if not (sidebar and sidebar:IsShown()) then return end
    if not (C_Timer and C_Timer.After) then
        refreshSidebar()
        return
    end
    if _statusRefreshQueued then return end
    _statusRefreshQueued = true
    C_Timer.After(0.05, function()
        _statusRefreshQueued = false
        if mod._enabled and sidebar and sidebar:IsShown() then
            refreshSidebar()
        end
    end)
end

local function onInventoryChanged(_, unit)
    if unit == "player" or unit == nil then refreshStatusDots() end
end

-- =========================================================
-- Nach Speichern, Loeschen und Umbenennen (aufgerufen aus den Huellen in
-- Sets.lua): Auswahl und Aufklapp-Markierung mitziehen, neu zeichnen.
-- =========================================================
function GS.sidebarAfterSave(name)
    if not sidebar then return end
    -- Derselbe Zuschnitt wie in saveAs, sonst zeigte die Auswahl auf
    -- "Tank " statt auf das gespeicherte "Tank".
    sidebarSelected = name and name:match("^%s*(.-)%s*$")
    refreshSidebar()
end

function GS.sidebarAfterDelete(name)
    if not sidebar then return end
    if sidebarSelected == name then sidebarSelected = nil end
    refreshSidebar()
end

function GS.sidebarAfterRename(oldName, finalName)
    if not sidebar then return end
    if sidebarSelected == oldName then sidebarSelected = finalName end
    -- Auch die Aufklapp-Markierung mitziehen, sonst klappt ein gerade
    -- offenes Set beim Umbenennen kommentarlos zu.
    if sidebarExpanded == oldName then sidebarExpanded = finalName end
    refreshSidebar()
end

-- Fuer OnDisable (Lifecycle.lua).
function GS.hideSidebar()
    if sidebar then sidebar:Hide() end
end

-- Fuer die spaeter geladenen Dateien (siehe Shared.lua).
-- refreshSidebar braucht auch Pickers.lua, das VORHER geladen wird und es
-- deshalb erst zur Laufzeit ueber GS aufruft.
GS.refreshSidebar = refreshSidebar
GS.applySidebarVisibility = applySidebarVisibility
GS.createSidebar          = createSidebar
GS.onInventoryChanged     = onInventoryChanged
GS.refreshStatusDots      = refreshStatusDots
