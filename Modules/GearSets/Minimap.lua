-- =========================================================
-- VuloGearSets / Modules / GearSets / Minimap
-- Minimap-Knopf und sein Set-Menue.
-- =========================================================
local _, ns = ...
local L   = ns.L
local GS  = ns.GS
local mod = GS.mod

-- Aus frueher geladenen Dateien (siehe Shared.lua).
local SLOT_GROUPS         = GS.SLOT_GROUPS
local equipLoadout        = GS.equipLoadout
local equipPrevious       = GS.equipPrevious
local hasPreviousGear     = GS.hasPreviousGear
local promptSaveWithSlots = GS.promptSaveWithSlots
local sortedLoadoutNames  = GS.sortedLoadoutNames


-- =========================================================
-- Minimap button
-- =========================================================
local mmBtn

local function updateMinimapPos()
    if not mmBtn then return end
    local angle = (mod.db.minimap and mod.db.minimap.angle) or 45
    local rad = math.rad(angle)
    local r = 80  -- distance from minimap center
    local x = r * math.cos(rad)
    local y = r * math.sin(rad)
    mmBtn:ClearAllPoints()
    mmBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Forward declarations (resolves circular references between popup menu and settings opener)
local openLoadoutsSettings

-- Loadouts dropdown — uses ns:ShowPopupMenu (shared helper, EasyMenu replacement)
local function showLoadoutMenu(anchor)
    local entries = {
        { title = true, text = L["Gear Sets"] },
    }

    local names = sortedLoadoutNames()
    if #names == 0 then
        table.insert(entries, { text = "  " .. L["No gear sets saved yet."], disabled = true })
    else
        for _, name in ipairs(names) do
            local capturedName = name
            table.insert(entries, {
                text = "  " .. name,
                func = function() equipLoadout(capturedName) end,
            })
        end
    end

    table.insert(entries, { separator = true })
    table.insert(entries, { text = L["Back to previous gear"],
        disabled = not hasPreviousGear(), func = equipPrevious })
    table.insert(entries, { separator = true })
    table.insert(entries, { text = L["Save current as new..."], func = function() promptSaveWithSlots(nil) end })
    table.insert(entries, { text = L["Save trinkets only..."],  func = function() promptSaveWithSlots(SLOT_GROUPS.trinkets) end })
    table.insert(entries, { text = L["Save weapons only..."],   func = function() promptSaveWithSlots(SLOT_GROUPS.weapons)  end })
    table.insert(entries, { text = L["Save rings only..."],     func = function() promptSaveWithSlots(SLOT_GROUPS.rings)    end })
    table.insert(entries, { text = L["Save armor only..."],     func = function() promptSaveWithSlots(SLOT_GROUPS.armor)    end })
    table.insert(entries, { separator = true })
    table.insert(entries, { text = L["Settings..."],
        func = function() openLoadoutsSettings() end })

    ns:ShowPopupMenu(entries, anchor)
end

-- Oeffnet die Einstellungen. Im Standalone gibt es genau ein Fenster.
-- Zugewiesen an das weiter oben deklarierte Local.
function openLoadoutsSettings()
    ns:ToggleOptions()
end

local function createMinimapButton()
    if mmBtn then return end
    if not Minimap then return end

    -- LibDBIcon standard layout: 31x31 button, 53x53 border at TOPLEFT (0,0),
    -- icon 17x17 at TOPLEFT(7, -6), background 20x20 at TOPLEFT(7, -5).
    mmBtn = CreateFrame("Button", "VGS_GearSetsMinimapButton", Minimap)
    mmBtn:SetFrameStrata("MEDIUM")
    mmBtn:SetFrameLevel(8)
    mmBtn:SetSize(31, 31)
    -- Kein SetMovable: verschoben wird nicht der Frame, sondern der Winkel
    -- um die Minikarte (siehe OnDragStart weiter unten).
    mmBtn:RegisterForClicks("AnyUp")
    mmBtn:RegisterForDrag("LeftButton")

    -- Background (the dark circle behind the icon)
    local background = mmBtn:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)

    -- Icon: dasselbe Kachel-V wie in der AddOn-Liste
    local icon = mmBtn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\VuloGearSets\\Media\\Icons\\vgs")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- crop default Blizzard icon border

    -- Round border (Blizzard minimap-tracking style) — standard LibDBIcon offset
    local border = mmBtn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", 0, 0)

    -- Hover highlight
    mmBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    -- Drag to reposition around minimap (saved as angle)
    mmBtn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            if not mx then return end
            local sx, sy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale() or 1
            sx, sy = sx / scale, sy / scale
            local angle = math.deg(math.atan2(sy - my, sx - mx))
            mod.db.minimap = mod.db.minimap or {}
            mod.db.minimap.angle = angle
            updateMinimapPos()
        end)
    end)
    mmBtn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    -- Click handlers — Left = quick switcher menu, Right = settings
    mmBtn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            showLoadoutMenu(self)
        elseif button == "RightButton" then
            openLoadoutsSettings()
        end
    end)

    mmBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff9b6cff" .. L["Gear Sets"] .. "|r")
        GameTooltip:AddLine(L["Left-click: switch set"],   1, 1, 1)
        GameTooltip:AddLine(L["Right-click: settings"],    1, 1, 1)
        GameTooltip:AddLine(L["Drag: reposition"],         0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    mmBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    updateMinimapPos()

    if mod.db.minimap and mod.db.minimap.hidden then
        mmBtn:Hide()
    end
end

local function applyMinimapVisibility()
    if not mmBtn then return end
    if mod.db.minimap and mod.db.minimap.hidden then
        mmBtn:Hide()
    else
        mmBtn:Show()
    end
end

-- Fuer OnDisable (Lifecycle.lua).
function GS.hideMinimapButton()
    if mmBtn then mmBtn:Hide() end
end

-- Fuer die spaeter geladenen Dateien (siehe Shared.lua).
GS.applyMinimapVisibility = applyMinimapVisibility
GS.createMinimapButton    = createMinimapButton
