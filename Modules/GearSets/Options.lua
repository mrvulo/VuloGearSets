-- =========================================================
-- VuloGearSets / Modules / GearSets / Options
-- Die Eintraege des Moduls im Einstellungsfenster.
-- =========================================================
local _, ns = ...
local L   = ns.L
local GS  = ns.GS
local mod = GS.mod

-- Aus frueher geladenen Dateien (siehe Shared.lua).
local LO                     = GS.LO
local SLOT_GROUPS            = GS.SLOT_GROUPS
local applyMinimapVisibility = GS.applyMinimapVisibility
local applyMountEvents       = GS.applyMountEvents
local applyMountState        = GS.applyMountState
local applySidebarVisibility = GS.applySidebarVisibility
local countSlots             = GS.countSlots
local deleteLoadout          = GS.deleteLoadout
local charDB                 = GS.charDB
local equipLoadout           = GS.equipLoadout
local formMap                = GS.formMap
local getFormName            = GS.getFormName
local getNumSpecGroups       = GS.getNumSpecGroups
local getSpecGroupLabel      = GS.getSpecGroupLabel
local overwriteLoadout       = GS.overwriteLoadout
local promptSaveWithSlots    = GS.promptSaveWithSlots
local sortedLoadoutNames     = GS.sortedLoadoutNames
local specMap                = GS.specMap


-- =========================================================
-- Options UI
-- =========================================================
-- Build a list of available form indices for dropdown values
local function buildFormDropdownValues()
    local values = { { value = 0, text = L["None"] } }
    -- Add all known shapeshift forms (max 6 in Anniversary classes)
    local numForms = (GetNumShapeshiftForms and GetNumShapeshiftForms()) or 0
    for i = 1, numForms do
        table.insert(values, { value = i, text = getFormName(i) })
    end
    return values
end

-- Build a list of spec groups (dual-spec) for dropdown values
local function buildSpecDropdownValues()
    local values = { { value = 0, text = L["None"] } }
    local numGroups = getNumSpecGroups()
    for g = 1, numGroups do
        table.insert(values, { value = g, text = getSpecGroupLabel(g) })
    end
    return values
end

-- =========================================================
-- Seiten
--
-- Jede Seite ist eine eigene Funktion; mod:GetOptions(page) waehlt aus.
-- Tooltips fuer jedes Element, Standardwerte fuer "Seite zuruecksetzen"
-- (siehe UI/OptionsFrame.lua).
-- =========================================================
local D = mod.defaults or {}

local function reanchor()
    if mod._reanchorSidebar then mod._reanchorSidebar() end
end

local function generalPage()
    local items = {
        { type = "dropdown", label = L["Window style"],
          tooltip = ns.isForever
              and L["Forever takes the look of VuloForeverUI: its colors and, with its Blizzard themes, the client's metal frame. Modern uses the dark look with a purple accent. Classic uses Blizzard's dialog frame."]
              or  L["Modern uses the dark look with a purple accent. Classic uses Blizzard's dialog frame so the windows match the default interface."],
          values = ns.STYLES,
          default = function() return ns:DefaultStyle() end,
          get = function() return ns:GetStyle() end,
          set = function(_, v) ns:SetStyle(v) end },
        { type = "toggle", label = L["Confirm before deleting a gear set"],
          tooltip = L["Asks before a gear set is deleted - from the sidebar, the settings or with /gearset delete."],
          default = D.confirmDelete ~= false,
          get = function() return mod.db.confirmDelete ~= false end,
          set = function(_, v) mod.db.confirmDelete = v end },
        { type = "dropdown", label = L["Chat messages when equipping"],
          tooltip = L["What the chat says when a gear set goes on - by click, key, spec or form. Only problems: just what did not work, such as missing items or a full bag. Saving, deleting and commands always answer."],
          values = {
              { value = "all",      text = L["All"] },
              { value = "problems", text = L["Only problems"] },
              { value = "none",     text = L["None"] },
          },
          default = D.chatMessages or "all",
          get = function() return mod.db.chatMessages or "all" end,
          set = function(_, v) mod.db.chatMessages = v end },
    }
    -- Forever: die Kampfregeln der Mainline-Familie lassen das nicht zu.
    if not ns.isForever then
        table.insert(items, { type = "toggle", label = L["Swap weapons in combat"],
          tooltip = L["Equipping a set in combat - by its key, the sidebar or the minimap menu - swaps main hand, off hand and ranged weapon right away. The game allows no other gear changes in combat; the rest of the set follows when combat ends."],
          default = D.combatWeaponSwap ~= false,
          get = function() return mod.db.combatWeaponSwap ~= false end,
          set = function(_, v) mod.db.combatWeaponSwap = v end })
    end
    return items
end

local function sliderItem(label, tooltip, field, minV, maxV)
    return { type = "slider", label = label, tooltip = tooltip,
        min = minV, max = maxV, step = 1,
        default = D[field],
        get = function() return mod.db[field] or D[field] or 0 end,
        set = function(_, v)
            mod.db[field] = v
            reanchor()
        end }
end

local function sidebarPage()
    return {
        { type = "header", text = L["Character Frame Sidebar"] },
        { type = "toggle", label = L["Show sidebar on character frame"],
          tooltip = L["Attach a quick-access sidebar to the right of the character window. Click a set to select, double-click or button to equip, right-click for context menu."],
          default = D.sidebarEnabled ~= false,
          get = function() return mod.db.sidebarEnabled ~= false end,
          set = function(_, v)
              mod.db.sidebarEnabled = v
              applySidebarVisibility()
          end },
        { type = "desc", text = L["|cffaaaaaaTip: with the character window open, enable edit mode (Unlock) to drag the sidebar; right-click the purple box to reset its position.|r"] },

        -- Expertenwerte: frueher nur ueber /gearset tune erreichbar.
        { type = "section", title = L["Fine position (advanced)"], collapsed = true, items = {
            { type = "desc", text = L["|cffaaaaaaOpen the character window to watch the sidebar move while you drag.|r"] },
            sliderItem(L["Top edge"],
                L["Moves the top edge of the sidebar up (positive) or down (negative)."],
                "sidebarTopOffset", -60, 60),
            sliderItem(L["Bottom edge"],
                L["Moves the bottom edge of the sidebar up (positive) or down (negative)."],
                "sidebarBottomOffset", -40, 160),
            sliderItem(L["Horizontal position"],
                L["Moves the sidebar left (negative) or right (positive) of the character window's visible edge."],
                "sidebarXOffset", -100, 60),
            sliderItem(L["Gap to a stats column"],
                L["Only matters when another addon attaches a stats column to the right of the character window: the space between it and the sidebar."],
                "sidebarStatsGap", 0, 60),
            { type = "button", label = L["Reset position"], width = 150,
              tooltip = L["Puts the sidebar back where it starts: the four values above and any position dragged in edit mode."],
              onClick = function()
                  for _, f in ipairs({ "sidebarTopOffset", "sidebarBottomOffset",
                                       "sidebarXOffset", "sidebarStatsGap" }) do
                      mod.db[f] = D[f]
                  end
                  local pos = charDB().sidebarPos
                  if pos then pos.x, pos.y = 0, 0 end
                  reanchor()
                  ns:RefreshOptions()
              end },
        } },

        { type = "spacer", height = 6 },
        { type = "header", text = L["Minimap Button"] },
        { type = "toggle", label = L["Show minimap button"],
          tooltip = L["Left-click for a quick set-switcher menu, right-click to open settings, drag to reposition."],
          default = true,
          get = function() return not (mod.db.minimap and mod.db.minimap.hidden) end,
          set = function(_, v)
              mod.db.minimap = mod.db.minimap or {}
              mod.db.minimap.hidden = not v
              applyMinimapVisibility()
          end },
    }
end

-- Auswahl "kein Set" plus alle Sets in der Reihenfolge der Leiste.
local function setChoiceValues()
    local values = { { value = "", text = L["None"] } }
    for _, n in ipairs(sortedLoadoutNames()) do
        values[#values + 1] = { value = n, text = n }
    end
    return values
end

-- Eine Situation: Auswahlliste mit dem Set, das sie anlegt. Kein default -
-- Zuordnungen sind wie Spec- und Gestalt-Bindungen Daten, keine
-- Einstellung, und bleiben beim Zuruecksetzen stehen (I-21).
local function triggerItem(key, label, tooltip, values)
    return { type = "dropdown", label = label, tooltip = tooltip, values = values,
        get = function() return GS.triggerMap()[key] or "" end,
        set = function(_, v)
            GS.triggerMap()[key] = (v ~= "" and v) or nil
            GS.applyTriggerEvents()
        end }
end

local function situationItems()
    local values = setChoiceValues()
    local tempTip = L["Equips the chosen set while this lasts and puts back what you wore before when it ends. Waits for the end of combat."]
    local placeTip = L["Equips the chosen set when you get there. A place without a set puts back what you wore before the first place set. Waits for the end of combat."]
    return {
        { type = "spacer", height = 6 },
        { type = "header", text = L["Situations"] },
        { type = "toggle", label = L["Equip sets for situations"],
          tooltip = L["Turns all situations below on or off at once. Which set belongs to which situation stays saved."],
          default = D.triggersEnabled ~= false,
          get = function() return mod.db.triggersEnabled ~= false end,
          set = function(_, v)
              mod.db.triggersEnabled = v
              -- Aus: Situations-Teile runter, Zustand verwerfen. An: neu
              -- beginnen, ohne alte Staende zurueckzulegen.
              GS.resetTriggerState()
              GS.applyTriggerEvents()
          end },
        { type = "desc", text = L["|cffaaaaaaWhile something lasts - the set comes off again afterwards:|r"] },
        triggerItem("mount", L["Mounted"], tempTip, values),
        triggerItem("swim", L["Swimming"], tempTip, values),
        triggerItem("fishing", L["Fishing pole in hand"],
            L["Equips the chosen set as soon as you hold a fishing pole, for example a fishing hat and boots. Your weapons are not swapped back afterwards - you just took one in hand."], values),
        triggerItem("eat", L["Eating or drinking"], tempTip, values),
        { type = "desc", text = L["|cffaaaaaaWhere you are - the set stays on until another place wants a different one:|r"] },
        triggerItem("pvp", L["Battleground"], placeTip, values),
        triggerItem("arena", L["Arena"], placeTip, values),
        triggerItem("party", L["Dungeon"], placeTip, values),
        triggerItem("raid", L["Raid"], placeTip, values),
        triggerItem("rest", L["City or inn"],
            L["Places where you rest: cities and inns. Equips the chosen set when you get there."], values),
        triggerItem("world", L["Open world"],
            L["Everywhere outside instances, cities and inns. Useful as the way back from a battleground or dungeon set."], values),
    }
end

local function automationPage()
    local items = {
        { type = "desc", text = L["|cffaaaaaaWhich gear set belongs to a stance, form or spec is chosen per set on the Saved Gear Sets page or in the sidebar's right-click menu.|r"] },
        { type = "header", text = L["Auto-Switch on Stance/Form"] },
        { type = "toggle", label = L["Enable auto-switching"],
          tooltip = L["Automatically equips a gear set when your stance/form changes (warrior stances, druid forms). Out-of-combat only — if a stance change happens in combat, the swap is deferred until combat ends."],
          default = D.autoSwitchEnabled ~= false,
          get = function() return mod.db.autoSwitchEnabled ~= false end,
          set = function(_, v) mod.db.autoSwitchEnabled = v end },
    }

    -- Dual-Spec gibt es in Classic Era gar nicht und in TBC erst nach dem
    -- Kauf. Ohne zweite Talentgruppe waere die Einstellung wirkungslos,
    -- deshalb erscheint sie dort nicht.
    if getNumSpecGroups() >= 2 then
        table.insert(items, { type = "spacer", height = 6 })
        table.insert(items, { type = "header", text = L["Auto-Switch on Dual Spec"] })
        table.insert(items, { type = "toggle", label = L["Enable spec auto-switching"],
            tooltip = L["Automatically equips a gear set when you switch between Spec 1 and Spec 2 (dual spec). Bind each gear set to a spec below. Requires dual spec to be active."],
            default = D.specSwitchEnabled ~= false,
            get = function() return mod.db.specSwitchEnabled ~= false end,
            set = function(_, v) mod.db.specSwitchEnabled = v end })
    end

    table.insert(items, { type = "spacer", height = 6 })
    table.insert(items, { type = "header", text = L["Mount Speed Trinket"] })
    table.insert(items, { type = "toggle", label = L["Equip speed trinket when mounting"],
        tooltip = L["Equips the Riding Crop (or Carrot on a Stick) from your bags into a trinket slot when you mount up, and puts it back when you dismount. Druids in flight form get the Charm of Swift Flight instead — the riding crop only affects mount speed and does nothing in flight form. Prefers a free trinket slot; otherwise the lower one is used and its item is restored afterwards. Out-of-combat only — a swap that falls into combat is deferred until combat ends."],
        default = D.ridingCropEnabled == true,
        get = function() return mod.db.ridingCropEnabled == true end,
        set = function(_, v)
            mod.db.ridingCropEnabled = v
            -- Erst die Ereignisse nachziehen, dann handeln: das Abschalten
            -- meldet UNIT_AURA ab, das Anlegen bzw. Zuruecklegen laeuft
            -- gleich darunter trotzdem direkt.
            applyMountEvents()
            -- Sofort reagieren: einschalten waehrend man reitet legt die
            -- Gerte gleich an, ausschalten nimmt sie gleich wieder ab.
            applyMountState(true)
        end })
    table.insert(items, { type = "desc", text = L["|cffaaaaaaIf a set is chosen for Mounted below and it covers a trinket slot, the speed trinket stays out of it.|r"] })
    for _, it in ipairs(situationItems()) do table.insert(items, it) end
    return items
end

-- Sets der anderen Charaktere dieses Kontos (F072). Gewaehlter Charakter
-- nur fuer die Sitzung gemerkt.
local otherChar

local function otherCharacterItems()
    local chars = GS.otherCharacters()
    local items = {
        { type = "spacer", height = 8 },
        { type = "header", text = L["Sets of your other characters"] },
    }
    if #chars == 0 then
        table.insert(items, { type = "desc", text = L["|cffaaaaaaLog in with another character once - its gear sets then show up here.|r"] })
        return items
    end
    local found = false
    for _, c in ipairs(chars) do if c == otherChar then found = true end end
    if not found then otherChar = chars[1] end

    local values = {}
    for _, c in ipairs(chars) do values[#values + 1] = { value = c, text = c } end
    table.insert(items, { type = "dropdown", label = L["Character"],
        tooltip = L["Characters of this account whose gear sets VuloGearSets has seen. Updated whenever that character logs in or out."],
        values = values,
        get = function() return otherChar end,
        set = function(_, v) otherChar = v; ns:RefreshOptions() end })
    for _, setName in ipairs(GS.setsOfCharacter(otherChar)) do
        local n, c = setName, otherChar
        table.insert(items, { type = "group", layout = "row", gap = 6, items = {
            { type = "button", label = n, width = 236,
              tooltip = L["Copies this set to the character you are playing. A set with the same name gets a number added."],
              onClick = function() GS.copyFromCharacter(c, n) end },
        } })
    end
    table.insert(items, { type = "button", label = L["Forget this character"], width = 180,
        tooltip = L["Removes this character from the list, for example after deleting it. Its own gear sets are not touched."],
        onClick = function() GS.forgetCharacter(otherChar); otherChar = nil end })
    return items
end

local function setsPage()
    local partTip = L["Saves only these slots. Equipping the set later leaves all other slots alone."]
    local items = {
        -- Breite bewusst 118: drei Knoepfe plus zwei Luecken muessen in die
        -- Inhaltsbreite des Scrollbereichs passen. Der Zeilen-Renderer
        -- bricht nicht um, deshalb zwei Gruppen statt einer langen Reihe.
        { type = "group", layout = "row", gap = 6,
          items = {
              { type = "button", label = L["Save All..."], width = 118,
                tooltip = L["Saves everything you are wearing as a gear set."],
                onClick = function() promptSaveWithSlots(nil) end },
              { type = "button", label = L["Save Trinkets..."], width = 118, tooltip = partTip,
                onClick = function() promptSaveWithSlots(SLOT_GROUPS.trinkets) end },
              { type = "button", label = L["Save Weapons..."], width = 118, tooltip = partTip,
                onClick = function() promptSaveWithSlots(SLOT_GROUPS.weapons) end },
          },
        },
        { type = "group", layout = "row", gap = 6,
          items = {
              { type = "button", label = L["Save Rings..."], width = 118, tooltip = partTip,
                onClick = function() promptSaveWithSlots(SLOT_GROUPS.rings) end },
              { type = "button", label = L["Save Armor..."], width = 118, tooltip = partTip,
                onClick = function() promptSaveWithSlots(SLOT_GROUPS.armor) end },
          },
        },
        { type = "group", layout = "row", gap = 6,
          items = {
              { type = "button", label = L["Import set..."], width = 118,
                tooltip = L["Paste a gear set someone shared as text. Their items are kept by ID, enchant and gems; what you do not have shows as missing."],
                onClick = function() GS.showImport() end },
          },
        },
        { type = "spacer", height = 8 },
    }

    local names = sortedLoadoutNames()
    if #names == 0 then
        table.insert(items, { type = "desc", text = L["|cffaaaaaaNo gear sets saved yet. Use the button above to save your current gear.|r"] })
        for _, it in ipairs(otherCharacterItems()) do table.insert(items, it) end
        return items
    end

    local formValues = buildFormDropdownValues()
    local hasForms = #formValues > 1  -- 1 = only "None" → no stance class
    local specValues = buildSpecDropdownValues()
    local hasSpecs = getNumSpecGroups() >= 2  -- only show when dual spec is active

    for _, name in ipairs(names) do
        local capturedName = name  -- closure capture
        local slotCount = countSlots(LO()[name])

        -- Row 1: name + item count (full width, separate line)
        table.insert(items, { type = "desc",
            text = string.format("|cffffd100%s|r |cff888888(%d %s)|r",
                name, slotCount, L["items"]) })

        -- Row 2: action buttons (under the name, fits properly in content width)
        table.insert(items, { type = "group", layout = "row", gap = 6,
            items = {
                { type = "button", label = L["Equip"], width = 100,
                  tooltip = L["Puts this gear set on now."],
                  onClick = function() equipLoadout(capturedName) end },
                { type = "button", label = L["Overwrite"], width = 130,
                  tooltip = L["Replaces the set's items with what you are wearing in its slots."],
                  onClick = function() overwriteLoadout(capturedName) end },
                { type = "button", label = L["Delete"], width = 100,
                  tooltip = L["Deletes this gear set."],
                  onClick = function()
                      if mod.db.confirmDelete then
                          local dlg = StaticPopup_Show("VGS_GEARSET_DELETE", capturedName)
                          if dlg then dlg.data = capturedName end
                      else
                          deleteLoadout(capturedName)
                      end
                  end },
            },
        })

        -- Row 3: Auto-equip on talent spec dropdown
        if hasSpecs then
            table.insert(items, { type = "dropdown",
                label = L["Auto-equip on spec"],
                tooltip = L["Equip this gear set automatically when you switch to this spec."],
                values = specValues,
                get = function() return (specMap() and specMap()[capturedName]) or 0 end,
                set = function(_, v)
                    -- 1:1 mapping — clear any other loadout on this spec tab
                    if v and v ~= 0 then
                        for other, tabIdx in pairs(specMap()) do
                            if tabIdx == v and other ~= capturedName then
                                specMap()[other] = nil
                            end
                        end
                    end
                    specMap()[capturedName] = (v ~= 0) and v or nil
                end,
            })
        end

        -- Row 4: Auto-equip on form dropdown (only show if class has forms)
        if hasForms then
            table.insert(items, { type = "dropdown",
                label = L["Auto-equip on form"],
                tooltip = L["Equip this gear set automatically when the chosen stance/form is activated."],
                values = formValues,
                get = function() return (formMap() and formMap()[capturedName]) or 0 end,
                set = function(_, v)
                    -- Clear any other loadout currently mapped to this form (1:1 mapping)
                    if v and v ~= 0 then
                        for other, formIdx in pairs(formMap()) do
                            if formIdx == v and other ~= capturedName then
                                formMap()[other] = nil
                            end
                        end
                    end
                    formMap()[capturedName] = (v ~= 0) and v or nil
                end,
            })
        end

        -- Separator before next loadout
        table.insert(items, { type = "spacer", height = 4 })
    end
    for _, it in ipairs(otherCharacterItems()) do table.insert(items, it) end
    return items
end

local function infoPage()
    local items = {
        { type = "desc", text = L["Save your current equipment as named gear sets and quickly switch between them. Equipping requires you to be out of combat — items in your bags are auto-equipped via Use."] },
        { type = "spacer", height = 6 },
        { type = "header", text = L["Commands"] },
    }
    for _, line in ipairs(GS.commandLines()) do
        table.insert(items, { type = "desc", text = line })
    end
    return items
end

local PAGE_BUILDERS = {
    general    = generalPage,
    sidebar    = sidebarPage,
    automation = automationPage,
    sets       = setsPage,
    info       = infoPage,
}

-- Vor den Eintraegen anderer Module auf denselben Seiten.
mod.optionsOrder = { general = 10, sidebar = 10, automation = 10, sets = 10, info = 10 }

function mod:GetOptions(page)
    local build = PAGE_BUILDERS[page]
    return build and build() or nil
end
