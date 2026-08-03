-- =========================================================
-- VuloGearSets / Modules / SocketBar
-- Eine Leiste mit jedem Sockel der angelegten Ausruestung, unter die
-- Seitenleiste gehaengt - samt dem Sockeln selbst: Klick auf einen
-- leeren Sockel, Stein aus den Taschen waehlen, fertig.
--
-- WARUM EIN EIGENES MODUL
--   Es ist eine eigenstaendige Flaeche, die vom Set-Modul nur den
--   Anker (die Seitenleiste) borgt. Versteckt registriert wie der
--   Slot-Picker: die Einstellungen stehen auf der Seite des
--   Set-Moduls, eine eigene Optionsseite wuerde nie aufgerufen.
--
-- CLIENT-UNTERSCHIEDE
--   Nirgends wird gefragt, welche Spielversion laeuft. Jeder
--   Sockel-Aufruf wird einmal geprobt und faellt von C_ItemSocketInfo
--   auf das blanke Global zurueck. Die Sockeldaten selbst kommen aus
--   dem Item-Tooltip und dem Itemlink, und die beantwortet jeder
--   Client gleich. In Classic Era gibt es gar keine Sockel - der Scan
--   findet nichts und die Leiste erscheint nie, ganz ohne Versionstest.
--
-- TAINT
--   Alle Frames hier sind unsere eigenen. Blizzard-Frames werden nur
--   GELESEN (GetBottom, Breite) und als Elternteil bzw. Anker benutzt.
--   Die Sockel-Folge laeuft aus einem echten Klick und fasst nur
--   ungeschuetzte API an.
-- =========================================================
local _, ns = ...
local L = ns.L

-- Verstecktes Modul, siehe Kopf: die Optionen stehen im Abschnitt
-- "Sockel-Leiste" auf der Seite des Set-Moduls.
local mod = ns:RegisterModule("socketbar", {
    name     = "Socket Bar",
    group    = "_hidden",
    defaults = {
        enabled   = true,
        markEmpty = true,
    },
})

-- =========================================================
-- Was der Client kann
--
-- Proben und zurueckfallen, nie ein Versionstest: diese Aufrufe liegen
-- auf neueren Clients unter C_ItemSocketInfo und auf aelteren als
-- blanke Globals. Was fehlt, liefert schlicht nil, und die Leiste
-- bleibt eine reine Anzeige.
-- =========================================================
local CIS = _G.C_ItemSocketInfo
local SocketInventoryItemFn = (CIS and CIS.SocketInventoryItem) or _G.SocketInventoryItem
local GetNumSocketsFn       = (CIS and CIS.GetNumSockets)       or _G.GetNumSockets
local ClickSocketButtonFn   = (CIS and CIS.ClickSocketButton)   or _G.ClickSocketButton
local AcceptSocketsFn       = (CIS and CIS.AcceptSockets)       or _G.AcceptSockets
local CloseSocketInfoFn     = (CIS and CIS.CloseSocketInfo)     or _G.CloseSocketInfo
-- Nennt das Item, zu dem die offene Sitzung gehoert. Fuers Sockeln nicht
-- noetig, aber der Beweis, dass die Sitzung die ist, nach der unser Klick
-- gefragt hat. Wo der Aufruf fehlt, fassen wir keine Sitzung an, die wir
-- nicht identifizieren koennen.
local GetSocketItemInfoFn   = (CIS and CIS.GetSocketItemInfo)   or _G.GetSocketItemInfo

local CAN_SOCKET = (SocketInventoryItemFn and GetNumSocketsFn
    and ClickSocketButtonFn and AcceptSocketsFn) and true or false

local GetContainerItemID   = (C_Container and C_Container.GetContainerItemID)   or _G.GetContainerItemID
local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
local PickupContainerItem  = (C_Container and C_Container.PickupContainerItem)  or _G.PickupContainerItem

-- =========================================================
-- Masse
-- =========================================================
local ICON     = 18   -- Kantenlaenge eines Sockelsymbols
local GAP      = 3
local BAR_PAD  = 5
local GEM_SIZE = 30   -- Steinknopf in der Auswahl
local GEM_PAD  = 4
local GEM_COLS = 6

-- Itemklasse "Edelstein". Das Enum fehlt auf den aelteren Clients; 3 ist
-- auf jedem von ihnen die Klassen-ID.
local GEM_CLASS = (_G.Enum and _G.Enum.ItemClass and _G.Enum.ItemClass.Gem) or 3

-- Der Item-Tooltip traegt eine Textur je Sockel. Vier ist das Maximum
-- eines Items - alles darueber waere kein Sockel mehr, sondern ein
-- Phantomsymbol, das eine Sitzung fuer einen nicht vorhandenen
-- Sockelindex oeffnet. GELEERT werden trotzdem zehn: davor schuetzt das,
-- naemlich vor Resten aus dem Scan eines anderen Items.
local MAX_SOCKETS      = 4
local MAX_TIP_TEXTURES = 10

-- Aus den Globals gebaut, damit ein Client, dem ein Slot fehlt, einfach
-- nichts beitraegt. Nach Inventar-ID sortiert: grob Kopf bis Fuesse, der
-- Umhang sitzt spaet (er ist ID 15) statt neben den Schultern. Betrifft
-- nur die Reihenfolge in der Leiste.
local SLOTS = {}
do
    local names = {
        "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HAND", "WAIST",
        "LEGS", "FEET", "FINGER1", "FINGER2", "TRINKET1", "TRINKET2",
        "MAINHAND", "OFFHAND", "RANGED",
    }
    for _, n in ipairs(names) do
        local id = _G["INVSLOT_" .. n]
        if id then SLOTS[#SLOTS + 1] = id end
    end
    table.sort(SLOTS)
end

-- =========================================================
-- Optionen
-- =========================================================
local function opt(key, default)
    local d = mod.db
    if d and d[key] ~= nil then return d[key] end
    return default
end

-- VuloClassicUI bringt dieselbe Leiste mit. Laufen beide, stuenden zwei
-- identische Streifen am Charakterfenster - deshalb tritt unserer
-- zurueck, solange der andere sichtbar ist. Nur gelesen, nichts
-- angefasst.
local function foreignBarUp()
    local f = _G.VCUI_SocketBar
    return (f and f.IsShown and f:IsShown()) and true or false
end

local function barWanted()
    if not ns:IsModuleEnabled("socketbar") then return false end
    if foreignBarUp() then return false end
    return true
end

-- =========================================================
-- Die Sockel lesen
-- =========================================================
local scanTip

local function ensureScanTip()
    if scanTip then return scanTip end
    scanTip = CreateFrame("GameTooltip", "VGS_SocketScanTooltip", nil, "GameTooltipTemplate")
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    return scanTip
end

-- Eine Textur je Sockel, in Sockelreihenfolge: das Symbol des Steins, wo
-- einer sitzt, sonst die Grafik des leeren Sockels. ClearLines versteckt
-- Tooltip-TEXTUREN nicht zuverlaessig, ein sockelloses Item nach einem
-- besetzten wuerde dessen Symbole erben - also von Hand verstecken.
local function socketTexturesFor(slot)
    local tip = ensureScanTip()
    for i = 1, MAX_TIP_TEXTURES do
        local t = _G["VGS_SocketScanTooltipTexture" .. i]
        if t then t:Hide() end
    end
    tip:ClearLines()
    tip:SetInventoryItem("player", slot)

    local out = {}
    for i = 1, MAX_SOCKETS do
        local t = _G["VGS_SocketScanTooltipTexture" .. i]
        if t and t:IsShown() then
            out[#out + 1] = t:GetTexture()
        end
    end
    return out
end

-- Die Stein-IDs sind Feld 3..6 des Itemstrings, also Feld 3+index fuer
-- Sockel `index`. Die zusaetzlichen Klammern um select() sind Pflicht: es
-- liefert alle Werte ab dieser Position, und der naechste wuerde bei
-- tonumber als Basis-Argument landen.
local function gemIDAt(link, index)
    if not link then return nil end
    local itemString = link:match("item[%-?%d:]+")
    if not itemString then return nil end
    local id = tonumber((select(3 + index, strsplit(":", itemString))))
    if id and id > 0 then return id end
    return nil
end

local sockets = {}   -- geordnet: { slot, index, gemID, texture, itemLink }

local function rebuildSocketList()
    for i = #sockets, 1, -1 do sockets[i] = nil end

    for _, slot in ipairs(SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local textures = socketTexturesFor(slot)
            for i = 1, #textures do
                sockets[#sockets + 1] = {
                    slot     = slot,
                    index    = i,
                    gemID    = gemIDAt(link, i),
                    texture  = textures[i],
                    itemLink = link,
                }
            end
        end
    end
end

-- =========================================================
-- Steine in den Taschen
-- =========================================================
local function bagGems()
    local out, seen = {}, {}
    if not (GetContainerNumSlots and GetItemInfoInstant) then return out end

    for bag = 0, (_G.NUM_BAG_SLOTS or 4) do
        local n = GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            -- GetContainerItemID liest den Platz direkt und antwortet auch
            -- fuer ein Item, das dieser Client nie zwischengespeichert hat
            -- (ein Stein frisch aus der Post) - was GetContainerItemInfo
            -- nicht tut.
            local id = GetContainerItemID and GetContainerItemID(bag, slot)
            if id and not seen[id] then
                local _, _, _, _, icon, classID = GetItemInfoInstant(id)
                if classID == GEM_CLASS then
                    seen[id] = true
                    out[#out + 1] = { itemID = id, bag = bag, slot = slot, icon = icon }
                end
            end
        end
    end
    return out
end

local function findBagSlot(itemID)
    if not GetContainerNumSlots then return nil end
    for bag = 0, (_G.NUM_BAG_SLOTS or 4) do
        local n = GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            if GetContainerItemID and GetContainerItemID(bag, slot) == itemID then
                return bag, slot
            end
        end
    end
    return nil
end

-- =========================================================
-- Die Sockel-Folge (ereignisgesteuert, ohne Timer)
-- =========================================================
local pending       -- laufende Aktion
local pendingToken  -- steigt mit jeder Aktion, damit ein spaeter Timer weiss, dass er veraltet ist
local ourSession    -- eine von UNS geoeffnete Sockel-Sitzung ist womoeglich noch offen
local picker                         -- vorwaerts: der Steinauswahl-Frame
local refreshBar, queueRefresh       -- vorwaerts
local watchSession, unwatchSession   -- vorwaerts: der Ereignis-Frame der Sitzung

local function closeOurSession()
    if CloseSocketInfoFn then CloseSocketInfoFn() end
    -- Guertel fuer einen Client, auf dem der Aufruf still ins Leere geht:
    -- das Fenster verstecken, dessen eigenes OnHide die Sitzung beendet.
    -- Niemals unsichtbar-aber-lebendig zuruecklassen - eine offene Sitzung
    -- blockiert jeden weiteren Sockelklick, ohne Weg sie zu beenden.
    local f = _G.ItemSocketingFrame
    if f and f:IsShown() and not InCombatLockdown() and _G.HideUIPanel then
        _G.HideUIPanel(f)
    end
end

-- Alles, was eine Aktion beendet, beendet sie HIER, damit kein Pfad die
-- laufende Aktion und den Sitzungs-Lauscher zuruecklaesst. Eine
-- liegengebliebene Aktion ist kein totes Feature, sondern eine scharfe
-- Falle: die naechste Sockel-Sitzung, die der SPIELER von Hand oeffnet,
-- wuerde von unserem Handler beantwortet - der wuerde den alten Stein in
-- ihr Item setzen und fuer sie bestaetigen.
local function abandonPending()
    pending = nil
    ourSession = false
    unwatchSession()
end

local function doSocket(rec, gemItemID)
    if not CAN_SOCKET then return end
    if InCombatLockdown() then
        ns:Print(L["Cannot socket gems in combat."])
        return
    end
    if CursorHasItem and CursorHasItem() then return end   -- nie ein gehaltenes Item kapern

    local f = _G.ItemSocketingFrame
    if f and f:IsShown() then
        if ourSession then
            -- Rest unserer eigenen letzten Aktion (das Bestaetigen hat sie
            -- nicht geschlossen): jetzt beenden, damit das Sockeln nicht
            -- stumm tot ist, bis der Spieler das Fenster von Hand
            -- schliesst. Bewusst KEIN Neuoeffnen im selben Klick - das
            -- Schliessereignis der alten Sitzung wuerde die neue Aktion
            -- mitten im Flug loeschen. Der naechste Klick geht sauber durch.
            closeOurSession()
        else
            ns:Print(L["Close the socketing window first."])
        end
        return
    end

    -- Der Itemname wird VOR dem Aufruf gelesen, damit der Update-Handler
    -- beweisen kann, dass die Sitzung die ist, nach der dieser Klick fragte.
    local wantName
    if GetItemInfo then
        wantName = GetItemInfo(GetInventoryItemLink("player", rec.slot) or "")
    end

    local token = (pendingToken or 0) + 1
    pendingToken = token
    pending = {
        slot      = rec.slot,
        index     = rec.index,
        gemItemID = gemItemID,
        itemName  = wantName,
        token     = token,
        acted     = false,
    }
    ourSession = true
    -- Die Sitzungsereignisse bekommen ihren EIGENEN Lauscher, lebendig von
    -- hier bis zum Ende der Sitzung. Sie duerfen nicht an der Leiste
    -- haengen: das Sockelfenster zu oeffnen ist das Oeffnen eines
    -- UI-Panels, und der Panel-Manager schiebt dafuer womoeglich das
    -- Charakterfenster hinaus - was den Lauscher der Leiste mitnaehme und
    -- die Folge auf ein Update warten liesse, das nie kommt.
    watchSession()
    SocketInventoryItemFn(rec.slot)
    if picker then picker:Hide() end

    -- Der Aufruf oben oeffnet gar nichts, wenn der Slot unter der offenen
    -- Auswahl geleert wurde oder das Item doch nicht sockelbar ist. Dann
    -- kommt nie ein Ereignis, also wuerde nichts die Aktion loeschen -
    -- das hier tut es. Das Token macht ihn wirkungslos, sobald die Aktion,
    -- fuer die er scharf gemacht wurde, vorbei ist.
    if C_Timer and C_Timer.After then
        C_Timer.After(5, function()
            if pending and pending.token == token and not pending.acted then
                abandonPending()
            end
        end)
    end
end

-- Laeuft innerhalb von SOCKET_INFO_UPDATE, sobald die Sitzung wirklich steht.
local function onSocketInfoUpdate()
    if not pending then return end

    if pending.acted then
        -- Nach dem Handeln kommen weiter Updates (der aufgenommene Stein,
        -- der im Sockel-UI landet, ist eines). War das erste Bestaetigen
        -- schneller als die Registrierung des Steins, kommt nie ein
        -- Bestaetigungsereignis und das Fenster wartet auf einen
        -- Handklick - also begrenzt nachlegen, damit ein wirklich nicht
        -- annehmbarer Zustand keine Schleife dreht.
        --
        -- Niemals waehrend einer stehenden Rueckfrage: erneut zu
        -- bestaetigen ist genau das, was deren Ja-Knopf tut - wir wuerden
        -- also die Frage "das bindet das Item an dich" fuer den Spieler
        -- beantworten.
        if pending.awaitConfirm then return end
        local n = pending.reaccepts or 0
        if n < 3 and AcceptSocketsFn then
            pending.reaccepts = n + 1
            AcceptSocketsFn()
        end
        return
    end

    -- Ist diese Sitzung ueberhaupt unsere? Ein Klick, der nichts geoeffnet
    -- hat, laesst die Aktion stehen (der Timer oben loescht sie, aber nicht
    -- sofort), und ohne diese Pruefung wuerde die naechste Sitzung, die der
    -- Spieler VON HAND oeffnet, fuer ihn gesockelt und bestaetigt. Der
    -- Itemvergleich ist der Beweis; wo der Client das Item der Sitzung
    -- nicht nennt, bleibt die Sitzung ganz unangetastet.
    if not GetInventoryItemLink("player", pending.slot) then
        abandonPending()   -- der Slot wurde unter der offenen Auswahl geleert
        return
    end
    if GetSocketItemInfoFn then
        local sessionName = GetSocketItemInfoFn()
        if not sessionName or (pending.itemName and sessionName ~= pending.itemName) then
            return
        end
    elseif not ourSession then
        return
    end

    local numSockets = GetNumSocketsFn and GetNumSocketsFn()
    if not numSockets or pending.index > numSockets then
        return   -- Sitzung noch nicht bereit; das naechste Update probiert es. Kein Timer.
    end
    pending.acted = true

    -- Jetzt gesucht, nicht beim Klick: die Taschen koennen sich zwischen
    -- Klick und Oeffnen der Sitzung umsortieren.
    local bag, slot = findBagSlot(pending.gemItemID)
    if not bag then
        abandonPending()
        closeOurSession()
        return
    end

    if PickupContainerItem then PickupContainerItem(bag, slot) end
    -- Ein gesperrter Taschenplatz (ein Tausch noch im Flug) macht das
    -- Aufnehmen zum stillen Nichts, und ein Sockelklick mit leerer Hand
    -- ENTFERNT den vorgeschlagenen Stein, statt einen zu setzen. Verloren
    -- geht so oder so nichts, aber einen leeren Vorschlag zu bestaetigen
    -- hat keinen Sinn.
    if CursorHasItem and not CursorHasItem() then
        pending.acted = false
        return
    end
    ClickSocketButtonFn(pending.index)
    if ClearCursor then ClearCursor() end
    AcceptSocketsFn()
    -- Kein erzwungenes Schliessen: ab hier gehoeren die Binde- und
    -- Erstattungsrueckfragen dem Client.
end

-- =========================================================
-- Die Steinauswahl
-- =========================================================
local gemButtons = {}

local function createPicker()
    if picker then return picker end

    picker = CreateFrame("Frame", "VGS_SocketGemPicker", UIParent,
        BackdropTemplateMixin and "BackdropTemplate")
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetSize(240, 80)
    picker:EnableMouse(true)
    picker:SetClampedToScreen(true)
    picker:Hide()
    ns.UI:SkinFrame(picker, "window")
    ns.UI:CreateShadow(picker)
    tinsert(UISpecialFrames, "VGS_SocketGemPicker")

    picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    picker.title:SetTextColor(ns:AccentColor())

    picker.close = ns.UI:CreateButton(picker, "X", 18, 18)
    picker.close:SetOnClick(function() picker:Hide() end)

    -- Schliesst sich selbst, sobald der Zeiger drin war und wieder
    -- draussen ist, mit einer Gnadenfrist, die den Weg zurueck zum
    -- Sockelsymbol ueberbrueckt.
    picker:SetScript("OnShow", function(self) self.armed = false; self.outTime = 0 end)
    picker:SetScript("OnUpdate", function(self, elapsed)
        local overSelf = self:IsMouseOver(8, -8, -8, 8)
        local overIcon = self.anchorBtn and self.anchorBtn.IsMouseOver and self.anchorBtn:IsMouseOver()
        if overSelf then self.armed = true end
        if overSelf or overIcon then
            self.outTime = 0
        elseif self.armed then
            self.outTime = (self.outTime or 0) + elapsed
            if self.outTime > 0.5 then self:Hide() end
        end
    end)

    return picker
end

local function acquireGemButton(i)
    local btn = gemButtons[i]
    if btn then return btn end

    btn = CreateFrame("Button", nil, picker)
    btn:SetSize(GEM_SIZE, GEM_SIZE)

    btn.ring = btn:CreateTexture(nil, "BACKGROUND")
    btn.ring:SetAllPoints(btn)
    btn.ring:SetColorTexture(0.25, 0.25, 0.3, 1)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    btn.count = btn:CreateFontString(nil, "OVERLAY")
    btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    ns.UI.Font(btn.count, 10, "OUTLINE")
    btn.count:SetTextColor(1, 1, 1)

    local hov = btn:CreateTexture(nil, "HIGHLIGHT")
    hov:SetAllPoints(btn)
    hov:SetColorTexture(1, 1, 1, 0.12)

    btn:SetScript("OnEnter", function(self)
        if not (self.bag and self.slot) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.bag, self.slot)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self)
        if not (picker and picker.rec and self.itemID) then return end
        doSocket(picker.rec, self.itemID)
    end)

    gemButtons[i] = btn
    return btn
end

local function populatePicker(rec, anchorBtn)
    createPicker()

    picker.rec = rec
    picker.anchorBtn = anchorBtn
    picker.title:SetText(L["Choose a gem"])
    picker.title:SetTextColor(ns:AccentColor())

    local gems = bagGems()
    for _, b in ipairs(gemButtons) do b:Hide() end

    local pad = 8 + ns:FrameInset()
    local top = 26 + ns:FrameInset()

    -- Kopfzeile bei jedem Oeffnen neu setzen statt einmal beim Bauen: der
    -- Aufschlag fuer den Rahmen aendert sich mit dem Stil, und ohne das
    -- saessen Titel und Schliessen-Knopf im Classic-Stil auf der Grafik.
    picker.title:ClearAllPoints()
    picker.title:SetPoint("TOPLEFT", picker, "TOPLEFT", pad, -(6 + ns:FrameInset()))
    picker.close:ClearAllPoints()
    picker.close:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -(pad - 2), -(4 + ns:FrameInset()))

    if #gems == 0 then
        if not picker.emptyText then
            picker.emptyText = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            picker.emptyText:SetPoint("CENTER", picker, "CENTER", 0, -10)
            picker.emptyText:SetTextColor(0.7, 0.7, 0.7)
        end
        picker.emptyText:SetText(L["No gems in your bags."])
        picker.emptyText:Show()
        picker:SetSize(200 + ns:FrameInset() * 2, top + 30 + ns:FrameInset())
    else
        if picker.emptyText then picker.emptyText:Hide() end

        local cols = math.min(GEM_COLS, #gems)
        local rows = math.ceil(#gems / cols)
        -- Das Fenster WAECHST um den Rahmen, den es traegt, statt ihn aus
        -- dem Inhalt zu bezahlen: Blizzards Dialograhmen ist 32 Pixel
        -- Grafik gegen eine Ein-Pixel-Kante, und ohne den Aufschlag saesse
        -- die letzte Spalte auf dem Rahmen.
        picker:SetSize(
            math.max(200, cols * (GEM_SIZE + GEM_PAD) - GEM_PAD + pad * 2),
            top + rows * (GEM_SIZE + GEM_PAD) - GEM_PAD + pad)

        for i, g in ipairs(gems) do
            local btn = acquireGemButton(i)
            btn.itemID, btn.bag, btn.slot = g.itemID, g.bag, g.slot

            local icon = g.icon
            local _, _, quality = GetItemInfo(g.itemID)
            -- Ein Stein, den dieser Client nie geladen hat (frisch aus der
            -- Post), hat noch keine Qualitaet. Das Laden anstossen, sonst
            -- bliebe sein Ring grau, bis die Taschen sich das naechste Mal
            -- ruehren.
            if quality == nil and C_Item and C_Item.RequestLoadItemDataByID then
                pcall(C_Item.RequestLoadItemDataByID, g.itemID)
            end
            btn.icon:SetTexture(icon)
            -- Nur die ersten drei Rueckgaben: die vierte ist die Farbe als
            -- Hex-STRING und landete sonst als Alpha-Argument.
            if quality and quality >= 2 and GetItemQualityColor then
                local qr, qg, qb = GetItemQualityColor(quality)
                btn.ring:SetColorTexture(qr, qg, qb, 1)
            else
                btn.ring:SetColorTexture(0.25, 0.25, 0.3, 1)
            end

            local count = (GetItemCount and GetItemCount(g.itemID)) or 1
            btn.count:SetText(count > 1 and tostring(count) or "")

            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", picker, "TOPLEFT",
                pad + col * (GEM_SIZE + GEM_PAD),
                -(top + row * (GEM_SIZE + GEM_PAD)))
            btn:Show()
        end
    end

    picker:ClearAllPoints()
    -- Unter das Symbol, nach oben gekippt, wenn es sonst unten aus dem
    -- Bild liefe.
    local bottom = anchorBtn:GetBottom() or 0
    if bottom - picker:GetHeight() - 6 < 0 then
        picker:SetPoint("BOTTOMLEFT", anchorBtn, "TOPLEFT", 0, 4)
    else
        picker:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -4)
    end
    picker:Show()
end

-- =========================================================
-- Die Leiste
-- =========================================================
local bar
local icons = {}

local function acquireIcon(i)
    local btn = icons[i]
    if btn then return btn end

    btn = CreateFrame("Button", nil, bar)
    btn:SetSize(ICON, ICON)

    btn.ring = btn:CreateTexture(nil, "BACKGROUND")
    btn.ring:SetAllPoints(btn)
    btn.ring:SetColorTexture(0.25, 0.25, 0.3, 1)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)

    local hov = btn:CreateTexture(nil, "HIGHLIGHT")
    hov:SetAllPoints(btn)
    hov:SetColorTexture(1, 1, 1, 0.15)

    btn:SetScript("OnEnter", function(self)
        local rec = self.rec
        if not rec then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if rec.gemID then
            pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. rec.gemID)
        else
            GameTooltip:AddLine(L["Empty socket"], 1, 1, 1)
            if CAN_SOCKET then
                GameTooltip:AddLine(L["Click to pick a gem from your bags."], 0.7, 0.7, 0.75, true)
            end
        end
        if rec.itemLink then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(rec.itemLink, 0.6, 0.6, 0.65)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self)
        if not (CAN_SOCKET and self.rec) then return end
        if InCombatLockdown() then
            ns:Print(L["Cannot socket gems in combat."])
            return
        end
        -- Klick auf das Symbol, dessen Auswahl schon offen ist, schliesst sie.
        if picker and picker:IsShown() and picker.anchorBtn == self then
            picker:Hide()
            return
        end
        populatePicker(self.rec, self)
    end)

    icons[i] = btn
    return btn
end

-- Wo die Leiste haengt und wie breit sie werden darf.
--
-- Die Seitenleiste ist das Ziel, solange sie steht: sie ist das
-- rechteste Ding am Charakterfenster, sie ist bereits genau so breit,
-- wie eine Leiste es sein will, und der Platz darunter ist frei.
local sidebarHooked = false

local function anchorTarget()
    local sb = _G.VGS_GearSetsSidebar
    -- Die Seitenleiste wird faul gebaut und kommt und geht mit ihrer
    -- Einstellung, und keine der beiden Bewegungen feuert etwas, worauf
    -- die Leiste bereits lauscht. Beim ersten Sichtkontakt gehookt, damit
    -- sie folgt, statt auf den naechsten Ausruestungswechsel zu warten.
    if sb and not sidebarHooked then
        sidebarHooked = true
        sb:HookScript("OnShow", function() queueRefresh() end)
        sb:HookScript("OnHide", function() queueRefresh() end)
    end
    if sb and sb:IsShown() then return sb, true end
    return _G.CharacterFrame, false
end

-- Gemessen, nicht geraten: die Reiter haengen je nach Client und Reskin
-- unterschiedlich weit unter dem Fenster, ein fester Abstand liesse die
-- Leiste irgendwo auf ihnen landen. Unter der Seitenleiste gibt es keine
-- Reiter, deshalb gilt die Messung nur fuer den Ausweichanker.
local function anchorBar()
    local target, onSidebar = anchorTarget()
    if not (bar and target) then return end

    local drop = 0
    if not onSidebar then
        local cfBottom = target.GetBottom and target:GetBottom()
        if cfBottom then
            for i = 1, 8 do
                local tab = _G["CharacterFrameTab" .. i]
                if tab and tab:IsShown() and tab.GetBottom then
                    local tb = tab:GetBottom()
                    if tb then
                        local d = cfBottom - tb
                        if d > drop then drop = d end
                    end
                end
            end
        end
    end

    bar:ClearAllPoints()

    -- Darunter gehoert sie hin, aber das Charakterfenster laesst sich
    -- verschieben, und eine Leiste unter einem Fenster, das schon am
    -- Bildschirmrand sitzt, laege ausserhalb und waere nicht erreichbar.
    -- Dann geht sie darueber.
    local bottom = target.GetBottom and target:GetBottom()
    local needed = (drop + 4) + (bar:GetHeight() or 0)
    local above  = bottom and (bottom - needed) < 0

    -- BEIDE Ecken auf der Seitenleiste, damit die Leiste von Bauart her
    -- genau so breit ist wie sie. Eine gemessene Breite waere eine
    -- Momentaufnahme, und die Seitenleiste setzt ihre Breite bei jedem
    -- Stilwechsel neu (der Classic-Rahmen ist 32 Pixel breit und laesst
    -- sie wachsen) - die Leiste behielte dann die Zahl von gestern.
    if onSidebar then
        -- Im Classic-Stil duerfen sich beide Frames BERUEHREN: der
        -- Dialograhmen wird nach innen gezeichnet, eine Luecke ergaebe
        -- zwei Rahmenlaeufe mit einem Streifen Welt dazwischen. Der
        -- schlichte Stil will die Luecke, sonst lesen sich seine zwei
        -- Ein-Pixel-Kanten als eine dicke Linie.
        local gap = (ns:FrameInset() > 0) and 0 or 4
        if above then
            bar:SetPoint("BOTTOMLEFT",  target, "TOPLEFT",  0, gap)
            bar:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, gap)
        else
            bar:SetPoint("TOPLEFT",  target, "BOTTOMLEFT",  0, -gap)
            bar:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, -gap)
        end
        return
    end

    if above then
        bar:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, 4)
    else
        bar:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, -(drop + 4))
    end
end

local function ensureBar()
    if bar then return bar end
    local cf = _G.CharacterFrame
    if not cf then return nil end

    -- An die Puppenstube gehaengt, wo es eine gibt, damit die Leiste mit
    -- dem Reiter kommt und geht, statt unter der Rufseite zu haengen.
    local parent = _G.PaperDollFrame or cf
    bar = CreateFrame("Frame", "VGS_SocketBar", parent,
        BackdropTemplateMixin and "BackdropTemplate")
    bar:SetFrameStrata(cf:GetFrameStrata())
    bar:SetFrameLevel((cf:GetFrameLevel() or 1) + 20)
    bar:SetSize(ICON + BAR_PAD * 2, ICON + BAR_PAD * 2)
    -- Bewusst ohne Schatten: die Leiste soll sich als letzter Abschnitt
    -- der Spalte darueber lesen, ein Schatten macht ein zweites,
    -- schwebendes Fenster daraus. Ueber SkinFrame, damit ein Stilwechsel
    -- sie ohne /reload mitnimmt.
    ns.UI:SkinFrame(bar, "window")
    bar:Hide()

    return bar
end

local function paintIcon(btn, rec)
    btn.rec = rec
    btn.icon:SetTexture(rec.texture)

    if rec.gemID then
        -- Ein Steinsymbol ist normale Symbolgrafik: den eingebackenen
        -- dunklen Rand wegschneiden.
        btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        btn.ring:SetColorTexture(0.25, 0.25, 0.3, 1)
        btn:SetAlpha(1)
    else
        -- Die Grafik des leeren Sockels bringt ihren eigenen Rahmen mit;
        -- beschnitten gezeigt schneidet er ab.
        btn.icon:SetTexCoord(0, 1, 0, 1)
        if opt("markEmpty", true) then
            btn.ring:SetColorTexture(0.85, 0.15, 0.15, 1)
        else
            btn.ring:SetColorTexture(0.25, 0.25, 0.3, 1)
        end
        btn:SetAlpha(0.95)
    end
end

local function layoutBar()
    if not bar then return end

    for i = #sockets + 1, #icons do icons[i]:Hide() end

    local n = #sockets
    if n == 0 then
        if picker then picker:Hide() end
        bar:Hide()
        return
    end

    -- Ausruestung dieser Aera traegt weit mehr Sockel, als eine Reihe des
    -- Fensters darueber fasst, deshalb bricht die Leiste nach unten um,
    -- statt ueber den Rand zu laufen. Die Breite, die sie nutzen darf,
    -- ist die Breite dessen, woran sie haengt.
    local target, onSidebar = anchorTarget()
    local avail = (target and target.GetWidth and target:GetWidth()) or 320
    -- Die Leiste WAECHST um den Rahmen, den sie traegt, statt ihn aus dem
    -- Inhalt zu bezahlen: die Spalte darueber macht es genauso, damit die
    -- nutzbare Breite in beiden Stilen gleich bleibt und die Zeilenzahl
    -- beim Stilwechsel nicht springt.
    local pad = BAR_PAD + ns:FrameInset()
    local perRow = math.floor((avail - pad * 2 + GAP) / (ICON + GAP))
    if perRow < 1 then perRow = 1 end
    if perRow > n then perRow = n end
    local rows = math.ceil(n / perRow)

    -- Unter der Seitenleiste geben die beiden Ankerpunkte auf deren
    -- unteren Ecken der Leiste ihre Breite; die hier gesetzte ist
    -- dieselbe Zahl, damit es nicht darauf ankommt, welchen von beiden
    -- der Client bevorzugt, und eine Breite aus dem Ausweichlayout den
    -- Wechsel nicht ueberlebt.
    local height = rows * (ICON + GAP) - GAP + pad * 2
    bar:SetSize(onSidebar and avail
        or (perRow * (ICON + GAP) - GAP + pad * 2), height)
    if target and target.GetFrameStrata then
        bar:SetFrameStrata(target:GetFrameStrata())
    end

    for i, rec in ipairs(sockets) do
        local btn = acquireIcon(i)
        paintIcon(btn, rec)
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", bar, "TOPLEFT",
            pad + col * (ICON + GAP),
            -(pad + row * (ICON + GAP)))
        btn:Show()
    end

    -- Der Neuaufbau hat den Datensatz weggeworfen, an dem die offene
    -- Auswahl haengt, und das Symbol darunter ist gepoolt - beide zeigten
    -- sonst auf einen Sockel, der weitergerueckt ist. Denselben Slot und
    -- Index wiederfinden; ist er weg, ist es die Auswahl auch. Ohne das
    -- ginge der Stein in das, was die Position geerbt hat.
    if picker and picker:IsShown() and picker.rec then
        local want = picker.rec
        local found
        for i, rec in ipairs(sockets) do
            if rec.slot == want.slot and rec.index == want.index then
                found = i
                break
            end
        end
        if found then
            picker.rec = sockets[found]
            picker.anchorBtn = icons[found]
        else
            picker:Hide()
        end
    end

    anchorBar()
    bar:Show()
end

-- =========================================================
-- Auffrischen und Lebenszyklus
-- =========================================================
local events
local eventsOn = false

-- Nur registriert, solange die Leiste steht: alles hier haelt das
-- Gezeichnete im Gleichschritt mit Ausruestung und Taschen.
local SHOWN_EVENTS = {
    "PLAYER_EQUIPMENT_CHANGED",
    "UNIT_INVENTORY_CHANGED",
    "BAG_UPDATE_DELAYED",
    "ITEM_CHANGED",          -- fehlt auf aelteren Clients; das Registrieren laeuft in pcall
    "PLAYER_REGEN_DISABLED",
}

local function registerShownEvents()
    if eventsOn or not events then return end
    eventsOn = true
    for _, ev in ipairs(SHOWN_EVENTS) do
        pcall(events.RegisterEvent, events, ev)
    end
end

local function unregisterShownEvents()
    if not (eventsOn and events) then return end
    eventsOn = false
    for _, ev in ipairs(SHOWN_EVENTS) do
        pcall(events.UnregisterEvent, events, ev)
    end
end

refreshBar = function()
    if not barWanted() then
        if picker then picker:Hide() end
        unregisterShownEvents()
        if bar then bar:Hide() end
        return
    end
    if not ensureBar() then return end
    if not (bar:GetParent() and bar:GetParent():IsVisible()) then
        unregisterShownEvents()
        bar:Hide()
        return
    end

    registerShownEvents()
    rebuildSocketList()
    layoutBar()
end

-- Mehrere dieser Ereignisse kommen fuer eine Spieleraktion zusammen
-- (Anlegen feuert zwei). Ein Neuaufbau kostet einen Tooltip-Scan ueber
-- alle siebzehn Slots, deshalb werden die Aufrufe zu einem Durchlauf am
-- Ende des Frames gefaltet statt je einem pro Ereignis.
local refreshQueued = false

queueRefresh = function()
    if refreshQueued then return end
    if not (C_Timer and C_Timer.After) then
        refreshBar()
        return
    end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        refreshBar()
    end)
end

local function onEvent(_, event, arg1)
    if event == "PLAYER_REGEN_DISABLED" then
        if picker then picker:Hide() end
        return
    elseif event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
        return
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Eine Taschenaenderung kann keinen Sockel eines angelegten Teils
        -- verschieben, nur die Steinliste und ihre Zahlen. Dafuer die
        -- ganze Leiste neu zu zeichnen waeren siebzehn Tooltip-Scans
        -- umsonst.
        if picker and picker:IsShown() and picker.rec and picker.anchorBtn then
            populatePicker(picker.rec, picker.anchorBtn)
        end
        return
    end

    -- Alles andere hier heisst, die Ausruestung selbst hat sich bewegt.
    -- Die offene Auswahl zeigt auf einen Sockel des Teils, das eben noch
    -- da war, also geht sie: sie zu behalten hiesse, den Stein in das zu
    -- setzen, was den Slot jetzt belegt.
    if picker then picker:Hide() end
    queueRefresh()
end

-- =========================================================
-- Sitzungsereignisse
-- Eigener Frame, lebendig nur zwischen dem Klick, der eine Sitzung
-- oeffnet, und ihrem Ende - damit nichts daran haengt, ob das
-- Charakterfenster noch steht.
-- =========================================================
local sessionFrame

local SESSION_EVENTS = {
    "SOCKET_INFO_UPDATE",
    "SOCKET_INFO_ACCEPT",
    "SOCKET_INFO_CLOSE",
    "SOCKET_INFO_FAILURE",
    -- Die beiden Rueckfragen werden aus genau einem Grund beobachtet:
    -- damit das Nachlegen sie nicht beantwortet. Siehe onSocketInfoUpdate.
    "SOCKET_INFO_BIND_CONFIRM",
    "SOCKET_INFO_REFUNDABLE_CONFIRM",
}

local function onSessionEvent(_, event)
    if event == "SOCKET_INFO_UPDATE" then
        onSocketInfoUpdate()
        return
    end

    if event == "SOCKET_INFO_BIND_CONFIRM" or event == "SOCKET_INFO_REFUNDABLE_CONFIRM" then
        if pending then pending.awaitConfirm = true end
        return
    end

    if event == "SOCKET_INFO_FAILURE" then
        -- Die Aktion ist nicht passiert, und ein Schliessen kommt dafuer
        -- auch nicht.
        abandonPending()
        return
    end

    local wasOurs = pending ~= nil
    pending = nil
    if event == "SOCKET_INFO_CLOSE" then
        ourSession = false
        unwatchSession()
    end

    -- Sockeln schreibt den Link des angelegten Teils AN ORT UND STELLE um,
    -- deshalb bleibt das Ausruestungsereignis stumm, und ein sofortiges
    -- Nachlesen sieht auf den Clients ohne ITEM_CHANGED noch die alten
    -- Steine. Ein verzoegerter Durchlauf faengt die ab.
    queueRefresh()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, refreshBar)
    end

    if event == "SOCKET_INFO_ACCEPT" and wasOurs then
        closeOurSession()
    end
end

watchSession = function()
    if not sessionFrame then
        sessionFrame = CreateFrame("Frame")
        sessionFrame:SetScript("OnEvent", onSessionEvent)
    end
    for _, ev in ipairs(SESSION_EVENTS) do
        pcall(sessionFrame.RegisterEvent, sessionFrame, ev)
    end
end

unwatchSession = function()
    if not sessionFrame then return end
    for _, ev in ipairs(SESSION_EVENTS) do
        pcall(sessionFrame.UnregisterEvent, sessionFrame, ev)
    end
end

-- Von den Optionen und von der Seitenleiste aus erreichbar.
ns.RefreshSocketBar = function() queueRefresh() end

-- =========================================================
-- Modul-Lebenszyklus
-- =========================================================
function mod:OnEnable()
    events = events or CreateFrame("Frame")
    events:SetScript("OnEvent", onEvent)

    -- Alles Folgende genau EINMAL. Ein HookScript laesst sich nicht mehr
    -- loesen, und ns:OnStyleChanged haengt an eine Liste, die nie geleert
    -- wird - das Modul in den Optionen aus- und wieder einzuschalten
    -- stapelte sonst bei jedem Mal einen weiteren Satz.
    if not self._hooked then
        self._hooked = true

        if _G.PaperDollFrame then
            _G.PaperDollFrame:HookScript("OnShow", function() queueRefresh() end)
            _G.PaperDollFrame:HookScript("OnHide", function()
                if picker then picker:Hide() end
                unregisterShownEvents()
                if bar then bar:Hide() end
            end)
        end
        if _G.CharacterFrame then
            _G.CharacterFrame:HookScript("OnShow", function() queueRefresh() end)
            _G.CharacterFrame:HookScript("OnHide", function()
                if picker then picker:Hide() end
                unregisterShownEvents()
            end)
        end

        -- Der Stilwechsel faerbt die gemerkten Frames selbst um
        -- (Core/Skin), aber der Innenabstand haengt an ns:FrameInset() -
        -- und der aendert sich mit. Ohne das Neuzeichnen behielte die
        -- Leiste die Polsterung des alten Stils und die Symbole saessen
        -- im Rahmen.
        ns:OnStyleChanged(function() queueRefresh() end)
    end

    queueRefresh()
end

function mod:OnDisable()
    -- Die Hooks bleiben liegen: ein HookScript laesst sich nicht loesen.
    -- Sie laufen ueber queueRefresh, und refreshBar fragt barWanted() -
    -- das genuegt.
    if picker then picker:Hide() end
    abandonPending()
    unregisterShownEvents()
    if bar then bar:Hide() end
end

-- =========================================================
-- Optionen
--
-- Bewusst KEIN mod:GetOptions(): das Modul ist versteckt
-- (group = "_hidden"), das Optionsfenster rendert nur die Seite des
-- Set-Moduls. Die Einstellungen stehen dort im Abschnitt "Socket Bar"
-- und schreiben ueber ns.modules.socketbar.db direkt hierher.
-- =========================================================
