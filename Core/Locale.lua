-- =========================================================
-- VuloGearSets / Core / Locale
-- Die Keys SIND der englische Text. Fehlt eine Uebersetzung,
-- liefert der Fallback den Key zurueck.
-- =========================================================
local _, ns = ...

ns.localeData = ns.localeData or {}

local _cached = nil

local function resolveLocale()
    if _cached then return _cached end
    _cached = (GetLocale and GetLocale()) or "enUS"
    return _cached
end

ns.L = setmetatable({}, {
    __index = function(_, key)
        local data = ns.localeData[resolveLocale()]
        if data and data[key] then return data[key] end
        return key
    end,
})

function ns:RegisterLocale(code, tbl)
    if type(code) ~= "string" or type(tbl) ~= "table" then return end
    ns.localeData[code] = ns.localeData[code] or {}
    for k, v in pairs(tbl) do
        ns.localeData[code][k] = v
    end
end
