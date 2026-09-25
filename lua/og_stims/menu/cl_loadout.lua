-- Stim inventory menu: quick slots on top, a tile grid of your stims grouped by category on the left,
-- and a detail panel (what it does, how long, USE button) on the right. A second tab lists crates.
-- Themed with OG.UI (rounded, shared with skilltrees via OG_core).
local UI = OG.UI

local FRAME_W, FRAME_H = 780, 540
local TITLE_H = 40
local SLOT_SIZE = 52
local TILE, TILE_GAP, COLS = 64, 8, 6
local GRID_W = COLS * TILE + (COLS - 1) * TILE_GAP
local LEFT_W = GRID_W + 22 -- grid plus the scroll bar
local BODY_Y = TITLE_H + 12 + 16 + SLOT_SIZE + 14

local selectedID = nil -- stim shown in the detail panel
local viewMode = "stims" -- "stims" | "boxes"

local function ItemList(inv, kindFilter)
    local list = {}
    for id, qty in pairs(inv) do
        local def, kind = OG_Stims:GetItemDef(id)
        if def and qty > 0 and kind == kindFilter then
            table.insert(list, { id = id, qty = qty, def = def })
        end
    end
    -- Stims group by category, best tier first within a bonus; anything else by id
    local function catIndex(def)
        for i, cat in ipairs(OG_Stims.CategoryOrder) do
            if cat == def.category then return i end
        end
        return 0
    end
    table.sort(list, function(a, b)
        local ca, cb = catIndex(a.def), catIndex(b.def)
        if ca ~= cb then return ca < cb end
        local ea, eb = a.def.icon or "", b.def.icon or ""
        if ea ~= eb then return ea < eb end
        local ra, rb = OG_Stims:RarityRank(a.def.rarity), OG_Stims:RarityRank(b.def.rarity)
        if ra ~= rb then return ra > rb end
        return a.id < b.id
    end)
    return list
end

local function RarityColor(rarityID)
    local r = OG_Stims:GetRarity(rarityID)
    return r and r.color or UI.Col.text
end

local function RarityName(rarityID)
    local r = OG_Stims:GetRarity(rarityID)
    return r and r.name or rarityID
end

local function CategoryName(catID)
    local c = OG_Stims:GetCategory(catID)
    return c and c.name or catID
end

local function TimeLeft(seconds)
    seconds = math.max(math.ceil(seconds), 0)
    if seconds >= 3600 then return string.format("%dh %02dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)) end
    if seconds >= 60 then return string.format("%dm", math.ceil(seconds / 60)) end
    return seconds .. "s"
end

-- The buff currently running in a stim's category (nil if none / expired)
local function ActiveIn(stim)
    local active = OG_Stims.MyActive[stim.category]
    if active and active.expires > CurTime() then return active end
    return nil
end

-- What using this stim does to the buff you already have in its category:
-- "use" (nothing active), "refresh" (same stim, timer resets), "replace" (a different stim).
local function UseMode(stim, id)
    local active = ActiveIn(stim)
    if not active then return "use" end
    return active.id == id and "refresh" or "replace"
end

-- Use a stim from the inventory. Asks first if it would replace a HIGHER tier buff, since that
-- throws away the better stim's remaining time.
local function TryUse(id)
    local stim = OG_Stims:GetStim(id)
    if not stim then return end

    local active = ActiveIn(stim)
    local current = active and active.id ~= id and OG_Stims:GetStim(active.id)
    if current and OG_Stims:RarityRank(current.rarity) > OG_Stims:RarityRank(stim.rarity) then
        Derma_Query(
            "Using " .. stim.name .. " will replace your active " .. current.name .. ", which is a higher tier.",
            "Replace buff?",
            "Replace", function() OG_Stims.UseItem(id) end,
            "Cancel"
        )
        return
    end

    OG_Stims.UseItem(id)
end

local function StyleScrollbar(scroll)
    local bar = scroll:GetVBar()
    bar:SetWide(8)
    bar:SetHideButtons(true)
    bar.Paint = function(self, w, h) UI.RoundBox(0, 0, w, h, 4, Color(8, 14, 22)) end
    bar.btnGrip.Paint = function(self, w, h) UI.RoundBox(0, 0, w, h, 4, UI.Col.edgeDim) end
end

-- ── Main menu ────────────────────────────────────────────────────────────
function OG_Stims.OpenMenu()
    if IsValid(OG_Stims.MenuFrame) then
        OG_Stims.MenuFrame:Remove()
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(FRAME_W, FRAME_H)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(true)
    frame:MakePopup()
    frame.Paint = function(self, w, h) UI.Panel(w, h) end
    OG_Stims.MenuFrame = frame

    -- Title bar: name, tabs, totals
    local titleBar = vgui.Create("Panel", frame)
    titleBar:SetPos(1, 1)
    titleBar:SetSize(FRAME_W - 2, TITLE_H)
    titleBar.Paint = function(self, w, h)
        UI.RoundBox(0, 0, w, h, 5, UI.Col.titleBar)
        surface.SetDrawColor(UI.Col.titleBar)
        surface.DrawRect(0, h / 2, w, h / 2) -- square off the bottom corners

        draw.SimpleText("STIMS", "OG_Title", 16, h / 2, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local stims, crates = 0, 0
        for id, qty in pairs(OG_Stims.MyData.inventory) do
            local _, kind = OG_Stims:GetItemDef(id)
            if kind == "stim" then stims = stims + qty elseif kind == "lootbox" then crates = crates + qty end
        end
        draw.SimpleText(stims .. " stims  ·  " .. crates .. " crates", "OG_Small", w - 52, h / 2, UI.Col.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = UI.Button(titleBar, "X", function() frame:Remove() end)
    closeBtn:SetPos(FRAME_W - 2 - 34, 8)
    closeBtn:SetSize(24, 24)

    local tabBtns = {}
    local Rebuild -- assigned below; the tab buttons need it to redraw the list
    for i, tab in ipairs({ { id = "stims", label = "STIMS" }, { id = "boxes", label = "CRATES" } }) do
        local btn = UI.Button(titleBar, tab.label, function()
            viewMode = tab.id
            Rebuild()
        end)
        btn:SetPos(110 + (i - 1) * 104, 7)
        btn:SetSize(96, 26)
        tabBtns[tab.id] = btn
    end

    -- Quick slots
    local slotsY = TITLE_H + 12 + 16
    local slotsLabel = vgui.Create("Panel", frame)
    slotsLabel:SetPos(16, TITLE_H + 10)
    slotsLabel:SetSize(400, 16)
    slotsLabel:SetMouseInputEnabled(false)
    slotsLabel.Paint = function(self, w, h)
        draw.SimpleText("QUICK SLOTS  -  click to use, right-click to clear", "OG_Rank", 0, h / 2, UI.Col.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    for i = 1, OG_Stims.LOADOUT_SLOTS do
        local slot = vgui.Create("DButton", frame)
        slot:SetText("")
        slot:SetPos(16 + (i - 1) * (SLOT_SIZE + 8), slotsY)
        slot:SetSize(SLOT_SIZE, SLOT_SIZE)
        slot.SlotIndex = i
        slot.DoClick = function(self)
            local id = OG_Stims.MyData.loadout[self.SlotIndex]
            if id then TryUse(id) end
        end
        slot.DoRightClick = function(self)
            if OG_Stims.MyData.loadout[self.SlotIndex] then OG_Stims.SetLoadoutSlot(self.SlotIndex, nil) end
        end
        slot.Think = function(self)
            local id = OG_Stims.MyData.loadout[self.SlotIndex]
            local stim = id and OG_Stims:GetStim(id)
            self:SetTooltip(stim and (stim.name .. "\n" .. table.concat(OG_Stims:BuffLines(stim), ", ") .. "\nClick to use, right-click to clear")
                or ("Quick slot " .. self.SlotIndex .. "\nPick a stim, then press this number in the detail panel"))
        end
        slot.Paint = function(self, w, h)
            local id = OG_Stims.MyData.loadout[self.SlotIndex]
            local stim = id and OG_Stims:GetStim(id)

            if stim then
                OG_Stims.DrawTile(0, 0, w, stim.icon, RarityColor(stim.rarity))
                if self:IsHovered() then UI.Outline(0, 0, w, h, UI.Col.text) end

                local active = ActiveIn(stim)
                if active and active.id == id then
                    draw.SimpleText(TimeLeft(active.expires - CurTime()), "OG_Small", w / 2, h - 4, UI.Col.green, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                end
            else
                UI.RoundBox(0, 0, w, h, 6, UI.Col.frame, self:IsHovered() and UI.Col.frameEdge or UI.Col.edgeDim)
            end
            draw.SimpleText(self.SlotIndex, "OG_Small", 6, 3, stim and UI.Col.text or UI.Col.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    local bodyH = FRAME_H - BODY_Y - 12

    -- ── Stims view: grid + detail ────────────────────────────────────────
    local stimsView = vgui.Create("Panel", frame)
    stimsView:SetPos(12, BODY_Y)
    stimsView:SetSize(FRAME_W - 24, bodyH)

    local scroll = vgui.Create("DScrollPanel", stimsView)
    scroll:SetPos(0, 0)
    scroll:SetSize(LEFT_W, bodyH)
    StyleScrollbar(scroll)

    local detail = vgui.Create("Panel", stimsView)
    detail:SetPos(LEFT_W + 12, 0)
    detail:SetSize(FRAME_W - 24 - LEFT_W - 12, bodyH)

    local function SelectedStim()
        if not selectedID or (OG_Stims.MyData.inventory[selectedID] or 0) <= 0 then return nil end
        return OG_Stims:GetStim(selectedID)
    end

    local descCache = {}
    local function Wrapped(text, font, width)
        local key = font .. width .. text
        descCache[key] = descCache[key] or UI.Wrap(text, font, width)
        return descCache[key]
    end

    local useBtn = UI.Button(detail, "USE", function()
        if SelectedStim() then TryUse(selectedID) end
    end)

    local slotBtns = {}
    for i = 1, OG_Stims.LOADOUT_SLOTS do
        slotBtns[i] = UI.Button(detail, tostring(i), function()
            if not SelectedStim() then return end
            local holds = OG_Stims.MyData.loadout[i] == selectedID
            OG_Stims.SetLoadoutSlot(i, holds and nil or selectedID)
        end)
    end

    detail.PerformLayout = function(self, w, h)
        useBtn:SetPos(16, h - 102)
        useBtn:SetSize(w - 32, 40)
        local bw = math.floor((w - 32 - (OG_Stims.LOADOUT_SLOTS - 1) * 6) / OG_Stims.LOADOUT_SLOTS)
        for i, b in ipairs(slotBtns) do
            b:SetPos(16 + (i - 1) * (bw + 6), h - 40)
            b:SetSize(bw, 28)
        end
    end

    detail.Think = function(self)
        local stim = SelectedStim()
        useBtn:SetVisible(stim ~= nil)
        for i, b in ipairs(slotBtns) do
            b:SetVisible(stim ~= nil)
            b.Accent = (stim and OG_Stims.MyData.loadout[i] == selectedID) and UI.Col.staged or nil
        end
        if not stim then return end

        local mode = UseMode(stim, selectedID)
        useBtn.Label = mode == "replace" and "REPLACE ACTIVE BUFF" or mode == "refresh" and "REFRESH TIMER" or "USE"
        useBtn.Accent = mode == "replace" and UI.Col.gold or (mode == "refresh" and UI.Col.staged or UI.Col.green)
    end

    detail.Paint = function(self, w, h)
        UI.RoundBox(0, 0, w, h, 6, Color(10, 18, 28), UI.Col.edgeDim)

        local stim = SelectedStim()
        if not stim then
            draw.SimpleText("Select a stim", "OG_Body", w / 2, h / 2 - 10, UI.Col.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("to see what it does", "OG_Small", w / 2, h / 2 + 10, UI.Col.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local rc = RarityColor(stim.rarity)
        OG_Stims.DrawTile(16, 16, 96, stim.icon, rc)

        -- Name (wrapped), then rarity and category
        local y = 18
        for _, line in ipairs(Wrapped(stim.name, "OG_Heading", w - 132 - 12)) do
            draw.SimpleText(line, "OG_Heading", 124, y, rc, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            y = y + 20
        end
        draw.SimpleText(string.upper(RarityName(stim.rarity)) .. "  ·  " .. string.upper(CategoryName(stim.category)),
            "OG_Small", 124, y + 2, UI.Col.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- What it gives, big
        y = 128
        for _, line in ipairs(OG_Stims:BuffLines(stim)) do
            draw.SimpleText(line, "OG_Title", 16, y, UI.Col.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            y = y + 26
        end

        -- What it does
        for _, line in ipairs(Wrapped(stim.desc or "", "OG_Body", w - 32)) do
            draw.SimpleText(line, "OG_Body", 16, y, UI.Col.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            y = y + 18
        end
        y = y + 8

        -- The fine print
        draw.SimpleText("Lasts " .. string.NiceTime(stim.duration), "OG_Small", 16, y, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        y = y + 16
        if OG_Stims:KeepsOnDeath(stim) then
            draw.SimpleText("Kept when you die", "OG_Small", 16, y, UI.Col.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        else
            draw.SimpleText("Lost when you die", "OG_Small", 16, y, UI.Col.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        y = y + 16
        draw.SimpleText("You own " .. (OG_Stims.MyData.inventory[selectedID] or 0), "OG_Small", 16, y, UI.Col.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        y = y + 16

        local active = ActiveIn(stim)
        if active then
            local current = OG_Stims:GetStim(active.id)
            local text = active.id == selectedID
                and ("Active now - " .. TimeLeft(active.expires - CurTime()) .. " left")
                or ("Replaces your active " .. (current and current.name or "buff") .. " (" .. TimeLeft(active.expires - CurTime()) .. " left)")
            draw.SimpleText(text, "OG_Small", 16, y, UI.Col.staged, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        draw.SimpleText("QUICK SLOT", "OG_Rank", 16, h - 60, UI.Col.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local function RebuildStims()
        local vbar = scroll:GetVBar()
        local keep = vbar:GetScroll()
        scroll:Clear()

        local list = ItemList(OG_Stims.MyData.inventory, "stim")
        if #list == 0 then
            selectedID = nil
            local empty = vgui.Create("Panel", scroll)
            empty:Dock(TOP)
            empty:SetTall(80)
            empty.Paint = function(self, w, h)
                draw.SimpleText("No stims yet", "OG_Body", w / 2, h / 2 - 10, UI.Col.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("Buy a crate at the crate machine, or ask an admin.", "OG_Small", w / 2, h / 2 + 10, UI.Col.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            return
        end

        if not SelectedStim() then selectedID = list[1].id end

        for _, cat in ipairs(OG_Stims.CategoryOrder) do
            local entries = {}
            for _, entry in ipairs(list) do
                if entry.def.category == cat then table.insert(entries, entry) end
            end
            if #entries == 0 then continue end

            local header = vgui.Create("Panel", scroll)
            header:Dock(TOP)
            header:SetTall(24)
            header.Paint = function(self, w, h)
                draw.SimpleText(string.upper(CategoryName(cat)), "OG_Rank", 2, h / 2, UI.Col.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                surface.SetDrawColor(UI.Col.edgeDim)
                surface.DrawRect(90, h / 2, GRID_W - 90, 1)
            end

            local rows = math.ceil(#entries / COLS)
            local grid = vgui.Create("Panel", scroll)
            grid:Dock(TOP)
            grid:SetTall(rows * TILE + (rows - 1) * TILE_GAP)
            grid:DockMargin(0, 0, 0, 12)

            for i, entry in ipairs(entries) do
                local stim = entry.def
                local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)

                local tile = vgui.Create("DButton", grid)
                tile:SetText("")
                tile:SetPos(col * (TILE + TILE_GAP), row * (TILE + TILE_GAP))
                tile:SetSize(TILE, TILE)
                tile:SetTooltip(stim.name .. "\n" .. table.concat(OG_Stims:BuffLines(stim), ", "))
                tile.DoClick = function() selectedID = entry.id end
                tile.DoDoubleClick = function() selectedID = entry.id TryUse(entry.id) end
                tile.DoRightClick = function()
                    selectedID = entry.id
                    local menu = DermaMenu()
                    menu:AddOption("Use", function() TryUse(entry.id) end)
                    local sub = menu:AddSubMenu("Put in quick slot")
                    for slotIndex = 1, OG_Stims.LOADOUT_SLOTS do
                        sub:AddOption("Slot " .. slotIndex, function() OG_Stims.SetLoadoutSlot(slotIndex, entry.id) end)
                    end
                    menu:Open()
                end
                tile.Paint = function(self, w, h)
                    OG_Stims.DrawTile(0, 0, w, stim.icon, RarityColor(stim.rarity))
                    if selectedID == entry.id then
                        UI.Outline(0, 0, w, h, UI.Col.text, 2)
                    elseif self:IsHovered() then
                        UI.Outline(0, 0, w, h, UI.Alpha(UI.Col.text, 120))
                    end

                    local active = ActiveIn(stim)
                    if active and active.id == entry.id then
                        draw.RoundedBox(4, 6, 6, 9, 9, UI.Col.green)
                    end
                    if entry.qty > 1 then
                        draw.RoundedBox(4, w - 27, h - 19, 23, 15, Color(8, 14, 22, 230))
                        draw.SimpleText("x" .. entry.qty, "OG_Small", w - 15, h - 12, UI.Col.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end
        end

        timer.Simple(0, function()
            if IsValid(scroll) then scroll:GetVBar():SetScroll(keep) end
        end)
    end

    -- ── Crates view ──────────────────────────────────────────────────────
    local boxScroll = vgui.Create("DScrollPanel", frame)
    boxScroll:SetPos(12, BODY_Y)
    boxScroll:SetSize(FRAME_W - 24, bodyH)
    StyleScrollbar(boxScroll)

    local function RebuildBoxes()
        boxScroll:Clear()
        for _, entry in ipairs(ItemList(OG_Stims.MyData.inventory, "lootbox")) do
            local box = entry.def
            local row = vgui.Create("Panel", boxScroll)
            row:Dock(TOP)
            row:DockMargin(0, 0, 8, 6)
            row:SetTall(64)
            row.Paint = function(self, w, h)
                UI.RoundBox(0, 0, w, h, 6, UI.Col.frame, UI.Col.edgeDim)
                OG_Stims.DrawTile(8, 8, h - 16, box.icon)
                draw.SimpleText(box.name, "OG_Heading", h + 4, 12, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(box.desc or "", "OG_Small", h + 4, 34, UI.Col.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("x" .. entry.qty, "OG_Title", w - 130, h / 2, UI.Col.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            local openBtn = UI.Button(row, "OPEN", function() OG_Stims.OpenBox(entry.id) end)
            openBtn:SetSize(96, 32)
            row.PerformLayout = function(self, w, h) openBtn:SetPos(w - 108, (h - 32) / 2) end
        end

        if #ItemList(OG_Stims.MyData.inventory, "lootbox") == 0 then
            local empty = vgui.Create("Panel", boxScroll)
            empty:Dock(TOP)
            empty:SetTall(80)
            empty.Paint = function(self, w, h)
                draw.SimpleText("No crates yet", "OG_Body", w / 2, h / 2 - 10, UI.Col.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("Buy them at the crate machine. Crates you already own open anywhere.", "OG_Small", w / 2, h / 2 + 10, UI.Col.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    Rebuild = function()
        for id, btn in pairs(tabBtns) do btn.Accent = (id == viewMode) and UI.Col.staged or nil end
        stimsView:SetVisible(viewMode == "stims")
        boxScroll:SetVisible(viewMode == "boxes")
        if viewMode == "boxes" then RebuildBoxes() else RebuildStims() end
    end

    Rebuild()
    -- Inventory changes rebuild the lists; buff changes need no rebuild (the buttons read them live)
    hook.Add("OG_Stims_DataUpdated", frame, Rebuild)
    frame.OnRemove = function()
        hook.Remove("OG_Stims_DataUpdated", frame)
    end
end

-- C (context) menu: an icon in the top-left desktop area that opens the stims menu.
-- Sandbox-derived gamemodes (DarkRP included) build these from the DesktopWindows list.
list.Set("DesktopWindows", "OGStims", {
    title = "Stims",
    icon  = "icon64/tool.png",
    init  = function(icon, window)
        window:Remove() -- the desktop system makes its own empty window; we open our own menu
        OG_Stims.OpenMenu()
    end,
})
