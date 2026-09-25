OG.Net.Strings({
    "og_stims.sync",         -- sv -> cl: full inventory/loadout (Store:Save's syncNetString)
    "og_stims.active_sync",  -- sv -> cl: one category's active buff state, for the HUD
    "og_stims.use",          -- cl -> sv: use the stim in a loadout slot
    "og_stims.set_slot",     -- cl -> sv: assign a loadout slot from the menu
    "og_stims.open_box",     -- cl -> sv: open a lootbox
    "og_stims.box_result",   -- sv -> cl: what a just-opened crate gave, for the reel animation
    "og_stims.buy_box",      -- cl -> sv: pay for a crate and open it
    "og_stims.open_machine", -- sv -> cl: open the crate machine menu
    "og_stims.open_menu",    -- sv -> cl: open the loadout/inventory menu (chat command)
})

OG.Net.Receive("og_stims.use", 0.25, function(len, ply)
    local slot = net.ReadUInt(4)
    local ok, reason = OG_Stims:UseSlot(ply, slot)
    if not ok and OG.Notify then
        OG.Notify(ply, reason or "Couldn't use that stim.", "bad")
    end
end)

OG.Net.Receive("og_stims.set_slot", 0.25, function(len, ply)
    local slot = net.ReadUInt(4)
    local hasID = net.ReadBool()
    local id = hasID and net.ReadString() or nil

    local ok, reason = OG_Stims:SetLoadoutSlot(ply, slot, id)
    if not ok and OG.Notify then
        OG.Notify(ply, reason or "Couldn't update loadout.", "bad")
    end
end)

OG.Net.Receive("og_stims.open_box", 0.5, function(len, ply)
    local boxID = net.ReadString()
    local ok, reason = OG_Stims:OpenLootbox(ply, boxID)
    if not ok and OG.Notify then
        OG.Notify(ply, reason or "Couldn't open that lootbox.", "bad")
    end
end)

OG.Net.Receive("og_stims.buy_box", 0.5, function(len, ply)
    local boxID = net.ReadString()
    local ok, reason = OG_Stims:PurchaseAndOpen(ply, boxID)
    if not ok and OG.Notify then
        OG.Notify(ply, reason or "Couldn't buy that crate.", "bad")
    end
end)

-- !stims or /stims opens the loadout/inventory menu. Returning "" hides the message so it
-- doesn't show in chat (or reach DarkRP as an unknown /command).
hook.Add("PlayerSay", "OG_Stims_ChatCommand", function(ply, text)
    local cmd = string.lower(string.Trim(text))
    if cmd ~= "!stims" and cmd ~= "/stims" then return end

    net.Start("og_stims.open_menu")
    net.Send(ply)
    return ""
end)

-- Tell joining clients to download our icon images (they come from FastDL / the game server).
-- Built from the config so it stays in sync; remember to copy materials/og_stims/*.png to FastDL.
if OG_Stims.IconsViaFastDL then
    local files = {}
    local function add(icon)
        if isstring(icon) and icon:sub(1, 9) == "og_stims/" then files["materials/" .. icon] = true end
    end
    for _, stim in pairs(OG_Stims.Definitions) do add(stim.icon) end
    for _, box in pairs(OG_Stims.Lootboxes) do add(box.icon) end
    for path in pairs(files) do resource.AddFile(path) end
end
