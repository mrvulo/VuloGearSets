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

local FALLBACK_FONT = "Fonts\\ARIALN.TTF"

-- Expressway rendert erst, wenn der Client die Datei geladen hat. Das ist
-- beim Einloggen noch nicht der Fall: Texte, die dann schon Expressway
-- bekommen (die Knoepfe der Seitenleiste), bleiben leer, spaeter gebaute
-- (Menues) nicht. Deshalb bekommen Texte zuerst Arial Narrow - im Schnitt
-- nah an Expressway - und werden umgestellt, sobald Expressway zeichnet.
-- Zeichnet sie nach 15 Sekunden immer noch nicht, nimmt dieser Client
-- keine Addon-Schriften, und es bleibt bei Arial Narrow.
local _ready   = false
local _waiting = setmetatable({}, { __mode = "k" })   -- FontString -> { Groesse, Flags }
-- Alle Texte, die Expressway tragen - fuer redraw().
local _onFont  = setmetatable({}, { __mode = "k" })   -- FontString -> { Groesse, Flags }

local function apply(fs, path, size, flags)
    fs:SetFont(path, size, flags)
    -- Notnagel, falls selbst diese Schrift nicht sitzt.
    if not fs:GetFont() then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags)
    end
end

-- Expressway und Arial Narrow kennen weder Kyrillisch noch chinesische
-- oder koreanische Schriftzeichen - die Texte blieben dort leer. Auf
-- solchen Clients bleibt es bei Blizzards Standardschrift, die der Client
-- passend zur Sprache mitbringt.
local NON_LATIN = { ruRU = true, zhCN = true, zhTW = true, koKR = true }
local _gameFontOnly = GetLocale and NON_LATIN[GetLocale()] or false

function UI.Font(fs, size, flags)
    size, flags = size or 12, flags or ""
    if _gameFontOnly then
        apply(fs, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flags)
        return fs
    end
    if _ready then
        apply(fs, FONT_PATH, size, flags)
        _onFont[fs] = { size, flags }
    else
        apply(fs, FALLBACK_FONT, size, flags)
        _waiting[fs] = { size, flags }
    end
    return fs
end

-- Zeichnet alle Expressway-Texte neu. Ein SetFont mit denselben Werten
-- und ein SetText mit demselben Text uebergeht der Client - deshalb erst
-- eine andere Groesse und ein leerer Text, dann zurueck.
local function redraw()
    for fs, p in pairs(_onFont) do
        local text = fs:GetText()
        fs:SetFont(FONT_PATH, p[1] + 1, p[2])
        apply(fs, FONT_PATH, p[1], p[2])
        if text then
            fs:SetText("")
            fs:SetText(text)
        end
    end
end

-- Laeuft ab dem Laden der Datei. Erst auf eine andere Schrift und dann
-- zurueck, damit jede Pruefung wirklich neu setzt statt nur zu bestaetigen.
do
    local probe   = UIParent:CreateFontString(nil, "BACKGROUND")
    local elapsed, nextCheck = 0, 0
    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < nextCheck then return end
        nextCheck = elapsed + 0.2

        probe:SetFont(FALLBACK_FONT, 12, "")
        probe:SetFont(FONT_PATH, 12, "")
        probe:SetText("VuloGearSets")
        local drawn = (probe:GetStringWidth() or 0) > 0
        if not drawn and elapsed < 15 then return end

        self:SetScript("OnUpdate", nil)
        probe:SetText("")
        probe:Hide()
        if drawn then
            _ready = true
            for fs, p in pairs(_waiting) do
                apply(fs, FONT_PATH, p[1], p[2])
                _onFont[fs] = p
            end
            redraw()
            -- Die Messung kann schon Breite liefern, bevor die Schrift
            -- wirklich zeichnet - dann blieben gerade die frueh gebauten
            -- Knoepfe der Seitenleiste nach dem Einloggen leer. Deshalb
            -- noch zweimal nachzeichnen.
            if C_Timer and C_Timer.After then
                C_Timer.After(1, redraw)
                C_Timer.After(5, redraw)
            end
        end
        wipe(_waiting)
    end)

    -- Nach jedem Ladebildschirm ebenfalls einmal nachzeichnen.
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function()
        if _ready and C_Timer and C_Timer.After then C_Timer.After(1, redraw) end
    end)
end

-- Nur fuer /vgsfont: welche Schrift gerade vergeben wird, und eine frische
-- Messung beider Kandidaten.
local function measure(path)
    local fs = UIParent:CreateFontString(nil, "BACKGROUND")
    fs:SetFont(path, 12, "")
    fs:SetText("VuloGearSets")
    local w = fs:GetStringWidth() or 0
    fs:Hide()
    fs:SetText("")
    return w
end

function UI.GetResolvedFont()
    local probe = {
        candidates = {
            { path = FONT_PATH,     width = measure(FONT_PATH) },
            { path = FALLBACK_FONT, width = measure(FALLBACK_FONT) },
        },
        fallback = measure(STANDARD_TEXT_FONT),
    }
    return _ready and FONT_PATH or FALLBACK_FONT, _ready, probe
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

-- style bleibt als Parameter stehen (RestyleButtons reicht ihn durch);
-- das Aussehen entscheidet ns:ButtonLook, weil der Forever-Stil je nach
-- Theme Blizzards Knopfgrafik oder flache Knoepfe traegt.
local function styleButton(b, style, hovered)
    local blizzard = (ns:ButtonLook() == "blizzard")
    -- Der Dropdown-Pfeil haengt am Knopf und folgt derselben Farbe.
    if b.arrow then
        if blizzard then
            b.arrow:SetVertexColor(ns:AccentColor())
        else
            b.arrow:SetVertexColor(C.textDim.r, C.textDim.g, C.textDim.b)
        end
    end
    -- Mit Blizzards Grafik zeigt diese den gesperrten Zustand. Flach ist
    -- sie ausgeblendet, also muss die Schrift ihn tragen - sonst sieht ein
    -- gesperrter Knopf aus wie ein bedienbarer.
    local off = (b.IsEnabled and not b:IsEnabled()) and true or false
    if blizzard then
        setBlizzTextures(b, true)
        if b.bg then b.bg:Hide() end
        b.text:SetTextColor(ns:AccentColor())    -- Blizzard-Gold bzw. Theme-Akzent
    else
        setBlizzTextures(b, false)
        if b.bg then
            b.bg:Show()
            local ir, ig, ib, hr, hg, hb = ns:ButtonColors()
            if off then
                b.bg:SetColorTexture(C.bg.r, C.bg.g, C.bg.b, 1)
            elseif hovered then
                b.bg:SetColorTexture(hr, hg, hb, 1)
            else
                b.bg:SetColorTexture(ir, ig, ib, 1)
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
