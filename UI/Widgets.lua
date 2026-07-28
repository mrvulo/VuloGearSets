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
UI.FONT_PATH = FONT_PATH

-- Gemessen auf dem Anniversary-Client: Schriftdateien aus Addon-Ordnern
-- werden NICHT geladen - weder unsere noch dieselbe Datei aus Details oder
-- VuloClassicUI (Textbreite jeweils 0). Client-interne Schriften laden
-- dagegen problemlos. Pruefen mit /vgsfont.
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

-- Dunkler Grund mit 1px-Rand.
function UI:CreateBackdrop(frame, bg)
    bg = bg or C.bg
    UI.SetColorBG(frame, bg.r, bg.g, bg.b, 0.95)
    local edges = {
        { "TOPLEFT",  "TOPRIGHT",    "h" },
        { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
        { "TOPLEFT",  "BOTTOMLEFT",  "v" },
        { "TOPRIGHT", "BOTTOMRIGHT", "v" },
    }
    for _, e in ipairs(edges) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(C.border.r, C.border.g, C.border.b, 1)
        t:SetPoint(e[1]); t:SetPoint(e[2])
        if e[3] == "h" then t:SetHeight(1) else t:SetWidth(1) end
    end
end

function UI:CreateButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 120, height or 22)
    b.bg = UI.SetColorBG(b, C.bgLight.r, C.bgLight.g, C.bgLight.b, 1)
    b.text = b:CreateFontString(nil, "OVERLAY")
    UI.Font(b.text, 12)
    b.text:SetPoint("CENTER")
    b.text:SetText(text or "")
    b.text:SetTextColor(C.text.r, C.text.g, C.text.b)
    b:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(C.accent.r * 0.5, C.accent.g * 0.5, C.accent.b * 0.5, 1)
        if self._tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self._tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(C.bgLight.r, C.bgLight.g, C.bgLight.b, 1)
        GameTooltip:Hide()
    end)
    function b:SetOnClick(fn)
        self:SetScript("OnClick", function() if fn then fn() end end)
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
    f.fill:SetColorTexture(C.accent.r, C.accent.g, C.accent.b, 1)
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
    f.value:SetTextColor(C.accent.r, C.accent.g, C.accent.b)

    f.slider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        f.value:SetText(tostring(v))
        if not f._suppress and f.OnValueChanged then f.OnValueChanged(v) end
    end)
    function f:SetValue(v)
        self._suppress = true
        self.slider:SetValue(v or minV or 0)
        self.value:SetText(tostring(math.floor((v or 0) + 0.5)))
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

    local arrow = f.button:CreateFontString(nil, "OVERLAY")
    UI.Font(arrow, 12)
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")
    arrow:SetTextColor(C.textDim.r, C.textDim.g, C.textDim.b)

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
