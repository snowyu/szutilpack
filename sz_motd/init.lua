local modname = minetest.get_current_modname()

-- Generic function to read an entire text file, used to load
-- the "seen" database, and to read the motd.
local function readfile(path, trans)
	local f = io.open(path, "rb")
	if f then
		local d = f:read("*all")
		f:close()
		if trans then return trans(d) end
		return d
	end
end

-- Path to the extended motd file, stored in the world path.
local motdpath = minetest.get_worldpath() .. "/" .. modname .. ".txt"

-- Maintain a database on disk of all players who have seen an MOTD, and
-- which specific version each has seen, so we only need to pop up a
-- nag screen if there's new content.
local seenpath = minetest.get_worldpath() .. "/" .. modname .. "_seen"
local seendb = {}
readfile(seenpath, function(d) seendb = minetest.deserialize(d) end)

-- Function to send the actual MOTD content to the player, in either
-- automatic mod (on login) or "forced" mode (on player request).
local function sendmotd(name, force)
	local motd = readfile(motdpath)
	if not motd then return end

	-- Compute a hash of the MOTD content, and figure out
	-- if a player has already seen this version.
	local hash = minetest.get_password_hash("", motd)
	local seen = seendb[name] and seendb[name] == hash

	-- If player has seen this version and did not specifically
	-- request redisplay, just send a chat message reminding them that
	-- it's available if they want.
	if seen and not force then
		minetest.chat_send_player(name,
			"No MOTD changes since your last view.  Use /motd command to "
			.. "review it any time.")
		return
	end

	-- Send MOTD as a nicely-formatted formspec popup.
	motd = minetest.formspec_escape(motd):gsub(",", "\,"):gsub("\n", ",")
	motd = "size[12,8]textlist[0,0;11.75,7.25;motd;" .. motd
		.. ";0;true]button_exit[0,7.5;12,1;ok;Continue]"
	minetest.show_formspec(name, modname, motd);

	-- If the player had already seen the MOTD (i.e. this is a
	-- forced request) then we don't need to update the database or
	-- send them a reminder.
	if seen then return end

	-- Update the seen database in-memory and on-disk
	-- so we don't send another copy of the same content to the
	-- same player automatically.
	seendb[name] = hash
	local f = io.open(seenpath, "wb")
	if f then
		f:write(minetest.serialize(seendb))
		f:close()
	end

	-- Remind the player where they can get the MOTD if they
	-- want it, and explain why it may or may not appear again
	-- automatically on future logins.
	minetest.chat_send_player(name, "Updated MOTD.  It will not display again "
		.. "automatically, unless there are changes.  Use /motd command to "
		.. "review it at any time.")
end

-- Display an "automatic" MOTD popup on new player joins, i.e. for completely
-- new players, or those who have not seen the latest version yet.
minetest.register_on_joinplayer(function(player) sendmotd(player:get_player_name()) end)

-- Force popup display for players who request it via the /motd command.
minetest.register_chatcommand("motd", { func = function(name) sendmotd(name, true) end})
