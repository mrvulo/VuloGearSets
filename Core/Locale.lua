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

-- Das Ergebnis wird per rawset in die Tabelle geschrieben: jeder Key wird
-- nur einmal aufgeloest, danach ist der Zugriff ein einfacher Tabellenzugriff
-- ohne Umweg ueber die Metatabelle. Gefahrlos, weil alle Locale-Dateien vor
-- dem ersten L[]-Zugriff der Module geladen sind (siehe TOC-Reihenfolge).
ns.L = setmetatable({}, {
    __index = function(t, key)
        local data = ns.localeData[resolveLocale()]
        local value = (data and data[key]) or key
        rawset(t, key, value)
        return value
    end,
})

function ns:RegisterLocale(code, tbl)
    if type(code) ~= "string" or type(tbl) ~= "table" then return end
    ns.localeData[code] = ns.localeData[code] or {}
    for k, v in pairs(tbl) do
        ns.localeData[code][k] = v
    end
end
