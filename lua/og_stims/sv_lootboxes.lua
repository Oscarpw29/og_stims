-- Buying/opening crates. Server-authoritative: the roll, the payment, the pity counter and
-- the grant all happen here; the client only animates a result it's been told about.

local MACHINE_CLASS = "og_stims_crate_machine"

function OG_Stims:IsNearMachine(ply)
    if not IsValid(ply) then return false end
    local rangeSqr = self.MachineRange * self.MachineRange
    local pos = ply:GetPos()
    for _, ent in ipairs(ents.FindByClass(MACHINE_CLASS)) do
        if pos:DistToSqr(ent:GetPos()) <= rangeSqr then return true end
    end
    return false
end

-- Roll a rarity from `weights` that actually has at least one stim defined for it.
-- Falls back down the rarity order if the rolled rarity has no stims, so a misconfigured
-- crate (weights for a rarity nobody's defined a stim for) can't dead-end.
local function rollRarity(weights)
    local usable = {}
    for rarity, w in pairs(weights) do
        if #OG_Stims:GetStimsByRarity(rarity) > 0 then usable[rarity] = w end
    end
    return OG_Stims:WeightedPick(usable)
end

-- Roll one drop from `box` for `ply`, applying and updating that player's pity counter.
-- Returns stimID, rarity, pityTriggered - or nil if the crate has nothing to drop.
function OG_Stims:Roll(ply, boxID)
    local box = self:GetLootbox(boxID)
    local data = self.Store:Get(ply)
    if not box or not data then return nil end

    data.pity = data.pity or {}
    local opens = data.pity[boxID] or 0

    local weights = box.rarityWeights or {}
    local pity = box.pity
    local pityRank = pity and self:RarityRank(pity.rarity) or 0
    local forced = pity ~= nil and pityRank > 0 and opens + 1 >= pity.after

    if forced then
        local filtered = {}
        for rarity, w in pairs(weights) do
            if self:RarityRank(rarity) >= pityRank then filtered[rarity] = w end
        end
        if next(filtered) then weights = filtered else forced = false end
    end

    local rarity = rollRarity(weights)
    if not rarity then return nil end

    local pool = self:GetStimsByRarity(rarity)
    local stimID = pool[math.random(#pool)]

    if pityRank > 0 and self:RarityRank(rarity) >= pityRank then
        data.pity[boxID] = 0
    else
        data.pity[boxID] = opens + 1
    end

    -- Only report "pity" when it actually changed the outcome's floor
    return stimID, rarity, forced and self:RarityRank(rarity) >= pityRank
end

local function sendResult(ply, boxID, stimID, rarity, pityTriggered)
    net.Start("og_stims.box_result")
        net.WriteString(boxID)
        net.WriteString(stimID)
        net.WriteString(rarity)
        net.WriteBool(pityTriggered)
    net.Send(ply)
end

-- Open a crate the player already owns (event/admin reward). Works anywhere - only buying
-- a crate (PurchaseAndOpen) needs a machine nearby.
function OG_Stims:OpenLootbox(ply, boxID)
    local box = self:GetLootbox(boxID)
    if not box then return false, "Unknown crate." end
    if not IsValid(ply) or not self.Store:IsLoaded(ply) then return false, "Your data is still loading." end
    if (self:GetInventory(ply)[boxID] or 0) <= 0 then return false, "You don't own that crate." end

    local stimID, rarity, pityTriggered = self:Roll(ply, boxID)
    if not stimID then return false, "That crate has nothing to drop (check its config)." end

    self:TakeItem(ply, boxID, 1)
    self:GiveItem(ply, stimID, 1)
    sendResult(ply, boxID, stimID, rarity, pityTriggered)
    return true, stimID
end

-- Pay for a crate and open it in one step.
function OG_Stims:PurchaseAndOpen(ply, boxID)
    local box = self:GetLootbox(boxID)
    if not box then return false, "Unknown crate." end
    if not IsValid(ply) or not self.Store:IsLoaded(ply) then return false, "Your data is still loading." end
    if not self:IsNearMachine(ply) then return false, "You need to be at a crate machine." end

    local price = box.price
    if not price then return false, "That crate isn't for sale." end
    if not OG.Currency.IsAvailable(price.currency) then
        return false, OG.Currency.Name(price.currency) .. " aren't available on this server."
    end
    if not OG.Currency.CanAfford(ply, price.currency, price.amount) then
        return false, "You can't afford that (" .. OG.Currency.Format(price.currency, price.amount) .. ")."
    end

    OG.Currency.Take(ply, price.currency, price.amount)

    local stimID, rarity, pityTriggered = self:Roll(ply, boxID)
    if not stimID then
        OG.Currency.Give(ply, price.currency, price.amount) -- misconfigured crate: refund
        return false, "That crate has nothing to drop (check its config)."
    end

    self:GiveItem(ply, stimID, 1)
    sendResult(ply, boxID, stimID, rarity, pityTriggered)
    return true, stimID
end
