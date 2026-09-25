-- Shared icon tile: a dark rounded card with a rarity-coloured glow and border behind the item
-- image, so the same artwork reads as common/uncommon/rare/epic/legendary at a glance. Used by the
-- buff bar, quick slots, inventory grid, crate shop and the crate reel.
local UI = OG.UI

-- x, y, size: square tile. rc: rarity colour (nil = plain frame). alpha: 0-255 fade.
function OG_Stims.DrawTile(x, y, size, iconPath, rc, alpha)
    alpha = alpha or 255
    local fill = UI.Col.frame
    local r = math.max(3, math.floor(size * 0.12))
    local edge = rc and UI.Alpha(rc, alpha) or UI.Alpha(UI.Col.edgeDim, alpha)
    local thick = size >= 48 and 2 or 1

    UI.RoundBox(x, y, size, size, r, Color(fill.r, fill.g, fill.b, alpha), edge, thick)

    if rc then
        UI.RoundGradient(x + thick, y + thick, size - thick * 2, size - thick * 2, math.max(r - thick, 1),
            UI.Mat.gradUp, Color(rc.r, rc.g, rc.b, 95 * alpha / 255), true, true)
    end

    local icon = UI.Icon(iconPath)
    if icon then
        local pad = math.floor(size * 0.12)
        surface.SetMaterial(icon)
        surface.SetDrawColor(255, 255, 255, alpha)
        surface.DrawTexturedRect(x + pad, y + pad, size - pad * 2, size - pad * 2)
    end
end
