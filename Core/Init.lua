-- =========================================================
-- VuloGearSets / Core / Init
-- Startreihenfolge: Datenbank -> Import -> Module.
-- =========================================================
local _, ns = ...

local function onLogin()
    ns:InitDB()
    ns:ImportFromVuloClassicUI()
    ns:EnableModules()
    -- Nach EnableModules, damit der Hinweis in der Chatausgabe unter
    -- den Meldungen der Module steht und nicht davor.
    ns:WarnIfVuloAlsoRunning()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    onLogin()
end)
