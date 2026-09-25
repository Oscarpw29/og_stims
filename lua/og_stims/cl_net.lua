OG_Stims.MyData   = { inventory = {}, loadout = {}, pity = {} }
OG_Stims.DisplayPity = {}
OG_Stims.MyActive = {} -- category -> { id, expires } (expires is CurTime()-relative, set on receive)

net.Receive("og_stims.sync", function()
    OG_Stims.MyData = net.ReadTable()
    -- Hold the displayed pity counter while a reel is spinning so it can't spoil the result
    if not OG_Stims.CrateBusy then OG_Stims.DisplayPity = table.Copy(OG_Stims.MyData.pity or {}) end
    hook.Run("OG_Stims_DataUpdated")
end)

net.Receive("og_stims.box_result", function()
    local boxID = net.ReadString()
    local stimID = net.ReadString()
    local rarity = net.ReadString()
    local pityTriggered = net.ReadBool()
    hook.Run("OG_Stims_BoxResult", boxID, stimID, rarity, pityTriggered)
end)

net.Receive("og_stims.active_sync", function()
    local category = net.ReadString()
    local active = net.ReadBool()

    local ply = LocalPlayer()
    local source = OG_Stims:StatSource(category)

    if not active then
        OG_Stims.MyActive[category] = nil
        if IsValid(ply) then OG.Stats.Clear(source, ply) end
    else
        local id = net.ReadString()
        local remaining = net.ReadFloat()
        OG_Stims.MyActive[category] = { id = id, expires = CurTime() + remaining }

        local stim = OG_Stims:GetStim(id)
        if IsValid(ply) and stim then OG.Stats.Set(source, ply, stim.buffs) end
    end

    -- Mirror the buffs on the client too. The server applies them, but the client predicts firing
    -- and reloading and must use the same numbers, or shots and reloads feel out of step.
    if IsValid(ply) then
        OG.Stats.Invalidate(ply) -- clears skilltrees' cached totals via OG_StatsChanged
        if SkillTrees and SkillTrees.RefreshWeapons then SkillTrees:RefreshWeapons(ply) end
    end

    hook.Run("OG_Stims_ActiveUpdated", category)
end)

function OG_Stims.UseSlot(slot)
    net.Start("og_stims.use")
        net.WriteUInt(slot, 4)
    net.SendToServer()
end

function OG_Stims.SetLoadoutSlot(slot, id)
    net.Start("og_stims.set_slot")
        net.WriteUInt(slot, 4)
        net.WriteBool(id ~= nil)
        if id then net.WriteString(id) end
    net.SendToServer()
end

function OG_Stims.OpenBox(boxID)
    net.Start("og_stims.open_box")
        net.WriteString(boxID)
    net.SendToServer()
end

concommand.Add("og_stims_use", function(ply, cmd, args)
    local slot = tonumber(args[1])
    if not slot then
        chat.AddText("Usage: og_stims_use <slot 1-" .. OG_Stims.LOADOUT_SLOTS .. ">")
        return
    end
    OG_Stims.UseSlot(slot)
end)

concommand.Add("og_stims_menu", function()
    OG_Stims.OpenMenu()
end)

net.Receive("og_stims.open_machine", function()
    OG_Stims.OpenMachineMenu()
end)

net.Receive("og_stims.open_menu", function()
    OG_Stims.OpenMenu()
end)

-- Use a stim straight from the inventory; the server checks you own it and its cooldown.
function OG_Stims.UseItem(id)
    net.Start("og_stims.use_item")
        net.WriteString(id)
    net.SendToServer()
end
