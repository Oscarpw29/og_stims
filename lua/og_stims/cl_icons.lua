-- Shared icon tile: a dark card with a rarity-coloured glow and border behind the item image,
-- so the same artwork reads as common/uncommon/rare/epic/legendary at a glance. Used by the
-- buff bar, loadout slots, inventory rows, crate machine and the crate reel.
local UI = OG.UI

-- x, y, size: square tile. rc: rarity colour (nil = plain frame). alpha: 0-255 fade.
function OG_Stims.DrawTile(x, y, size, iconPath, rc, alpha)
    alpha = alpha or 255
    local fill = UI.Col.frame
    surface.SetDrawColor(fill.r, fill.g, fill.b, alpha)
    surface.DrawRect(x, y, size, size)

    if rc then
        surface.SetMaterial(UI.Mat.gradUp)
        surface.SetDrawColor(rc.r, rc.g, rc.b, 95 * alpha / 255)
        surface.DrawTexturedRect(x, y, size, size)
        UI.Outline(x, y, size, size, UI.Alpha(rc, alpha))
    else
        UI.Outline(x, y, size, size, UI.Alpha(UI.Col.edgeDim, alpha))
    end

    local icon = UI.Icon(iconPath)
    if icon then
        local pad = math.floor(size * 0.1)
        surface.SetMaterial(icon)
        surface.SetDrawColor(255, 255, 255, alpha)
        surface.DrawTexturedRect(x + pad, y + pad, size - pad * 2, size - pad * 2)
    end
end
