-- Crate machine: shop menu + the reel animation shown when a crate is opened.
-- The roll is decided server-side before the reel starts; the reel is purely cosmetic
-- (filler cards are random, the winning card is placed at a fixed slot).
local UI = OG.UI

local function RarityColor(rarityID)
    local r = OG_Stims:GetRarity(rarityID)
    return r and r.color or UI.Col.text
end

local function RarityName(rarityID)
    local r = OG_Stims:GetRarity(rarityID)
    return r and r.name or rarityID
end

function OG_Stims.BuyBox(boxID)
    net.Start("og_stims.buy_box")
        net.WriteString(boxID)
    net.SendToServer()
end

-- ── Reel animation ────────────────────────────────────────────────────────
local CARD_W, CARD_H, CARD_GAP = 88, 88, 6
local STEP = CARD_W + CARD_GAP
local STRIP_W = 520
local CARD_COUNT, WIN_INDEX = 56, 46
local SPIN_TIME = 6

local queue = {}
OG_Stims.CrateBusy = false

-- Random stim for a filler card, drawn from the crate's own odds so the reel looks like it.
local function FillerStim(box)
    local rarity = OG_Stims:WeightedPick(box.rarityWeights or {})
    local pool = rarity and OG_Stims:GetStimsByRarity(rarity) or {}
    if #pool == 0 then
        for id in pairs(OG_Stims.Definitions) do table.insert(pool, id) end
    end
    return pool[math.random(#pool)]
end

local function PlayNext()
    if OG_Stims.CrateBusy then return end
    local nextResult = table.remove(queue, 1)
    if not nextResult then return end
    OG_Stims.PlayCrate(nextResult.boxID, nextResult.stimID, nextResult.rarity, nextResult.pity)
end

function OG_Stims.PlayCrate(boxID, stimID, rarity, pityTriggered)
    local box = OG_Stims:GetLootbox(boxID)
    local winner = OG_Stims:GetStim(stimID)
    if not box or not winner then return end

    OG_Stims.CrateBusy = true

    local cards = {}
    for i = 1, CARD_COUNT do
        cards[i] = (i == WIN_INDEX) and stimID or FillerStim(box)
    end

    local target = (WIN_INDEX - 1) * STEP + CARD_W / 2 - STRIP_W / 2 + math.Rand(-CARD_W * 0.35, CARD_W * 0.35)
    local startTime = SysTime()
    local lastTick = 0
    local finished = false

    local w, h = STRIP_W + 40, 300
    local frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    frame.Paint = function(self, pw, ph)
        UI.Panel(pw, ph)
        surface.SetDrawColor(UI.Col.titleBar)
        surface.DrawRect(1, 1, pw - 2, 30)
        draw.SimpleText(string.upper(box.name), "OG_Heading", 12, 16, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if finished then
            local col = RarityColor(rarity)
            draw.SimpleText(RarityName(rarity), "OG_Small", pw / 2, 172, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText(winner.name, "OG_Big", pw / 2, 188, UI.Col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText(table.concat(OG_Stims:BuffLines(winner), ", "), "OG_Body", pw / 2, 222, UI.Col.green, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            if pityTriggered then
                draw.SimpleText("Pity protection triggered", "OG_Small", pw / 2, 246, UI.Col.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
        end
    end
    frame.OnRemove = function()
        OG_Stims.CrateBusy = false
        timer.Simple(0.1, PlayNext)
    end

    local function offsetNow()
        local t = math.Clamp((SysTime() - startTime) / SPIN_TIME, 0, 1)
        return target * (1 - (1 - t) ^ 4), t
    end

    local strip = vgui.Create("Panel", frame)
    strip:SetPos(20, 46)
    strip:SetSize(STRIP_W, CARD_H + 16)
    strip.Paint = function(self, sw, sh)
        surface.SetDrawColor(UI.Col.bg)
        surface.DrawRect(0, 0, sw, sh)

        local offset, t = offsetNow()

        -- Tick as each card crosses the marker
        local under = math.floor((offset + STRIP_W / 2) / STEP)
        if under ~= lastTick then
            lastTick = under
            if not finished then surface.PlaySound("ui/buttonrollover.wav") end
        end

        local sx, sy = self:LocalToScreen(0, 0)
        render.SetScissorRect(sx, sy, sx + sw, sy + sh, true)
        for i, id in ipairs(cards) do
            local x = (i - 1) * STEP - offset
            if x + CARD_W >= 0 and x <= sw then
                local stim = OG_Stims:GetStim(id)
                local col = RarityColor(stim.rarity)
                local dim = finished and i ~= WIN_INDEX

                surface.SetDrawColor(UI.Col.frame)
                surface.DrawRect(x, 8, CARD_W, CARD_H)
                surface.SetDrawColor(col.r, col.g, col.b, dim and 70 or 255)
                surface.DrawRect(x, 8 + CARD_H - 5, CARD_W, 5)
                UI.Outline(x, 8, CARD_W, CARD_H, UI.Alpha(col, dim and 60 or 200))

                local icon = UI.Icon(stim.icon)
                if icon then
                    surface.SetMaterial(icon)
                    surface.SetDrawColor(255, 255, 255, dim and 90 or 255)
                    surface.DrawTexturedRect(x + 20, 8 + 16, CARD_W - 40, CARD_H - 40)
                end
            end
        end
        render.SetScissorRect(0, 0, 0, 0, false)

        -- Centre marker
        local cx = sw / 2
        surface.SetDrawColor(UI.Col.gold)
        surface.DrawRect(cx - 1, 0, 2, sh)
        draw.NoTexture()
        surface.DrawPoly({ { x = cx - 7, y = 0 }, { x = cx + 7, y = 0 }, { x = cx, y = 9 } })
        surface.DrawPoly({ { x = cx - 7, y = sh }, { x = cx, y = sh - 9 }, { x = cx + 7, y = sh } })

        if t >= 1 and not finished then
            finished = true
            OG_Stims.DisplayPity = table.Copy(OG_Stims.MyData.pity or {})
            surface.PlaySound(rarity == "legendary" and "garrysmod/content_downloaded.wav" or "buttons/button14.wav")
            chat.AddText(RarityColor(rarity), "[" .. RarityName(rarity) .. "] ", UI.Col.text, "You got " .. winner.name .. ".")
            if IsValid(frame.SkipBtn) then frame.SkipBtn:SetDisabled(true) end
        end
    end

    frame.SkipBtn = UI.Button(frame, "Skip", function()
        startTime = SysTime() - SPIN_TIME
    end)
    frame.SkipBtn:SetPos(w - 100 - 20, h - 40)
    frame.SkipBtn:SetSize(100, 26)

    local closeBtn = UI.Button(frame, "Close", function() frame:Remove() end)
    closeBtn:SetPos(20, h - 40)
    closeBtn:SetSize(100, 26)
    closeBtn.Think = function(self) self:SetDisabled(not finished) end
end

hook.Add("OG_Stims_BoxResult", "OG_Stims_CrateReel", function(boxID, stimID, rarity, pityTriggered)
    table.insert(queue, { boxID = boxID, stimID = stimID, rarity = rarity, pity = pityTriggered })
    PlayNext()
end)

-- ── Machine menu ──────────────────────────────────────────────────────────
local ROW_H = 94

local function SaleCrates()
    local list = {}
    for id, box in pairs(OG_Stims.Lootboxes) do
        if box.price then table.insert(list, { id = id, box = box }) end
    end
    table.sort(list, function(a, b)
        if a.box.price.currency ~= b.box.price.currency then return a.box.price.currency < b.box.price.currency end
        if a.box.price.amount ~= b.box.price.amount then return a.box.price.amount < b.box.price.amount end
        return a.id < b.id
    end)
    return list
end

local function DrawOdds(box, x, y)
    local weights = box.rarityWeights or {}
    local total = 0
    for _, wt in pairs(weights) do total = total + wt end
    if total <= 0 then return end

    for _, rarity in ipairs(OG_Stims.RarityOrder) do
        local wt = weights[rarity]
        if wt and wt > 0 then
            local text = string.format("%s %s%%", RarityName(rarity), math.Round(wt / total * 100, 1))
            draw.SimpleText(text, "OG_Small", x, y, RarityColor(rarity), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            x = x + surface.GetTextSize(text) + 12
        end
    end
end

function OG_Stims.OpenMachineMenu()
    if IsValid(OG_Stims.MachineFrame) then OG_Stims.MachineFrame:Remove() end

    local crates = SaleCrates()
    local w = 560
    local h = math.min(90 + #crates * (ROW_H + 6), ScrH() - 120)

    local frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(true)
    frame:MakePopup()
    frame.Paint = function(self, pw, ph) UI.Panel(pw, ph) end
    OG_Stims.MachineFrame = frame

    local titleBar = vgui.Create("Panel", frame)
    titleBar:SetPos(1, 1)
    titleBar:SetSize(w - 2, 32)
    titleBar.Paint = function(self, tw, th)
        surface.SetDrawColor(UI.Col.titleBar)
        surface.DrawRect(0, 0, tw, th)
        draw.SimpleText("STIM CRATES", "OG_Heading", 12, th / 2, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local x = tw - 40
        for _, id in ipairs({ "playtime", "money" }) do
            local bal = OG.Currency.Balance(LocalPlayer(), id)
            if bal then
                local text = OG.Currency.Format(id, bal)
                draw.SimpleText(text, "OG_Small", x, th / 2, UI.Col.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                x = x - surface.GetTextSize(text) - 16
            end
        end
    end

    local closeBtn = UI.Button(titleBar, "X", function() frame:Remove() end)
    closeBtn:SetPos(w - 32, 4)
    closeBtn:SetSize(24, 24)

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(12, 44)
    scroll:SetSize(w - 24, h - 56)

    for _, entry in ipairs(crates) do
        local box, id = entry.box, entry.id
        local price = box.price

        local row = vgui.Create("Panel", scroll)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 6)
        row:SetTall(ROW_H)
        row.Paint = function(self, rw, rh)
            surface.SetDrawColor(UI.Col.frame)
            surface.DrawRect(0, 0, rw, rh)
            UI.Outline(0, 0, rw, rh, UI.Col.edgeDim)

            local icon = UI.Icon(box.icon)
            if icon then
                surface.SetMaterial(icon)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(10, 10, 40, 40)
            end

            draw.SimpleText(box.name, "OG_Heading", 62, 10, UI.Col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(box.desc or "", "OG_Small", 62, 30, UI.Col.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            DrawOdds(box, 62, 52)

            if box.pity then
                local remaining = box.pity.after - ((OG_Stims.DisplayPity or {})[id] or 0)
                local text = remaining <= 1
                    and ("Next open guarantees " .. RarityName(box.pity.rarity) .. " or better")
                    or (RarityName(box.pity.rarity) .. " or better guaranteed within " .. remaining .. " opens")
                draw.SimpleText(text, "OG_Small", 62, 70, UI.Col.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            draw.SimpleText(OG.Currency.Format(price.currency, price.amount), "OG_Body", rw - 12, 12, UI.Col.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end

        local buy = UI.Button(row, "Buy & Open", function() OG_Stims.BuyBox(id) end)
        buy:SetSize(110, 28)
        row.PerformLayout = function(self, rw, rh) buy:SetPos(rw - 122, rh - 38) end
        buy.Think = function(self)
            local bal = OG.Currency.Balance(LocalPlayer(), price.currency)
            local unavailable = not OG.Currency.IsAvailable(price.currency)
            local poor = bal ~= nil and bal < price.amount
            self:SetDisabled(OG_Stims.CrateBusy or unavailable or poor)
        end
    end
end
