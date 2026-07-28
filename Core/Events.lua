-- =========================================================
-- VuloGearSets / Core / Events
-- Ein gemeinsamer Frame verteilt an beliebig viele Handler.
-- =========================================================
local _, ns = ...

local frame    = CreateFrame("Frame", "VuloGearSetsEventFrame")
local handlers = {}

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    -- Rueckwaerts iterieren, damit ein Handler sich selbst abmelden darf.
    for i = #list, 1, -1 do
        local fn = list[i]
        if fn then
            local ok, err = pcall(fn, event, ...)
            if not ok then ns:Debug("Event %s: %s", event, tostring(err)) end
        end
    end
end)

function ns:RegisterEvent(event, handler)
    if type(event) ~= "string" or type(handler) ~= "function" then return end
    if not handlers[event] then
        handlers[event] = {}
        frame:RegisterEvent(event)
    end
    for _, fn in ipairs(handlers[event]) do
        if fn == handler then return end   -- schon registriert
    end
    table.insert(handlers[event], handler)
end

function ns:UnregisterEvent(event, handler)
    local list = handlers[event]
    if not list then return end
    if handler then
        for i = #list, 1, -1 do
            if list[i] == handler then table.remove(list, i) end
        end
    else
        wipe(list)
    end
    if #list == 0 then
        handlers[event] = nil
        frame:UnregisterEvent(event)
    end
end
