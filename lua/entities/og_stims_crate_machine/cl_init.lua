include("shared.lua")

surface.CreateFont("OG_Stims_Machine3D", { font = "Roboto", size = 60, weight = 800, antialias = true })

function ENT:Draw()
    self:DrawModel()
    local pos = self:GetPos() + Vector(0, 0, 60)

    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    pos = pos + Vector(0, 0, math.sin(CurTime() * 2) * 2)

    cam.Start3D2D(pos, ang, 0.1)
        local text = "Stim Crates"
        surface.SetFont("OG_Stims_Machine3D")
        local tW, tH = surface.GetTextSize(text)

        draw.RoundedBox(12, -tW / 2 - 20, -tH / 2, tW + 40, tH, Color(0, 0, 0, 200))
        draw.SimpleText(text, "OG_Stims_Machine3D", 0, 0, Color(245, 200, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
