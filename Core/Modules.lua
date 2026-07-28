-- =========================================================
-- VuloGearSets / Core / Modules
-- Modulregistry.
--
-- def = {
--   name        = "Anzeigename",
--   description = "Was das Modul tut",
--   defaults    = { enabled = true, ... },
--   OnEnable    = function(self) end,
--   OnDisable   = function(self) end,
--   GetOptions  = function(self) return { ... } end,
-- }
-- =========================================================
local _, ns = ...
local L = ns.L

function ns:RegisterModule(key, def)
    if ns.modules[key] then
        ns:Print(L["WARN: Module '%s' already registered."], key)
        return ns.modules[key]
    end
    def.key      = key
    def.name     = def.name or key
    def.defaults = def.defaults or {}
    if def.defaults.enabled == nil then
        def.defaults.enabled = true
    end
    ns.modules[key] = def
    table.insert(ns.moduleOrder, key)
    return def
end

-- Ein/Aus liegt PRO CHARAKTER, alles andere kontoweit.
function ns:IsModuleEnabled(key)
    local mod = ns.modules[key]
    if not mod then return false end
    local ov = ns:GetCharDB().modEnabled
    if ov[key] ~= nil then return ov[key] end
    return (mod.db and mod.db.enabled) and true or false
end

function ns:SetModuleEnabledPref(key, state)
    ns:GetCharDB().modEnabled[key] = state and true or false
end

function ns:SafeEnable(mod)
    if mod._enabled then return end
    if not mod.OnEnable then mod._enabled = true; return end
    local ok, err = pcall(mod.OnEnable, mod)
    if not ok then
        ns:Print(L["|cffff5555Error enabling module '%s':|r %s"], mod.name, tostring(err))
        return
    end
    mod._enabled = true
    ns:Debug("Module enabled: %s", mod.name)
end

function ns:SafeDisable(mod)
    if not mod._enabled then return end
    if mod.OnDisable then
        local ok, err = pcall(mod.OnDisable, mod)
        if not ok then
            ns:Print(L["|cffff5555Error disabling '%s':|r %s"], mod.name, tostring(err))
        end
    end
    mod._enabled = false
end

function ns:EnableModules()
    for _, key in ipairs(ns.moduleOrder) do
        local mod = ns.modules[key]
        if mod and ns:IsModuleEnabled(key) then
            ns:SafeEnable(mod)
        end
    end
end

function ns:ToggleModule(key, state, silent)
    local mod = ns.modules[key]
    if not mod then return end
    state = state and true or false
    ns:SetModuleEnabledPref(key, state)
    if state then
        ns:SafeEnable(mod)
        return
    end
    ns:SafeDisable(mod)
    -- Viele Hooks lassen sich zur Laufzeit nicht loesen.
    if not silent then
        ns:Print(L["Module '%s' disabled. /reload recommended for full effect."], mod.name)
    end
end
