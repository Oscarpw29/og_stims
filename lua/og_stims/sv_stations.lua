-- Crate machines placed on a map are saved per map to data/og_stims/<map>.txt
-- (same pattern as skilltrees' skill stations).
local FOLDER = "og_stims"
local CLASS  = "og_stims_crate_machine"

local function mapFile()
    return FOLDER .. "/" .. game.GetMap() .. ".txt"
end

local function removeAll()
    for _, ent in ipairs(ents.FindByClass(CLASS)) do ent:Remove() end
end

function OG_Stims:SaveMachines()
    local machines = {}
    for _, ent in ipairs(ents.FindByClass(CLASS)) do
        table.insert(machines, { pos = ent:GetPos(), ang = ent:GetAngles() })
    end
    if #machines == 0 then return 0 end

    file.CreateDir(FOLDER)
    file.Write(mapFile(), util.TableToJSON(machines, true))
    return #machines
end

function OG_Stims:LoadMachines()
    removeAll()

    local raw = file.Read(mapFile(), "DATA")
    local machines = raw and util.JSONToTable(raw)
    if not machines then return end

    for _, info in ipairs(machines) do
        local ent = ents.Create(CLASS)
        ent:SetPos(info.pos)
        ent:SetAngles(info.ang)
        ent:Spawn()

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
    end
    print("[OG Stims] Spawned " .. #machines .. " crate machine(s).")
end

function OG_Stims:ClearMachines()
    if file.Exists(mapFile(), "DATA") then file.Delete(mapFile()) end
    removeAll()
end

hook.Add("InitPostEntity", "OG_Stims_LoadMachines", function()
    OG_Stims:LoadMachines()
end)

hook.Add("PostCleanupMap", "OG_Stims_RestoreMachines", function()
    timer.Simple(0.5, function() OG_Stims:LoadMachines() end)
end)
