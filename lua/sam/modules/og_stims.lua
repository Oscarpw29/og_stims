if SAM_LOADED then return end

local sam, command = sam, sam.command

command.set_category("OG Stims")

-- SAM has no "string" argument type; free text is "text". `check` rejects unknown ids up
-- front so the player gets SAM's usual "invalid <hint>" message instead of a silent no-op.
local function validItem(str)
    return OG_Stims:GetItemDef(str) ~= nil
end

command.new("og_stims_give")
    :SetPermission("og_stims_give", "superadmin")
    :AddArg("player")
    :AddArg("text", { hint = "stim or lootbox id", check = validItem })
    :AddArg("number", { hint = "amount", min = 1, round = true, optional = true, default = 1 })
    :Help("Give a stim or lootbox to a player.")
    :OnExecute(function(ply, targets, id, qty)
        qty = qty or 1
        local given = {}
        for _, target in ipairs(targets) do
            local ok, reason = OG_Stims:GiveItem(target, id, qty)
            if ok then
                table.insert(given, target)
            else
                sam.player.send_message(ply, "Couldn't give " .. id .. " to " .. target:Nick() .. ": " .. tostring(reason))
            end
        end
        if #given > 0 then
            sam.player.send_message(nil, "{A} gave {T} {V}x " .. id .. ".", { A = ply, T = given, V = qty })
        end
    end)
:End()

command.new("og_stims_revoke")
    :SetPermission("og_stims_revoke", "superadmin")
    :AddArg("player")
    :AddArg("text", { hint = "stim or lootbox id", check = validItem })
    :Help("Take all of a stim or lootbox away from a player.")
    :OnExecute(function(ply, targets, id)
        local taken = {}
        for _, target in ipairs(targets) do
            local ok, reason = OG_Stims:TakeItem(target, id)
            if ok then
                table.insert(taken, target)
            else
                sam.player.send_message(ply, "Couldn't revoke " .. id .. " from " .. target:Nick() .. ": " .. tostring(reason))
            end
        end
        if #taken > 0 then
            sam.player.send_message(nil, "{A} revoked " .. id .. " from {T}.", { A = ply, T = taken })
        end
    end)
:End()

command.new("og_stims_reset")
    :SetPermission("og_stims_reset", "superadmin")
    :AddArg("player")
    :Help("Wipe a player's stim inventory, loadout and crate pity counters.")
    :OnExecute(function(ply, targets)
        for _, target in ipairs(targets) do
            if OG_Stims.Store:IsLoaded(target) then
                local data = OG_Stims.Store:Get(target)
                data.inventory = {}
                data.loadout = {}
                data.pity = {}
                OG_Stims.Store:Save(target, "og_stims.sync")
            end
        end
        sam.player.send_message(nil, "{A} reset the stim inventory of {T}.", { A = ply, T = targets })
    end)
:End()

command.new("og_stims_savemachines")
    :SetPermission("og_stims_savemachines", "superadmin")
    :Help("Save all stim crate machines on the map.")
    :OnExecute(function(ply)
        local n = OG_Stims:SaveMachines()
        sam.player.send_message(nil, "{A} saved " .. n .. " crate machine(s).", { A = ply })
    end)
:End()

command.new("og_stims_clearmachines")
    :SetPermission("og_stims_clearmachines", "superadmin")
    :Help("Remove all stim crate machines from the map (and its save file).")
    :OnExecute(function(ply)
        OG_Stims:ClearMachines()
        sam.player.send_message(nil, "{A} cleared all crate machines.", { A = ply })
    end)
:End()
