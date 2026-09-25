-- Shared rules, same split as skilltrees/sh_core.lua: server enforces, menu displays,
-- both go through these so they agree.
OG_Stims.Table = OG_Stims.Definitions -- alias, matches skilltrees' `Tree` naming habit
OG_Stims.LOADOUT_SLOTS = 4

function OG_Stims:GetStim(id)
    return self.Definitions[id]
end

function OG_Stims:GetLootbox(id)
    return self.Lootboxes[id]
end

-- Any ownable item (stim or lootbox). Returns def, kind ("stim" | "lootbox").
function OG_Stims:GetItemDef(id)
    local stim = self:GetStim(id)
    if stim then return stim, "stim" end
    local box = self:GetLootbox(id)
    if box then return box, "lootbox" end
    return nil, nil
end

function OG_Stims:GetCategory(catID)
    return self.Categories[catID]
end

function OG_Stims:GetRarity(rarityID)
    return self.Rarities[rarityID]
end

-- 1 (common) .. N (legendary); 0 for an unknown rarity
function OG_Stims:RarityRank(rarityID)
    for i, id in ipairs(self.RarityOrder) do
        if id == rarityID then return i end
    end
    return 0
end

-- Build once: rarity -> { stimID, stimID, ... }. Rebuilt lazily if a config reload
-- clears it (nothing does that today, but cheap to guard).
local rarityIndex

function OG_Stims:BuildRarityIndex()
    rarityIndex = {}
    for id, stim in pairs(self.Definitions) do
        local rarity = stim.rarity or "common"
        rarityIndex[rarity] = rarityIndex[rarity] or {}
        table.insert(rarityIndex[rarity], id)
    end
    return rarityIndex
end

function OG_Stims:GetStimsByRarity(rarity)
    if not rarityIndex then self:BuildRarityIndex() end
    return rarityIndex[rarity] or {}
end

-- Can `ply` own/use this stim at all (access rule)?
function OG_Stims:CanUse(ply, id)
    local stim = self:GetStim(id)
    if not stim then return false, "Unknown stim." end
    if not IsValid(ply) then return false, "Invalid player." end
    if stim.unlock and OG and not OG.MatchesAccess(ply, stim.unlock) then
        return false, "You don't have access to " .. stim.name .. "."
    end
    return true
end

-- Source key used with OG.Stats for a given category, e.g. "og_stims_stim".
function OG_Stims:StatSource(category)
    return "og_stims_" .. category
end

-- Weighted-random pick from { key = weight, ... }. Returns nil if every weight is <= 0
-- or the table is empty.
function OG_Stims:WeightedPick(weights)
    local total = 0
    for _, w in pairs(weights) do
        if w > 0 then total = total + w end
    end
    if total <= 0 then return nil end

    local roll = math.random() * total
    local running = 0
    for key, w in pairs(weights) do
        if w > 0 then
            running = running + w
            if roll <= running then return key end
        end
    end
    return nil -- unreachable in practice
end

OG_Stims:BuildRarityIndex()

-- Display names for stat keys. Skilltrees' labels win when it's installed so a stat reads
-- the same everywhere; this table covers OG_stims running on its own.
local FALLBACK_LABELS = {
    hp          = { label = "Max Health" },
    armor       = { label = "Armor" },
    speed       = { label = "Speed" },
    hpregen     = { label = "Health Regen", suffix = " / 2s" },
    armorregen  = { label = "Armor Regen", suffix = " / 2s" },
    firerate    = { label = "Fire Rate", pct = true },
    reloadspeed = { label = "Reload Speed", pct = true },
    movespeed   = { label = "Move Speed", pct = true },
    resistance  = { label = "Damage Resist", pct = true },
    damage      = { label = "Bullet Damage", pct = true },
    xp_boost    = { label = "XP Gain", pct = true },
}

-- "+25% Bullet Damage" / "+15 Max Health" / "+6 Health Regen / 2s"
function OG_Stims:FormatBuff(stat, value)
    local def = (SkillTrees and SkillTrees.StatLabels and SkillTrees.StatLabels[stat]) or FALLBACK_LABELS[stat] or { label = stat }
    local amount = def.pct and string.format("%g%%", math.Round(value * 100, 1)) or string.format("%g", math.Round(value, 2))
    return "+" .. amount .. " " .. def.label .. (def.suffix or "")
end

-- Stable-ordered list of formatted lines for a stim's buffs (config order isn't stable
-- for hash tables, so sort by label).
function OG_Stims:BuffLines(stim)
    local lines = {}
    for stat, value in pairs(stim.buffs or {}) do
        table.insert(lines, self:FormatBuff(stat, value))
    end
    table.sort(lines)
    return lines
end
