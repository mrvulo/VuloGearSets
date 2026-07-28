-- =========================================================
-- VuloGearSets / UI / OptionsFrame
-- Ein Fenster, ein Scrollbereich, ein Renderer fuer die
-- deklarative Item-Liste aus mod:GetOptions().
--
-- Unterstuetzte Typen: header, desc, spacer, button, toggle,
-- slider, dropdown, group (layout="row"), section.
-- Setter werden als set(nil, value) gerufen - diese Signatur
-- stammt aus dem Modulcode und darf sich nicht aendern.
-- =========================================================
local _, ns = ...
local UI = ns.UI
local L  = ns.L
local C  = ns.COLORS

local WIDTH, HEIGHT = 460, 560
local PAD           = 16
local CONTENT_W     = WIDTH - PAD * 2 - 20   -- 20px fuer die Scrollleiste

local frame, content
local renderItems   -- vorwaerts deklariert: section/group rufen rekursiv auf

-- =========================================================
-- Tooltip-Helfer
-- =========================================================
local function attachTooltip(widget, text)
    if not text or text == "" then return end
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- =========================================================
-- Ein Renderer je Typ. Signatur immer (parent, item, y, width),
-- Rueckgabe ist die verbrauchte Hoehe in Pixeln.
-- =========================================================
local renderers = {}

renderers.header = function(parent, item, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    UI.Font(fs, 14, "OUTLINE")
    fs:SetPoint("TOPLEFT", PAD, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetText(item.text or "")
    fs:SetTextColor(C.accent.r, C.accent.g, C.accent.b)
    return fs:GetStringHeight() + 8
end

renderers.desc = function(parent, item, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    UI.Font(fs, 11)
    fs:SetPoint("TOPLEFT", PAD, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetText(item.text or "")
    fs:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
    return fs:GetStringHeight() + 6
end

renderers.spacer = function(_, item)
    return item.height or 8
end

renderers.button = function(parent, item, y)
    local b = UI:CreateButton(parent, item.label or "", item.width or 130, 22)
    b:SetPoint("TOPLEFT", PAD, y)
    b:SetOnClick(item.onClick)
    b._tooltip = item.tooltip
    return 26
end

renderers.toggle = function(parent, item, y, width)
    local t = UI:CreateToggle(parent, item.label or "")
    t:SetPoint("TOPLEFT", PAD, y)
    t:SetWidth(width)
    t:SetChecked(item.get and item.get() or false)
    t.OnValueChanged = function(v)
        if item.set then item.set(nil, v) end
    end
    attachTooltip(t, item.tooltip)
    return 26
end

renderers.slider = function(parent, item, y)
    local s = UI:CreateSlider(parent, item.label or "", item.min, item.max, item.step)
    s:SetPoint("TOPLEFT", PAD, y)
    s:SetValue(item.get and item.get() or item.min or 0)
    s.OnValueChanged = function(v)
        if item.set then item.set(nil, v) end
    end
    attachTooltip(s.slider, item.tooltip)
    return 48
end

renderers.dropdown = function(parent, item, y)
    local d = UI:CreateDropdown(parent, item.label or "", item.values)
    d:SetPoint("TOPLEFT", PAD, y)
    d:SetValue(item.get and item.get() or nil)
    d.OnValueChanged = function(v)
        if item.set then item.set(nil, v) end
    end
    d.button._tooltip = item.tooltip
    return 50
end

-- Nebeneinander in einer Zeile, sonst wie eine normale Liste.
renderers.group = function(parent, item, y, width)
    if item.layout ~= "row" then
        return renderItems(parent, item.items or {}, y, width)
    end
    local gap, x, maxH = item.gap or 6, 0, 0
    for _, sub in ipairs(item.items or {}) do
        local w = sub.width or 130
        local b = UI:CreateButton(parent, sub.label or "", w, 22)
        b:SetPoint("TOPLEFT", PAD + x, y)
        b:SetOnClick(sub.onClick)
        b._tooltip = sub.tooltip
        x = x + w + gap
        maxH = math.max(maxH, 26)
    end
    return maxH
end

-- Aufklappbarer Block. Der Zustand wird in item.collapsed zurueckgeschrieben,
-- damit er ein Neuzeichnen ueberlebt.
renderers.section = function(parent, item, y, width)
    local head = CreateFrame("Button", nil, parent)
    head:SetPoint("TOPLEFT", PAD, y)
    head:SetSize(width, 20)

    local fs = head:CreateFontString(nil, "OVERLAY")
    UI.Font(fs, 13, "OUTLINE")
    fs:SetPoint("LEFT")
    fs:SetTextColor(C.accent.r, C.accent.g, C.accent.b)

    local collapsed = item.collapsed and true or false
    fs:SetText((collapsed and "+ " or "- ") .. (item.title or ""))

    head:SetScript("OnClick", function()
        item.collapsed = not collapsed
        ns:RefreshOptions()
    end)

    if collapsed then return 24 end
    return 24 + renderItems(parent, item.items or {}, y - 24, width - 10)
end

-- =========================================================
-- Liste rendern. Gibt die Gesamthoehe zurueck.
-- =========================================================
-- Jedes Element einzeln gekapselt: faellt eines aus (fehlendes Blizzard-Template,
-- kaputter get/set-Callback), wird nur dieses uebersprungen. Ohne die Kapselung
-- reisst der erste Fehler den gesamten Rest der Seite mit.
renderItems = function(parent, items, y, width)
    local used = 0
    for i, item in ipairs(items) do
        local fn = renderers[item.type]
        if not fn then
            ns:Print("|cffff5555Options:|r unbekannter Typ '%s' an Position %d",
                     tostring(item.type), i)
        else
            local ok, result = pcall(fn, parent, item, y - used, width)
            if ok then
                used = used + (tonumber(result) or 0)
            else
                ns:Print("|cffff5555Options:|r '%s' an Position %d fehlgeschlagen: %s",
                         tostring(item.type), i, tostring(result))
                used = used + 20   -- Luecke lassen, damit nichts uebereinander liegt
            end
        end
    end
    return used
end

-- =========================================================
-- Fenster
-- =========================================================
local function createFrame()
    frame = CreateFrame("Frame", "VuloGearSetsOptions", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    UI:CreateBackdrop(frame)
    UI:CreateShadow(frame)
    tinsert(UISpecialFrames, "VuloGearSetsOptions")   -- Escape schliesst

    local title = frame:CreateFontString(nil, "OVERLAY")
    UI.Font(title, 15, "OUTLINE")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(L["Gear Sets"])
    title:SetTextColor(C.accent.r, C.accent.g, C.accent.b)

    local close = UI:CreateButton(frame, "X", 22, 22)
    close:SetPoint("TOPRIGHT", -PAD, -PAD + 2)
    close:SetOnClick(function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "VuloGearSetsOptionsScroll", frame,
                               "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     PAD, -PAD - 30)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 20, PAD)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CONTENT_W, 10)
    scroll:SetScrollChild(content)
    frame.scroll = scroll
end

-- Erzeugt den Inhalt neu. Der alte Scroll-Child wird verworfen, weil sich
-- Sektionen auf- und zuklappen lassen und die Liste dann anders aussieht.
function ns:RefreshOptions()
    if not frame or not frame:IsShown() then return end
    if content then
        content:Hide()
        content:SetParent(nil)
    end
    content = CreateFrame("Frame", nil, frame.scroll)
    content:SetSize(CONTENT_W, 10)
    frame.scroll:SetScrollChild(content)

    local mod = ns.modules and ns.modules.gearsets
    if not (mod and mod.GetOptions) then return end
    local height = renderItems(content, mod:GetOptions(), -PAD, CONTENT_W - PAD * 2)
    content:SetHeight(math.max(height + PAD * 2, 10))
end

function ns:OpenOptions()
    if not frame then createFrame() end
    frame:Show()
    ns:RefreshOptions()
end

function ns:ToggleOptions()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        ns:OpenOptions()
    end
end
