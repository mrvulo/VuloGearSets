-- =========================================================
-- VuloGearSets / UI / OptionsFrame
-- Ein Fenster mit Seiten: links die Navigation, rechts ein Scrollbereich,
-- ein Renderer fuer deklarative Item-Listen.
--
-- Jedes Modul bringt seine Eintraege selbst mit: mod:GetOptions(page)
-- liefert die Liste fuer eine Seite (oder nil), mod.optionsOrder[page]
-- sortiert die Module auf derselben Seite (Standard 50). Die Seiten selbst
-- stehen fest in PAGES.
--
-- Unterstuetzte Typen: header, desc, spacer, button, toggle,
-- slider, dropdown, group (layout="row"), section.
-- Setter werden als set(nil, value) gerufen - diese Signatur
-- stammt aus dem Modulcode und darf sich nicht aendern.
--
-- default: toggle, slider und dropdown duerfen einen Standardwert tragen
-- (Wert oder Funktion). "Seite zuruecksetzen" setzt jedes Element der
-- Seite, das einen hat, ueber seinen eigenen Setter darauf zurueck - so
-- laeuft auch das Nachziehen (Leiste neu verankern usw.) mit. Sets und
-- ihre Bindungen tragen keinen und bleiben deshalb immer unberuehrt.
-- =========================================================
local _, ns = ...
local UI = ns.UI
local L  = ns.L
local C  = ns.COLORS

local WIDTH, HEIGHT = 620, 580
local PAD           = 16
local NAV_W         = 150                    -- Seitenliste links
local HEAD_H        = 30                     -- Seitentitel + Zuruecksetzen
local CONTENT_W     = WIDTH - PAD * 3 - NAV_W - 20   -- 20px fuer die Scrollleiste
local FOOTER_H      = 26                     -- Leiste unten fuer Discord und Version

local DISCORD_URL = "https://discord.gg/P5dTSB6wC"

-- Feste Seitenliste. key ist auch der Name fuer /vgs <seite>.
local PAGES = {
    { key = "general",    title = L["General"] },
    { key = "sidebar",    title = L["Sidebar & Minimap"] },
    { key = "automation", title = L["Automation"] },
    { key = "slots",      title = L["Slot Picker & Sockets"] },
    { key = "sets",       title = L["Saved Gear Sets"] },
    { key = "info",       title = L["Commands & Info"] },
}
ns.OPTIONS_PAGES = PAGES

local currentPage = "general"
local frame, content
local renderItems   -- vorwaerts deklariert: section/group rufen rekursiv auf

-- =========================================================
-- Widget-Pools
--
-- Frames lassen sich in WoW nie wieder einsammeln. Der fruehere Weg -
-- bei jedem Neuzeichnen einen frischen Scroll-Child samt aller Widgets
-- erzeugen und den alten nur verstecken - liess deshalb bei jedem
-- Speichern, Loeschen oder Stilwechsel Dutzende Frames dauerhaft liegen.
-- Stattdessen werden die Widgets jetzt je Typ gepoolt: verstecken,
-- Zaehler zuruecksetzen, beim Rendern in derselben Reihenfolge wieder
-- einsammeln und komplett neu konfigurieren.
-- =========================================================
local pools = {}

local function acquire(kind, create)
    local p = pools[kind]
    if not p then p = { widgets = {}, n = 0 }; pools[kind] = p end
    p.n = p.n + 1
    local w = p.widgets[p.n]
    if not w then
        w = create()
        p.widgets[p.n] = w
    end
    w:Show()
    return w
end

local function resetPools()
    for _, p in pairs(pools) do
        for i = 1, #p.widgets do p.widgets[i]:Hide() end
        p.n = 0
    end
end

-- =========================================================
-- Tooltip-Helfer
--
-- Der Text haengt am Widget, die Skripte werden nur einmal gesetzt:
-- gepoolte Widgets bekommen bei jedem Rendern einen neuen (oder gar
-- keinen) Text - ein fest eingebauter Text aus der letzten Verwendung
-- wuerde sonst stehenbleiben.
-- =========================================================
local function attachTooltip(widget, text)
    widget._tooltipText = (text ~= "") and text or nil
    if widget._tooltipHooked then return end
    widget._tooltipHooked = true
    widget:SetScript("OnEnter", function(self)
        if not self._tooltipText then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self._tooltipText, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- =========================================================
-- Ein Renderer je Typ. Signatur immer (parent, item, y, width),
-- Rueckgabe ist die verbrauchte Hoehe in Pixeln.
-- =========================================================
local renderers = {}

-- Header und Beschreibung teilen sich das Aussehen nicht, deshalb
-- getrennte Pools - sonst muesste die Schrift bei jedem Rendern neu
-- gesetzt werden.
local function acquireText(kind, size, flags)
    return acquire(kind, function()
        local fs = content:CreateFontString(nil, "OVERLAY")
        UI.Font(fs, size, flags)
        fs:SetJustifyH("LEFT")
        return fs
    end)
end

renderers.header = function(parent, item, y, width)
    local fs = acquireText("header", 14, "OUTLINE")
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", PAD, y)
    fs:SetWidth(width)
    fs:SetText(item.text or "")
    fs:SetTextColor(ns:AccentColor())
    return fs:GetStringHeight() + 8
end

renderers.desc = function(parent, item, y, width)
    local fs = acquireText("desc", 11)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", PAD, y)
    fs:SetWidth(width)
    fs:SetText(item.text or "")
    fs:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
    return fs:GetStringHeight() + 6
end

renderers.spacer = function(_, item)
    return item.height or 8
end

-- Knoepfe kommen aus einem gemeinsamen Pool (auch die der group-Zeilen).
local function acquireButton(label, width, x, y)
    local b = acquire("button", function()
        return UI:CreateButton(content, "", 130, 22)
    end)
    b:SetSize(width or 130, 22)
    b:SetText(label or "")
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", x, y)
    return b
end

renderers.button = function(parent, item, y)
    local b = acquireButton(item.label, item.width, PAD, y)
    b:SetOnClick(item.onClick)
    b._tooltip = item.tooltip
    return 26
end

renderers.toggle = function(parent, item, y, width)
    local t = acquire("toggle", function() return UI:CreateToggle(content) end)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", PAD, y)
    t:SetWidth(width)
    t.label:SetText(item.label or "")
    -- Akzentfarbe je Rendern neu setzen: CreateToggle faerbt die Fuellung
    -- nur einmal beim Erzeugen, ein Stilwechsel erreichte sie sonst nicht.
    t.fill:SetColorTexture(ns:AccentColor())
    t.OnValueChanged = nil   -- kein Callback der letzten Verwendung treffen
    t:SetChecked(item.get and item.get() or false)
    t.OnValueChanged = function(v)
        if item.set then item.set(nil, v) end
    end
    attachTooltip(t, item.tooltip)
    return 26
end

renderers.slider = function(parent, item, y, width)
    local s = acquire("slider", function() return UI:CreateSlider(content) end)
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", PAD, y)
    s:SetWidth(width)   -- ohne Breite rendert der Frame seine Kinder nicht
    s.label:SetText(item.label or "")
    -- Wie beim Toggle: die Farbe der Wertanzeige setzt CreateSlider nur
    -- einmal beim Erzeugen.
    s.value:SetTextColor(ns:AccentColor())
    -- Callback VOR SetMinMaxValues loesen: klemmt der alte Wert auf die
    -- neue Spanne, feuert der Regler sofort - und traefe sonst noch den
    -- Setter der letzten Verwendung.
    s.OnValueChanged = nil
    s.slider:SetMinMaxValues(item.min or 0, item.max or 100)
    s.slider:SetValueStep(item.step or 1)
    s:SetValue(item.get and item.get() or item.min or 0)
    s.OnValueChanged = function(v)
        if item.set then item.set(nil, v) end
    end
    attachTooltip(s.slider, item.tooltip)
    return 48
end

renderers.dropdown = function(parent, item, y, width)
    local d = acquire("dropdown", function() return UI:CreateDropdown(content) end)
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", PAD, y)
    d:SetWidth(width)   -- ohne Breite rendert der Frame seine Kinder nicht
    d.label:SetText(item.label or "")
    d.values = item.values or {}
    d.OnValueChanged = nil
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
        local b = acquireButton(sub.label, w, PAD + x, y)
        b:SetOnClick(sub.onClick)
        b._tooltip = sub.tooltip
        x = x + w + gap
        maxH = math.max(maxH, 26)
    end
    return maxH
end

-- Aufklappbarer Block.
--
-- Der Zustand darf NICHT in item.collapsed liegen: mod:GetOptions() baut die
-- Liste bei jedem Neuzeichnen frisch auf, der geschriebene Wert waere sofort
-- wieder weg und der Kopf damit ohne Wirkung. Deshalb nach Titel gemerkt,
-- ausserhalb der Liste. item.collapsed liefert nur noch den Startwert.
local sectionCollapsed = {}

renderers.section = function(parent, item, y, width)
    local key = item.title or ""
    if sectionCollapsed[key] == nil then
        sectionCollapsed[key] = item.collapsed and true or false
    end
    local collapsed = sectionCollapsed[key]

    local head = acquire("sectionHead", function()
        local h = CreateFrame("Button", nil, content)
        h.fs = h:CreateFontString(nil, "OVERLAY")
        UI.Font(h.fs, 13, "OUTLINE")
        h.fs:SetPoint("LEFT")
        return h
    end)
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", PAD, y)
    head:SetSize(width, 20)
    head.fs:SetTextColor(ns:AccentColor())
    head.fs:SetText((collapsed and "+ " or "- ") .. (item.title or ""))

    head:SetScript("OnClick", function()
        sectionCollapsed[key] = not collapsed
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
-- Link zum Kopieren anbieten
--
-- Der Client kann keine URL im Browser oeffnen. Stattdessen ein Dialog
-- mit vorselektiertem Text, den man mit Strg+C mitnimmt.
-- =========================================================
StaticPopupDialogs["VGS_COPY_URL"] = StaticPopupDialogs["VGS_COPY_URL"] or {
    text = L["Copy the link with Ctrl+C:"],
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        local eb = ns.PopupEditBox(self)
        if not eb then return end
        eb:SetText(self.data or "")
        eb:HighlightText()
        eb:SetFocus()
    end,
    -- Eingaben verwerfen: der Text soll unveraendert kopierbar bleiben.
    EditBoxOnTextChanged = function(self, data)
        if self:GetText() ~= (data or "") then
            self:SetText(data or "")
            self:HighlightText()
        end
    end,
    EditBoxOnEscapePressed = function() StaticPopup_Hide("VGS_COPY_URL") end,
    EditBoxOnEnterPressed  = function() StaticPopup_Hide("VGS_COPY_URL") end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function createSocialButton(parent, iconFile, label, url)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(b)
    t:SetTexture("Interface\\AddOns\\VuloGearSets\\Media\\Icons\\" .. iconFile)
    t:SetVertexColor(0.85, 0.85, 0.85, 0.9)
    b:SetScript("OnEnter", function(self)
        t:SetVertexColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:AddLine(L["Click: copy link"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
        t:SetVertexColor(0.85, 0.85, 0.85, 0.9)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function()
        local dlg = StaticPopup_Show("VGS_COPY_URL", nil, nil, url)
        -- data kommt je nach Client nicht als Argument durch.
        if dlg then dlg.data = url end
    end)
    return b
end

-- =========================================================
-- Seiteninhalt einsammeln
-- =========================================================
local function pageItems(page)
    local parts = {}
    for i, key in ipairs(ns.moduleOrder or {}) do
        local mod = ns.modules[key]
        if mod and mod.GetOptions then
            local ok, list = pcall(mod.GetOptions, mod, page)
            if not ok then
                ns:Print("|cffff5555Options:|r %s: %s", tostring(key), tostring(list))
            elseif type(list) == "table" and #list > 0 then
                local order = (mod.optionsOrder and mod.optionsOrder[page]) or 50
                parts[#parts + 1] = { order = order, idx = i, items = list }
            end
        end
    end
    table.sort(parts, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.idx < b.idx
    end)
    local items = {}
    for _, part in ipairs(parts) do
        for _, it in ipairs(part.items) do items[#items + 1] = it end
    end
    return items
end

-- Alle Elemente mit Standardwert, auch in Abschnitten und Zeilen.
local function collectDefaults(items, out)
    for _, it in ipairs(items or {}) do
        if it.default ~= nil and it.set then out[#out + 1] = it end
        if it.items then collectDefaults(it.items, out) end
    end
    return out
end

local function resetPage(page)
    for _, it in ipairs(collectDefaults(pageItems(page), {})) do
        local v = it.default
        if type(v) == "function" then v = v() end
        pcall(it.set, nil, v)
    end
end

local function pageHasDefaults(page)
    return #collectDefaults(pageItems(page), {}) > 0
end

StaticPopupDialogs["VGS_RESET_PAGE"] = {
    text = L["Reset the settings on this page to their defaults? Gear sets and their bindings stay."],
    button1 = YES or L["Yes"],
    button2 = NO  or L["No"],
    -- Die Seite beim Oeffnen gemerkt (data), nicht beim Ja: die Navigation
    -- bleibt hinter dem Dialog klickbar.
    OnAccept = function(self, data)
        resetPage(data or (self and self.data) or currentPage)
        ns:Print(L["Settings reset to defaults."])
        ns:RefreshOptions()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["VGS_RESET_ALL"] = {
    text = L["Reset all settings to their defaults? Gear sets and their bindings stay."],
    button1 = YES or L["Yes"],
    button2 = NO  or L["No"],
    OnAccept = function()
        for _, pg in ipairs(PAGES) do resetPage(pg.key) end
        ns:Print(L["Settings reset to defaults."])
        ns:RefreshOptions()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- =========================================================
-- Fenster
-- =========================================================
local navButtons = {}
local pageTitle, resetBtn

-- Seitenknopf links. Eigener schlichter Knopf statt UI:CreateButton: die
-- gewaehlte Seite traegt die Auswahlfarbe des Stils, wie eine Zeile in
-- der Set-Leiste.
local function createNavButton(parent, page, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(NAV_W, 24)
    b:SetPoint("TOPLEFT", PAD, -PAD - 30 - (index - 1) * 26)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.text = b:CreateFontString(nil, "OVERLAY")
    UI.Font(b.text, 12)
    b.text:SetPoint("LEFT", 8, 0)
    b.text:SetPoint("RIGHT", -4, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b.text:SetText(page.title)
    b.key = page.key
    b:SetScript("OnClick", function(self)
        currentPage = self.key
        if frame.scroll then frame.scroll:SetVerticalScroll(0) end
        ns:RefreshOptions()
    end)
    return b
end

local function updateNav()
    for _, b in ipairs(navButtons) do
        b.hl:SetColorTexture(ns:HoverColor())
        if b.key == currentPage then
            b.sel:SetColorTexture(ns:SelectionColor())
            b.sel:Show()
            b.text:SetTextColor(ns:AccentColor())
        else
            b.sel:Hide()
            b.text:SetTextColor(C.text.r, C.text.g, C.text.b)
        end
    end
end

local function createFrame()
    frame = CreateFrame("Frame", "VuloGearSetsOptions", UIParent,
        BackdropTemplateMixin and "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
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
    title:SetTextColor(ns:AccentColor())
    frame.title = title

    local close = UI:CreateButton(frame, "X", 22, 22)
    close:SetPoint("TOPRIGHT", -PAD, -PAD + 2)
    close:SetOnClick(function() frame:Hide() end)

    for i, page in ipairs(PAGES) do
        navButtons[i] = createNavButton(frame, page, i)
    end

    -- Trennlinie zwischen Navigation und Inhalt
    local vsep = frame:CreateTexture(nil, "ARTWORK")
    vsep:SetColorTexture(C.border.r, C.border.g, C.border.b, 1)
    vsep:SetWidth(1)
    vsep:SetPoint("TOPLEFT", PAD + NAV_W + PAD / 2, -PAD - 30)
    vsep:SetPoint("BOTTOMLEFT", PAD + NAV_W + PAD / 2, PAD + FOOTER_H)

    local left = PAD * 2 + NAV_W

    pageTitle = frame:CreateFontString(nil, "OVERLAY")
    UI.Font(pageTitle, 14, "OUTLINE")
    pageTitle:SetPoint("TOPLEFT", left, -PAD - 34)

    resetBtn = UI:CreateButton(frame, L["Reset page"], 160, 20)
    resetBtn:SetPoint("TOPRIGHT", -PAD, -PAD - 30)
    resetBtn._tooltip = L["Sets every option on this page back to its default. Gear sets, keys and spec or form bindings are not touched."]
    resetBtn:SetOnClick(function()
        local dlg = StaticPopup_Show("VGS_RESET_PAGE", nil, nil, currentPage)
        -- data kommt je nach Client nicht als Argument durch.
        if dlg then dlg.data = currentPage end
    end)

    local scroll = CreateFrame("ScrollFrame", "VuloGearSetsOptionsScroll", frame,
                               "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     left, -PAD - 30 - HEAD_H)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 20, PAD + FOOTER_H)

    -- Fusszeile mit Trennlinie
    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(C.border.r, C.border.g, C.border.b, 1)
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT",  PAD, PAD + FOOTER_H - 4)
    sep:SetPoint("BOTTOMRIGHT", -PAD, PAD + FOOTER_H - 4)

    local discord = createSocialButton(frame, "DiscordV.tga", "Discord", DISCORD_URL)
    discord:SetPoint("BOTTOMLEFT", PAD, PAD)

    local resetAll = UI:CreateButton(frame, L["Reset all"], 160, 20)
    resetAll:SetPoint("LEFT", discord, "RIGHT", 12, 0)
    resetAll._tooltip = L["Sets every option on every page back to its default. Gear sets, keys and spec or form bindings are not touched."]
    resetAll:SetOnClick(function() StaticPopup_Show("VGS_RESET_ALL") end)

    local ver = frame:CreateFontString(nil, "OVERLAY")
    UI.Font(ver, 11)
    ver:SetPoint("BOTTOMRIGHT", -PAD, PAD + 4)
    ver:SetText("v" .. (ns.VERSION or "?"))
    ver:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CONTENT_W, 10)
    scroll:SetScrollChild(content)
    frame.scroll = scroll
end

local function pageTitleOf(key)
    for _, pg in ipairs(PAGES) do
        if pg.key == key then return pg.title end
    end
    return ""
end

-- Zeichnet den Inhalt neu. Der Scroll-Child bleibt derselbe Frame; nur
-- die gepoolten Widgets werden versteckt und in neuer Anordnung wieder
-- eingesammelt (siehe Pools oben).
function ns:RefreshOptions()
    if not frame or not frame:IsShown() then return end
    resetPools()
    updateNav()
    frame.title:SetTextColor(ns:AccentColor())
    pageTitle:SetText(pageTitleOf(currentPage))
    pageTitle:SetTextColor(ns:AccentColor())
    if pageHasDefaults(currentPage) then resetBtn:Show() else resetBtn:Hide() end

    -- Der Inhalt beginnt direkt oben: der Seitentitel steht schon ueber
    -- dem Scrollbereich. Die Breite ohne den zweiten PAD - der Renderer
    -- setzt PAD links selbst.
    local height = renderItems(content, pageItems(currentPage), 0, CONTENT_W - PAD)
    content:SetHeight(math.max(height + PAD, 10))
end

-- Gibt es die Seite? Fuer /vgs <seite>.
function ns:IsOptionsPage(key)
    for _, pg in ipairs(PAGES) do
        if pg.key == key then return true end
    end
    return false
end

-- page: optional, eine der PAGES. Ohne bleibt die zuletzt gezeigte.
function ns:OpenOptions(page)
    if page and ns:IsOptionsPage(page) then
        currentPage = page
        if frame and frame.scroll then frame.scroll:SetVerticalScroll(0) end
    end
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
