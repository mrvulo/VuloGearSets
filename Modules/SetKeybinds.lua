-- =========================================================
-- VuloGearSets / Modules / SetKeybinds
-- Ein Set auf eine Taste legen: Rechtsklick auf die Set-Zeile ->
-- "Taste belegen...", der naechste Tastendruck wird uebernommen. Die
-- Taste legt das Set an, genau wie der Doppelklick auf die Zeile - also
-- auch nur die Teile, die in den Taschen liegen (bei offener Bank auch
-- die von dort).
--
-- WARUM OVERRIDE-BINDINGS
--   SetBinding wuerde Blizzards gespeicherte Tastenbelegung des Spielers
--   umschreiben und muesste mit SaveBindings festgehalten werden - ein
--   Eingriff, der einen Reload ueberlebt und nach dem Abschalten des
--   Addons stehen bliebe. Override-Bindings haengen an einem eigenen
--   Besitzer-Frame, gelten nur solange das Addon laeuft, und sind mit
--   einem einzigen ClearOverrideBindings wieder weg. Preis dafuer: die
--   Belegung taucht in Blizzards Tastenbelegung nicht auf und deckt dort
--   Vergebenes zu, solange sie gilt.
--
-- WARUM EIN KNOPF JE BELEGUNG
--   Eine Taste kann nur auf einen Klick eines BENANNTEN Knopfes gelegt
--   werden. Die Knoepfe sind unsichtbar, tragen den Setnamen und rufen
--   beim Klick ns:EquipGearSet - keine geschuetzte Aktion, deshalb reicht
--   ein gewoehnlicher Button ohne Secure-Vorlage.
--
-- PRO CHARAKTER
--   Die Sets liegen in der Charakter-Datenbank, ihre Tasten deshalb auch.
--   Ein Set namens "Tank" auf dem Krieger hat mit dem "Tank" des
--   Druiden nichts zu tun.
-- =========================================================
local _, ns = ...
local L = ns.L

local mod = ns:RegisterModule("setkeybinds", {
    name     = "Set Keybinds",
    group    = "_hidden",
    defaults = { enabled = true },
})

-- =========================================================
-- Speicherung: { [Setname] = "SHIFT-1" }
-- =========================================================
local function keyMap()
    local c = ns:GetCharDB()
    c.keybinds = c.keybinds or {}
    return c.keybinds
end

local function sets()
    local c = ns:GetCharDB()
    c.sets = c.sets or {}
    return c.sets
end

-- Lesbarer Name der Taste. GetBindingText uebersetzt "SHIFT-1" in die
-- Sprache des Clients; wo es das nicht gibt, tut es der Rohwert.
function ns:KeybindText(key)
    if type(key) ~= "string" or key == "" then return nil end
    if GetBindingText then
        local ok, txt = pcall(GetBindingText, key, "KEY_")
        if ok and type(txt) == "string" and txt ~= "" then return txt end
    end
    return key
end

function ns:GetSetKeybind(name)
    local key = keyMap()[name]
    if type(key) == "string" and key ~= "" then return key end
    return nil
end

-- =========================================================
-- Die unsichtbaren Knoepfe, auf die die Tasten zeigen
-- =========================================================
local owner = CreateFrame("Frame", "VGS_SetKeybindOwner", UIParent)
local runners = {}

local function getRunner(idx)
    local btn = runners[idx]
    if btn then return btn end
    btn = CreateFrame("Button", "VGS_SetKeybindRunner" .. idx, UIParent)
    -- Bewusst NICHT versteckt: ein Frame, den es auf dem Bildschirm nicht
    -- gibt, nimmt den Klick einer Bindung nicht zwingend an. Stattdessen
    -- ein Pixel in der Ecke, unsichtbar und ohne Mausannahme - anfassen
    -- kann ihn damit niemand, die Bindung erreicht ihn trotzdem.
    btn:SetSize(1, 1)
    btn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    btn:SetAlpha(0)
    btn:EnableMouse(false)
    -- Nur beim Loslassen: eine Bindung schickt Druck UND Loslassen an den
    -- Knopf. Waeren beide registriert, legte ein Tastendruck das Set zweimal an.
    btn:RegisterForClicks("AnyUp")
    btn:SetScript("OnClick", function(self)
        if not self.setName then return end
        if not ns:IsModuleEnabled("setkeybinds") then return end
        -- Sperre gegen einen doppelten Anlauf: schicken kuenftige Clients
        -- Druck UND Loslassen an einen Knopf, der nur auf eines registriert
        -- ist, liefe das Anlegen sonst zweimal und schriebe seine Meldung
        -- doppelt in den Chat. Zwei Tastendrucke in einer Fuenftelsekunde
        -- meint ohnehin niemand ernst.
        local now = GetTime and GetTime() or 0
        if self._lastRun and (now - self._lastRun) < 0.2 then return end
        self._lastRun = now
        ns:EquipGearSet(self.setName)
    end)
    runners[idx] = btn
    return btn
end

-- =========================================================
-- Anwenden
--
-- Immer alles neu setzen statt einzelne Tasten nachzupflegen: die Liste
-- ist kurz, und so kann keine geloeschte Belegung liegen bleiben.
-- =========================================================
local _pending = false

local function bindingAPI()
    return SetOverrideBindingClick and ClearOverrideBindings
end

local function applyBindings()
    if not bindingAPI() then return end
    -- Bindungen sind im Kampf gesperrt. Nachholen, sobald er vorbei ist -
    -- sonst faehrt eine im Kampf geaenderte Belegung erst nach dem naechsten
    -- Reload los.
    if InCombatLockdown() then
        _pending = true
        return
    end
    _pending = false

    ClearOverrideBindings(owner)
    if not ns:IsModuleEnabled("setkeybinds") then return end

    local known = sets()
    local n = 0
    for name, key in pairs(keyMap()) do
        -- Nur fuer Sets, die es noch gibt. Eine verwaiste Belegung wuerde
        -- sonst eine Taste blockieren und dabei nichts tun.
        if type(key) == "string" and key ~= "" and known[name] then
            n = n + 1
            local btn = getRunner(n)
            btn.setName = name
            SetOverrideBindingClick(owner, false, key, btn:GetName(), "LeftButton")
        end
    end
end

-- =========================================================
-- Belegen, loeschen, umbenennen
-- =========================================================
function ns:SetSetKeybind(name, key)
    if not sets()[name] then
        ns:Print(string.format(L["Gear set '%s' does not exist."], name))
        return
    end

    -- Eine Taste gehoert genau einem Set. Wird sie neu vergeben, verliert
    -- der bisherige Besitzer sie - und erfaehrt davon.
    for other, k in pairs(keyMap()) do
        if k == key and other ~= name then
            keyMap()[other] = nil
            ns:Print(string.format(L["%s was taken from '%s'."],
                ns:KeybindText(key), other))
        end
    end

    keyMap()[name] = key
    applyBindings()
    ns:Print(string.format(L["'%s' is now on %s."], name, ns:KeybindText(key)))
end

function ns:ClearSetKeybind(name, silent)
    if not keyMap()[name] then return end
    keyMap()[name] = nil
    applyBindings()
    if not silent then
        ns:Print(string.format(L["'%s' no longer has a key."], name))
    end
end

-- Beim Umbenennen zieht die Taste mit, wie Spec- und Gestalt-Bindung auch.
function ns:RenameSetKeybind(oldName, newName)
    local key = keyMap()[oldName]
    if not key then return end
    keyMap()[oldName] = nil
    keyMap()[newName] = key
    applyBindings()
end

-- =========================================================
-- Abfrage der Taste
--
-- Ein eigener Frame statt eines StaticPopup: der muss die Tastatur an
-- sich ziehen und jeden Druck abfangen, auch Leertaste und Zahlen, die
-- ein Dialog sonst weiterreicht.
-- =========================================================
local capture

-- Reine Modifikatoren sind keine Belegung, sie gehoeren zur naechsten Taste.
local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true,
    LCTRL  = true, RCTRL  = true,
    LALT   = true, RALT   = true,
    UNKNOWN = true,
}

-- Maustasten, die man gefahrlos belegen kann. Links und rechts bleiben
-- aussen vor: mit denen wird die Abfrage selbst bedient.
local MOUSE_KEYS = {
    MiddleButton = "BUTTON3",
    Button4      = "BUTTON4",
    Button5      = "BUTTON5",
}

local function withModifiers(key)
    -- Reihenfolge wie in Blizzards Bindungen: ALT-CTRL-SHIFT-TASTE.
    local prefix = ""
    if IsAltKeyDown()     then prefix = prefix .. "ALT-"   end
    if IsControlKeyDown() then prefix = prefix .. "CTRL-"  end
    if IsShiftKeyDown()   then prefix = prefix .. "SHIFT-" end
    return prefix .. key
end

local function finishCapture(key)
    local name = capture and capture.setName
    capture:Hide()
    if name and key then ns:SetSetKeybind(name, key) end
end

local function createCapture()
    if capture then return capture end
    capture = CreateFrame("Frame", "VGS_KeybindCapture", UIParent,
        BackdropTemplateMixin and "BackdropTemplate")
    capture:SetFrameStrata("FULLSCREEN_DIALOG")
    capture:SetSize(340, 110)
    capture:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    capture:Hide()
    capture:EnableMouse(true)
    capture:EnableKeyboard(true)
    ns.UI:SkinFrame(capture, "window")
    if ns.UI.CreateShadow then ns.UI:CreateShadow(capture) end

    local title = capture:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", capture, "TOP", 0, -18)
    capture.title = title

    local hint = capture:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT",  capture, "TOPLEFT",  16, -48)
    hint:SetPoint("TOPRIGHT", capture, "TOPRIGHT", -16, -48)
    hint:SetJustifyH("CENTER")
    hint:SetTextColor(0.7, 0.7, 0.7)
    capture.hint = hint

    capture:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            return
        end
        if MODIFIER_KEYS[key] then return end
        finishCapture(withModifiers(key))
    end)
    capture:SetScript("OnMouseDown", function(self, button)
        local key = MOUSE_KEYS[button]
        if key then finishCapture(withModifiers(key)) end
    end)
    -- Die Tastatur erst beim Anzeigen an sich ziehen: ein versteckter Frame
    -- soll dem Spieler nicht die Eingabe wegnehmen.
    capture:SetScript("OnShow", function(self)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
    end)
    capture:SetScript("OnHide", function(self)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        self.setName = nil
    end)

    return capture
end

function ns:PromptSetKeybind(name)
    if not bindingAPI() then
        ns:Print(L["Keybinds are not available on this client."])
        return
    end
    if InCombatLockdown() then
        ns:Print(L["Cannot change keybinds in combat."])
        return
    end
    if not sets()[name] then
        ns:Print(string.format(L["Gear set '%s' does not exist."], name))
        return
    end

    createCapture()
    capture.setName = name
    capture.title:SetText(string.format(L["Press a key for '%s'"], name))
    capture.hint:SetText(L["ESC cancels. The key takes precedence over other bindings while the addon is loaded."])
    capture:Show()
    if capture.Raise then capture:Raise() end
end

-- =========================================================
-- Lebenszyklus
-- =========================================================
function mod:OnEnable()
    -- Override-Bindungen ueberleben keinen Reload, sie werden bei jedem
    -- Start neu gesetzt.
    applyBindings()

    if not self._eventsHooked then
        self._eventsHooked = true
        ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            if _pending then applyBindings() end
        end)
    end
end

function mod:OnDisable()
    if not bindingAPI() then return end
    -- Im Kampf geht es nicht; dann bleibt die Belegung bis zum Kampfende
    -- stehen. Der Klick-Handler prueft ohnehin, ob das Modul laeuft.
    if InCombatLockdown() then return end
    ClearOverrideBindings(owner)
end

-- =========================================================
-- Optionen
--
-- Bewusst KEIN mod:GetOptions(): das Modul ist versteckt
-- (group = "_hidden") und hat nichts einzustellen - eine Taste entsteht
-- am Set, nicht auf einer Optionsseite.
-- =========================================================
