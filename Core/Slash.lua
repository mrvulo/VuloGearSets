-- =========================================================
-- VuloGearSets / Core / Slash
-- Allgemeine Slash-Befehle, die nicht an ein Modul haengen.
-- =========================================================
local _, ns = ...
local L = ns.L

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
