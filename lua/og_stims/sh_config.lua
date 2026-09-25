-- Stim/adrenal/medpac definitions - SWTOR-style consumable buffs.
-- One active buff per category: using a new stim in the same category replaces the old
-- one (its timer resets to the new stim's duration).
--
-- `buffs` uses the same stat keys as skilltrees (SkillTrees.StatLabels, sh_core.lua):
-- hp, armor, speed/movespeed, firerate, reloadspeed, resistance, damage, salary_bonus,
-- salary_per_kill, xp_boost, etc. Any addon reading SkillTrees:CalculateBuffs (or
-- OG.Stats.Get directly) sees these the moment a stim is used, no other code changes.
OG_Stims = OG_Stims or {}

OG_Stims.CategoryOrder = { "stim", "adrenal", "medpac" }

OG_Stims.Categories = {
    stim    = { name = "Stim",    desc = "Combat stims: health, resistance and mobility bonuses." },
    adrenal = { name = "Adrenal", desc = "Offensive boosts: fire rate, damage, reload." },
    medpac  = { name = "Medpac",  desc = "Recovery: health and armor regeneration." },
}

-- Quality tiers. `weight` is only used as the *default* lootbox roll distribution
-- (a lootbox can override with its own `rarityWeights`); `color` drives icon/text tint.
OG_Stims.RarityOrder = { "common", "uncommon", "rare", "epic", "legendary" }

OG_Stims.Rarities = {
    common    = { name = "Common",    color = Color(190, 195, 200), weight = 65 },
    uncommon  = { name = "Uncommon",  color = Color(90, 200, 110),  weight = 25 },
    rare      = { name = "Rare",      color = Color(80, 160, 235),  weight = 8 },
    epic      = { name = "Epic",      color = Color(180, 100, 235), weight = 1.8 },
    legendary = { name = "Legendary", color = Color(245, 170, 40),  weight = 0.2 },
}

-- id -> { name, category, rarity, duration (seconds), buffs = {stat=amount}, cooldown,
--         icon, unlock }
-- `unlock` is an OG.MatchesAccess rule (Teams/MRSGroup/Ranks/SteamIDs); omit for "everyone".
-- Higher rarities are just bigger/longer versions of the same category - lootboxes roll
-- a rarity first, then a random stim of that rarity.
OG_Stims.Definitions = {
    battle_stim = {
        name     = "Battle Stim",
        category = "stim",
        rarity   = "common",
        duration = 3600,
        cooldown = 60,
        icon     = "icon16/heart.png",
        buffs    = { hp = 20, resistance = 0.02 },
    },
    reflex_stim = {
        name     = "Reflex Stim",
        category = "stim",
        rarity   = "common",
        duration = 3600,
        cooldown = 60,
        icon     = "icon16/user_go.png",
        buffs    = { movespeed = 0.03, reloadspeed = 0.05 },
    },
    kolto_medpac = {
        name     = "Kolto Medpac",
        category = "medpac",
        rarity   = "common",
        duration = 3600,
        cooldown = 45,
        icon     = "icon16/heart_add.png",
        buffs    = { hpregen = 1 },
    },
    exotech_adrenal = {
        name     = "Exotech Adrenal",
        category = "adrenal",
        rarity   = "uncommon",
        duration = 3600,
        cooldown = 90,
        icon     = "icon16/lightning.png",
        buffs    = { firerate = 0.04, damage = 0.04 },
    },
    advanced_battle_stim = {
        name     = "Advanced Battle Stim",
        category = "stim",
        rarity   = "rare",
        duration = 3600,
        cooldown = 60,
        icon     = "icon16/heart.png",
        buffs    = { hp = 40, resistance = 0.04 },
    },
    bio_medpac = {
        name     = "Bio-Medpac",
        category = "medpac",
        rarity   = "rare",
        duration = 3600,
        cooldown = 45,
        icon     = "icon16/heart_add.png",
        buffs    = { hpregen = 2, armorregen = 1 },
    },
    exotech_adrenal_mk2 = {
        name     = "Exotech Adrenal MK-2",
        category = "adrenal",
        rarity   = "epic",
        duration = 3600,
        cooldown = 90,
        icon     = "icon16/lightning.png",
        buffs    = { firerate = 0.07, damage = 0.07, reloadspeed = 0.05 },
    },
    exotech_adrenal_prototype = {
        name     = "Exotech Adrenal Prototype",
        category = "adrenal",
        rarity   = "legendary",
        duration = 3600,
        cooldown = 90,
        icon     = "icon16/lightning.png",
        buffs    = { firerate = 0.10, damage = 0.10, reloadspeed = 0.08, movespeed = 0.03 },
    },
}

-- id -> { name, icon, desc, price, rarityWeights, pity }
-- price:         { currency = "money" | "playtime", amount = N }  (see OG_core sh_currency.lua)
--                A crate with no price can only be opened from inventory (event/admin rewards).
-- rarityWeights: overrides OG_Stims.Rarities[x].weight for this crate only; a rarity left
--                out can't drop from it. Opening rolls a rarity from these weights, then a
--                uniformly random stim among that rarity's definitions.
-- pity:          { rarity = "rare", after = 10 } - the Nth open in a row without a drop of
--                that rarity or better is forced to be that rarity or better. The counter
--                is per player, per crate, and persists.
OG_Stims.Lootboxes = {
    standard_case = {
        name  = "Standard Stim Case",
        icon  = "icon16/box.png",
        desc  = "Mostly common and uncommon stims. A rare drop now and then.",
        price = { currency = "money", amount = 25000 },
        rarityWeights = { common = 65, uncommon = 27, rare = 7, epic = 1 },
        pity  = { rarity = "rare", after = 12 },
    },
    premium_case = {
        name  = "Premium Stim Case",
        icon  = "icon16/box.png",
        desc  = "Better odds at rare and epic stims, with a shot at a legendary.",
        price = { currency = "money", amount = 100000 },
        rarityWeights = { common = 25, uncommon = 35, rare = 28, epic = 10, legendary = 2 },
        pity  = { rarity = "epic", after = 15 },
    },
    elite_case = {
        name  = "Elite Stim Case",
        icon  = "icon16/box.png",
        desc  = "No commons. Rare and epic stims, with a real chance at a legendary.",
        price = { currency = "money", amount = 2500000 },
        rarityWeights = { uncommon = 10, rare = 42, epic = 36, legendary = 12 },
        pity  = { rarity = "legendary", after = 10 },
    },
    playtime_case = {
        name  = "Veteran Stim Case",
        icon  = "icon16/box.png",
        desc  = "Earned with playtime points (1 per 15 min). Same odds as a Standard case.",
        price = { currency = "playtime", amount = 10 },
        rarityWeights = { common = 65, uncommon = 27, rare = 7, epic = 1 },
        pity  = { rarity = "rare", after = 12 },
    },
}

-- How close (units) a player must be to a crate machine to buy or open crates.
OG_Stims.MachineRange = 200

-- Buff bar (top right). Offsets are from the screen edge, in pixels at 1080p.
OG_Stims.HUD = {
    Right    = 16,
    Top      = 16,
    IconSize = 40,
}
