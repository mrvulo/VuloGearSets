-- =========================================================
-- VuloGearSets / Core / Mover
-- Ein verschiebbarer Frame, kein Layoutsystem.
--
-- Vertrag (identisch zum Original, damit das Modul unveraendert bleibt):
--   ns:CreateMover(target, { key, label, db, width, height, applyPos })
--   Die Position lebt in opts.db.x / opts.db.y, nicht im Mover.
--   Nach jeder Aenderung wird opts.applyPos(mover) gerufen.
--
-- Im Edit-Modus liegt ein lila Kasten ueber dem Frame:
--   ziehen        -> verschieben
--   Pfeiltasten   -> 1px, mit Shift 5px
--   Rechtsklick   -> Position zuruecksetzen
-- =========================================================
local _, ns = ...
local L = ns.L

local editMode = false
local movers   = {}

function ns:IsMoverEditMode()
    return editMode
end

function ns:SetMoversEditMode(state)
    editMode = state and true or false
    for _, mover in ipairs(movers) do
        -- Nur zeigen, wenn der Zielframe selbst sichtbar ist.
        if editMode and mover.target:IsShown() then mover:Show() else mover:Hide() end
    end
    ns:Print(editMode
        and L["Edit mode enabled. Drag the purple box, arrow keys nudge, right-click resets."]
        or  L["Edit mode disabled."])
end

function ns:CreateMover(target, opts)
    opts = opts or {}
    local db = opts.db
    assert(db,     "ns:CreateMover braucht opts.db")
    assert(target, "ns:CreateMover braucht target")

    target:SetMovable(true)
    target:SetClampedToScreen(false)

    local mover = CreateFrame("Frame", nil, target)
    mover.target = target
    mover.opts   = opts
    mover.key    = opts.key
    mover:SetPoint("CENTER", target, "CENTER", 0, 0)
    mover:SetSize(opts.width or 200, opts.height or 40)
    mover:SetFrameStrata("HIGH")
    mover:EnableMouse(true)
    mover:Hide()

    mover.bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.bg:SetAllPoints(mover)
    mover.bg:SetColorTexture(0.6, 0.4, 1.0, 0.4)

    mover.border = CreateFrame("Frame", nil, mover,
        BackdropTemplateMixin and "BackdropTemplate")
    mover.border:SetAllPoints(mover)
    if mover.border.SetBackdrop then
        mover.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        mover.border:SetBackdropBorderColor(0.75, 0.35, 1, 1)
    end

    if opts.label then
        mover.label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
        mover.label:SetJustifyH("CENTER")
        mover.label:SetText(opts.label)
    end

    local function applyPos()
        if opts.applyPos then opts.applyPos(mover) end
    end

    -- Standardverhalten: frei ziehen, Mitte relativ zu UIParent speichern.
    -- Das Modul ueberschreibt beide Skripte, weil die Seitenleiste am
    -- Charakterfenster verankert bleiben muss.
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function() target:StartMoving() end)
    mover:SetScript("OnDragStop", function()
        target:StopMovingOrSizing()
        local fx, fy = target:GetCenter()
        local px, py = UIParent:GetCenter()
        if fx and fy and px and py then
            db.x, db.y = fx - px, fy - py
            applyPos()
        end
    end)

    mover:SetScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" then return end
        db.x, db.y = 0, 0
        applyPos()
        ns:Print(L["Sidebar position reset."])
    end)

    mover:EnableKeyboard(true)
    mover:SetPropagateKeyboardInput(true)
    mover:SetScript("OnKeyDown", function(self, key)
        if not editMode then self:SetPropagateKeyboardInput(true); return end
        local step = IsShiftKeyDown() and 5 or 1
        local dx, dy = 0, 0
        if     key == "UP"    then dy =  step
        elseif key == "DOWN"  then dy = -step
        elseif key == "LEFT"  then dx = -step
        elseif key == "RIGHT" then dx =  step
        else   self:SetPropagateKeyboardInput(true); return end
        self:SetPropagateKeyboardInput(false)
        db.x = (db.x or 0) + dx
        db.y = (db.y or 0) + dy
        applyPos()
    end)

    movers[#movers + 1] = mover
    return mover
end
