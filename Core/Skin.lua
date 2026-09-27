-- =========================================================
-- VuloGearSets / Core / Skin
-- Erscheinungsbilder fuer alle Fenster des Addons:
--
--   modern   dunkle Flaeche mit duennem Rand und lila Akzent
--   classic  Blizzards Dialograhmen, passend zum Standard-Interface
--   forever  nur auf WoW: Forever - das Aussehen von VuloForeverUI:
--            dessen Farben, Randstaerke und bei den Blizzard-Themes der
--            Metallrahmen des Clients
--
-- Alle laufen ueber SetBackdrop. Dadurch ist ein Wechsel nur ein
-- erneuter Aufruf auf denselben Frames - kein /reload noetig.
--
-- Jeder geskinnte Frame wird gemerkt, damit ns:SetStyle alle erreicht.
-- =========================================================
local _, ns = ...
local C = ns.COLORS

ns.UI = ns.UI or {}
local UI = ns.UI

-- Nur diese Werte sind gueltig; alles andere faellt auf den Standard.
-- Der Standard steht zuerst (siehe ns:DefaultStyle) - die Liste liest sich
-- sonst so, als waere ein anderer die Vorgabe. "forever" gibt es nur auf
-- dem Forever-Client, dort ist es der Standard.
ns.STYLES = {
    { value = "classic", text = "Classic" },
    { value = "modern",  text = "Modern"  },
}
if ns.isForever then
    table.insert(ns.STYLES, 1, { value = "forever", text = "Forever" })
end

local VALID = { classic = true, modern = true, forever = ns.isForever }

local registry = {}   -- { [frame] = kind }

function ns:DefaultStyle()
    return ns.isForever and "forever" or "classic"
end

function ns:GetStyle()
    local s = ns.db and ns.db.style
    if s and VALID[s] then return s end
    return ns:DefaultStyle()
end

-- =========================================================
-- Forever: das Aussehen von VuloForeverUI
--
-- Laeuft VuloForeverUI, kommen Farben und Rahmen live aus dessen aktivem
-- Theme (es legt seinen Namespace global als VuloForeverUI ab: COLORS ist
-- die fertig aufgeloeste Palette, theme die Rahmenangaben). Sonst gilt
-- dessen Standard-Theme, hier nachgebaut - damit VuloGearSets auf Forever
-- auch allein so aussieht wie die Familie.
-- =========================================================
local function rgb(r, g, b, a) return { r = r, g = g, b = b, a = a } end

local FOREVER_THEME = {
    edge = 2, art = "classic",
    window = { layout = "ButtonFrameTemplateNoPortrait",
               bgFile = "Interface\\FrameGeneral\\UI-Background-Rock" },
}
local FOREVER_COLORS = {
    accent  = rgb(1.0, 0.82, 0.0),
    bg      = rgb(0.04, 0.04, 0.035, 0.97), bgLight = rgb(0.03, 0.03, 0.025, 0.55),
    border  = rgb(0.48, 0.39, 0.21, 1),     borderDark = rgb(0.48, 0.39, 0.21, 1),
    text    = rgb(1, 1, 1),                 textDim = rgb(0.72, 0.68, 0.58),
    popup   = rgb(0.07, 0.06, 0.05, 0.98),
    control = rgb(0.42, 0.08, 0.04, 1),     controlHover = rgb(0.56, 0.12, 0.06, 1),
}

local function foreverSource()
    local vf = _G.VuloForeverUI
    if type(vf) == "table" and type(vf.theme) == "table" and type(vf.COLORS) == "table"
       and type(vf.COLORS.accent) == "table" then
        return vf.theme, vf.COLORS
    end
    return FOREVER_THEME, FOREVER_COLORS
end

local function foreverColor(key)
    local _, colors = foreverSource()
    local c = colors[key]
    if type(c) == "table" and type(c.r) == "number" then return c end
    return FOREVER_COLORS[key]
end

-- Die Blizzard-Themes von VuloForeverUI rahmen ihr Fenster mit dem Metall
-- des Clients. Hier kommt die schlichte Fassung davon (SimplePanelTemplate):
-- sie ist auf allen vier Seiten gleich stark, und die Fenster dieses Addons
-- ruecken ihren Inhalt ueberall um denselben Betrag ein (ns:FrameInset).
-- Die Fassung mit Titelleiste deckte oben den Inhalt ab.
local METAL_LAYOUT = "SimplePanelTemplate"

local function foreverHasMetal()
    local theme = foreverSource()
    return type(theme.window) == "table" and theme.window.layout ~= nil
        and _G.NineSliceUtil ~= nil and _G.NineSliceUtil.ApplyLayoutByName ~= nil
end

-- Blizzards Knopfgrafik statt der flachen Knoepfe: die Blizzard-Themes von
-- VuloForeverUI setzen dafuer art ("classic" oder "modern").
local function foreverHasButtonArt()
    local theme = foreverSource()
    return theme.art ~= nil
end

-- Die eigene Palette, bevor Forever sie ueberschreibt. ns.COLORS wird im
-- Forever-Stil an Ort und Stelle umgefaerbt (wie VuloForeverUI es mit
-- seinen Themes macht), damit jeder Maler, der dort liest, folgt.
local PALETTE_KEYS = { "accent", "bg", "bgLight", "border", "borderDark", "text", "textDim" }
local OWN_PALETTE = {}
for _, k in ipairs(PALETTE_KEYS) do
    local c = C[k]
    if c then OWN_PALETTE[k] = rgb(c.r, c.g, c.b) end
end

-- Schreibt die Palette des aktiven Stils nach ns.COLORS. Bereits gemalte
-- Flaechen, die ihre Farbe nur beim Bauen bekommen, folgen erst nach
-- einem /reload.
function ns:ApplyStylePalette()
    local forever = (ns:GetStyle() == "forever")
    for _, k in ipairs(PALETTE_KEYS) do
        local src = forever and foreverColor(k) or OWN_PALETTE[k]
        local dst = C[k]
        if dst and src then dst.r, dst.g, dst.b = src.r, src.g, src.b end
    end
end

-- =========================================================
-- Backdrop-Beschreibungen
--
-- "window" = eigenstaendiges Fenster, "pane" = Flaeche darin.
-- =========================================================
local BACKDROPS = {
    modern = {
        window = {
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        },
        pane = {
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        },
    },
    -- Nur die RAHMEN kommen von Blizzard. Als Grund dient eine eigene
    -- dunkle Flaeche: UI-DialogBox-Background wird auf dem Anniversary-
    -- Client nicht gezeichnet (Fenster blieb durchsichtig), und
    -- ChatFrameBackground ist eine weisse Textur, die eingefaerbt werden
    -- muss - ohne Einfaerbung leuchtet das Menue weiss.
    -- Die Insets ruecken die Grundflaeche vom Rand ein. Sie muessen KLEINER
    -- sein als der sichtbare Rahmen, damit die Flaeche unter ihn laeuft -
    -- sonst klafft dazwischen eine Luecke und man sieht durch.
    classic = {
        window = {
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = false, edgeSize = 32,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        },
        pane = {
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 16,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
    },
}

-- Farbtoene fuer den Classic-Stil: dunkel wie Blizzards Dialoge innen.
local CLASSIC_BG     = { r = 0.05, g = 0.05, b = 0.06, a = 0.95 }
local CLASSIC_PANE   = { r = 0.09, g = 0.09, b = 0.11, a = 0.95 }
local CLASSIC_BORDER = { r = 1,    g = 1,    b = 1,    a = 1    }   -- Textur faerben nicht

-- Farben je Stil. Im Classic-Stil traegt die Textur die Farbe, deshalb
-- bleibt der Grund dort weiss (= unveraendert) und nur die Deckkraft zaehlt.
local function applyColors(frame, style, kind)
    if style == "classic" then
        -- Der Grund ist eine weisse Textur und MUSS eingefaerbt werden,
        -- sonst leuchtet das ganze Fenster weiss. Nur der Rahmen bleibt
        -- ungefaerbt, der bringt seine Farbe selbst mit.
        local c = (kind == "pane") and CLASSIC_PANE or CLASSIC_BG
        frame:SetBackdropColor(c.r, c.g, c.b, c.a)
        frame:SetBackdropBorderColor(CLASSIC_BORDER.r, CLASSIC_BORDER.g,
                                     CLASSIC_BORDER.b, CLASSIC_BORDER.a)
        return
    end
    if kind == "pane" then
        frame:SetBackdropColor(C.bgLight.r, C.bgLight.g, C.bgLight.b, 0.95)
    else
        frame:SetBackdropColor(C.bg.r, C.bg.g, C.bg.b, 0.95)
    end
    frame:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 1)
end

-- Forever: flache Flaeche mit dem Rand des Themes (Staerke und Farbe);
-- Fenster tragen bei den Blizzard-Themes dazu den Fels-Hintergrund und
-- den Metallrahmen darueber.
local function foreverBackdrop(kind)
    local theme = foreverSource()
    local edge = tonumber(theme.edge) or 1
    local w = (kind == "window") and type(theme.window) == "table" and theme.window or nil
    local bgFile = w and w.bgFile
    return {
        bgFile   = bgFile or "Interface\\Buttons\\WHITE8X8",
        tile     = bgFile and true or false,
        tileSize = bgFile and 256 or nil,
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = edge,
        insets   = { left = edge, right = edge, top = edge, bottom = edge },
    }, (bgFile ~= nil)
end

-- Der Metallrahmen liegt als eigener Frame UEBER dem Fenster und seinen
-- Kindern (der Inhalt ist um ns:FrameInset eingerueckt und bleibt frei),
-- nimmt keine Maus und wird beim Stilwechsel nur versteckt.
local metal = setmetatable({}, { __mode = "k" })   -- [frame] = Rahmenframe | false

local function setMetal(frame, on)
    local art = metal[frame]
    if not on then
        if art then art:Hide() end
        return false
    end
    if art == nil then
        art = CreateFrame("Frame", nil, frame)
        art:SetAllPoints(frame)
        art:EnableMouse(false)
        if not pcall(NineSliceUtil.ApplyLayoutByName, art, METAL_LAYOUT) then
            art:Hide()
            art = false
        end
        metal[frame] = art
    end
    if not art then return false end
    art:SetFrameLevel((frame:GetFrameLevel() or 1) + 30)
    art:Show()
    return true
end

local function applyForever(frame, kind)
    local bd, textured = foreverBackdrop(kind)
    frame:SetBackdrop(bd)
    local hasMetal = (kind == "window") and foreverHasMetal() and setMetal(frame, true)
    if not hasMetal then setMetal(frame, false) end

    if textured then
        frame:SetBackdropColor(1, 1, 1, 1)
    else
        local c = (kind == "pane") and (foreverColor("popup") or C.bgLight) or C.bg
        frame:SetBackdropColor(c.r, c.g, c.b, c.a or 0.95)
    end
    local b = C.border
    -- Unter dem Metall bleibt die eigene Kante unsichtbar, sonst lugt sie
    -- an den Ecken hervor.
    frame:SetBackdropBorderColor(b.r, b.g, b.b, hasMetal and 0 or 1)
end

local function apply(frame, kind, style)
    if not frame or not frame.SetBackdrop then return end
    if style == "forever" then
        applyForever(frame, kind)
        return
    end
    setMetal(frame, false)
    frame:SetBackdrop(BACKDROPS[style][kind] or BACKDROPS[style].window)
    applyColors(frame, style, kind)
end

-- =========================================================
-- Oeffentlich
-- =========================================================

-- Frame skinnen und fuer spaetere Stilwechsel merken.
-- kind: "window" (Standard) oder "pane"
function UI:SkinFrame(frame, kind)
    if not frame then return frame end
    kind = kind or "window"
    if not frame.SetBackdrop then
        -- Ohne BackdropTemplate gibt es kein SetBackdrop. Lieber still
        -- bleiben als abstuerzen - der Frame ist dann eben ungeskinnt.
        ns:Debug("SkinFrame: %s kann kein SetBackdrop", tostring(frame:GetName()))
        return frame
    end
    registry[frame] = kind
    apply(frame, kind, ns:GetStyle())
    return frame
end

-- =========================================================
-- Farben, die vom Stil abhaengen
--
-- Im Classic-Stil traegt Blizzard-Gold den Akzent, sonst das Lila
-- der Vulo-Familie.
-- =========================================================
function ns:AccentColor()
    if ns:GetStyle() == "classic" then return 1, 0.82, 0 end
    -- Im Forever-Stil steht hier bereits der Akzent des Themes (siehe
    -- ns:ApplyStylePalette).
    return C.accent.r, C.accent.g, C.accent.b
end

-- Hinterlegung des ausgewaehlten Sets in der Seitenleiste.
-- Im Classic-Stil zurueckhaltender: der Goldton wirkt auf dem hellen
-- Blizzard-Rahmen sonst schnell zu massiv. Forever leitet sie aus dem
-- Akzent des Themes ab, damit jedes Theme seine eigene Farbe traegt.
function ns:SelectionColor()
    local style = ns:GetStyle()
    if style == "classic" then return 0.50, 0.39, 0.10, 0.38 end
    if style == "forever" then
        return C.accent.r * 0.5, C.accent.g * 0.5, C.accent.b * 0.5, 0.40
    end
    return 0.40, 0.30, 0.60, 0.45
end

-- Zusaetzlicher Innenabstand, den der Rahmen des Stils braucht.
-- Blizzards Dialograhmen ist deutlich breiter als der duenne Rand des
-- modernen Stils; ohne den Aufschlag sitzt der Inhalt im Rahmen. Der
-- Metallrahmen im Forever-Stil ist aehnlich stark.
function ns:FrameInset()
    local style = ns:GetStyle()
    if style == "classic" then return 8 end
    if style == "forever" and foreverHasMetal() then return 8 end
    return 0
end

-- Wie weit der Metallrahmen links ueber sein Fenster hinausragt. Die
-- Set-Leiste rueckt um so viel ab, damit das Metall nicht auf den Reitern
-- des Charakterfensters liegt.
function ns:WindowArtReach()
    if ns:GetStyle() == "forever" and foreverHasMetal() then return 5 end
    return 0
end

-- Hinterlegung beim Ueberfahren.
function ns:HoverColor()
    local style = ns:GetStyle()
    if style == "classic" then return 0.42, 0.34, 0.12, 0.40 end
    if style == "forever" then
        return C.accent.r * 0.4, C.accent.g * 0.4, C.accent.b * 0.4, 0.35
    end
    return 0.25, 0.20, 0.35, 0.40
end

-- Wie Knoepfe aussehen: "blizzard" = Blizzards Knopfgrafik (Classic-Stil
-- und die Blizzard-Themes von VuloForeverUI), sonst "flat".
function ns:ButtonLook()
    local style = ns:GetStyle()
    if style == "classic" then return "blizzard" end
    if style == "forever" and foreverHasButtonArt() then return "blizzard" end
    return "flat"
end

-- Grund eines flachen Knopfes: ruhend und ueberfahren. Forever nimmt die
-- Knopffarben des Themes, modern die eigenen.
function ns:ButtonColors()
    if ns:GetStyle() == "forever" then
        local idle, hover = foreverColor("control"), foreverColor("controlHover")
        return idle.r, idle.g, idle.b, hover.r, hover.g, hover.b
    end
    return C.bgLight.r, C.bgLight.g, C.bgLight.b,
           C.accent.r * 0.5, C.accent.g * 0.5, C.accent.b * 0.5
end

-- Module tragen sich hier ein, um auf einen Stilwechsel zu reagieren -
-- etwa um bereits erzeugte Zeilen neu einzufaerben.
local callbacks = {}
function ns:OnStyleChanged(fn)
    if type(fn) == "function" then callbacks[#callbacks + 1] = fn end
end

-- Alle gemerkten Frames neu zeichnen.
function ns:RefreshStyle()
    ns:ApplyStylePalette()
    local style = ns:GetStyle()
    for frame, kind in pairs(registry) do
        apply(frame, kind, style)
    end
    if UI.RestyleButtons then UI.RestyleButtons(style) end
    for _, fn in ipairs(callbacks) do pcall(fn, style) end
end

function ns:SetStyle(style)
    if not VALID[style] then style = ns:DefaultStyle() end
    if not ns.db then return end
    ns.db.style = style
    ns:RefreshStyle()
    if ns.RefreshOptions then ns:RefreshOptions() end
end
