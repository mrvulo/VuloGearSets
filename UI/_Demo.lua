-- =========================================================
-- VuloGearSets / UI / _Demo   TEMPORAER
--
-- Nur zum Sichtpruefen der UI-Schicht, solange Modules/GearSets.lua
-- noch nicht portiert ist. Wird in Task 7 samt TOC-Zeile geloescht.
--
-- /vgsdemo    Widgets einzeln
-- /vgsopt     Optionsfenster mit allen neun Item-Typen
-- /vgsmover   Mover an einem Testframe
-- =========================================================
local _, ns = ...
local UI = ns.UI

-- ---------------------------------------------------------
-- Schrift-Diagnose
-- ---------------------------------------------------------
SLASH_VGSFONT1 = "/vgsfont"
SlashCmdList["VGSFONT"] = function()
    local path, isExpressway = UI.GetResolvedFont()
    ns:Print("Benutzte Schrift: %s", tostring(path))
    ns:Print("Expressway aktiv: %s", isExpressway and "ja" or "NEIN")

    -- Direkter Ladeversuch, unabhaengig vom gemerkten Ergebnis.
    local probe = CreateFont("VuloGearSetsFontProbe2")
    local ok = probe and probe:SetFont(UI.FONT_PATH, 12, "")
    ns:Print("Direkter Ladeversuch: %s", ok and "erfolgreich" or "fehlgeschlagen")
    ns:Print("Erwarteter Pfad: %s", UI.FONT_PATH)
end

-- ---------------------------------------------------------
-- Widgets einzeln
-- ---------------------------------------------------------
SLASH_VGSDEMO1 = "/vgsdemo"
SlashCmdList["VGSDEMO"] = function()
    if _G.VuloGearSetsDemo then _G.VuloGearSetsDemo:Show(); return end
    local f = CreateFrame("Frame", "VuloGearSetsDemo", UIParent)
    f:SetSize(320, 230)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    UI:CreateBackdrop(f)
    UI:CreateShadow(f)
    tinsert(UISpecialFrames, "VuloGearSetsDemo")

    local t = UI:CreateToggle(f, "Demo toggle")
    t:SetPoint("TOPLEFT", 16, -16); t:SetWidth(280); t:SetChecked(true)
    t.OnValueChanged = function(v) ns:Print("toggle %s", tostring(v)) end

    local s = UI:CreateSlider(f, "Demo slider", 4, 14, 1)
    s:SetPoint("TOPLEFT", 16, -50); s:SetValue(8)
    s.OnValueChanged = function(v) ns:Print("slider %d", v) end

    local d = UI:CreateDropdown(f, "Demo dropdown", {
        { value = "a", text = "Option A" },
        { value = "b", text = "Option B" },
        { value = "c", text = "Option C" },
    })
    d:SetPoint("TOPLEFT", 16, -104); d:SetValue("a")
    d.OnValueChanged = function(v) ns:Print("dropdown %s", v) end

    local b = UI:CreateButton(f, "Demo button", 130, 22)
    b:SetPoint("TOPLEFT", 16, -170)
    b._tooltip = "Tooltip am Button"
    b:SetOnClick(function() ns:Print("button ok") end)
end

-- ---------------------------------------------------------
-- Optionsfenster: haengt ein Pseudo-Modul ein, das alle
-- neun Item-Typen benutzt.
-- ---------------------------------------------------------
local demoState = { toggle = true, slider = 8, dropdown = "a" }

SLASH_VGSOPT1 = "/vgsopt"
SlashCmdList["VGSOPT"] = function()
    ns.modules.gearsets = ns.modules.gearsets or {
        GetOptions = function()
            return {
                { type = "header", text = "Demo header" },
                { type = "desc",   text = "Ein laengerer Beschreibungstext, der ueber mehrere "
                                       .. "Zeilen umbrechen soll, damit die Hoehenberechnung "
                                       .. "sichtbar wird." },
                { type = "spacer", height = 6 },
                { type = "group", layout = "row", gap = 6, items = {
                    { type = "button", label = "Eins", width = 80,
                      onClick = function() ns:Print("Eins") end },
                    { type = "button", label = "Zwei", width = 80,
                      onClick = function() ns:Print("Zwei") end },
                    { type = "button", label = "Drei", width = 80,
                      onClick = function() ns:Print("Drei") end },
                } },
                { type = "toggle", label = "Demo toggle", tooltip = "Tooltip am Toggle",
                  get = function() return demoState.toggle end,
                  set = function(_, v) demoState.toggle = v; ns:Print("toggle %s", tostring(v)) end },
                { type = "spacer", height = 6 },
                { type = "section", title = "Aufklappbare Sektion", collapsed = false, items = {
                    { type = "desc", text = "Inhalt der Sektion." },
                    { type = "slider", label = "Demo slider", min = 4, max = 14, step = 1,
                      tooltip = "Tooltip am Slider",
                      get = function() return demoState.slider end,
                      set = function(_, v) demoState.slider = v; ns:Print("slider %d", v) end },
                    { type = "dropdown", label = "Demo dropdown", tooltip = "Tooltip am Dropdown",
                      values = {
                          { value = "a", text = "Option A" },
                          { value = "b", text = "Option B" },
                      },
                      get = function() return demoState.dropdown end,
                      set = function(_, v) demoState.dropdown = v; ns:Print("dropdown %s", v) end },
                } },
                { type = "section", title = "Zugeklappte Sektion", collapsed = true, items = {
                    { type = "desc", text = "Sollte erst nach dem Aufklappen sichtbar sein." },
                } },
            }
        end,
    }
    ns:ToggleOptions()
end

-- ---------------------------------------------------------
-- Mover an einem Testframe
-- ---------------------------------------------------------
SLASH_VGSMOVER1 = "/vgsmover"
SlashCmdList["VGSMOVER"] = function()
    if not _G.VuloGearSetsMoverDemo then
        local f = CreateFrame("Frame", "VuloGearSetsMoverDemo", UIParent)
        f:SetSize(180, 60)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
        UI:CreateBackdrop(f)
        local fs = f:CreateFontString(nil, "OVERLAY")
        UI.Font(fs, 12)
        fs:SetPoint("CENTER")
        fs:SetText("Testframe")

        ns:GetCharDB().demoPos = ns:GetCharDB().demoPos or { x = 0, y = 150 }
        local pos = ns:GetCharDB().demoPos
        ns:CreateMover(f, {
            key    = "demo",
            label  = "DEMO",
            db     = pos,
            width  = 180,
            height = 60,
            applyPos = function()
                f:ClearAllPoints()
                f:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
            end,
        })
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
    end
    ns:SetMoversEditMode(not ns:IsMoverEditMode())
end
