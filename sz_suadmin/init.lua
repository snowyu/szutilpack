local modname = minetest.get_current_modname()

-- Minetest password hashes (and password hashes in general) should have a
-- fixed length, though the actual length may be subject to change in
-- future versions.
local hashlen = minetest.get_password_hash("a", "b"):len()

-- Helper function to generate a new, random(-ish) salt value.  The quality
-- of the random source is questionable, but it's probably the best we have
-- reliable access to here.
local function gensalt()
	local alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	local salt = ""
	while salt:len() < hashlen do
		local n = math.random(1, alpha:len())
		salt = salt .. alpha:sub(n, n)
	end
	return salt
end

-- Helper function to automatically upgrade non-secure un-hashed passwords
-- to hashed versions, using a new, random(-ish) salt.  The old, unencrypted
-- password is replaced with a "~" string to indicate that it has already
-- been converted to a hash (using ~ instead of empty string so we can set
-- the password to empty-string to disable this feature).
local function upgradepass(changed)
	local rawpass = minetest.setting_get(modname .. "_password")
	if rawpass and rawpass ~= "~" then
		local newsalt = ""
		local newhash = ""
		if rawpass ~= "~" then
			newsalt = gensalt()
			newhash = minetest.get_password_hash(newsalt, rawpass)
		end
		minetest.setting_set(modname .. "_password", "~")
		minetest.setting_set(modname .. "_password_salt", newsalt)
		minetest.setting_set(modname .. "_password_hash", newhash)
		if changed then return changed() end
	end
end

-- On initial startup, if there's an unsafe password set in the config
-- file, upgrade it automatically, and save the upgraded config so it's
-- not exposed on disk, e.g. in backups.
upgradepass(minetest.setting_save)

-- Try to wrap the built-in "set" chat command, so that changing the
-- su password that way will also hash it.  This prevents users with server
-- privs (who can use /set) but not necessarily /su privs from just
-- trivially reading the config to use /su.
if minetest.chatcommands and minetest.chatcommands.set
	and minetest.chatcommands.set.func then
	local oldfunc = minetest.chatcommands.set.func
	local function postset(...)
		upgradepass()
		return ...
	end
	minetest.chatcommands.set.func = function(...)
		return postset(oldfunc(...))
	end
end

-- Helper function to add/remove the "privs" priviledge for a user.
local function changeprivs(name, priv)
	local privs = minetest.get_player_privs(name)
	privs.privs = priv
	minetest.set_player_privs(name, privs)
	return true, "Privileges of " .. name .. ": "
		.. minetest.privs_to_string(minetest.get_player_privs(name))
end

-- Register /su command to escalate privs by password.  The argument is the
-- password, which must match the one configured.  If no password is configured,
-- then the command will always return failure.
minetest.register_chatcommand("su", {
	description = "Escalate privileges by password.",
	func = function(name, pass)
		local hash = minetest.setting_get(modname .. "_password_hash")
		local salt = minetest.setting_get(modname .. "_password_salt")
		if not pass or pass == ""
			or not hash or hash == ""
			or not salt or salt == ""
			or minetest.get_password_hash(salt, pass) ~= hash then
			return false, "Authentication failure."
		end
		return changeprivs(name, true)
	end
})

-- A shortcut to exit "su mode"; this is really just a shortcut for
-- "/revoke <me> privs", which escalated users will be able to do.
minetest.register_chatcommand("unsu", {
	description = "Shortcut to de-escalate privileges from su.",
	privs = {privs = true},
	func = function(name) return changeprivs(name) end
})

-- Allow a "strict" setting to be set, which requires players to use
-- /su to escalate to admin after login, i.e. their privs are NOT persisted
-- after logout.
minetest.register_on_joinplayer(function(player)
	if not player then return end
	local name = player:get_player_name()
	if not name then return end
	if minetest.setting_getbool(modname .. "_strict") then
		return changeprivs(name)
	end
end)
