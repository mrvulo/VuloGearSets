-- =========================================================
-- VuloGearSets / Core / PopupMenu
-- Shared popup-menu helper as a replacement for EasyMenu, which is
-- unreliable in Anniversary (often nil → modules that call it crash).
--
-- Usage:
--   ns:ShowPopupMenu(entries, anchorFrame)
--
-- Entry shape:
--   { title     = true,  text = "Header" }              — section header
--   { separator = true }                                — visual divider
--   { text      = "Item", func = function() ... end }   — clickable
--   { text      = "...",  checked = function() return mod.db.x end,
--     func = function() ... end }                       — with checkmark
--   { text      = "...",  disabled = true }             — greyed
-- =========================================================
local _, ns = ...

local _menuFrame
local _menuButtons = {}

local function createMenuFrame()
    if _menuFrame then return _menuFrame end
    _menuFrame = CreateFrame("Frame", "VGS_SharedPopupMenu", UIParent,
        BackdropTemplateMixin and "BackdropTemplate")
    _menuFrame:SetFrameStrata("DIALOG")
    _menuFrame:SetWidth(200)
    _menuFrame:SetHeight(30)
    _menuFrame:Hide()
    _menuFrame:EnableMouse(true)
    _menuFrame:SetClampedToScreen(true)
    -- Menue nutzt den Flaechen-Rahmen: es steht in einem Fenster, nicht daneben.
    if ns.UI and ns.UI.SkinFrame then ns.UI:SkinFrame(_menuFrame, "pane") end
    -- Soft drop shadow (UI helpers exist by the time a menu is first opened)
    if ns.UI and ns.UI.CreateShadow then ns.UI:CreateShadow(_menuFrame) end
    -- ESC closes
    tinsert(UISpecialFrames, "VGS_SharedPopupMenu")

    -- Klick daneben schliesst ebenfalls.
    --
    -- Bewusst KEIN unsichtbarer Faenger ueber dem ganzen Bildschirm: der
    -- wuerde den Klick schlucken, statt ihn durchzulassen, und muesste sich
    -- mit Symbolauswahl und Slot-Picker um die Ebene streiten - beide liegen
    -- in derselben Strata. Stattdessen prueft das Menue selbst, und zwar nur
    -- solange es offen ist; OnUpdate laeuft auf versteckten Frames nicht.
    _menuFrame:SetScript("OnUpdate", function(self)
        local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
        -- Erst scharf schalten, wenn keine Taste mehr gedrueckt ist: geoeffnet
        -- wird aus einem "...Up"-Handler, und ohne das koennte derselbe Klick
        -- das Menue sofort wieder zuschlagen.
        if not down then
            self._armed = true
            return
        end
        if not self._armed then return end
        if self:IsMouseOver() then return end
        -- Druck auf den eigenen Anker NICHT hier behandeln. Dessen OnClick
        -- feuert erst beim Loslassen und klappt das Menue selbst zu; wuerden
        -- wir schon beim Druecken verstecken, saehe OnClick ein geschlossenes
        -- Menue und oeffnete es sofort wieder. Der zweite Klick auf dieselbe
        -- Zeile bliebe damit wirkungslos.
        local a = self._openAnchor
        if type(a) == "table" and a.IsMouseOver and a:IsMouseOver() then return end
        self:Hide()
        self._openAnchor = nil
    end)

    return _menuFrame
end

local function getMenuButton(idx)
    local btn = _menuButtons[idx]
    if btn then return btn end
    btn = CreateFrame("Button", nil, _menuFrame)
    btn:SetHeight(20)

    -- Check indicator (left): small accent square, matches the dropdown widget
    -- Die Farbe setzt ShowPopupMenu, damit ein Stilwechsel auch bereits
    -- erzeugte Knoepfe erreicht - sie werden wiederverwendet.
    btn.check = btn:CreateTexture(nil, "OVERLAY")
    btn.check:SetSize(6, 6)
    btn.check:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btn.check:Hide()

    -- Label
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if ns.UI and ns.UI.Font then ns.UI.Font(btn.text, 11) end
    btn.text:SetPoint("LEFT", btn, "LEFT", 22, 0)
    btn.text:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
    btn.text:SetJustifyH("LEFT")

    -- Hover highlight, Farbe ebenfalls in ShowPopupMenu
    btn.hl = btn:CreateTexture(nil, "BACKGROUND")
    btn.hl:SetAllPoints(btn)
    btn.hl:Hide()

    btn:SetScript("OnEnter", function(self)
        if self._clickable then self.hl:Show() end
    end)
    btn:SetScript("OnLeave", function(self) self.hl:Hide() end)
    _menuButtons[idx] = btn
    return btn
end

function ns:ShowPopupMenu(entries, anchor)
    if type(entries) ~= "table" then return end
    local menu = createMenuFrame()

    -- Hide leftover buttons from a previous menu
    for _, b in ipairs(_menuButtons) do b:Hide() end

    local y, maxTextWidth = -6, 0

    for i, entry in ipairs(entries) do
        local btn = getMenuButton(i)
        btn:Show()
        btn.check:Hide()
        btn._clickable = false
        -- Farben bei jedem Oeffnen setzen: die Knoepfe werden
        -- wiederverwendet und muessen einem Stilwechsel folgen.
        btn.check:SetColorTexture(ns:AccentColor())
        btn.hl:SetColorTexture(ns:HoverColor())

        if entry.separator then
            btn:SetHeight(6)
            btn.text:SetText("")
            btn:EnableMouse(false)
            btn:SetScript("OnClick", nil)
        elseif entry.title then
            btn:SetHeight(20)
            btn.text:SetText(entry.text or "")
            btn.text:SetTextColor(ns:AccentColor())
            btn:EnableMouse(false)
            btn:SetScript("OnClick", nil)
        else
            btn:SetHeight(20)
            btn.text:SetText(entry.text or "")
            if entry.disabled then
                btn.text:SetTextColor(0.5, 0.5, 0.5)
                btn:EnableMouse(false)
                btn:SetScript("OnClick", nil)
            else
                btn.text:SetTextColor(1, 1, 1)
                btn:EnableMouse(true)
                btn._clickable = true
                btn:RegisterForClicks("LeftButtonUp")
                local fn = entry.func
                btn:SetScript("OnClick", function()
                    menu:Hide()
                    if fn then fn() end
                end)
            end
            -- Checkmark
            if entry.checked then
                local ok, isChecked = pcall(entry.checked)
                if ok and isChecked then btn.check:Show() end
            end
        end

        -- Compute approximate text width to size the menu
        local stringWidth = btn.text:GetStringWidth() or 0
        if stringWidth > maxTextWidth then maxTextWidth = stringWidth end

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT",  menu, "TOPLEFT",  4, y)
        btn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, y)
        y = y - btn:GetHeight() - 1
    end

    -- Auto-size width based on widest label (with some padding for checkmark + margins)
    local desiredWidth = math.min(360, math.max(180, maxTextWidth + 40))
    menu:SetWidth(desiredWidth)
    menu:SetHeight(-y + 6)

    -- Position relative to anchor
    menu:ClearAllPoints()
    if anchor and anchor.GetLeft then
        menu:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", -2, 0)
    else
        menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- Toggle: clicking the SAME anchor again closes; a different anchor moves it
    if menu:IsShown() and menu._openAnchor == anchor then
        menu:Hide()
        menu._openAnchor = nil
    else
        menu._openAnchor = anchor
        menu._armed      = false
        menu:Show()
    end
end

-- Convenience: force-close (e.g. when toggling a checkbox should hide elsewhere)
function ns:HidePopupMenu()
    if _menuFrame and _menuFrame:IsShown() then _menuFrame:Hide() end
end
