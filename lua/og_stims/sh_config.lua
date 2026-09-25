-- Stims: 1-hour consumable buffs. Each stim gives exactly ONE kind of bonus, in five quality
-- tiers (common -> legendary). Bonuses are grouped into categories, and only one buff per
-- category can be active - so you can't stack two health stims, but you can run a health,
-- a damage and an XP stim together.
--
-- `stat` keys are the same ones skilltrees uses (SkillTrees.StatLabels, sh_core.lua). Any
-- addon reading SkillTrees:CalculateBuffs (or OG.Stats.Get) sees them the moment a stim is
-- used, no other code changes.
OG_Stims = OG_Stims or {}

OG_Stims.CategoryOrder = { "health", "armor", "weapon", "damage", "money", "xp" }

OG_Stims.Categories = {
    health = { name = "Health",     desc = "Max health or health regeneration." },
    armor  = { name = "Armor",      desc = "Max armor or armor regeneration." },
    weapon = { name = "Weapon",     desc = "Fire rate or reload speed." },
    damage = { name = "Damage",     desc = "Bullet damage." },
    money  = { name = "Salary",     desc = "Bigger paydays." },
    xp     = { name = "Experience", desc = "Faster skill tree XP." },
}

-- Quality tiers. `color` drives icon/text tint; `prefix` names the stims.
OG_Stims.RarityOrder = { "common", "uncommon", "rare", "epic", "legendary" }

OG_Stims.Rarities = {
    common    = { name = "Common",    prefix = "Basic",     color = Color(190, 195, 200) },
    uncommon  = { name = "Uncommon",  prefix = "Improved",  color = Color(90, 200, 110) },
    rare      = { name = "Rare",      prefix = "Advanced",  color = Color(80, 160, 235) },
    epic      = { name = "Epic",      prefix = "Superior",  color = Color(180, 100, 235) },
    legendary = { name = "Legendary", prefix = "Prototype", color = Color(245, 170, 40) },
}

OG_Stims.DURATION = 3600 -- seconds; every stim lasts an hour
OG_Stims.COOLDOWN = 30   -- seconds before the same stim can be used again

-- One entry per kind of bonus. `values` are the five tiers, common -> legendary.
-- Percent stats are fractions (0.05 = 5%). Regen values are per 2 seconds (skilltrees' tick).
-- Balanced against ~350 HP troopers and skilltrees' per-level values (5-12 HP, 5% damage,
-- 5% fire rate, 2 HP regen per level).
OG_Stims.Effects = {
    { key = "hp",          name = "Vitality Stim",     category = "health", stat = "hp",
      icon = "og_stims/hp.png",
      desc = "Raises your maximum health.",
      values = { 20, 30, 40, 55, 70 } },

    { key = "hpregen",     name = "Recovery Stim",     category = "health", stat = "hpregen",
      icon = "og_stims/hpregen.png",
      desc = "Slowly restores health when you're not being shot at.",
      values = { 1, 2, 3, 4, 5 } },

    { key = "armor",       name = "Bulwark Stim",      category = "armor",  stat = "armor",
      icon = "og_stims/armor.png",
      desc = "Raises your maximum armor.",
      values = { 10, 15, 25, 35, 50 } },

    { key = "armorregen",  name = "Mending Stim",      category = "armor",  stat = "armorregen",
      icon = "og_stims/armorregen.png",
      desc = "Slowly restores armor over time.",
      values = { 1, 2, 3, 4, 5 } },

    { key = "firerate",    name = "Overclock Adrenal", category = "weapon", stat = "firerate",
      icon = "og_stims/firerate.png",
      desc = "Your weapons fire faster.",
      values = { 0.03, 0.05, 0.07, 0.09, 0.12 } },

    { key = "reloadspeed", name = "Quickload Adrenal", category = "weapon", stat = "reloadspeed",
      icon = "og_stims/reloadspeed.png",
      desc = "Your weapons reload faster.",
      values = { 0.05, 0.08, 0.11, 0.14, 0.18 } },

    { key = "damage",      name = "Precision Adrenal", category = "damage", stat = "damage",
      icon = "og_stims/damage.png",
      desc = "Your bullets hit harder.",
      values = { 0.03, 0.05, 0.07, 0.09, 0.12 } },

    { key = "money",       name = "Windfall Stim",     category = "money",  stat = "salary_bonus",
      icon = "og_stims/money.png",
      desc = "Every payday pays out more.",
      values = { 0.05, 0.08, 0.12, 0.16, 0.20 } },

    { key = "xp",          name = "Insight Stim",      category = "xp",     stat = "xp_boost",
      icon = "og_stims/xp.png",
      desc = "You earn skill tree XP faster.",
      values = { 0.05, 0.10, 0.15, 0.20, 0.25 } },
}

-- Build the definitions: id = "<key>_<rarity>", e.g. "hp_common", "damage_legendary".
-- id -> { name, category, rarity, duration, cooldown, icon, desc, buffs = { stat = amount },
--         unlock }.  `unlock` is an optional OG.MatchesAccess rule (Teams/MRSGroup/Ranks/SteamIDs).
-- Add hand-written one-offs below the loop if you ever need a stim that breaks the pattern.
OG_Stims.Definitions = {}

for _, effect in ipairs(OG_Stims.Effects) do
    for tier, rarity in ipairs(OG_Stims.RarityOrder) do
        OG_Stims.Definitions[effect.key .. "_" .. rarity] = {
            name     = OG_Stims.Rarities[rarity].prefix .. " " .. effect.name,
            category = effect.category,
            rarity   = rarity,
            duration = OG_Stims.DURATION,
            cooldown = OG_Stims.COOLDOWN,
            icon     = effect.icon,
            desc     = effect.desc,
            buffs    = { [effect.stat] = effect.values[tier] },
        }
    end
end

-- id -> { name, icon, desc, price, rarityWeights, pity }
-- price:         { currency = "money" | "playtime", amount = N }  (see OG_core sh_currency.lua)
--                A crate with no price can only be opened from inventory (event/admin rewards).
-- rarityWeights: a rarity left out can't drop from the crate. Opening rolls a rarity from
--                these weights, then a uniformly random stim of that rarity (9 per rarity).
-- pity:          { rarity = "rare", after = 10 } - the Nth open in a row without a drop of
--                that rarity or better is forced to be that rarity or better. The counter
--                is per player, per crate, and persists.
OG_Stims.Lootboxes = {
    standard_case = {
        name  = "Standard Stim Case",
        icon  = "og_stims/crate.png",
        desc  = "Mostly common and uncommon stims. A rare drop now and then.",
        price = { currency = "money", amount = 25000 },
        rarityWeights = { common = 65, uncommon = 27, rare = 7, epic = 1 },
        pity  = { rarity = "rare", after = 12 },
    },
    premium_case = {
        name  = "Premium Stim Case",
        icon  = "og_stims/crate.png",
        desc  = "Better odds at rare and epic stims, with a shot at a legendary.",
        price = { currency = "money", amount = 100000 },
        rarityWeights = { common = 25, uncommon = 35, rare = 28, epic = 10, legendary = 2 },
        pity  = { rarity = "epic", after = 15 },
    },
    elite_case = {
        name  = "Elite Stim Case",
        icon  = "og_stims/crate.png",
        desc  = "No commons. Rare and epic stims, with a real chance at a legendary.",
        price = { currency = "money", amount = 2500000 },
        rarityWeights = { uncommon = 10, rare = 42, epic = 36, legendary = 12 },
        pity  = { rarity = "legendary", after = 10 },
    },
    playtime_case = {
        name  = "Veteran Stim Case",
        icon  = "og_stims/crate.png",
        desc  = "Earned with playtime points (1 per 15 min). Same odds as a Standard case.",
        price = { currency = "playtime", amount = 10 },
        rarityWeights = { common = 65, uncommon = 27, rare = 7, epic = 1 },
        pity  = { rarity = "rare", after = 12 },
    },
}

-- How close (units) a player must be to a crate machine to buy a crate.
OG_Stims.MachineRange = 200

-- Buff bar (top right). Offsets are from the screen edge, in pixels at 1080p.
OG_Stims.HUD = {
    Right    = 16,
    Top      = 16,
    IconSize = 40,
}

-- Which rarities survive the player dying. Anything not listed here is lost on death (the buff
-- ends immediately and the stim is not refunded). Set a stim's own `keepOnDeath = true/false`
-- to override its rarity.
OG_Stims.KeepOnDeath = {
    epic      = true,
    legendary = true,
}

-- Send the icon PNGs to joining clients through the game server's download list (FastDL /
-- direct download). Leave off when the icons come from a Workshop content addon listed in
-- workshop.lua (the recommended setup); turn on only if you serve materials/og_stims/*.png
-- from FastDL yourself.
OG_Stims.IconsViaFastDL = false
