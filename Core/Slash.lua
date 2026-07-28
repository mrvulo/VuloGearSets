-- =========================================================
-- VuloGearSets / Core / Slash
-- Allgemeine Slash-Befehle, die nicht an ein Modul haengen.
-- =========================================================
local _, ns = ...
local L = ns.L

-- Schriftdiagnose. Bleibt dauerhaft drin: wenn Texte unsichtbar sind
-- oder die falsche Schrift benutzt wird, ist das die erste Anlaufstelle.
SLASH_VGS_FONT1 = "/vgsfont"
SlashCmdList["VGS_FONT"] = function()
    local path, isWanted, probe = ns.UI.GetResolvedFont()
    ns:Print("Benutzte Schrift: %s", tostring(path))
    ns:Print("Expressway aktiv: %s", isWanted and "ja" or "NEIN")
    if not probe then return end
    -- Gemessene Textbreite je Kandidat. 0 heisst: der Client rendert mit
    -- dieser Datei nichts, egal was die API zurueckmeldet.
    for i, c in ipairs(probe.candidates or {}) do
        ns:Print("  [%d] Breite %.1f  %s", i, c.width or 0, c.path)
    end
    ns:Print("  Standardschrift: Breite %.1f", probe.fallback or 0)
end

-- Schnelles Neuladen. Belegen mehrere Addons /rl, ist das harmlos -
-- sie tun alle dasselbe. /reload und /reloadui bringt Blizzard schon mit.
SLASH_VGS_RELOAD1 = "/rl"
SlashCmdList["VGS_RELOAD"] = function()
    if InCombatLockdown and InCombatLockdown() then
        ns:Print(L["Not possible in combat."])
        return
    end
    ReloadUI()
end
