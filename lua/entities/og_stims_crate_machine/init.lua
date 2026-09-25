AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_combine/breenconsole.mdl")
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:DrawShadow(true)

    self:PhysicsInit(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self:SetUseType(SIMPLE_USE)
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if (activator.NextCrateMachineUse or 0) > CurTime() then return end
    activator.NextCrateMachineUse = CurTime() + 0.5

    net.Start("og_stims.open_machine")
    net.Send(activator)
end
