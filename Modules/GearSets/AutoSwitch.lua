-- =========================================================
-- VuloGearSets / Modules / GearSets / AutoSwitch
-- Automatisches Anlegen: bei Haltung und Gestalt, die Reitgerte beim
-- Aufsitzen, und beim Wechsel der Talentgruppe.
-- =========================================================
local _, ns = ...
local L   = ns.L
local GS  = ns.GS
local mod = GS.mod

-- Aus frueher geladenen Dateien (siehe Shared.lua).
local LO                = GS.LO
local charDB            = GS.charDB
local equipLoadout      = GS.equipLoadout
local findItemInBags    = GS.findItemInBags
local formMap           = GS.formMap
local getItemIDFromLink = GS.getItemIDFromLink
local specMap           = GS.specMap
local spellName         = GS.spellName
local stowCursorItem    = GS.stowCursorItem


-- =========================================================
-- Stance/Form auto-switching
-- =========================================================
local _lastForm = -1

local function getCurrentForm()
    if not GetShapeshiftForm then return 0 end
    return GetShapeshiftForm() or 0
end

-- Name einer Gestalt. GetShapeshiftFormInfo liefert auf allen Clients
-- (icon, active, castable, spellID) - so liest es auch Blizzards eigene
-- StanceBar.lua in Classic Era und TBC Anniversary. Der zweite Wert ist
-- also kein Name, sondern ein Wahrheitswert; der Name kommt ueber die
-- Zauber-ID. Frueher lief das nur auf Forever so: in Classic zeigte die
-- Auswahl deshalb nur "Gestalt 1/2/3", und die Fluggestalt wurde nie
-- erkannt.
local function formNameOf(formIdx)
    if not GetShapeshiftFormInfo then return nil end
    -- pcall stellt ok voran, deshalb steht der zweite Wert an dritter Stelle
    local ok, _icon, second, _castable, spellID = pcall(GetShapeshiftFormInfo, formIdx)
    if not ok then return nil end
    -- Rueckfall fuer einen Client, der doch noch den Namen liefert.
    if type(second) == "string" and second ~= "" then return second end
    if type(spellID) == "number" then return spellName(spellID) end
    return nil
end

local function getFormName(formIdx)
    if formIdx == 0 then return L["No Form"] end
    return formNameOf(formIdx) or string.format(L["Form %d"], formIdx)
end

local function onShapeshiftChange()
    if not mod._enabled or not mod.db then return end
    if not mod.db.autoSwitchEnabled then return end
    if InCombatLockdown() then return end

    local currentForm = getCurrentForm()
    if currentForm == _lastForm then return end
    _lastForm = currentForm

    -- formMapping is keyed by loadout name → form index (1:1).
    -- Reverse-look up to find which loadout is bound to the current form.
    if not formMap() then return end
    for loadoutName, formIdx in pairs(formMap()) do
        if formIdx == currentForm and LO()[loadoutName] then
            equipLoadout(loadoutName)
            return
        end
    end
end

-- =========================================================
-- Reitgerte beim Aufsitzen
--
-- Die Reitgerte (und in Classic Era die Karotte am Stiel) steckt bei den
-- meisten in der Tasche und wird vergessen. Ist der Schalter an, wandert
-- sie beim Aufsitzen oder in Fluggestalt in den Schmuckslot und beim
-- Absitzen wieder zurueck - inklusive des Teils, das sie verdraengt hat.
--
-- Nur ausserhalb des Kampfes: EquipCursorItem ist im Kampf gesperrt. Faellt
-- ein Wechsel in den Kampf, wird er bis PLAYER_REGEN_ENABLED aufgehoben.
-- =========================================================
-- Reihenfolge = Vorrang. 25653 Reitgerte (TBC, +10%),
-- 11122 Karotte am Stiel (Classic Era, +3%). Beide wirken auf das
-- REITtempo und helfen in Fluggestalt deshalb nicht.
local MOUNT_SPEED_ITEMS = { 25653, 11122 }
-- 32481 Gluecksbringer des schnellen Fluges: "Erhoeht das Tempo in Flug-
-- und Schneller Fluggestalt um 10%". Nutzt also ausschliesslich Druiden
-- in Fluggestalt - dort wiederum bringt die Reitgerte nichts. Die beiden
-- Listen schliessen sich aus, statt sich zu ergaenzen.
local FLIGHT_SPEED_ITEMS = { 32481 }
local TRINKET_SLOTS      = { 13, 14 }
-- Fluggestalt und Schnelle Fluggestalt. In Classic Era gibt es die Zauber
-- nicht - GetSpellInfo liefert dann nil und der Eintrag entfaellt.
local FLIGHT_FORM_SPELLS = { 33943, 40120 }

-- Was wir angelegt haben und was dafuer weichen musste. nil = die Gerte
-- steckt nicht durch uns im Slot, also fassen wir auch nichts an.
--
-- Das liegt in der Charakter-Datenbank statt in einer Variablen: nach
-- einem /reload im Sattel waere der Zustand sonst weg, die Gerte bliebe
-- fuer immer im Schmuckslot und das verdraengte Teil in der Tasche.
local function cropState()      return charDB().cropState end
local function setCropState(v)  charDB().cropState = v    end

local _cropStateKey = "none" -- letzter bekannter Zustand: none | mount | fly
local _cropPending  = false  -- Wechsel faellig, aber Kampf war im Weg

-- Zuruecklegen kann misslingen (kein Platz in den Taschen, verdraengtes
-- Teil unauffindbar). Dann bleibt der gemerkte Zustand stehen und der
-- naechste Durchlauf versucht es erneut. UNIT_AURA feuert dabei staendig,
-- deshalb ein Deckel: nach ein paar Fehlversuchen ist Ruhe bis zum
-- naechsten echten Zustandswechsel.
local _cropRestoreTries = 0
local CROP_RESTORE_TRIES = 3

-- Die lokalisierten Gestaltnamen einmal aufloesen. GetSpellInfo ist billig,
-- aber UNIT_AURA feuert oft genug, dass sich das Merken lohnt.
local _flightFormNames
local function flightFormNames()
    if _flightFormNames then return _flightFormNames end
    local names, found = {}, false
    for _, spellID in ipairs(FLIGHT_FORM_SPELLS) do
        local sname = spellName(spellID)
        if sname then
            names[sname] = true
            found = true
        end
    end
    -- Nur ein Treffer wird gemerkt. Ein leeres Ergebnis kann auch heissen,
    -- dass die Zauberdaten kurz nach dem Login noch nicht stehen - das
    -- duerfen wir nicht als "gibt es hier nicht" festschreiben, sonst
    -- bliebe die Fluggestalt fuer die ganze Sitzung unerkannt.
    if found then _flightFormNames = names end
    return names
end

local function isFlightForm()
    local idx = getCurrentForm()
    if idx == 0 then return false end
    local fname = formNameOf(idx)
    if not fname then return false end
    return flightFormNames()[fname] == true
end

local _isDruid
local function isDruid()
    if _isDruid == nil then
        local _, class = UnitClass("player")
        _isDruid = (class == "DRUID")
    end
    return _isDruid
end

-- Grober Zustand, aus dem sich der passende Gegenstand ergibt. Absichtlich
-- billig: UNIT_AURA feuert staendig, und der teure Taschendurchlauf soll
-- erst laufen, wenn sich hier wirklich etwas geaendert hat.
--
-- Fluggestalt zuerst pruefen: sie zaehlt je nach Build auch als "beritten",
-- braucht aber den Gluecksbringer statt der Reitgerte.
local function mountStateKey()
    if isDruid() and isFlightForm() then return "fly" end
    if IsMounted and IsMounted() then return "mount" end
    return "none"
end

-- Welche Gegenstaende im jeweiligen Zustand etwas bringen.
local function itemsForState(key)
    if key == "fly"   then return FLIGHT_SPEED_ITEMS end
    if key == "mount" then return MOUNT_SPEED_ITEMS  end
    return nil
end

-- Steckt einer der Gegenstuecke aus der Liste schon im Schmuckslot?
local function wornSlotOf(list)
    if not list then return nil end
    for _, s in ipairs(TRINKET_SLOTS) do
        local id = getItemIDFromLink(GetInventoryItemLink("player", s))
        if id then
            for _, wantID in ipairs(list) do
                if id == wantID then return s, id end
            end
        end
    end
    return nil
end

-- Alles, was wir selbst anlegen - egal fuer welchen Zustand. Brauchen wir
-- beim Zuruecklegen: dort zaehlt, wo das Teil JETZT steckt.
local function wornManagedSlot()
    local slot, id = wornSlotOf(FLIGHT_SPEED_ITEMS)
    if slot then return slot, id end
    return wornSlotOf(MOUNT_SPEED_ITEMS)
end

local function findInBags(list)
    if not list then return nil end
    for _, wantID in ipairs(list) do
        local bag, bagSlot = findItemInBags(wantID)
        if bag then return bag, bagSlot, wantID end
    end
    return nil
end

local function equipMountSpeedItem(list)
    if cropState() then return end       -- steckt schon durch uns im Slot
    if wornSlotOf(list) then return end  -- der Spieler traegt es selbst
    local bag, bagSlot = findInBags(list)
    if not bag then return end

    -- Freien Schmuckslot bevorzugen. Ist keiner frei, muss der untere
    -- weichen - und was dort sass, merken wir uns fuers Absitzen.
    local target, prevLink
    for _, s in ipairs(TRINKET_SLOTS) do
        if not GetInventoryItemLink("player", s) then
            target = s
            break
        end
    end
    if not target then
        target   = TRINKET_SLOTS[#TRINKET_SLOTS]
        prevLink = GetInventoryItemLink("player", target)
    end

    if ns:EquipBagItemToSlot(bag, bagSlot, target) then
        setCropState({ slot = target, prevLink = prevLink })
    end
end

-- Rueckgabe: true = erledigt (oder nichts zu tun), false = spaeter nochmal.
--
-- Der gemerkte Zustand wird erst geloescht, wenn das Teil den Slot auch
-- wirklich verlassen hat. Frueher stand das Loeschen ganz oben - jeder
-- Fehlschlag darunter (Taschen voll, Anlegen abgelehnt) liess die Gerte
-- damit fuer immer im Schmuckslot: der Zustand war weg, also fasste sie
-- danach niemand mehr an.
local function restoreMountSpeedItem()
    local state = cropState()
    if not state then return true end

    -- Wo unser Teil JETZT steckt, nicht wo wir es hingelegt haben: nach
    -- einem /reload kann der Spieler selbst umgesteckt haben. Traegt er
    -- keines mehr, ist der gemerkte Zustand veraltet und wir fassen
    -- nichts an - sonst raeumten wir ein fremdes Schmuckstueck ab.
    local slot = wornManagedSlot()
    if not slot then
        setCropState(nil)
        return true
    end

    -- War der Slot vorher belegt, legt das alte Teil unseres von selbst
    -- ab - ein Tausch statt zweier Einzelschritte.
    if state.prevLink then
        local id = getItemIDFromLink(state.prevLink)
        local bag, bagSlot = nil, nil
        if id then bag, bagSlot = findItemInBags(id) end
        if bag and ns:EquipBagItemToSlot(bag, bagSlot, slot) then
            setCropState(nil)
            return true
        end
        -- Altes Teil nicht auffindbar oder Anlegen abgelehnt: unten weiter.
        -- Hauptsache unseres kommt aus dem Slot.
    end

    -- Slot war vorher leer (oder das alte Teil ist nicht auffindbar):
    -- unseres einfach in die Taschen zuruecklegen.
    if not PickupInventoryItem then return false end
    ClearCursor()
    PickupInventoryItem(slot)
    if CursorHasItem and not CursorHasItem() then return false end
    if not stowCursorItem() then return false end

    setCropState(nil)
    return true
end

-- Wechsel zwischen Reittier und Fluggestalt: nur der Gegenstand im Slot
-- wechselt, der Slot und das dafuer verdraengte Teil bleiben. Sonst wuerde
-- erst zurueckgelegt und dann neu verdraengt - zwei Umsteckvorgaenge und
-- ein kurzer Moment, in dem das alte Schmuckstueck wieder sichtbar ist.
--
-- Grundregel dahinter: im Slot steckt nur, was im aktuellen Zustand auch
-- wirklich etwas bringt. Nichts Passendes da heisst zurueckraeumen.
local function swapMountSpeedItem(list)
    local state = cropState()
    if not state then return end
    local slot = wornManagedSlot()
    if not slot then
        -- Nicht mehr auffindbar: Zustand ist veraltet, sauber neu anfangen.
        setCropState(nil)
        equipMountSpeedItem(list)
        return
    end
    -- Kein Ersatz in den Taschen: dann raeumen wir das bisherige zurueck,
    -- statt es liegen zu lassen. Es hilft im neuen Zustand nicht mehr, und
    -- wer aus der Fluggestalt heraus in einen Kampf geraet, haette es sonst
    -- bis zum Kampfende im Slot - Zuruecklegen ist im Kampf gesperrt.
    local bag, bagSlot = findInBags(list)
    if not bag then
        restoreMountSpeedItem()
        return
    end
    if ns:EquipBagItemToSlot(bag, bagSlot, slot) then
        setCropState({ slot = slot, prevLink = state.prevLink })
    end
end

-- force = auch handeln, wenn sich der Zustand nicht geaendert hat. Braucht
-- der Schalter in den Optionen: wer ihn im Sattel umlegt, erwartet eine
-- sofortige Wirkung, obwohl _cropStateKey schon stimmt.
local function applyMountState(force)
    if not mod._enabled or not mod.db then return end

    if not mod.db.ridingCropEnabled then
        -- Ausgeschaltet, waehrend unser Teil angelegt war: zurueck, sonst
        -- bliebe es fuer immer im Schmuckslot stehen.
        if cropState() and not InCombatLockdown() then restoreMountSpeedItem() end
        return
    end

    local key  = mountStateKey()
    local list = itemsForState(key)

    -- Wir tragen noch etwas von uns, obwohl der aktuelle Zustand nichts
    -- davon braucht. Zwei Faelle, in denen sich der Zustandsschluessel dabei
    -- NICHT geaendert hat und der Vergleich unten sonst aussteigen wuerde:
    -- ein misslungenes Zuruecklegen von eben, und der Login abgesessen,
    -- nachdem man beritten ausgeloggt hat. Beide Male bliebe die Gerte
    -- sonst fuer immer im Schmuckslot.
    local stale = cropState() ~= nil and list == nil
                  and _cropRestoreTries < CROP_RESTORE_TRIES

    if key == _cropStateKey and not _cropPending and not force and not stale then return end
    -- Echter Zustandswechsel (und der Schalter in den Optionen) geben die
    -- Versuche wieder frei.
    if key ~= _cropStateKey or force then _cropRestoreTries = 0 end
    _cropStateKey = key

    if InCombatLockdown() then
        _cropPending = true
        return
    end
    _cropPending = false

    if not list then
        if restoreMountSpeedItem() then
            _cropRestoreTries = 0
        else
            _cropRestoreTries = _cropRestoreTries + 1
        end
    elseif cropState() then
        -- Schon etwas von uns drin. Passt es zum neuen Zustand, bleibt es
        -- liegen; sonst wird an Ort und Stelle getauscht (Reittier <-> Flug).
        if wornSlotOf(list) then return end
        swapMountSpeedItem(list)
    else
        equipMountSpeedItem(list)
    end
end

local function onMountStateChange(event, unit)
    -- UNIT_AURA feuert fuer jede Einheit in der Naehe. Alles ausser dem
    -- Spieler faellt hier sofort raus, bevor irgendetwas gerechnet wird.
    if event == "UNIT_AURA" and unit ~= "player" then return end
    applyMountState(false)
end

-- Die vier Ereignisse der Reitgerte haengen an IHRER Einstellung, nicht am
-- Modul.
--
-- UNIT_AURA ist eines der lautesten Ereignisse im Spiel: es feuert fuer
-- jede Einheit in der Naehe, in einem Schlachtzugskampf hunderte Male pro
-- Sekunde. Es fest zu abonnieren hiess, jeden dieser Aufrufe durch den
-- Verteiler und ein pcall zu schicken - fuer ein Feature, das ab Werk aus
-- ist und dessen Handler ohnehin sofort wieder aussteigt. Ausgeschaltet
-- kostet es jetzt gar nichts, weil der Client das Ereignis nicht mehr
-- zustellt.
--
-- Bewusst NICHT auf mod._enabled pruefen: aus OnEnable heraus steht das
-- noch auf false (SafeEnable setzt es erst danach), die Ereignisse waeren
-- also nie angemeldet. OnDisable meldet sie unabhaengig davon ab.
local function applyMountEvents()
    local on = mod.db and mod.db.ridingCropEnabled
    local fn = on and ns.RegisterEvent or ns.UnregisterEvent
    fn(ns, "UNIT_AURA",              onMountStateChange)
    fn(ns, "UPDATE_SHAPESHIFT_FORM", onMountStateChange)
    fn(ns, "PLAYER_REGEN_ENABLED",   onMountStateChange)
    fn(ns, "PLAYER_ENTERING_WORLD",  onMountStateChange)
end
mod._applyMountEvents = applyMountEvents

-- =========================================================
-- Dual-spec auto-switching
-- Anniversary backported the WotLK dual-spec system. We use the real spec
-- group APIs (GetActiveTalentGroup + ACTIVE_TALENT_GROUP_CHANGED) so switching
-- between Spec 1 and Spec 2 in-game instantly equips the bound loadout.
-- =========================================================
local _lastSpecGroup = -1

-- Forever hat ebenfalls zwei Talentgruppen, fragt sie aber ueber die
-- Retail-Aufrufe ab: C_SpecializationInfo.GetActiveSpecGroup und
-- GetNumSpecGroups. GetActiveTalentGroup gibt es dort nicht.
local CSI = _G.C_SpecializationInfo
local GetActiveGroupFn = _G.GetActiveTalentGroup
    or (CSI and CSI.GetActiveSpecGroup) or _G.GetActiveSpecGroup
local GetNumGroupsFn = _G.GetNumTalentGroups or _G.GetNumSpecGroups

local function getActiveSpecGroup()
    if GetActiveGroupFn then
        local ok, g = pcall(GetActiveGroupFn)
        if ok and type(g) == "number" then return g end
    end
    return 1
end

local function getNumSpecGroups()
    if GetNumGroupsFn then
        local ok, n = pcall(GetNumGroupsFn)
        if ok and type(n) == "number" then return n end
    end
    return 1
end

-- Points spent in a talent tab FOR A SPECIFIC spec group (4th param = talentGroup).
local function getTabPoints(tab, group)
    if GetTalentTabInfo then
        local _, _, pointsSpent = GetTalentTabInfo(tab, false, false, group)
        if type(pointsSpent) == "number" then return pointsSpent end
    end
    local total = 0
    -- Ohne GetTalentInfo (Forever) gibt es auch keine Baeume zu zaehlen.
    if not GetTalentInfo then return total end
    local numTalents = (GetNumTalents and GetNumTalents(tab)) or 0
    for t = 1, numTalents do
        local rank = select(5, GetTalentInfo(tab, t, false, false, group))
        total = total + (tonumber(rank) or 0)
    end
    return total
end

-- Label for a spec group: "Spec 1 (Shadow)" using the dominant talent tab name.
local function getSpecGroupLabel(group)
    local numTabs = (GetNumTalentTabs and GetNumTalentTabs()) or 0
    local bestName, bestPoints = nil, -1
    for tab = 1, numTabs do
        local pts = getTabPoints(tab, group)
        if pts > bestPoints then
            bestPoints = pts
            local name = GetTalentTabInfo and GetTalentTabInfo(tab, false, false, group)
            if type(name) == "string" and name ~= "" then bestName = name else bestName = nil end
        end
    end
    local base = string.format(L["Spec %d"], group)
    if bestName and bestPoints > 0 then
        return string.format("%s (%s)", base, bestName)
    end
    return base
end

local function onTalentChange()
    if not mod._enabled or not mod.db then return end
    if not mod.db.specSwitchEnabled then return end
    if InCombatLockdown() then return end

    local currentGroup = getActiveSpecGroup()
    if currentGroup == _lastSpecGroup then return end
    _lastSpecGroup = currentGroup

    -- specMapping is keyed by loadout name → spec group index (1:1)
    if not specMap() then return end
    for loadoutName, groupIdx in pairs(specMap()) do
        if groupIdx == currentGroup and LO()[loadoutName] then
            equipLoadout(loadoutName)
            return
        end
    end
end

-- Fuer /gearset spec, das weiter oben steht als diese Funktionen.
mod._getActiveSpecGroup = getActiveSpecGroup
mod._getNumSpecGroups   = getNumSpecGroups

-- Force a spec re-check (clears the cached group so it always re-evaluates).
-- Used by /loadout spec and as the polling fallback.
mod._forceSpecCheck = function()
    _lastSpecGroup = -1
    onTalentChange()
end

-- Event-independent polling fallback: some Anniversary builds don't fire
-- ACTIVE_TALENT_GROUP_CHANGED reliably, so we also poll every 2s.
local _specPoller
local function startSpecPolling()
    if _specPoller or not (C_Timer and C_Timer.NewTicker) then return end
    -- Ohne zweite Talentgruppe kann sich nichts aendern: in Classic Era
    -- liefe der Ticker alle zwei Sekunden fuer nichts.
    if getNumSpecGroups() < 2 then return end
    _specPoller = C_Timer.NewTicker(2, function()
        if not mod._enabled or not mod.db or not mod.db.specSwitchEnabled then return end
        if InCombatLockdown() then return end
        local g = getActiveSpecGroup()
        if g ~= _lastSpecGroup then
            onTalentChange()  -- group changed since last check → switch
        end
    end)
end

-- =========================================================
-- Vergleichsbasen fuer OnEnable/OnDisable (Lifecycle.lua)
--
-- Die Basen liegen in dieser Datei; Lifecycle setzt sie ueber diese
-- Funktionen, statt die Variablen selbst anzufassen.
-- =========================================================
function GS.resetSwitchBaselines()
    _lastForm      = getCurrentForm()
    _lastSpecGroup = getActiveSpecGroup()
    -- Gleiche Ueberlegung fuer die Reitgerte: wer beim Login schon sitzt,
    -- soll nicht sofort einen Tausch ausgeloest bekommen.
    _cropStateKey  = mountStateKey()
end

function GS.refreshSpecBaseline()
    _lastSpecGroup = getActiveSpecGroup()
end

function GS.stopSpecPolling()
    if _specPoller then _specPoller:Cancel(); _specPoller = nil end
end

-- Fuer die spaeter geladenen Dateien (siehe Shared.lua).
GS.applyMountEvents      = applyMountEvents
GS.applyMountState       = applyMountState
GS.cropState             = cropState
GS.getFormName           = getFormName
GS.getNumSpecGroups      = getNumSpecGroups
GS.getSpecGroupLabel     = getSpecGroupLabel
GS.onMountStateChange    = onMountStateChange
GS.onShapeshiftChange    = onShapeshiftChange
GS.onTalentChange        = onTalentChange
GS.restoreMountSpeedItem = restoreMountSpeedItem
GS.startSpecPolling      = startSpecPolling
