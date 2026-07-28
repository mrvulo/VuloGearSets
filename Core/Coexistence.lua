-- =========================================================
-- VuloGearSets / Core / Coexistence
-- Uebernimmt einmalig die Sets aus VuloClassicUI und weist auf
-- Doppelbetrieb hin. Kein Schlafmodus: VuloGearSets laeuft immer.
--
-- VuloClassicUIs SavedVariables werden ausschliesslich GELESEN.
-- =========================================================
local _, ns = ...
local L = ns.L

-- Einmaliger Import. Gibt die Anzahl uebernommener Sets zurueck.
function ns:ImportFromVuloClassicUI()
    local char = ns:GetCharDB()
    if char.imported then return 0 end

    local src = _G.VuloClassicUICharDB
    if not src then
        -- Nicht installiert: nichts zu holen. Bewusst NICHT als erledigt
        -- markieren, damit ein spaeterer Start noch importieren kann.
        return 0
    end

    char.imported = true

    local n = 0
    for name, data in pairs(src.loadouts or {}) do
        if not char.sets[name] then
            char.sets[name] = ns:DeepCopy(data)
            n = n + 1
        end
    end
    for name, g in pairs(src.specMapping or {}) do
        if char.specMapping[name] == nil then char.specMapping[name] = g end
    end
    for name, g in pairs(src.formMapping or {}) do
        if char.formMapping[name] == nil then char.formMapping[name] = g end
    end

    if n > 0 then
        ns:Print(L["Imported %d gear set(s) from VuloClassicUI onto this character."], n)
    end
    return n
end

-- Reiner Hinweis, einmal pro Sitzung. Aendert nichts am Verhalten.
function ns:WarnIfVuloAlsoRunning()
    if not ns:IsAddOnLoaded("VuloClassicUI") then return end

    -- Modulzustand: pro Charakter in modEnabled, sonst der Profil-Default.
    local active
    local charDB = _G.VuloClassicUICharDB
    local ov = charDB and charDB.modEnabled
    if ov and ov.loadouts ~= nil then
        active = ov.loadouts and true or false
    else
        local db   = _G.VuloClassicUIDB
        local prof = db and db.profiles and db.profiles[db.activeProfile or "Default"]
        local m    = prof and prof.modules and prof.modules.loadouts
        -- Vulo setzt enabled per Default auf true; nur ein explizites false zaehlt als aus.
        active = not (m and m.enabled == false)
    end
    if not active then return end

    ns:Print(L["VuloClassicUI also manages gear sets, so you will see two minimap buttons and two sidebars. Disable one of them if that bothers you."])
end
