-- Inventory + loadout panel, themed with OG.UI (shared with skilltrees via OG_core).
local UI = OG.UI

local FRAME_W, FRAME_H = 520, 460

local selectedID = nil -- stim picked from the inventory list, waiting for a slot click
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

    local titleBar = vgui.Create("Panel", frame)
    titleBar:SetPos(0, 0)
    titleBar:SetSize(FRAME_W, 32)
    titleBar.Paint = function(self, w, h)
        surface.SetDrawColor(UI.Col.titleBar)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("STIMS", "OG_Heading", 12, h / 2, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = UI.Button(titleBar, "X", function() frame:Remove() end)
    closeBtn:SetPos(FRAME_W - 30, 4)
    closeBtn:SetSize(24, 24)

    -- Loadout slots
    local slotY = 44
    local slotSize = 56
    local slotGap = 10

    for i = 1, OG_Stims.LOADOUT_SLOTS do
        local slot = vgui.Create("DButton", frame)
        slot:SetText("")
        slot:SetPos(12 + (i - 1) * (slotSize + slotGap), slotY)
        slot:SetSize(slotSize, slotSize)
        slot.SlotIndex = i
        slot.DoClick = function(self)
            if selectedID then
                OG_Stims.SetLoadoutSlot(self.SlotIndex, selectedID)
                selectedID = nil
            else
                local id = OG_Stims.MyData.loadout[self.SlotIndex]
                if id then OG_Stims.UseSlot(self.SlotIndex) end
            end
        end
        slot.Paint = function(self, w, h)
            local id = OG_Stims.MyData.loadout[self.SlotIndex]
            local stim = id and OG_Stims:GetStim(id)

            surface.SetDrawColor(UI.Col.frame)
            surface.DrawRect(0, 0, w, h)
            UI.Outline(0, 0, w, h, self:IsHovered() and UI.Col.frameEdge or (stim and RarityColor(stim.rarity) or UI.Col.edgeDim))

            if stim then
                local icon = UI.Icon(stim.icon)
                if icon then
                    surface.SetMaterial(icon)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.DrawTexturedRect(6, 6, w - 12, h - 12)
                end
                local active = OG_Stims.MyActive[stim.category]
                if active and active.id == id then
                    local remaining = math.max(active.expires - CurTime(), 0)
                    draw.SimpleText(remaining >= 60 and string.format("%dm", math.ceil(remaining / 60)) or string.format("%ds", math.ceil(remaining)), "OG_Small", w / 2, h - 6, UI.Col.green, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                end
            else
                draw.SimpleText(self.SlotIndex, "OG_Small", w / 2, h / 2, UI.Col.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    -- View toggle (Stims / Lootboxes)
    local tabY = slotY + slotSize + 10
    local tabs = { { id = "stims", label = "STIMS" }, { id = "boxes", label = "LOOTBOXES" } }
    local tabBtns = {}
    local Rebuild -- assigned below; the tab buttons need it to redraw the list
    for i, tab in ipairs(tabs) do
        local btn = UI.Button(frame, tab.label, function()
            viewMode = tab.id
            selectedID = nil
            Rebuild()
        end)
        btn:SetPos(12 + (i - 1) * 130, tabY)
        btn:SetSize(120, 26)
        tabBtns[tab.id] = btn
    end

    -- List (inventory or lootboxes, depending on viewMode)
    local listY = tabY + 34
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(12, listY)
    scroll:SetSize(FRAME_W - 24, FRAME_H - listY - 12)

    local function RebuildStims()
        scroll:Clear()
        for _, entry in ipairs(ItemList(OG_Stims.MyData.inventory, "stim")) do
            local stim = entry.def
            local row = vgui.Create("DButton", scroll)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 4)
            row:SetTall(58)
            row:SetText("")
            row.DoClick = function() selectedID = entry.id end
            row.Paint = function(self, w, h)
                local sel = selectedID == entry.id
                local rc = RarityColor(stim.rarity)
                surface.SetDrawColor(sel and UI.Alpha(rc, 60) or UI.Col.frame)
                surface.DrawRect(0, 0, w, h)
                UI.Outline(0, 0, w, h, sel and rc or UI.Col.edgeDim)

                local icon = UI.Icon(stim.icon)
                if icon then
                    surface.SetMaterial(icon)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.DrawTexturedRect(10, 14, h - 28, h - 28)
                end

                -- name / what it gives / what it does
                draw.SimpleText(stim.name, "OG_Body", h + 4, 8, rc, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(
                    table.concat(OG_Stims:BuffLines(stim), ", ") .. "  ·  " .. string.NiceTime(stim.duration),
                    "OG_Small", h + 4, 26, UI.Col.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
                )
                draw.SimpleText(stim.desc or "", "OG_Small", h + 4, 41, UI.Col.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("x" .. entry.qty, "OG_Body", w - 12, h / 2, UI.Col.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
        if #ItemList(OG_Stims.MyData.inventory, "stim") == 0 then
            local empty = vgui.Create("Panel", scroll)
            empty:Dock(TOP)
            empty:SetTall(40)
            empty.Paint = function(self, w, h)
                draw.SimpleText("No stims owned. Open a lootbox or ask an admin.", "OG_Small", w / 2, h / 2, UI.Col.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    local function RebuildBoxes()
        scroll:Clear()
        for _, entry in ipairs(ItemList(OG_Stims.MyData.inventory, "lootbox")) do
            local box = entry.def
            local row = vgui.Create("Panel", scroll)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 4)
            row:SetTall(48)
            row.Paint = function(self, w, h)
                surface.SetDrawColor(UI.Col.frame)
                surface.DrawRect(0, 0, w, h)
                UI.Outline(0, 0, w, h, UI.Col.edgeDim)

                local icon = UI.Icon(box.icon)
                if icon then
                    surface.SetMaterial(icon)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.DrawTexturedRect(6, 6, h - 12, h - 12)
                end

                draw.SimpleText(box.name, "OG_Body", h + 4, h / 2 - 10, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(box.desc or "", "OG_Small", h + 4, h / 2 + 8, UI.Col.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("x" .. entry.qty, "OG_Body", w - 90, h / 2, UI.Col.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            local openBtn = UI.Button(row, "Open", function()
                OG_Stims.OpenBox(entry.id)
            end)
            openBtn:SetPos(row:GetWide() - 76, 11) -- repositioned on resize below
            openBtn:SetSize(64, 26)
            row.PerformLayout = function(self, w, h)
                openBtn:SetPos(w - 76, 11)
            end
        end
        if #ItemList(OG_Stims.MyData.inventory, "lootbox") == 0 then
            local empty = vgui.Create("Panel", scroll)
            empty:Dock(TOP)
            empty:SetTall(40)
            empty.Paint = function(self, w, h)
                draw.SimpleText("No lootboxes owned.", "OG_Small", w / 2, h / 2, UI.Col.textFaint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    Rebuild = function()
        for id, btn in pairs(tabBtns) do btn.Accent = (id == viewMode) and UI.Col.staged or nil end
        if viewMode == "boxes" then RebuildBoxes() else RebuildStims() end
    end

    Rebuild()
    hook.Add("OG_Stims_DataUpdated", frame, Rebuild)
    hook.Add("OG_Stims_ActiveUpdated", frame, Rebuild)
    frame.OnRemove = function()
        hook.Remove("OG_Stims_DataUpdated", frame)
        hook.Remove("OG_Stims_ActiveUpdated", frame)
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
