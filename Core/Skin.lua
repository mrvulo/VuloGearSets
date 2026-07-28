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

-- Nur diese beiden Werte sind gueltig; alles andere faellt auf modern.
ns.STYLES = {
    { value = "modern",  text = "Modern"  },
    { value = "classic", text = "Classic" },
}

local registry = {}   -- { [frame] = kind }

function ns:GetStyle()
    local s = ns.db and ns.db.style
    return (s == "classic") and "classic" or "modern"
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
    classic = {
        -- Derselbe Rahmen, den Blizzards Dialoge benutzen.
        window = {
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        },
        -- Der schmalere Tooltip-Rahmen fuer Flaechen innerhalb eines Fensters.
        pane = {
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 3, right = 3, top = 5, bottom = 3 },
        },
    },
}

-- Farben je Stil. Im Classic-Stil traegt die Textur die Farbe, deshalb
-- bleibt der Grund dort weiss (= unveraendert) und nur die Deckkraft zaehlt.
local function applyColors(frame, style, kind)
    if style == "classic" then
        frame:SetBackdropColor(1, 1, 1, 1)
        frame:SetBackdropBorderColor(1, 1, 1, 1)
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

-- Alle gemerkten Frames neu zeichnen.
function ns:RefreshStyle()
    local style = ns:GetStyle()
    for frame, kind in pairs(registry) do
        apply(frame, kind, style)
    end
    if UI.RestyleButtons then UI.RestyleButtons(style) end
end

function ns:SetStyle(style)
    if style ~= "classic" then style = "modern" end
    if not ns.db then return end
    ns.db.style = style
    ns:RefreshStyle()
    if ns.RefreshOptions then ns:RefreshOptions() end
end
