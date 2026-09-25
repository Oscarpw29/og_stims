-- Ownership + loadout, backed by OG_core's generic per-SteamID data store.
local LOADOUT_SLOTS = OG_Stims.LOADOUT_SLOTS

local Store = OG.DataStore("og_stims_data", {
    version = 1,
    defaults = function()
        return {
            inventory = {}, -- id -> qty owned
            loadout   = {}, -- slot(1..LOADOUT_SLOTS) -> id
            pity      = {}, -- crate id -> opens since the last pity-rarity-or-better drop
            active    = {}, -- category -> { id, remaining } so timed buffs survive reconnects/restarts
        }
    end,
})

OG_Stims.Store = Store

hook.Add("PlayerInitialSpawn", "OG_Stims_Load", function(ply)
    Store:Load(ply, function(data)
        Store:Save(ply, "og_stims.sync")
        OG_Stims:RestoreActive(ply)
    end)
end)

function OG_Stims:GetInventory(ply)
    local data = Store:Get(ply)
    return data and data.inventory or {}
end

function OG_Stims:GetLoadout(ply)
    local data = Store:Get(ply)
    return data and data.loadout or {}
end

-- Grant `qty` of any owned item - stim or lootbox - to a player (admin command,
-- purchase hook, lootbox reward, etc).
function OG_Stims:GiveItem(ply, id, qty)
    if not Store:IsLoaded(ply) then return false, "Data still loading." end
    if not self:GetItemDef(id) then return false, "Unknown item." end
    qty = math.max(math.floor(qty or 1), 1)

    local data = Store:Get(ply)
    data.inventory[id] = (data.inventory[id] or 0) + qty
    Store:Save(ply, "og_stims.sync")
    return true
end

-- Remove `qty` (default: all) of an item. Also clears it from any loadout slot it's in
-- once the player owns none left.
function OG_Stims:TakeItem(ply, id, qty)
    if not Store:IsLoaded(ply) then return false, "Data still loading." end

    local data = Store:Get(ply)
    local have = data.inventory[id] or 0
    if have <= 0 then return false, "Player doesn't own that item." end

    qty = qty and math.max(math.floor(qty), 1) or have
    local left = math.max(have - qty, 0)

    if left <= 0 then
        data.inventory[id] = nil
        for slot, slotID in pairs(data.loadout) do
            if slotID == id then data.loadout[slot] = nil end
        end
    else
        data.inventory[id] = left
    end

    Store:Save(ply, "og_stims.sync")
    return true
end

-- Assign (or clear, id = nil) an owned stim to a loadout slot.
function OG_Stims:SetLoadoutSlot(ply, slot, id)
    if not Store:IsLoaded(ply) then return false, "Data still loading." end
    slot = math.floor(tonumber(slot) or 0)
    if slot < 1 or slot > LOADOUT_SLOTS then return false, "Invalid slot." end

    local data = Store:Get(ply)
    if id then
        if not self:GetStim(id) then return false, "Unknown stim." end
        if (data.inventory[id] or 0) <= 0 then return false, "You don't own that stim." end
    end

    data.loadout[slot] = id or nil
    Store:Save(ply, "og_stims.sync")
    return true
end
