-- Buff bar, top right (SWTOR style): one card per active stim, stacked downwards.
-- Each card shows the stim's name and what it gives ("+25% Bullet Damage") on the left, and
-- its icon with the time left beneath it on the right.
local UI = OG.UI

local PAD, GAP, LINE_H, TIMER_H = 6, 10, 14, 14
local WARN_SECONDS = 30 -- the icon and timer flash red below this

local function FormatTime(seconds)
    seconds = math.max(math.ceil(seconds), 0)
    local h = math.floor(seconds / 3600)
    local m = math.floor(seconds % 3600 / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

local function RarityColor(rarityID)
    local r = OG_Stims:GetRarity(rarityID)
    return r and r.color or UI.Col.text
end

-- Built per stim id and cached; text never changes while the config is loaded.
local textCache = {}
local function CardText(stimID, stim)
    local cached = textCache[stimID]
    if cached then return cached end

    surface.SetFont("OG_Rank")
    local width = surface.GetTextSize(stim.name)

    surface.SetFont("OG_Small")
    local lines = OG_Stims:BuffLines(stim)
    for _, line in ipairs(lines) do
        width = math.max(width, (surface.GetTextSize(line)))
    end

    cached = { lines = lines, width = width }
    textCache[stimID] = cached
    return cached
end

hook.Add("HUDPaint", "OG_Stims_BuffBar", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local cfg = OG_Stims.HUD
    local iconSize = cfg.IconSize
    local y = cfg.Top

    for _, category in ipairs(OG_Stims.CategoryOrder) do
        local entry = OG_Stims.MyActive[category]
        local stim = entry and OG_Stims:GetStim(entry.id)
        local remaining = entry and (entry.expires - CurTime()) or 0

        if stim and remaining > 0 then
            local text = CardText(entry.id, stim)
            local textH = (#text.lines + 1) * LINE_H
            local iconH = iconSize + 2 + TIMER_H
            local h = math.max(textH, iconH) + PAD * 2
            local w = PAD + text.width + GAP + iconSize + PAD
            local x = ScrW() - cfg.Right - w

            local rc = RarityColor(stim.rarity)
            local warn = remaining <= WARN_SECONDS
            local flash = warn and (0.55 + 0.45 * math.abs(math.sin(CurTime() * 4))) or 1

            -- Card
            draw.RoundedBox(6, x, y, w, h, UI.Alpha(rc, 150))
            draw.RoundedBox(6, x + 1, y + 1, w - 2, h - 2, Color(8, 14, 22, 215))

            -- Name + effects, right-aligned against the icon
            local tx = x + PAD + text.width
            draw.SimpleText(stim.name, "OG_Rank", tx, y + PAD, rc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            for i, line in ipairs(text.lines) do
                draw.SimpleText(line, "OG_Small", tx, y + PAD + i * LINE_H, UI.Col.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end

            -- Icon + timer
            local ix = x + w - PAD - iconSize
            local iy = y + PAD
            OG_Stims.DrawTile(ix, iy, iconSize, stim.icon, rc, 255 * flash)

            draw.SimpleText(FormatTime(remaining), "OG_Small", ix + iconSize / 2, iy + iconSize + 2,
                warn and UI.Alpha(UI.Col.red, 255 * flash) or UI.Col.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

            y = y + h + 6
        end
    end
end)
