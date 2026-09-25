-- Requires OG_core (for OG.Stats, OG.DataStore, OG.UI, OG.HasPermission, OG.Notify).
-- Load order: config -> core -> everything else. Prefix decides the realm.
local FILES = {
    "sh_config.lua",
    "sh_core.lua",

    "sv_inventory.lua",
    "sv_active.lua",
    "sv_lootboxes.lua",
    "sv_stations.lua",
    "sv_net.lua",

    "cl_net.lua",
    "cl_hud.lua",

    "menu/cl_loadout.lua",
    "menu/cl_machine.lua",
}

local function load()
    OG.Load("og_stims", FILES)
end

if OG and OG.Load then
    load()
else
    -- Addon mount order isn't guaranteed (workshop especially), so if OG_core hasn't run
    -- yet wait until every autorun script has, then check again.
    hook.Add("Initialize", "OG_Stims_DeferredLoad", function()
        if OG and OG.Load then
            load()
        else
            ErrorNoHalt("[OG_stims] OG_core is required (install and enable the OG_core addon).\n")
        end
    end)
end
