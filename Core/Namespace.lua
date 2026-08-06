-- =========================================================
-- VuloGearSets / Core / Namespace
-- Basis-Namespace, Farben und die Helfer, die ueberall gebraucht werden.
-- =========================================================
local _, ns = ...

ns.VERSION     = "1.11.1"
ns.modules     = {}
ns.moduleOrder = {}

-- Dieselbe Palette wie VuloClassicUI, damit beide Addons zusammenpassen.
ns.COLORS = {
    accent     = { r = 0.608, g = 0.424, b = 1 },
    bg         = { r = 0.06,  g = 0.06,  b = 0.08 },
    bgLight    = { r = 0.11,  g = 0.11,  b = 0.14 },
    border     = { r = 0.18,  g = 0.18,  b = 0.22 },
    borderDark = { r = 0.02,  g = 0.02,  b = 0.03 },
    text       = { r = 0.90,  g = 0.90,  b = 0.92 },
    textDim    = { r = 0.60,  g = 0.60,  b = 0.65 },
}

local PREFIX = "|cff9b6cffVuloGearSets|r: "

function ns:Print(fmt, ...)
    if not fmt then return end
    local msg = fmt
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, fmt, ...)
        if ok then msg = formatted end
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

-- Nur aktiv, wenn jemand VuloGearSetsDB.debug von Hand setzt.
function ns:Debug(fmt, ...)
    local db = _G.VuloGearSetsDB
    if not (db and db.debug) then return end
    ns:Print("|cff888888[debug]|r " .. tostring(fmt), ...)
end

-- Das Eingabefeld eines StaticPopup heisst je nach Client anders: im neuen
-- GameDialog self.EditBox, im alten StaticPopup self.editBox, in ganz alten
-- Fassungen nur global unter <popupName>EditBox. Alle drei abfragen, sonst
-- bricht jeder Dialog mit Eingabefeld auf dem falschen Client ab.
function ns.PopupEditBox(popup)
    if not popup then return nil end
    return popup.EditBox or popup.editBox
        or (popup.GetName and _G[(popup:GetName() or "") .. "EditBox"])
end

function ns:DeepCopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do
        out[k] = (type(v) == "table") and ns:DeepCopy(v) or v
    end
    return out
end

-- Ergaenzt fehlende Default-Werte, ohne vorhandene zu ueberschreiben.
function ns:ApplyDefaults(target, defaults)
    if type(target) ~= "table" then target = {} end
    if type(defaults) ~= "table" then return target end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            target[k] = ns:ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end
