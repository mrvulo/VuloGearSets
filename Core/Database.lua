-- =========================================================
-- VuloGearSets / Core / Database
-- Zwei SavedVariables, kein Profilsystem:
--   VuloGearSetsDB.modules[key]  -- kontoweite Darstellungsoptionen
--   VuloGearSetsCharDB           -- Sets, Bindungen, Position
-- =========================================================
local _, ns = ...

function ns:GetCharDB()
    _G.VuloGearSetsCharDB = _G.VuloGearSetsCharDB or {}
    return _G.VuloGearSetsCharDB
end

function ns:InitDB()
    _G.VuloGearSetsDB = _G.VuloGearSetsDB or {}
    local db = _G.VuloGearSetsDB
    db.modules = db.modules or {}
    db.style   = db.style or "modern"   -- "modern" | "classic", siehe Core/Skin.lua

    for key, mod in pairs(ns.modules) do
        db.modules[key] = ns:ApplyDefaults(db.modules[key], mod.defaults or {})
        mod.db = db.modules[key]
    end

    local char = ns:GetCharDB()
    char.sets        = char.sets        or {}
    char.specMapping = char.specMapping or {}
    char.formMapping = char.formMapping or {}
    char.modEnabled  = char.modEnabled  or {}

    ns.db = db
end
