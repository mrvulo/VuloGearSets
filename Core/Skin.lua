-- =========================================================
-- VuloGearSets / Core / Skin
-- Zwei Erscheinungsbilder fuer alle Fenster des Addons:
--
--   modern   dunkle Flaeche mit duennem Rand und lila Akzent
--   classic  Blizzards Dialograhmen, passend zum Standard-Interface
--
-- Beide laufen ueber SetBackdrop. Dadurch ist ein Wechsel nur ein
-- erneuter Aufruf auf denselben Frames - kein /reload noetig.
--
-- Jeder geskinnte Frame wird gemerkt, damit ns:SetStyle alle erreicht.
-- =========================================================
local _, ns = ...
local C = ns.COLORS

ns.UI = ns.UI or {}
local UI = ns.UI

-- Nur diese beiden Werte sind gueltig; alles andere faellt auf classic.
ns.STYLES = {
    { value = "modern",  text = "Modern"  },
    { value = "classic", text = "Classic" },
}

local registry = {}   -- { [frame] = kind }

function ns:GetStyle()
    local s = ns.db and ns.db.style
    return (s == "modern") and "modern" or "classic"
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

local function apply(frame, kind, style)
    if not frame or not frame.SetBackdrop then return end
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
    return C.accent.r, C.accent.g, C.accent.b
end

-- Hinterlegung des ausgewaehlten Sets in der Seitenleiste.
-- Im Classic-Stil zurueckhaltender: der Goldton wirkt auf dem hellen
-- Blizzard-Rahmen sonst schnell zu massiv.
function ns:SelectionColor()
    if ns:GetStyle() == "classic" then return 0.50, 0.39, 0.10, 0.38 end
    return 0.40, 0.30, 0.60, 0.45
end

-- Zusaetzlicher Innenabstand, den der Rahmen des Stils braucht.
-- Blizzards Dialograhmen ist deutlich breiter als der duenne Rand des
-- modernen Stils; ohne den Aufschlag sitzt der Inhalt im Rahmen.
function ns:FrameInset()
    return (ns:GetStyle() == "classic") and 8 or 0
end

-- Hinterlegung beim Ueberfahren.
function ns:HoverColor()
    if ns:GetStyle() == "classic" then return 0.42, 0.34, 0.12, 0.40 end
    return 0.25, 0.20, 0.35, 0.40
end

-- Module tragen sich hier ein, um auf einen Stilwechsel zu reagieren -
-- etwa um bereits erzeugte Zeilen neu einzufaerben.
local callbacks = {}
function ns:OnStyleChanged(fn)
    if type(fn) == "function" then callbacks[#callbacks + 1] = fn end
end

-- Alle gemerkten Frames neu zeichnen.
function ns:RefreshStyle()
    local style = ns:GetStyle()
    for frame, kind in pairs(registry) do
        apply(frame, kind, style)
    end
    if UI.RestyleButtons then UI.RestyleButtons(style) end
    for _, fn in ipairs(callbacks) do pcall(fn, style) end
end

function ns:SetStyle(style)
    if style ~= "modern" then style = "classic" end
    if not ns.db then return end
    ns.db.style = style
    ns:RefreshStyle()
    if ns.RefreshOptions then ns:RefreshOptions() end
end
