-- =========================================================
-- VuloGearSets / Core / Events
-- Ein gemeinsamer Frame verteilt an beliebig viele Handler.
-- =========================================================
local _, ns = ...

local frame    = CreateFrame("Frame", "VuloGearSetsEventFrame")
local handlers = {}

-- Waehrend ein Ereignis verteilt wird, entfernt UnregisterEvent nichts aus
-- der Liste, es setzt den Eintrag nur auf false: sonst verschoeben sich die
-- Indizes, und ein Handler liefe im selben Ereignis doppelt oder gar nicht
-- (z. B. wenn ein Handler einen anderen abmeldet). Aufgeraeumt wird danach.
-- Ohne Kopie der Liste, weil UNIT_AURA und BAG_UPDATE sehr oft feuern.
local dispatching = 0
local dirty = {}

local function compact(event)
    local list = handlers[event]
    if not list then return end
    for i = #list, 1, -1 do
        if not list[i] then table.remove(list, i) end
    end
    if #list == 0 then
        handlers[event] = nil
        frame:UnregisterEvent(event)
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    dispatching = dispatching + 1
    -- Rueckwaerts wie bisher; waehrend des Verteilens neu angemeldete
    -- Handler (hinten angehaengt) laufen erst beim naechsten Mal.
    for i = #list, 1, -1 do
        local fn = list[i]
        if fn then
            local ok, err = pcall(fn, event, ...)
            if not ok then ns:Debug("Event %s: %s", event, tostring(err)) end
        end
    end
    dispatching = dispatching - 1
    if dispatching == 0 and next(dirty) then
        for ev in pairs(dirty) do compact(ev) end
        wipe(dirty)
    end
end)

function ns:RegisterEvent(event, handler)
    if type(event) ~= "string" or type(handler) ~= "function" then return end
    if not handlers[event] then
        -- Ein Ereignis, das der Client nicht kennt, wirft einen Fehler und
        -- bricht sonst die ganze aufrufende Datei ab (Forever kennt nicht
        -- jedes Talent-Ereignis der Classic-Clients und umgekehrt).
        if not pcall(frame.RegisterEvent, frame, event) then return end
        handlers[event] = {}
    end
    -- Zaehlschleife statt ipairs: abgemeldete Eintraege stehen waehrend
    -- des Verteilens als false in der Liste, ipairs liefe weiter, aber so
    -- ist es ohne Nachdenken richtig.
    local list = handlers[event]
    for i = 1, #list do
        if list[i] == handler then return end   -- schon registriert
    end
    table.insert(handlers[event], handler)
end

function ns:UnregisterEvent(event, handler)
    local list = handlers[event]
    if not list then return end
    for i = #list, 1, -1 do
        if not handler or list[i] == handler then list[i] = false end
    end
    if dispatching > 0 then
        dirty[event] = true
    else
        compact(event)
    end
end
