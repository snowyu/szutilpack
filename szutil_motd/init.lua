-- LUALOCALS < ---------------------------------------------------------
local io, minetest, string, tonumber
    = io, minetest, string, tonumber
local io_close, io_open, string_match
    = io.close, io.open, string.match
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()
local modstore = minetest.get_mod_storage()

-- Path to the extended motd file, stored in the world path.

-- Function to read current MOTD
local readmotd
do
	local motdpath = minetest.get_worldpath() .. "/" .. modname .. ".txt"
	readmotd = function()
		local f = io_open(motdpath, "rb")
		if not f then return end
		local motd = f:read("*all")
		io_close(f)
		if not string_match(motd, "%S") then return end
		return motd
	end
end

-- Periodically scan for MOTD changes, and notify all online
-- players if there are any.
do
	local motdinterval = tonumber(minetest.settings:get(modname .. "_interval"))
	if motdinterval then
		minetest.log("action", "polling motd for changes every " .. motdinterval .. "s")
		local alertmotd = readmotd()
		local function alertcheck()
			minetest.after(motdinterval, alertcheck)
			local motd = readmotd()
			if motd == alertmotd then return end
			minetest.chat_send_all("Updated MOTD. Please use /motd to review.")
			alertmotd = motd
		end
		minetest.after(motdinterval, alertcheck)
	end
end

-- Function to send the actual MOTD content to the player, in either
-- automatic mode (on login) or "forced" mode (on player request).
local function sendmotd(name, force)
	-- Load the MOTD fresh on each request, so changes can be
	-- made while the server is running, and take effect immediately.
	local motd = readmotd()
	if not motd then return end

	-- Compute a hash of the MOTD content, and figure out
	-- if a player has already seen this version.
	local hash = minetest.sha1(motd)
	local seen = (modstore:get_string(name) or "") == hash

	-- If player has seen this version and did not specifically
	-- request redisplay, just send a chat message reminding them that
	-- it's available if they want.
	if seen and not force then
		minetest.chat_send_player(name,
			"No MOTD changes since your last view. Use /motd command to "
			.. "review it any time.")
		return
	end

	-- Send MOTD as a nicely-formatted formspec popup.
	local fsw = tonumber(minetest.settings:get(modname .. "_width")) or 8.5
	local fsh = tonumber(minetest.settings:get(modname .. "_height")) or 6
	minetest.show_formspec(name, modname,
		"size[" .. fsw .. "," .. fsh .. ",true]"
		.. "textarea[0.3,0;" .. fsw .. "," .. fsh .. ";;;"
		.. minetest.formspec_escape(motd)
		.. "]button_exit[0," .. (fsh - 0.75) .. ";" .. fsw
		.. ",1;ok;" .. (minetest.settings:get(modname
				.. "_button") or "Continue") .. "]")

	-- If the player had already seen the MOTD (i.e. this is a
	-- forced request) then we don't need to update the database or
	-- send them a reminder.
	if seen then return end

	-- Update the seen database in-memory and on-disk
	-- so we don't send another copy of the same content to the
	-- same player automatically.
	modstore:set_string(name, hash)

	-- Remind the player where they can get the MOTD if they
	-- want it, and explain why it may or may not appear again
	-- automatically on future logins.
	minetest.chat_send_player(name, "Updated MOTD. It will not display again "
		.. "automatically, unless there are changes. Use /motd command to "
		.. "review it at any time.")
end

-- Display an "automatic" MOTD popup on new player joins, i.e. for completely
-- new players, or those who have not seen the latest version yet.
minetest.register_on_joinplayer(function(player) sendmotd(player:get_player_name()) end)

-- Force popup display for players who request it via the /motd command.
minetest.register_chatcommand("motd", {func = function(name) sendmotd(name, true) end})
