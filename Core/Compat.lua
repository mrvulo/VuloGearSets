-- =========================================================
-- VuloGearSets / Core / Compat
-- API-Shims fuer das, was die Module NICHT selbst abfangen.
-- Die Container-Funktionen bringen GearSets und SlotPicker
-- bereits als eigene lokale Fallbacks mit.
-- =========================================================
local _, ns = ...

function ns:IsAddOnLoaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    if not fn then return false end
    local ok, loaded = pcall(fn, name)
    return ok and loaded and true or false
end
