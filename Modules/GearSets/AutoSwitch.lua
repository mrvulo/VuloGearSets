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
local GetItemInfoInstant = GS.GetItemInfoInstant
local LO                = GS.LO
local captureCurrentEquipment = GS.captureCurrentEquipment
local charDB            = GS.charDB
local currentAmmoID     = GS.currentAmmoID
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
    -- Ein im Kampf per Taste gewaehltes Set wird gleich nachgeholt und hat
    -- Vorrang; danach ruft Sets.lua diese Funktion erneut (F065).
    if GS.hasPendingAfterCombat and GS.hasPendingAfterCombat() then return end

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
    -- Wie bei der Gestalt: erst das im Kampf gewaehlte Set (F065).
    if GS.hasPendingAfterCombat and GS.hasPendingAfterCombat() then return end

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
    elseif not (key == "mount" and GS.mountSetCoversTrinkets
                and GS.mountSetCoversTrinkets()) then
        -- Fluggestalt zaehlt nicht als beritten: dort greift das Reit-Set
        -- nie, der Gluecksbringer also weiter.
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
-- Situationen
--
-- Je Situation hoechstens ein Set: charDB().triggers[key] = Setname.
-- Zwei Arten:
--   voruebergehend (TEMP_TRIGGERS): beritten, schwimmen, Angel in der
--     Waffenhand, essen/trinken. Endet die Situation, kommt der Stand von
--     davor zurueck.
--   Ort (LOC_TRIGGERS): Schlachtfeld, Arena, Dungeon, Schlachtzug,
--     Erholungsgebiet (Stadt, Gasthaus), offene Welt. Gilt, bis ein anderer
--     Ort ein anderes Set will; ein Ort ohne Set stellt den Stand von vor
--     dem ersten Ort-Set wieder her.
-- Eine laufende voruebergehende Situation hat Vorrang; ein Ortswechsel
-- waehrenddessen wird danach nachgeholt.
--
-- Der Zustand liegt in charDB().triggerState und ueberlebt einen Reload:
-- wer beritten ausloggt und abgesessen einloggt, bekommt den Stand von
-- davor zurueck. Beim allerersten Start und nach einem Reload am selben
-- Ort wird nichts angelegt - nur echte Wechsel loesen etwas aus (wie bei
-- Spec und Gestalt, siehe R-30).
--
-- Nur ausserhalb des Kampfs und nicht tot; PLAYER_REGEN_ENABLED holt nach.
-- =========================================================
local TEMP_TRIGGERS = { "swim", "mount", "fishing", "eat" }   -- Rangfolge
local LOC_TRIGGERS  = { "pvp", "arena", "party", "raid", "rest", "world" }

local function triggerMap()
    local c = charDB()
    c.triggers = c.triggers or {}
    return c.triggers
end

local function triggerState()
    local c = charDB()
    c.triggerState = c.triggerState or {}
    return c.triggerState
end

local function triggerSet(key)
    local name = triggerMap()[key]
    if name and LO()[name] then return name end
    return nil
end

local function anyTempMapped()
    for _, key in ipairs(TEMP_TRIGGERS) do
        if triggerSet(key) then return true end
    end
    return false
end

-- Buff-Name ueber beide APIs: Forever hat UnitBuff nicht mehr sicher.
local function buffName(i)
    local CUA = _G.C_UnitAuras
    if CUA and CUA.GetBuffDataByIndex then
        local d = CUA.GetBuffDataByIndex("player", i)
        return d and d.name
    end
    if UnitBuff then return (UnitBuff("player", i)) end
    return nil
end

-- Essen und Trinken heissen in jeder Sprache wie diese beiden Zauber.
local FOOD_NAME, DRINK_NAME
local function isEatingOrDrinking()
    FOOD_NAME  = FOOD_NAME  or spellName(433)
    DRINK_NAME = DRINK_NAME or spellName(430)
    for i = 1, 40 do
        local name = buffName(i)
        if not name then break end
        if name == FOOD_NAME or name == DRINK_NAME then return true end
    end
    return false
end

-- Angel in der Waffenhand: Waffe (2), Unterklasse Angelrute (20).
local function hasFishingPole()
    local id = GetInventoryItemID and GetInventoryItemID("player", 16)
    if not id or not GetItemInfoInstant then return false end
    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(id)
    return classID == 2 and subClassID == 20
end

local TEMP_CHECK = {
    swim    = function() return IsSwimming and IsSwimming() or false end,
    -- Flugmeister zaehlt nicht: dort laesst sich ohnehin nichts tauschen.
    mount   = function()
        return (IsMounted and IsMounted() and not (UnitOnTaxi and UnitOnTaxi("player"))) or false
    end,
    fishing = hasFishingPole,
    eat     = isEatingOrDrinking,
}

local function locationKey()
    local inInstance, instType = IsInInstance()
    if inInstance and (instType == "pvp" or instType == "arena"
                       or instType == "party" or instType == "raid") then
        return instType
    end
    if IsResting and IsResting() then return "rest" end
    return "world"
end

local function currentTempWant()
    for _, key in ipairs(TEMP_TRIGGERS) do
        if triggerSet(key) and TEMP_CHECK[key]() then return key end
    end
    return nil
end

-- Stand der Slots, die das Set anfassen wird - zum Zuruecklegen danach.
local function snapshotFor(setName)
    local set = LO()[setName]
    if not set then return nil end
    local touched = GS.touchedSlots(set)
    return { slots = captureCurrentEquipment(touched), slotMask = touched,
             ammo  = set.ammo and currentAmmoID() or nil }
end

-- Nach dem Angeln die Waffen nicht zuruecktauschen: wer die Angel ablegt,
-- hat gerade selbst eine Waffe in die Hand genommen.
local WEAPON_SLOTS = { [16] = true, [17] = true, [18] = true }
local function withoutWeapons(snap)
    local out = { slots = {}, slotMask = {}, ammo = nil }
    for _, s in ipairs(snap.slotMask or {}) do
        if not WEAPON_SLOTS[s] then
            out.slotMask[#out.slotMask + 1] = s
            out.slots[s] = snap.slots and snap.slots[s]
        end
    end
    return out
end

-- Wechselt eine Situation direkt in die naechste (beritten -> schwimmen,
-- Schlachtfeld -> Welt), bleibt der Stand von ganz vorher. Slots, die erst
-- das neue Set anfasst, kennt er noch nicht - die werden mit dem Stand von
-- jetzt nachgetragen, sonst blieben sie am Ende im Situations-Set stecken.
local function extendSnapshot(snap, setName)
    local set = LO()[setName]
    if not (snap and set) then return snap end
    local known = {}
    for _, s in ipairs(snap.slotMask or {}) do known[s] = true end
    local missing = {}
    for _, s in ipairs(GS.touchedSlots(set)) do
        if not known[s] then missing[#missing + 1] = s end
    end
    if #missing > 0 then
        local now = captureCurrentEquipment(missing)
        snap.slots = snap.slots or {}
        for _, s in ipairs(missing) do
            snap.slotMask[#snap.slotMask + 1] = s
            snap.slots[s] = now[s]
        end
        table.sort(snap.slotMask)
    end
    if set.ammo and snap.ammo == nil then snap.ammo = currentAmmoID() end
    return snap
end

local function snapshotOrExtend(snap, setName)
    if snap then return extendSnapshot(snap, setName) end
    return snapshotFor(setName)
end

-- Nach dem Zuruecklegen sind die Teile kurz gesperrt; bis dahin legt keine
-- Situation etwas an (sonst "liess sich nicht anlegen").
local _holdUntil = 0

local function restore(snap)
    if snap and #(snap.slotMask or {}) > 0 then
        equipLoadout(L["Previous gear"], snap, { auto = true })
        _holdUntil = GetTime() + 1
    end
end

local function triggersActive()
    return mod._enabled and mod.db and mod.db.triggersEnabled ~= false
end

-- Fuers An- und Abmelden der Ereignisse NICHT mod._enabled fragen: aus
-- OnEnable heraus steht es noch auf false (wie bei applyMountEvents).
local function triggersWanted()
    return mod.db and mod.db.triggersEnabled ~= false
end

local evaluateTriggers   -- vorwaerts: queueEvaluate ruft es spaeter auf

local _evalQueued = false
local function queueEvaluate(delay)
    if _evalQueued or not (C_Timer and C_Timer.After) then return end
    _evalQueued = true
    C_Timer.After(delay or 0.3, function()
        _evalQueued = false
        evaluateTriggers()
    end)
end

-- Voruebergehende Situationen werden erst nach zwei gleichen Abfragen
-- (eine Sekunde) wirksam: an der Wasseroberflaeche flackert IsSwimming,
-- und kurzes Auf- und Absitzen soll nicht zweimal tauschen.
local _candidate, _candidateTicks = nil, 0
local _triggerTicker

evaluateTriggers = function(fromTicker)
    if not triggersActive() then return end
    if InCombatLockdown() then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    if GetTime() < _holdUntil then
        if not fromTicker then queueEvaluate(_holdUntil - GetTime() + 0.1) end
        return
    end
    local state = triggerState()

    local want = currentTempWant()
    if fromTicker then
        if want ~= _candidate then
            _candidate, _candidateTicks = want, 1
            return
        end
        _candidateTicks = _candidateTicks + 1
        if _candidateTicks < 2 then return end
    elseif _triggerTicker then
        -- Ereignisse (Kampfende, Ortswechsel) warten nicht auf den Ticker,
        -- uebernehmen aber nur eine Lage, die er schon bestaetigt hat.
        want = (_candidateTicks >= 2) and _candidate or state.temp
    end
    -- Ohne Ticker (keiner Situation dieser Art ist ein Set zugeordnet)
    -- gilt die Abfrage direkt: eine noch laufende Situation endet dann,
    -- und ihr Stand von davor kommt zurueck.

    if want ~= state.temp then
        local endingSnap = state.tempSnap
        if state.temp == "fishing" and endingSnap then
            endingSnap = withoutWeapons(endingSnap)
        end
        if want then
            -- Direkt von einer Situation in die naechste: den Stand von ganz
            -- vorher behalten.
            state.tempSnap = snapshotOrExtend(state.tempSnap, triggerSet(want))
            state.temp = want
            equipLoadout(triggerSet(want), nil, { auto = true })
            return
        end
        state.temp, state.tempSnap = nil, nil
        restore(endingSnap)
        -- Der Ort kann sich waehrenddessen geaendert haben; bewertet wird,
        -- sobald die zurueckgelegten Teile angekommen sind (_holdUntil).
        queueEvaluate(1.1)
        return
    end
    if state.temp then return end

    local loc = locationKey()
    -- Allererste Auswertung: nur merken, wo man ist. Erst hier und nicht
    -- schon beim Login, weil der Ort dann sicher feststeht (Naehe R-30).
    if state.loc == nil then state.loc = loc return end
    if loc == state.loc then return end
    state.loc = loc
    local name = triggerSet(loc)
    if name then
        state.locSnap = snapshotOrExtend(state.locSnap, name)
        equipLoadout(name, nil, { auto = true })
    elseif state.locSnap then
        local snap = state.locSnap
        state.locSnap = nil
        restore(snap)
    end
end

local function onTriggerEvent()
    queueEvaluate(0.3)
end

local function applyTriggerEvents()
    local on = triggersWanted()
    local fn = on and ns.RegisterEvent or ns.UnregisterEvent
    fn(ns, "PLAYER_ENTERING_WORLD",  onTriggerEvent)
    fn(ns, "ZONE_CHANGED_NEW_AREA",  onTriggerEvent)
    fn(ns, "PLAYER_UPDATE_RESTING",  onTriggerEvent)
    fn(ns, "PLAYER_REGEN_ENABLED",   onTriggerEvent)
    -- Voruebergehende Situationen haben keine verlaessliche Meldung
    -- (Schwimmen gar keine). Ein Ticker jede halbe Sekunde, aber nur,
    -- solange einer Situation dieser Art ein Set zugeordnet ist.
    local wantTicker = on and anyTempMapped() and C_Timer and C_Timer.NewTicker
    if wantTicker and not _triggerTicker then
        _triggerTicker = C_Timer.NewTicker(0.5, function() evaluateTriggers(true) end)
    elseif not wantTicker and _triggerTicker then
        _triggerTicker:Cancel()
        _triggerTicker = nil
    end
end

-- Ausgangslage ohne Anlegen: beim ersten Start, und wenn nichts gemerkt
-- ist. Ein gemerkter Zustand bleibt - der echte Wechsel seit dem Logout
-- wird dann bei der ersten Auswertung nachgeholt.
local function triggerBaseline()
    _candidate, _candidateTicks = triggerState().temp, 2
end

-- Ausschalten (Schalter oder Modul): ein voruebergehendes Situations-Set
-- kommt wieder runter, sonst bliebe es stecken (wie die Reitgerte, R-50).
-- Der gemerkte Zustand wird verworfen - beim Wiedereinschalten beginnt
-- alles neu an der dann aktuellen Stelle, ohne alte Staende zurueckzulegen.
local function resetTriggerState()
    local state = triggerState()
    if state.tempSnap and not InCombatLockdown() then
        local snap = state.tempSnap
        if state.temp == "fishing" then snap = withoutWeapons(snap) end
        restore(snap)
    end
    charDB().triggerState = {}
    triggerBaseline()
end
GS.resetTriggerState = resetTriggerState

function GS.startTriggers()
    triggerBaseline()
    applyTriggerEvents()
end

function GS.stopTriggers()
    local wasOn = mod.db and mod.db.triggersEnabled
    resetTriggerState()
    if _triggerTicker then _triggerTicker:Cancel(); _triggerTicker = nil end
    ns:UnregisterEvent("PLAYER_ENTERING_WORLD",  onTriggerEvent)
    ns:UnregisterEvent("ZONE_CHANGED_NEW_AREA",  onTriggerEvent)
    ns:UnregisterEvent("PLAYER_UPDATE_RESTING",  onTriggerEvent)
    ns:UnregisterEvent("PLAYER_REGEN_ENABLED",   onTriggerEvent)
    return wasOn
end

-- Haengt ein Reit-Set an Schmuckslots, laesst die Reitgerte die Finger
-- davon: sonst stritten zwei Automatiken um denselben Slot.
function GS.mountSetCoversTrinkets()
    if not triggersActive() then return false end
    local name = triggerSet("mount")
    local set = name and LO()[name]
    if not set then return false end
    for _, s in ipairs(set.slotMask or {}) do
        if s == 13 or s == 14 then return true end
    end
    return false
end

GS.TEMP_TRIGGERS      = TEMP_TRIGGERS
GS.LOC_TRIGGERS       = LOC_TRIGGERS
GS.triggerMap         = triggerMap
GS.applyTriggerEvents = applyTriggerEvents

-- =========================================================
-- Dual-spec auto-switching
-- Anniversary backported the WotLK dual-spec system. We use the real spec
-- group APIs (GetActiveTalentGroup + ACTIVE_TALENT_GROUP_CHANGED) so switching
-- between Spec 1 and Spec 2 in-game instantly equips the bound loadout.
-- =========================================================
local _lastSpecGroup = -1
-- Erst wenn die Vergleichsbasis aus einem echten Wert stammt (der Abgleich
-- zwei Sekunden nach dem Login, siehe Lifecycle.lua), loest ein Wechsel ein
-- Anlegen aus. Davor ziehen die Ereignisse des Logins nur die Basis nach -
-- direkt nach dem Login kann die Talentgruppe noch auf 1 stehen, und
-- PLAYER_ENTERING_WORLD sah sonst wie ein Specwechsel aus (R-30).
local _specBaselineConfirmed = false

-- Forever hat ebenfalls zwei Talentgruppen, fragt sie aber ueber die
-- Retail-Aufrufe ab: C_SpecializationInfo.GetActiveSpecGroup und
-- GetNumSpecGroups. GetActiveTalentGroup gibt es dort nicht.
local CSI = _G.C_SpecializationInfo
local GetActiveGroupFn = _G.GetActiveTalentGroup
    or (CSI and CSI.GetActiveSpecGroup) or _G.GetActiveSpecGroup
local GetNumGroupsFn = _G.GetNumTalentGroups or _G.GetNumSpecGroups

-- nil, solange der Client keine Zahl liefert.
local function readActiveSpecGroup()
    if GetActiveGroupFn then
        local ok, g = pcall(GetActiveGroupFn)
        if ok and type(g) == "number" then return g end
    end
    return nil
end

local function getActiveSpecGroup()
    return readActiveSpecGroup() or 1
end

local function getNumSpecGroups()
    if GetNumGroupsFn then
        local ok, n = pcall(GetNumGroupsFn)
        if ok and type(n) == "number" then return n end
    end
    return 1
end

-- Name und Punkte eines Talentbaums. TBC Anniversary und Classic Era
-- liefern (id, name, description, icon, pointsSpent, ...), aeltere Clients
-- (name, icon, pointsSpent, ...) - erkennbar am Typ des ersten Werts.
local function talentTabInfo(tab, group)
    if not GetTalentTabInfo then return nil end
    local ok, a, b, c, _d, e = pcall(GetTalentTabInfo, tab, false, false, group)
    if not ok then return nil end
    if type(a) == "string" then return a, c end
    return b, e
end

-- Points spent in a talent tab FOR A SPECIFIC spec group (4th param = talentGroup).
local function getTabPoints(tab, group)
    local _, pointsSpent = talentTabInfo(tab, group)
    if type(pointsSpent) == "number" then return pointsSpent end
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
            local name = talentTabInfo(tab, group)
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
    -- Dual-Spec erst in dieser Sitzung gekauft: beim Login gab es nur eine
    -- Gruppe, der Ticker lief nie an. Die Talent-Ereignisse holen ihn nach
    -- (laeuft er schon, tut der Aufruf nichts). Zur Laufzeit ueber GS, weil
    -- startSpecPolling weiter unten steht.
    if GS.startSpecPolling then GS.startSpecPolling() end
    if not mod.db.specSwitchEnabled then return end
    if InCombatLockdown() then return end

    local currentGroup = readActiveSpecGroup()
    if not currentGroup then return end
    if not _specBaselineConfirmed then
        -- Nur die Basis nachziehen, nichts anlegen (siehe oben).
        _lastSpecGroup = currentGroup
        return
    end
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
        if not _specBaselineConfirmed then
            GS.refreshSpecBaseline()
            return
        end
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
    -- Noch nicht bestaetigt: das tut erst refreshSpecBaseline.
    _specBaselineConfirmed = false
    -- Gleiche Ueberlegung fuer die Reitgerte: wer beim Login schon sitzt,
    -- soll nicht sofort einen Tausch ausgeloest bekommen.
    _cropStateKey  = mountStateKey()
end

-- Basis aus einem echten Wert setzen und damit freigeben. Liefert der
-- Client noch keine Zahl, bleibt alles gesperrt; der Ticker versucht es
-- dann erneut.
function GS.refreshSpecBaseline()
    local g = readActiveSpecGroup()
    if not g then return end
    _lastSpecGroup = g
    _specBaselineConfirmed = true
end

function GS.stopSpecPolling()
    if _specPoller then _specPoller:Cancel(); _specPoller = nil end
end

-- Fuer die spaeter geladenen Dateien (siehe Shared.lua).
GS.applyMountEvents      = applyMountEvents
GS.applyMountState       = applyMountState
GS.cropState             = cropState
-- Fuer captureCurrentEquipment (Shared.lua): der Slot, in dem unser Teil
-- gerade steckt - nur solange wir es angelegt haben.
GS.cropWornSlot          = function()
    if not cropState() then return nil end
    return (wornManagedSlot())
end
GS.getFormName           = getFormName
GS.getNumSpecGroups      = getNumSpecGroups
GS.getSpecGroupLabel     = getSpecGroupLabel
GS.onMountStateChange    = onMountStateChange
GS.onShapeshiftChange    = onShapeshiftChange
GS.onTalentChange        = onTalentChange
GS.restoreMountSpeedItem = restoreMountSpeedItem
GS.startSpecPolling      = startSpecPolling
