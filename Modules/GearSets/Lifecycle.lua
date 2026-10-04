-- =========================================================
-- VuloGearSets / Modules / GearSets / Lifecycle
-- An- und Abschalten des Moduls: Migrationen, Oberflaeche aufbauen,
-- Ereignisse an- und abmelden.
-- =========================================================
local _, ns = ...
local L   = ns.L
local GS  = ns.GS
local mod = GS.mod

-- Aus frueher geladenen Dateien (siehe Shared.lua).
local LO                     = GS.LO
local applyMinimapVisibility = GS.applyMinimapVisibility
local applyMountEvents       = GS.applyMountEvents
local applySidebarVisibility = GS.applySidebarVisibility
local createMinimapButton    = GS.createMinimapButton
local createSidebar          = GS.createSidebar
local cropState              = GS.cropState
local formMap                = GS.formMap
local onInventoryChanged     = GS.onInventoryChanged
local onMountStateChange     = GS.onMountStateChange
local onShapeshiftChange     = GS.onShapeshiftChange
local onTalentChange         = GS.onTalentChange
local refreshStatusDots      = GS.refreshStatusDots
local restoreMountSpeedItem  = GS.restoreMountSpeedItem
local specMap                = GS.specMap
local startSpecPolling       = GS.startSpecPolling


function mod:OnEnable()
    if not mod.db then return end
    -- Ensure per-character tables exist (the accessors create them lazily)
    LO(); formMap(); specMap()
    mod.db.minimap     = mod.db.minimap     or { hidden = false, angle = 45 }

    -- Migration: legacy loadouts without slotMask → derive from currently saved slots
    for _, loadout in pairs(LO()) do
        if loadout and not loadout.slotMask then
            local mask = {}
            for slot in pairs(loadout.slots or {}) do
                table.insert(mask, slot)
            end
            table.sort(mask)
            loadout.slotMask = mask
        end
        -- Die eigenen Symbole aus Media/Icons/sets gibt es nicht mehr, die
        -- Auswahl bietet jetzt Blizzards Symbolliste. Wer eines davon hatte,
        -- bekommt wieder das automatische Symbol statt eines gruenen Felds.
        local ov = loadout and loadout.iconOverride
        if type(ov) == "string"
           and ov:lower():find("^interface\\addons\\vulogearsets\\media\\icons\\sets\\") then
            loadout.iconOverride = nil
        end
    end

    -- Die Seitenleiste schliesst jetzt buendig an das Charakterfenster an.
    -- Wer noch auf den frueheren Werten -14/45 steht, wird einmalig auf 0
    -- gesetzt; selbst eingestellte Werte bleiben erhalten.
    -- Nicht auf Forever: dort sind 0/0 die richtigen Standardwerte, und
    -- Altwerte aus VuloClassicUI gibt es nicht.
    if ns.isForever then mod.db._offsetMigrated_v3 = true end
    if not mod.db._offsetMigrated_v3 then
        -- Frueher galten -14/45 (aus VuloClassicUI) und zwischenzeitlich 0/0.
        -- Beide richteten sich nach den Frame-Grenzen statt nach dem
        -- sichtbaren Rahmen. Wer noch darauf steht, wird mitgenommen.
        local top, bot = mod.db.sidebarTopOffset or 0, mod.db.sidebarBottomOffset or 0
        if (top == -14 and bot == 45) or (top == 0 and bot == 0) then
            mod.db.sidebarTopOffset    = -12
            mod.db.sidebarBottomOffset = 76
            mod.db.sidebarXOffset      = -34
        end
        mod.db._offsetMigrated    = nil
        mod.db._offsetMigrated_v2 = nil
        mod.db._offsetMigrated_v3 = true
    end

    -- Create minimap button (deferred so Minimap definitely exists)
    --
    -- Beim WIEDEREINSCHALTEN existieren Knopf und Leiste schon und die
    -- create-Funktionen kehren sofort zurueck - OnDisable hat aber beide
    -- versteckt. Sichtbar machen muss sie deshalb der jeweilige
    -- apply-Aufruf, sonst blieben sie bis zum /reload verschwunden.
    local function setupUI()
        createMinimapButton()
        createSidebar()
        applyMinimapVisibility()
        applySidebarVisibility()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            -- Wurde das Modul innerhalb der Verzoegerung schon wieder
            -- ausgeschaltet, darf der Timer nichts einblenden. Die Leiste
            -- prueft das selbst, der Minimap-Knopf nicht. Nur im
            -- Timer-Pfad pruefen: beim synchronen Aufruf direkt aus
            -- OnEnable steht _enabled noch auf false (SafeEnable setzt
            -- es erst danach).
            if mod._enabled then setupUI() end
        end)
    else
        setupUI()
    end

    ns:RegisterEvent("UNIT_INVENTORY_CHANGED", onInventoryChanged)
    ns:RegisterEvent("BAG_UPDATE_DELAYED", refreshStatusDots)

    ns:RegisterEvent("UPDATE_SHAPESHIFT_FORM",  onShapeshiftChange)
    ns:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", onShapeshiftChange)
    ns:RegisterEvent("PLAYER_REGEN_ENABLED",    onShapeshiftChange)  -- retry leaving combat

    -- Reitgerte. Reittiere setzen einen Buff, deshalb reicht UNIT_AURA -
    -- PLAYER_MOUNT_DISPLAY_CHANGED gibt es nicht in allen Classic-Builds
    -- und RegisterEvent wirft bei unbekannten Ereignissen einen Fehler.
    -- Nur angemeldet, solange die Einstellung an ist (siehe applyMountEvents).
    applyMountEvents()

    -- Hook every plausible dual-spec event — Anniversary builds vary on which
    -- one actually fires. Plus a 2s polling fallback (startSpecPolling) covers
    -- builds where none of them fire reliably.
    ns:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", onTalentChange)
    ns:RegisterEvent("PLAYER_TALENT_UPDATE",        onTalentChange)
    ns:RegisterEvent("CHARACTER_POINTS_CHANGED",    onTalentChange)
    ns:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", onTalentChange)
    -- Forever: der Wechsel der Talentgruppe tauscht die Kampf-Konfiguration.
    ns:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED", onTalentChange)
    ns:RegisterEvent("PLAYER_ENTERING_WORLD",       onTalentChange)
    ns:RegisterEvent("PLAYER_REGEN_ENABLED",        onTalentChange)  -- retry after combat

    -- Vergleichsbasis SOFORT setzen, nicht erst per Timer.
    --
    -- _lastSpecGroup stand sonst noch auf -1, waehrend PLAYER_ENTERING_WORLD
    -- schon feuerte. onTalentChange hielt das fuer einen Specwechsel und hat
    -- bei jedem Login ungefragt das an die Spec gebundene Set angelegt.
    GS.resetSwitchBaselines()

    -- Kurz nach dem Login kann die Talentgruppe noch nicht feststehen;
    -- getActiveSpecGroup faellt dann auf 1 zurueck. Deshalb den Ausgangswert
    -- nach zwei Sekunden nachziehen. Das legt nichts an, es korrigiert nur
    -- die Vergleichsbasis - erst ein Wechsel DANACH loest ein Anlegen aus.
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function() GS.refreshSpecBaseline() end)
    end
    startSpecPolling()
end

function mod:OnDisable()
    ns:UnregisterEvent("UNIT_INVENTORY_CHANGED",  onInventoryChanged)
    ns:UnregisterEvent("BAG_UPDATE_DELAYED",      refreshStatusDots)
    ns:UnregisterEvent("UPDATE_SHAPESHIFT_FORM",  onShapeshiftChange)
    ns:UnregisterEvent("UPDATE_SHAPESHIFT_FORMS", onShapeshiftChange)
    ns:UnregisterEvent("PLAYER_REGEN_ENABLED",    onShapeshiftChange)
    ns:UnregisterEvent("UNIT_AURA",               onMountStateChange)
    ns:UnregisterEvent("UPDATE_SHAPESHIFT_FORM",  onMountStateChange)
    ns:UnregisterEvent("PLAYER_REGEN_ENABLED",    onMountStateChange)
    ns:UnregisterEvent("PLAYER_ENTERING_WORLD",   onMountStateChange)
    -- Die Gerte darf nicht zurueckbleiben, nur weil das Modul aus geht.
    if cropState() and not InCombatLockdown() then restoreMountSpeedItem() end
    ns:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED", onTalentChange)
    ns:UnregisterEvent("PLAYER_TALENT_UPDATE",        onTalentChange)
    ns:UnregisterEvent("CHARACTER_POINTS_CHANGED",    onTalentChange)
    ns:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", onTalentChange)
    ns:UnregisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED", onTalentChange)
    ns:UnregisterEvent("PLAYER_ENTERING_WORLD",       onTalentChange)
    ns:UnregisterEvent("PLAYER_REGEN_ENABLED",        onTalentChange)
    GS.stopSpecPolling()
    GS.hideMinimapButton()

    -- Sichtbares aufraeumen. updateVisibility entscheidet nur beim Oeffnen
    -- und Schliessen des Charakterfensters neu - ohne das hier bliebe eine
    -- gerade offene Seitenleiste samt Symbolauswahl und Kontextmenue stehen,
    -- obwohl das Modul aus ist.
    GS.hideSidebar()
    GS.hideIconPicker()
    ns:HidePopupMenu()
end
