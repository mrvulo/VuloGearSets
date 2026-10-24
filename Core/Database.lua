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
    -- "classic" | "modern" | "forever" (nur auf Forever und dort Standard),
    -- siehe Core/Skin.lua
    db.style   = db.style or ns:DefaultStyle()
    -- Einmalig: laeuft VuloClassicUI, folgt der bisherige Standard "classic"
    -- dessen Aussehen (Nutzerentscheidung 2026-10-24). Eine spaeter von Hand
    -- gewaehlte Einstellung bleibt danach unangetastet.
    if not ns.isForever and not db._vuloClassicStyleMigrated
       and ns.IsVuloClassicLoaded and ns:IsVuloClassicLoaded() then
        if db.style == "classic" then db.style = "vuloclassic" end
        db._vuloClassicStyleMigrated = true
    end

    for key, mod in pairs(ns.modules) do
        db.modules[key] = ns:ApplyDefaults(db.modules[key], mod.defaults or {})
        mod.db = db.modules[key]
    end

    local char = ns:GetCharDB()
    char.sets        = char.sets        or {}
    char.specMapping = char.specMapping or {}
    char.formMapping = char.formMapping or {}
    char.keybinds    = char.keybinds    or {}
    char.modEnabled  = char.modEnabled  or {}

    ns.db = db
    -- Vor dem ersten Fenster: im Forever-Stil malt alles in dessen Farben.
    ns:ApplyStylePalette()
end
