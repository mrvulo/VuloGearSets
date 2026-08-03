-- =========================================================
-- VuloGearSets / UI / Widgets
-- Nur die Bausteine, die das Optionsfenster tatsaechlich braucht.
-- =========================================================
local _, ns = ...
ns.UI = ns.UI or {}
local UI = ns.UI
local C  = ns.COLORS

-- Dieselbe Schrift wie VuloClassicUI.
local FONT_PATH = "Interface\\AddOns\\VuloGearSets\\Media\\Fonts\\Expressway.TTF"

-- Gemessen auf dem Anniversary-Client: Schriftdateien aus Addon-Ordnern
-- werden NICHT geladen - weder unsere noch dieselbe oder eine andere Datei
-- aus fremden Addon-Ordnern (Textbreite jeweils 0). Es liegt also nicht an
-- unserem Pfad. Client-interne Schriften laden dagegen problemlos.
-- Pruefen mit /vgsfont.
--
-- Deshalb der Reihe nach:
--   1. die eigene Expressway - falls ein Client sie doch annimmt
--   2. Arial Narrow, client-intern und im Schnitt nah an Expressway
--   3. die Standardschrift als Notnagel
local FONT_CANDIDATES = {
    FONT_PATH,
    "Fonts\\ARIALN.TTF",
}

-- Laesst sich die Schriftdatei nicht laden, rendert der Client den Text
-- kommentarlos leer - das Fenster sieht dann aus, als fehle jede Beschriftung.
--
-- Die Pruefung laeuft bewusst FUNKTIONAL statt ueber Rueckgabewerte:
--   FontString:GetFont() liefert den gesetzten Pfad auch dann, wenn die Datei
--   nie geladen wurde. Font:SetFont() liefert je nach Client gar nichts.
-- Verlaesslich ist nur: Text setzen und messen. Hat er Breite, rendert die
-- Schrift wirklich. Einmal pruefen, Ergebnis merken.
local _resolved
local _probeResult

local function measure(path)
    local fs = UIParent:CreateFontString(nil, "BACKGROUND")
    fs:SetFont(path, 12, "")
    fs:SetText("VuloGearSets")
    local w = fs:GetStringWidth() or 0
    fs:Hide()
    fs:SetText("")
    return w
end

local function resolveFont()
    if _resolved then return _resolved end

    _probeResult = { candidates = {}, fallback = measure(STANDARD_TEXT_FONT) }
    for i, path in ipairs(FONT_CANDIDATES) do
        local w = measure(path)
        _probeResult.candidates[i] = { path = path, width = w }
        if w > 0 and not _resolved then
            _resolved = path
            _probeResult.usedIndex = i
        end
    end

    if not _resolved then
        _resolved = STANDARD_TEXT_FONT
    end
    -- Bewusst keine Chatmeldung: dass dieser Client keine Addon-Schriften
    -- laedt, ist nichts, was der Nutzer abstellen koennte. Wer es wissen
    -- will, ruft /vgsfont auf.
    return _resolved
end

-- Nur fuer die Diagnose interessant. Zweiter Rueckgabewert heisst
-- "Expressway laeuft", egal aus welchem der Kandidatenpfade.
function UI.GetResolvedFont()
    resolveFont()
    return _resolved, (_resolved ~= STANDARD_TEXT_FONT), _probeResult
end

function UI.Font(fs, size, flags)
    fs:SetFont(resolveFont(), size or 12, flags or "")
    -- Notnagel, falls selbst die Standardschrift nicht sitzt.
    if not fs:GetFont() then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, flags or "")
    end
    return fs
end

function UI.SetColorBG(frame, r, g, b, a, layer)
    local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetAllPoints(frame)
    tex:SetColorTexture(r, g, b, a or 1)
    return tex
end

-- Weicher Schatten aus mehreren halbtransparenten Ringen.
function UI:CreateShadow(frame)
    if frame._vgsShadow then return end
    frame._vgsShadow = {}
    local layers = { { 1, 0.45 }, { 3, 0.28 }, { 5, 0.15 }, { 7, 0.07 } }
    for i, l in ipairs(layers) do
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, -8 + (i - 1))
        t:SetPoint("TOPLEFT",     frame, "TOPLEFT",     -l[1],  l[1])
        t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",  l[1], -l[1])
        t:SetColorTexture(0, 0, 0, l[2])
        frame._vgsShadow[i] = t
    end
end

-- Hintergrund und Rand. Das Aussehen bestimmt Core/Skin.lua, damit sich
-- der Stil zur Laufzeit umschalten laesst.
function UI:CreateBackdrop(frame, kind)
    return UI:SkinFrame(frame, kind or "window")
end

-- Knoepfe kennen beide Stile. Im Classic-Stil kommen Blizzards
-- Knopftexturen zum Einsatz, sonst eine schlichte Flaeche.
local buttons = setmetatable({}, { __mode = "k" })   -- schwach: Knoepfe duerfen sterben

-- Blizzards Knopfgrafik ist zerlegt (links, gedehnte Mitte, rechts). Sie
-- als ein Stueck zu strecken sieht falsch aus, deshalb kommt das
-- Original-Template zum Einsatz und wird im modernen Stil nur
-- ausgeblendet.
--
-- WIE die Teile am Knopf haengen, ist von Client zu Client verschieden:
-- mal als NormalTexture und Geschwister, mal als benannte Kindtexturen
-- (Left/Middle/Right). Auf dem Anniversary-Client antworten die vier
-- Getter GAR NICHT - die Grafik blieb im modernen Stil deshalb sichtbar
-- stehen, und die Knoepfe sahen nach einem Stilwechsel weiter nach
-- Blizzard aus. Statt zu raten, welcher Weg gilt: einmal beim Bauen ALLE
-- Texturregionen einsammeln, die der Knopf von sich aus mitbringt.
--
-- Muss VOR unserer eigenen bg-Textur laufen, sonst blendet der moderne
-- Stil seinen eigenen Grund gleich mit aus.
local function captureBlizzTextures(b)
    local list = {}
    local seen = {}
    for _, r in ipairs({ b:GetRegions() }) do
        if r and r.GetObjectType and r:GetObjectType() == "Texture" and not seen[r] then
            seen[r] = true
            list[#list + 1] = r
        end
    end
    -- Guertel fuer den umgekehrten Fall: wo die Stuecke NICHT als Regionen
    -- des Knopfes zurueckkommen, liefern die Getter sie.
    for _, get in ipairs({ b.GetNormalTexture, b.GetPushedTexture,
                           b.GetHighlightTexture, b.GetDisabledTexture }) do
        local t = get and get(b)
        if t and not seen[t] then
            seen[t] = true
            list[#list + 1] = t
        end
    end
    b._blizzTex = list
end

local function setBlizzTextures(b, shown)
    local a = shown and 1 or 0
    for _, t in ipairs(b._blizzTex or {}) do t:SetAlpha(a) end
end

local function styleButton(b, style, hovered)
    -- Der Dropdown-Pfeil haengt am Knopf und folgt derselben Farbe.
    if b.arrow then
        if style == "classic" then
            b.arrow:SetVertexColor(1, 0.82, 0)
        else
            b.arrow:SetVertexColor(C.textDim.r, C.textDim.g, C.textDim.b)
        end
    end
    -- Im Classic-Stil zeigt Blizzards eigene Grafik den gesperrten Zustand.
    -- Im modernen ist sie ausgeblendet, also muss die Schrift ihn tragen -
    -- sonst sieht ein gesperrter Knopf aus wie ein bedienbarer.
    local off = (b.IsEnabled and not b:IsEnabled()) and true or false
    if style == "classic" then
        setBlizzTextures(b, true)
        if b.bg then b.bg:Hide() end
        b.text:SetTextColor(1, 0.82, 0)          -- Blizzard-Gold
    else
        setBlizzTextures(b, false)
        if b.bg then
            b.bg:Show()
            if off then
                b.bg:SetColorTexture(C.bg.r, C.bg.g, C.bg.b, 1)
            elseif hovered then
                b.bg:SetColorTexture(C.accent.r * 0.5, C.accent.g * 0.5, C.accent.b * 0.5, 1)
            else
                b.bg:SetColorTexture(C.bgLight.r, C.bgLight.g, C.bgLight.b, 1)
            end
        end
        if off then
            b.text:SetTextColor(C.textDim.r * 0.8, C.textDim.g * 0.8, C.textDim.b * 0.8)
        else
            b.text:SetTextColor(C.text.r, C.text.g, C.text.b)
        end
    end
end

-- Von ns:RefreshStyle gerufen, wenn der Stil wechselt.
function UI.RestyleButtons(style)
    for b in pairs(buttons) do
        if b.bg and b.text then styleButton(b, style, false) end
    end
end

function UI:CreateButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, height or 22)
    -- Vor der eigenen Flaeche, siehe captureBlizzTextures.
    captureBlizzTextures(b)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetPoint("TOPLEFT", 1, -1)
    b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    b:SetText(text or "")
    b.text = b:GetFontString()
    UI.Font(b.text, 12)
    buttons[b] = true
    styleButton(b, ns:GetStyle(), false)

    b:SetScript("OnEnter", function(self)
        styleButton(self, ns:GetStyle(), true)
        if self._tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self._tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        styleButton(self, ns:GetStyle(), false)
        GameTooltip:Hide()
    end)
    function b:SetOnClick(fn)
        self:SetScript("OnClick", function() if fn then fn() end end)
    end

    -- Im modernen Stil steckt der gesperrte Zustand allein in den Farben,
    -- und die setzt von selbst niemand neu. Beide Aufrufe umhuellen, damit
    -- er sofort sichtbar wird und nicht erst beim naechsten Ueberfahren.
    local origEnable, origDisable = b.Enable, b.Disable
    b.Enable = function(self, ...)
        origEnable(self, ...)
        styleButton(self, ns:GetStyle(), false)
    end
    b.Disable = function(self, ...)
        origDisable(self, ...)
        styleButton(self, ns:GetStyle(), false)
    end

    return b
end

-- Kaestchen mit Fuellung. OnValueChanged(newState) wird von aussen gesetzt.
function UI:CreateToggle(parent, label)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(260, 22)   -- siehe CreateSlider: Breite 0 macht die Kinder unsichtbar
    f.box = CreateFrame("Frame", nil, f)
    f.box:SetSize(16, 16)
    f.box:SetPoint("LEFT", 0, 0)
    UI.SetColorBG(f.box, C.bgLight.r, C.bgLight.g, C.bgLight.b, 1)
    f.fill = f.box:CreateTexture(nil, "ARTWORK")
    f.fill:SetPoint("TOPLEFT", 3, -3)
    f.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    f.fill:SetColorTexture(ns:AccentColor())
    f.fill:Hide()
    f.label = f:CreateFontString(nil, "OVERLAY")
    UI.Font(f.label, 12)
    f.label:SetPoint("LEFT", f.box, "RIGHT", 8, 0)
    f.label:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.label:SetJustifyH("LEFT")
    f.label:SetText(label or "")
    f.label:SetTextColor(C.text.r, C.text.g, C.text.b)
    f._checked = false
    function f:GetChecked() return self._checked end
    function f:SetChecked(v)
        self._checked = v and true or false
        if self._checked then self.fill:Show() else self.fill:Hide() end
    end
    f:SetScript("OnClick", function(self)
        self:SetChecked(not self._checked)
        if self.OnValueChanged then self.OnValueChanged(self._checked) end
    end)
    return f
end

function UI:CreateSlider(parent, label, minV, maxV, step)
    local f = CreateFrame("Frame", nil, parent)
    -- Breite nicht weglassen: ein Frame mit Breite 0 zeichnet seine Kinder
    -- nicht, ohne dabei einen Fehler zu werfen.
    f:SetSize(260, 44)
    f.label = f:CreateFontString(nil, "OVERLAY")
    UI.Font(f.label, 12)
    f.label:SetPoint("TOPLEFT")
    f.label:SetText(label or "")
    f.label:SetTextColor(C.text.r, C.text.g, C.text.b)

    f.slider = CreateFrame("Slider", nil, f, "OptionsSliderTemplate")
    f.slider:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -6)
    -- Hoehe nicht dem Template ueberlassen: kommt sie dort nicht mit,
    -- waere der Regler unsichtbar, ohne dass ein Fehler auffaellt.
    f.slider:SetSize(200, 17)
    f.slider:SetMinMaxValues(minV or 0, maxV or 100)
    f.slider:SetValueStep(step or 1)
    if f.slider.SetObeyStepOnDrag then f.slider:SetObeyStepOnDrag(true) end
    -- Die Template-Beschriftungen stoeren das Layout.
    if f.slider.Low  then f.slider.Low:SetText("")  end
    if f.slider.High then f.slider.High:SetText("") end
    if f.slider.Text then f.slider.Text:SetText("") end

    f.value = f:CreateFontString(nil, "OVERLAY")
    UI.Font(f.value, 12)
    f.value:SetPoint("LEFT", f.slider, "RIGHT", 10, 0)
    f.value:SetTextColor(ns:AccentColor())

    f.slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        f.value:SetText(tostring(v))
        if not f._suppress and f.OnValueChanged then f.OnValueChanged(v) end
    end)
    function f:SetValue(v)
        self._suppress = true
        self.slider:SetValue(v or minV or 0)
        -- Zurueckgelesen statt v angezeigt: der Regler klemmt selbst auf
        -- min/max. Ein Wert ausserhalb stand sonst in der Anzeige, waehrend
        -- der Regler sichtbar woanders stand.
        self.value:SetText(tostring(self:GetValue()))
        self._suppress = false
    end
    function f:GetValue() return math.floor(self.slider:GetValue() + 0.5) end
    return f
end

-- values = { { value = "x", text = "Anzeige" }, ... }
function UI:CreateDropdown(parent, label, values)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(260, 46)   -- siehe CreateSlider: Breite 0 macht die Kinder unsichtbar
    f.values = values or {}
    f.label = f:CreateFontString(nil, "OVERLAY")
    UI.Font(f.label, 12)
    f.label:SetPoint("TOPLEFT")
    f.label:SetText(label or "")
    f.label:SetTextColor(C.text.r, C.text.g, C.text.b)

    f.button = UI:CreateButton(f, "", 220, 22)
    f.button:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -6)
    f.button.text:ClearAllPoints()
    f.button.text:SetPoint("LEFT", 8, 0)
    f.button.text:SetPoint("RIGHT", -20, 0)
    f.button.text:SetJustifyH("LEFT")

    -- Pfeilsymbol statt eines getippten "v". Die Grafik ist weiss und
    -- wird eingefaerbt; die Farbe setzt styleButton ueber b.arrow mit.
    local arrow = f.button:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\AddOns\\VuloGearSets\\Media\\Icons\\arrow_down")
    arrow:SetSize(11, 11)
    arrow:SetPoint("RIGHT", -7, 0)
    f.button.arrow = arrow
    f.arrow = arrow
    -- Nochmal einfaerben: der Knopf wurde gestylt, als es den Pfeil noch
    -- nicht gab - er waere sonst weiss bis zum ersten Ueberfahren.
    styleButton(f.button, ns:GetStyle(), false)

    function f:SetValue(v)
        self._value = v
        for _, entry in ipairs(self.values) do
            if entry.value == v then self.button.text:SetText(entry.text); return end
        end
        self.button.text:SetText(tostring(v or ""))
    end
    function f:GetValue() return self._value end

    f.button:SetOnClick(function()
        local entries = {}
        for _, entry in ipairs(f.values) do
            table.insert(entries, {
                text    = entry.text,
                checked = function() return f._value == entry.value end,
                func    = function()
                    f:SetValue(entry.value)
                    if f.OnValueChanged then f.OnValueChanged(entry.value) end
                end,
            })
        end
        -- Achtung: entries kommt ZUERST, dann der Anker.
        ns:ShowPopupMenu(entries, f.button)
    end)
    return f
end
