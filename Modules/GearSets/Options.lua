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

function mod:GetOptions()
    local items = {
        { type = "header", text = L["Gear Sets"] },
        { type = "desc", text = L["Save your current equipment as named gear sets and quickly switch between them. Equipping requires you to be out of combat — items in your bags are auto-equipped via Use."] },

        { type = "spacer", height = 6 },
        -- Breite bewusst 118: drei Knoepfe plus zwei Luecken muessen in die
        -- Inhaltsbreite des Scrollbereichs passen (408 px). Mit 130 ragte der
        -- dritte darueber hinaus und wurde am rechten Rand abgeschnitten.
        -- Der Zeilen-Renderer bricht nicht um, deshalb zwei Gruppen statt
        -- einer langen Reihe.
        { type = "group", layout = "row", gap = 6,
          items = {
              { type = "button", label = L["Save All..."], width = 118,
                onClick = function() promptSaveWithSlots(nil) end },
              { type = "button", label = L["Save Trinkets..."], width = 118,
                onClick = function() promptSaveWithSlots(SLOT_GROUPS.trinkets) end },
              { type = "button", label = L["Save Weapons..."], width = 118,
                onClick = function() promptSaveWithSlots(SLOT_GROUPS.weapons) end },
          },
        },
        { type = "group", layout = "row", gap = 6,
          items = {
              { type = "button", label = L["Save Rings..."], width = 118,
                onClick = function() promptSaveWithSlots(SLOT_GROUPS.rings) end },
              { type = "button", label = L["Save Armor..."], width = 118,
                onClick = function() promptSaveWithSlots(SLOT_GROUPS.armor) end },
          },
        },
        { type = "toggle", label = L["Confirm before deleting a gear set"],
          get = function() return mod.db.confirmDelete ~= false end,
          set = function(_, v) mod.db.confirmDelete = v end },

        { type = "toggle", label = L["Show set membership in item tooltips"],
          tooltip = L["Adds a line to every item tooltip naming the gear sets the item belongs to — in your bags, at the bank, on your character and on links in chat."],
          get = function() return ns:IsModuleEnabled("itemtooltip") end,
          set = function(_, v) if ns.ToggleModule then ns:ToggleModule("itemtooltip", v, true) end end },

        { type = "dropdown", label = L["Window style"],
          tooltip = ns.isForever
              and L["Forever takes the look of VuloForeverUI: its colors and, with its Blizzard themes, the client's metal frame. Modern uses the dark look with a purple accent. Classic uses Blizzard's dialog frame."]
              or  L["Modern uses the dark look with a purple accent. Classic uses Blizzard's dialog frame so the windows match the default interface."],
          values = ns.STYLES,
          get = function() return ns:GetStyle() end,
          set = function(_, v) ns:SetStyle(v) end },

        { type = "spacer", height = 6 },
        { type = "header", text = L["Character Frame Sidebar"] },
        { type = "toggle", label = L["Show sidebar on character frame"],
          tooltip = L["Attach a quick-access sidebar to the right of the character window. Click a set to select, double-click or button to equip, right-click for context menu."],
          get = function() return mod.db.sidebarEnabled ~= false end,
          set = function(_, v)
              mod.db.sidebarEnabled = v
              applySidebarVisibility()
          end },
        { type = "desc", text = L["|cffaaaaaaTip: with the character window open, enable edit mode (Unlock) to drag the sidebar; right-click the purple box to reset its position.|r"] },

        -- Slot Picker (formerly its own module, now integrated here)
        { type = "spacer", height = 6 },
        { type = "section", title = L["Slot Picker"], collapsed = false, items = {
            { type = "desc", text = L["|cffaaaaaaHover an equipment slot to see the matching items from your bags right next to it, and click one to equip. The click below opens the full window with all of them.|r"] },
            { type = "toggle", label = L["Enable slot picker"],
              get = function() return ns:IsModuleEnabled("slotpicker") end,
              set = function(_, v) if ns.ToggleModule then ns:ToggleModule("slotpicker", v) end end },
            { type = "dropdown", label = L["Activation modifier"],
              tooltip = L["Which click opens the full picker window. Hovering a slot always shows the compact list, regardless of this setting."],
              values = {
                  { value = "right",       text = L["Right-click only"] },
                  { value = "shift-right", text = L["Shift + Right-click"] },
                  { value = "alt-right",   text = L["Alt + Right-click"] },
                  { value = "ctrl-right",  text = L["Ctrl + Right-click"] },
              },
              get = function() local sp = ns.modules and ns.modules.slotpicker; return (sp and sp.db and sp.db.modifier) or "right" end,
              set = function(_, v) local sp = ns.modules and ns.modules.slotpicker; if sp and sp.db then sp.db.modifier = v end end },
            { type = "slider", label = L["Grid columns"],
              tooltip = L["How many item icons per row in the picker popup."],
              min = 4, max = 14, step = 1,
              get = function() local sp = ns.modules and ns.modules.slotpicker; return (sp and sp.db and sp.db.cols) or 8 end,
              set = function(_, v) local sp = ns.modules and ns.modules.slotpicker; if sp and sp.db then sp.db.cols = v end end },
        } },

        -- Sockel-Leiste (eigenes Modul, versteckt registriert)
        { type = "spacer", height = 6 },
        { type = "section", title = L["Socket Bar"], collapsed = false, items = {
            { type = "desc", text = L["|cffaaaaaaA strip with every socket on your equipped gear, hung under the sidebar. Click an empty socket to pick a gem from your bags and set it.|r"] },
            { type = "toggle", label = L["Show the socket bar"],
              -- Auf Forever gibt es VuloClassicUI nicht, der zweite Satz
              -- waere dort nur verwirrend.
              tooltip = ns.isForever and L["Only appears when your gear actually has sockets."]
                  or L["Only appears when your gear actually has sockets. If VuloClassicUI shows the same strip, this one steps back so there are not two of them."],
              get = function() return ns:IsModuleEnabled("socketbar") end,
              set = function(_, v)
                  if ns.ToggleModule then ns:ToggleModule("socketbar", v, true) end
                  if ns.RefreshSocketBar then ns.RefreshSocketBar() end
              end },
            { type = "toggle", label = L["Mark empty sockets"],
              tooltip = L["Draws a red frame around sockets that have no gem."],
              get = function()
                  local sb = ns.modules and ns.modules.socketbar
                  return not (sb and sb.db and sb.db.markEmpty == false)
              end,
              set = function(_, v)
                  local sb = ns.modules and ns.modules.socketbar
                  if sb and sb.db then sb.db.markEmpty = v end
                  if ns.RefreshSocketBar then ns.RefreshSocketBar() end
              end },
            { type = "toggle", label = L["Ask before overwriting a socket"],
              tooltip = L["A socket that already holds a gem asks first: the old gem is destroyed when a new one goes in. Empty sockets never ask."],
              get = function()
                  local sb = ns.modules and ns.modules.socketbar
                  return not (sb and sb.db and sb.db.confirmOverwrite == false)
              end,
              set = function(_, v)
                  local sb = ns.modules and ns.modules.socketbar
                  if sb and sb.db then sb.db.confirmOverwrite = v end
              end },
        } },

        { type = "spacer", height = 6 },
        { type = "header", text = L["Minimap Button"] },
        { type = "toggle", label = L["Show minimap button"],
          tooltip = L["Left-click for a quick set-switcher menu, right-click to open settings, drag to reposition."],
          get = function() return not (mod.db.minimap and mod.db.minimap.hidden) end,
          set = function(_, v)
              mod.db.minimap = mod.db.minimap or {}
              mod.db.minimap.hidden = not v
              applyMinimapVisibility()
          end },

        { type = "spacer", height = 6 },
        { type = "header", text = L["Auto-Switch on Stance/Form"] },
        { type = "toggle", label = L["Enable auto-switching"],
          tooltip = L["Automatically equips a gear set when your stance/form changes (warrior stances, druid forms). Out-of-combat only — if a stance change happens in combat, the swap is deferred until combat ends."],
          get = function() return mod.db.autoSwitchEnabled ~= false end,
          set = function(_, v) mod.db.autoSwitchEnabled = v end },
    }

    -- Forever: Spiegeln in Blizzards Ausruestungsmanager, direkt vor dem
    -- Fensterstil. Nicht als "cond and {...} or nil" in der Tabelle - das
    -- Loch beendete ipairs mitten in der Liste.
    if ns.isForever then
        for i, it in ipairs(items) do
            if it.label == L["Window style"] then
                table.insert(items, i, {
                    type = "toggle", label = L["Also keep sets in Blizzard's equipment manager"],
                    tooltip = L["Mirrors every set into the equipment manager of the character window as soon as you save it or wear it completely. This gives the set a button for your action bars (right-click menu of the set), stores it on the server and lets other addons and bag windows see which items belong to it. Blizzard only allows a limited number of sets per character."],
                    get = function() return ns:IsModuleEnabled("blizzsets") end,
                    set = function(_, v) if ns.ToggleModule then ns:ToggleModule("blizzsets", v, true) end end,
                })
                break
            end
        end
    end

    -- Dual-Spec gibt es in Classic Era gar nicht und in TBC erst nach dem
    -- Kauf. Ohne zweite Talentgruppe waere die Einstellung wirkungslos,
    -- deshalb erscheint sie dort nicht.
    if getNumSpecGroups() >= 2 then
        table.insert(items, { type = "spacer", height = 6 })
        table.insert(items, { type = "header", text = L["Auto-Switch on Dual Spec"] })
        table.insert(items, { type = "toggle", label = L["Enable spec auto-switching"],
            tooltip = L["Automatically equips a gear set when you switch between Spec 1 and Spec 2 (dual spec). Bind each gear set to a spec below. Requires dual spec to be active."],
            get = function() return mod.db.specSwitchEnabled ~= false end,
            set = function(_, v) mod.db.specSwitchEnabled = v end })
    end

    table.insert(items, { type = "spacer", height = 6 })
    table.insert(items, { type = "header", text = L["Mount Speed Trinket"] })
    table.insert(items, { type = "toggle", label = L["Equip speed trinket when mounting"],
        tooltip = L["Equips the Riding Crop (or Carrot on a Stick) from your bags into a trinket slot when you mount up, and puts it back when you dismount. Druids in flight form get the Charm of Swift Flight instead — the riding crop only affects mount speed and does nothing in flight form. Prefers a free trinket slot; otherwise the lower one is used and its item is restored afterwards. Out-of-combat only — a swap that falls into combat is deferred until combat ends."],
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

    table.insert(items, { type = "spacer", height = 8 })
    table.insert(items, { type = "header", text = L["Saved Gear Sets"] })

    local names = sortedLoadoutNames()
    if #names == 0 then
        table.insert(items, { type = "desc", text = L["|cffaaaaaaNo gear sets saved yet. Use the button above to save your current gear.|r"] })
    else
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
                      onClick = function() equipLoadout(capturedName) end },
                    { type = "button", label = L["Overwrite"], width = 130,
                      onClick = function() overwriteLoadout(capturedName) end },
                    { type = "button", label = L["Delete"], width = 100,
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
    end

    table.insert(items, { type = "spacer", height = 8 })
    table.insert(items, { type = "desc", text = L["|cffaaaaaaSlash commands: /gearset save <name>, /gearset equip <name>, /gearset delete <name>, /gearset list. Short alias: /vgs|r"] })

    return items
end
