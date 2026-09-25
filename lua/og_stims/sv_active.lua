-- Server-authoritative use/expiry. Client only ever renders what it's told (same trust
-- model as skilltrees: all charge consumption, cooldowns and timers happen here).
local cooldowns = {} -- "<steamid64>:<id>" -> CurTime() last used

-- ply.OGStimsActive[category] = { id = id, expires = CurTime() + duration }
local function activeTable(ply)
    ply.OGStimsActive = ply.OGStimsActive or {}
    return ply.OGStimsActive
end

local function timerName(ply, category)
    return "OG_Stims_" .. ply:SteamID64() .. "_" .. category
end

-- Save the active buffs with their time left, so an hour-long buff survives a reconnect or
-- restart. Time only runs down while the player is online.
local function persist(ply)
    if not OG_Stims.Store:IsLoaded(ply) then return end
    local saved = {}
    for category, entry in pairs(activeTable(ply)) do
        local remaining = entry.expires - CurTime()
        if remaining > 0 then saved[category] = { id = entry.id, remaining = remaining } end
    end
    OG_Stims.Store:Get(ply).active = saved
    OG_Stims.Store:Save(ply)
end

local function syncActive(ply, category)
    local entry = activeTable(ply)[category]
    net.Start("og_stims.active_sync")
        net.WriteString(category)
        net.WriteBool(entry ~= nil)
        if entry then
            net.WriteString(entry.id)
            net.WriteFloat(entry.expires - CurTime())
        end
    net.Send(ply)
end

-- Ends the buff for a category: clears the OG.Stats source, invalidates, refreshes
-- weapons, and tells the client to drop the HUD icon.
local function endBuff(ply, category)
    if not IsValid(ply) then return end
    activeTable(ply)[category] = nil

    OG.Stats.Clear(OG_Stims:StatSource(category), ply)
    OG.Stats.Invalidate(ply)

    timer.Remove(timerName(ply, category))
    syncActive(ply, category)
    persist(ply)
end

-- Starts (or replaces) the buff for a stim's category. `remaining` is only passed when
-- restoring a saved buff; a fresh use always gets the stim's full duration.
function OG_Stims:StartBuff(ply, id, remaining)
    local stim = self:GetStim(id)
    if not stim then return false, "Unknown stim." end

    local category = stim.category
    local duration = remaining or stim.duration
    timer.Remove(timerName(ply, category)) -- replacing resets the timer

    activeTable(ply)[category] = { id = id, expires = CurTime() + duration }

    OG.Stats.Set(self:StatSource(category), ply, stim.buffs)
    OG.Stats.Invalidate(ply)

    timer.Create(timerName(ply, category), duration, 1, function()
        endBuff(ply, category)
    end)

    syncActive(ply, category)
    persist(ply)
    return true
end

-- Re-apply buffs saved by persist() once the player's data has loaded.
function OG_Stims:RestoreActive(ply)
    local data = self.Store:Get(ply)
    if not data or not data.active then return end

    local saved = data.active
    data.active = {}
    for _, entry in pairs(saved) do
        if self:GetStim(entry.id) and (entry.remaining or 0) > 0 then
            self:StartBuff(ply, entry.id, entry.remaining)
        end
    end
end

function OG_Stims:GetActive(ply, category)
    return activeTable(ply)[category]
end

-- Consume the stim in `slot`, respecting per-stim cooldown, and start its buff.
function OG_Stims:UseSlot(ply, slot)
    local id = self:GetLoadout(ply)[slot]
    if not id then return false, "That loadout slot is empty." end

    local ok, reason = self:CanUse(ply, id)
    if not ok then return false, reason end

    local stim = self:GetStim(id)
    local cdKey = ply:SteamID64() .. ":" .. id
    local last = cooldowns[cdKey]
    if last and CurTime() - last < (stim.cooldown or 0) then
        return false, string.format("%s is on cooldown for %.0fs.", stim.name, (stim.cooldown - (CurTime() - last)))
    end

    local removed = self:TakeItem(ply, id, 1)
    if not removed then return false, "You don't have any left." end

    cooldowns[cdKey] = CurTime()
    self:StartBuff(ply, id)

    if OG.Notify then OG.Notify(ply, "Used " .. stim.name .. ".", "good") end
    return true
end

hook.Add("PlayerDisconnected", "OG_Stims_ActiveCleanup", function(ply)
    persist(ply) -- before the timers go, so the time left is saved
    for category in pairs(activeTable(ply)) do
        timer.Remove(timerName(ply, category))
    end
    ply.OGStimsActive = nil
end)

hook.Add("ShutDown", "OG_Stims_ActiveSave", function()
    for _, ply in ipairs(player.GetHumans()) do persist(ply) end
end)

-- Dying ends buffs whose rarity doesn't survive death (OG_Stims.KeepOnDeath). The player is
-- told which ones wore off; the HUD card is removed by the normal end-of-buff sync.
hook.Add("PlayerDeath", "OG_Stims_LoseOnDeath", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    -- Collect first: endBuff edits the active table
    local lost = {}
    for category, entry in pairs(activeTable(ply)) do
        local stim = OG_Stims:GetStim(entry.id)
        if stim and not OG_Stims:KeepsOnDeath(stim) then
            table.insert(lost, { category = category, stim = stim })
        end
    end

    for _, item in ipairs(lost) do
        endBuff(ply, item.category)
        if OG.Notify then OG.Notify(ply, item.stim.name .. " wore off when you died.", "warn") end
    end
end)
