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

local WIDTH, HEIGHT = 760, 600
local PAD           = 16                     -- Einrueckung der Eintraege im Inhalt
local NAV_W         = 190                    -- Seitenliste links
local ROW_H         = 28                     -- Zeile der Seitenliste
local TITLE_H       = 32                     -- Titelleiste
local BAND_TITLE_H  = 58                     -- mit Titelband: Band + Zeile fuer die Version
local PAGEBAR_H     = 34                     -- Seitentitel + Zuruecksetzen
local BOTTOM_H      = 44                     -- Fussleiste
local SCROLLBAR_W   = 26

local TWITCH_URL  = "https://www.twitch.tv/mrvulo"
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
--
-- Aufbau wie das Hauptfenster der Vulo-Familie: oben die Titelleiste
-- (Symbol, Titel, Version, Schliessen), links die Seitenliste, rechts eine
-- Kopfzeile mit Seitentitel und "Seite zuruecksetzen", darunter der
-- Inhalt, unten eine Leiste mit "Alles zuruecksetzen", den Links und
-- "Fertig". Traegt das Fenster den Metallrahmen mit Titelband (Forever,
-- Blizzard-Themes), sitzt der Titel im Band und die Version in einer
-- Zeile darunter.
--
-- applyLayout setzt Lage und Farben bei jedem Neuzeichnen neu: ein
-- Stilwechsel aendert Rahmen, Einrueckung und Titelleiste, und das soll
-- ohne /reload greifen.
-- =========================================================
local navButtons = {}
local parts = {}
local pageTitle, resetBtn

-- Verlauf auf einer Textur; aeltere Clients kennen nur SetGradientAlpha.
local function setGradient(tex, orient, r1, g1, b1, a1, r2, g2, b2, a2)
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    if tex.SetGradient and CreateColor then
        tex:SetGradient(orient, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
    elseif tex.SetGradientAlpha then
        tex:SetGradientAlpha(orient, r1, g1, b1, a1, r2, g2, b2, a2)
    else
        tex:SetColorTexture((r1 + r2) / 2, (g1 + g2) / 2, (b1 + b2) / 2, (a1 + a2) / 2)
    end
end

-- Breite des Scroll-Inhalts: Fenster ohne Rahmen, Seitenliste, deren
-- Trennlinie und Scrollleiste.
-- Im Titelband reicht das Metall rechts ein paar Pixel ins Fenster; so weit
-- rueckt der Inhalt dort ab, damit die Scrollleiste frei bleibt.
local BAND_RIGHT = 6

local function contentWidth()
    local band  = ns:WindowHasTitleBand(frame)
    local inset = band and 0 or ns:FrameInset("window")
    return WIDTH - inset * 2 - NAV_W - 1 - SCROLLBAR_W - (band and BAND_RIGHT or 0)
end

-- Seitenknopf links. Die gewaehlte Seite traegt einen Akzent-Verlauf und
-- einen Akzentbalken am linken Rand.
local function createNavButton(parent, page, index)
    local b = CreateFrame("Button", nil, parent)
    local y = -6 - (index - 1) * ROW_H
    b:SetHeight(ROW_H)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
    b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, y)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetPoint("TOPLEFT")
    b.bar:SetPoint("BOTTOMLEFT")
    b.bar:SetWidth(3)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.hl:SetColorTexture(1, 1, 1, 0.05)
    b.text = b:CreateFontString(nil, "OVERLAY")
    UI.Font(b.text, 12)
    b.text:SetPoint("LEFT", 12, 0)
    b.text:SetPoint("RIGHT", -6, 0)
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
    local ar, ag, ab = ns:AccentColor()
    for _, b in ipairs(navButtons) do
        if b.key == currentPage then
            setGradient(b.sel, "HORIZONTAL", ar, ag, ab, 0.26, ar, ag, ab, 0.02)
            b.sel:Show()
            b.bar:SetColorTexture(ar, ag, ab, 1)
            b.bar:Show()
            b.text:SetTextColor(1, 1, 1)
        else
            b.sel:Hide()
            b.bar:Hide()
            b.text:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
        end
    end
end

local function newLine()
    return frame:CreateTexture(nil, "ARTWORK")
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
    UI:CreateBackdrop(frame, "main")
    UI:CreateShadow(frame)
    tinsert(UISpecialFrames, "VuloGearSetsOptions")   -- Escape schliesst

    -- ---- Titelleiste ----
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() frame:StopMovingOrSizing() end)
    parts.titleBar = titleBar

    parts.titleBG = titleBar:CreateTexture(nil, "BACKGROUND")
    parts.titleBG:SetAllPoints(titleBar)

    -- Akzentlinie ganz oben, nur bei den flachen Stilen.
    local brand = titleBar:CreateTexture(nil, "ARTWORK")
    brand:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 1, -1)
    brand:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -1, -1)
    brand:SetHeight(2)
    parts.brand = brand

    local icon = titleBar:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\AddOns\\VuloGearSets\\Media\\Icons\\vgs")
    parts.icon = icon

    local title = titleBar:CreateFontString(nil, "OVERLAY")
    UI.Font(title, 15)
    title:SetText(L["Gear Sets"])
    parts.title = title

    -- Im Titelband Blizzards Schrift, wie Blizzards eigene Fenster (I-04).
    local bandTitle = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bandTitle:SetText(L["Gear Sets"])
    parts.bandTitle = bandTitle

    local ver = titleBar:CreateFontString(nil, "OVERLAY")
    UI.Font(ver, 10)
    ver:SetText("v" .. (ns.VERSION or "?"))
    parts.version = ver

    -- Flaches Schliessen: rot hinterlegt beim Ueberfahren.
    local close = CreateFrame("Button", nil, titleBar)
    close.bg = close:CreateTexture(nil, "BACKGROUND")
    close.bg:SetAllPoints(close)
    close.bg:SetColorTexture(0.78, 0.16, 0.16, 1)
    close.bg:Hide()
    close.text = close:CreateFontString(nil, "OVERLAY")
    UI.Font(close.text, 20)
    close.text:SetPoint("CENTER")
    close.text:SetText("\195\151")   -- Malzeichen
    close:SetScript("OnEnter", function(self)
        self.bg:Show()
        self.text:SetTextColor(1, 1, 1)
    end)
    close:SetScript("OnLeave", function(self)
        self.bg:Hide()
        self.text:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
    end)
    close:SetScript("OnClick", function() frame:Hide() end)
    parts.close = close

    -- Im Titelband Blizzards Schliessen-Knopf. Die Vorlage heisst nicht
    -- auf jedem Client gleich; eine unbekannte Vorlage wirft nicht, sie
    -- liefert einen nackten Knopf - deshalb an der Grafik pruefen. Fehlt
    -- sie, bleibt der flache Knopf.
    local function closeFrom(template)
        local ok, b = pcall(CreateFrame, "Button", nil, titleBar, template)
        if ok and b and b.GetNormalTexture and b:GetNormalTexture() then return b end
        if ok and b then b:Hide() end
        return nil
    end
    local bc = closeFrom("UIPanelCloseButtonNoScripts") or closeFrom("UIPanelCloseButton")
    if bc then
        bc:SetScript("OnClick", function() frame:Hide() end)
        bc:Hide()
        parts.bandClose = bc
    end

    parts.titleSep = newLine()

    -- ---- Fussleiste ----
    local bottomBar = CreateFrame("Frame", nil, frame)
    bottomBar:SetHeight(BOTTOM_H)
    parts.bottomBar = bottomBar
    parts.bottomBG = bottomBar:CreateTexture(nil, "BACKGROUND")
    parts.bottomBG:SetAllPoints(bottomBar)
    parts.bottomSep = newLine()

    local resetAll = UI:CreateButton(bottomBar, L["Reset all"], 150, 26)
    resetAll:SetPoint("LEFT", bottomBar, "LEFT", 10, 0)
    resetAll._tooltip = L["Sets every option on every page back to its default. Gear sets, keys and spec or form bindings are not touched."]
    resetAll:SetOnClick(function() StaticPopup_Show("VGS_RESET_ALL") end)

    local twitch = createSocialButton(bottomBar, "TwitchV.tga", "Twitch", TWITCH_URL)
    twitch:SetPoint("LEFT", resetAll, "RIGHT", 14, 0)
    local discord = createSocialButton(bottomBar, "DiscordV.tga", "Discord", DISCORD_URL)
    discord:SetPoint("LEFT", twitch, "RIGHT", 8, 0)

    local done = UI:CreateButton(bottomBar, DONE or CLOSE or "OK", 90, 26)
    done:SetPoint("RIGHT", bottomBar, "RIGHT", -10, 0)
    done:SetOnClick(function() frame:Hide() end)

    -- ---- Seitenliste ----
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetWidth(NAV_W)
    parts.sidebar = sidebar
    parts.sidebarBG = sidebar:CreateTexture(nil, "BACKGROUND")
    parts.sidebarBG:SetAllPoints(sidebar)
    parts.sidebarSep = newLine()
    for i, page in ipairs(PAGES) do
        navButtons[i] = createNavButton(sidebar, page, i)
    end

    -- ---- Kopfzeile der Seite ----
    local pageBar = CreateFrame("Frame", nil, frame)
    pageBar:SetHeight(PAGEBAR_H)
    parts.pageBar = pageBar
    parts.pageBarBG = pageBar:CreateTexture(nil, "BACKGROUND")
    parts.pageBarBG:SetAllPoints(pageBar)
    parts.pageSep = newLine()

    pageTitle = pageBar:CreateFontString(nil, "OVERLAY")
    UI.Font(pageTitle, 14)
    pageTitle:SetPoint("LEFT", pageBar, "LEFT", PAD, 0)

    resetBtn = UI:CreateButton(pageBar, L["Reset page"], 160, 22)
    resetBtn:SetPoint("RIGHT", pageBar, "RIGHT", -10, 0)
    resetBtn._tooltip = L["Sets every option on this page back to its default. Gear sets, keys and spec or form bindings are not touched."]
    resetBtn:SetOnClick(function()
        local dlg = StaticPopup_Show("VGS_RESET_PAGE", nil, nil, currentPage)
        -- data kommt je nach Client nicht als Argument durch.
        if dlg then dlg.data = currentPage end
    end)

    -- ---- Inhalt ----
    local body = CreateFrame("Frame", nil, frame)
    parts.body = body
    parts.bodyBG = body:CreateTexture(nil, "BACKGROUND")
    parts.bodyBG:SetAllPoints(body)

    local scroll = CreateFrame("ScrollFrame", "VuloGearSetsOptionsScroll", body,
                               "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     body, "TOPLEFT",     0, -8)
    scroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -SCROLLBAR_W, 8)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(contentWidth(), 10)
    scroll:SetScrollChild(content)
    frame.scroll = scroll
end

-- Lage und Farben nach dem aktiven Stil (siehe oben).
local function applyLayout()
    local P = parts
    local band   = ns:WindowHasTitleBand(frame)
    local inset  = band and 0 or ns:FrameInset("window")
    local titleH = band and BAND_TITLE_H or TITLE_H
    local ar, ag, ab = ns:AccentColor()
    local br, bg, bb = C.border.r, C.border.g, C.border.b

    -- Titelleiste. Im Titelband liegt sie ueber dem Metall (+30), sonst
    -- verdeckte das Band den Titel.
    P.titleBar:ClearAllPoints()
    P.titleBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  inset, -inset)
    P.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
    P.titleBar:SetHeight(titleH)
    P.titleBar:SetFrameLevel(frame:GetFrameLevel() + (band and 35 or 2))

    local tr, tg, tb, ta = ns:WindowColor("barTop")
    local lr, lg, lb, la = ns:WindowColor("barBottom")
    setGradient(P.titleBG, "VERTICAL", lr, lg, lb, la, tr, tg, tb, ta)
    P.titleBG:SetShown(not band)
    setGradient(P.brand, "HORIZONTAL", ar, ag, ab, 1, ar, ag, ab, 0.10)
    P.brand:SetShown(not band and ns:GetStyle() ~= "classic")

    P.title:SetTextColor(ar, ag, ab)
    P.version:SetTextColor(ns:WindowColor("textMuted"))
    P.icon:ClearAllPoints()
    P.title:ClearAllPoints()
    P.version:ClearAllPoints()
    if band then
        P.title:Hide()
        P.bandTitle:Show()
        P.icon:SetSize(17, 17)
        P.bandTitle:ClearAllPoints()
        P.bandTitle:SetPoint("TOP", P.titleBar, "TOP", 17 / 2, -5)
        P.icon:SetPoint("RIGHT", P.bandTitle, "LEFT", -2, 0)
        P.version:SetPoint("LEFT", P.titleBar, "BOTTOMLEFT", 16, 17)
    else
        P.bandTitle:Hide()
        P.title:Show()
        P.icon:SetSize(19, 19)
        P.icon:SetPoint("LEFT", P.titleBar, "LEFT", 10, 0)
        P.title:SetPoint("LEFT", P.icon, "RIGHT", 4, 0)
        P.version:SetPoint("LEFT", P.title, "RIGHT", 8, -1)
    end

    if band and P.bandClose then
        P.close:Hide()
        P.bandClose:ClearAllPoints()
        P.bandClose:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, 1)
        P.bandClose:SetFrameLevel(P.titleBar:GetFrameLevel() + 2)
        P.bandClose:Show()
    else
        if P.bandClose then P.bandClose:Hide() end
        P.close:ClearAllPoints()
        P.close:SetSize(38, TITLE_H - 3)
        P.close:SetPoint("TOPRIGHT", P.titleBar, "TOPRIGHT", -1, -3)
        P.close:SetFrameLevel(P.titleBar:GetFrameLevel() + 2)
        P.close.bg:Hide()
        P.close.text:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)
        P.close:Show()
    end

    P.titleSep:ClearAllPoints()
    P.titleSep:SetPoint("TOPLEFT",  P.titleBar, "BOTTOMLEFT",  0, 0)
    P.titleSep:SetPoint("TOPRIGHT", P.titleBar, "BOTTOMRIGHT", 0, 0)
    P.titleSep:SetHeight(1)
    P.titleSep:SetColorTexture(br, bg, bb, 1)

    -- Fussleiste
    P.bottomBar:ClearAllPoints()
    P.bottomBar:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  inset, inset)
    P.bottomBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    setGradient(P.bottomBG, "VERTICAL", tr, tg, tb, ta, lr, lg, lb, la)
    P.bottomSep:ClearAllPoints()
    P.bottomSep:SetPoint("BOTTOMLEFT",  P.bottomBar, "TOPLEFT",  0, 0)
    P.bottomSep:SetPoint("BOTTOMRIGHT", P.bottomBar, "TOPRIGHT", 0, 0)
    P.bottomSep:SetHeight(1)
    P.bottomSep:SetColorTexture(br, bg, bb, 1)

    -- Seitenliste zwischen den beiden Trennlinien
    local above = inset + BOTTOM_H + 1
    P.sidebar:ClearAllPoints()
    P.sidebar:SetPoint("TOPLEFT",    P.titleSep, "BOTTOMLEFT", 0, 0)
    P.sidebar:SetPoint("BOTTOMLEFT", frame,      "BOTTOMLEFT", inset, above)
    P.sidebarBG:SetColorTexture(ns:WindowColor("sidebar"))
    P.sidebarSep:ClearAllPoints()
    P.sidebarSep:SetPoint("TOPLEFT",    P.sidebar, "TOPRIGHT",    0, 0)
    P.sidebarSep:SetPoint("BOTTOMLEFT", P.sidebar, "BOTTOMRIGHT", 0, 0)
    P.sidebarSep:SetWidth(1)
    P.sidebarSep:SetColorTexture(br, bg, bb, 1)

    -- Kopfzeile und Inhalt rechts daneben
    local cr, cg, cb, ca = ns:WindowColor("content")
    P.pageBar:ClearAllPoints()
    P.pageBar:SetPoint("TOPLEFT",  P.sidebar,  "TOPRIGHT",    1, 0)
    P.pageBar:SetPoint("TOPRIGHT", P.titleSep, "BOTTOMRIGHT", 0, 0)
    P.pageBarBG:SetColorTexture(cr, cg, cb, ca)
    P.pageSep:ClearAllPoints()
    P.pageSep:SetPoint("TOPLEFT",  P.pageBar, "BOTTOMLEFT",  0, 0)
    P.pageSep:SetPoint("TOPRIGHT", P.pageBar, "BOTTOMRIGHT", 0, 0)
    P.pageSep:SetHeight(1)
    P.pageSep:SetColorTexture(br, bg, bb, 1)

    P.body:ClearAllPoints()
    P.body:SetPoint("TOPLEFT",     P.pageSep, "BOTTOMLEFT", 0, 0)
    P.body:SetPoint("BOTTOMRIGHT", frame,     "BOTTOMRIGHT", -inset - (band and BAND_RIGHT or 0), above)
    P.bodyBG:SetColorTexture(cr, cg, cb, ca)
end

-- Ein Stilwechsel, den niemand ueber SetStyle ausloest (der Stil folgt
-- VuloClassicUI), erreicht das offene Fenster sonst erst beim naechsten
-- Seitenwechsel.
ns:OnStyleChanged(function()
    if frame and frame:IsShown() then ns:RefreshOptions() end
end)

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
    applyLayout()
    updateNav()
    pageTitle:SetText(pageTitleOf(currentPage))
    pageTitle:SetTextColor(ns:AccentColor())
    if pageHasDefaults(currentPage) then resetBtn:Show() else resetBtn:Hide() end

    -- Der Renderer setzt PAD links selbst; rechts bleibt derselbe Abstand.
    local w = contentWidth()
    content:SetWidth(w)
    local height = renderItems(content, pageItems(currentPage), 0, w - PAD * 2)
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
