-- LUALOCALS < ---------------------------------------------------------
local error, math, minetest, os, pcall
    = error, math, minetest, os, pcall
local math_random, os_time
    = math.random, os.time
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

------------------------------------------------------------------------
-- SALT AND HASH GENERATION

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
		local n = math_random(1, alpha:len())
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

------------------------------------------------------------------------
-- PROTECT PRIVILEGE-RELATED SETTINGS

-- Try to wrap the built-in "set" chat command, so that:
--	- Changing the su password will trigger a re-hash.
--	- Users with "server" privs (who can use /set) but without "privs"
--	  privs cannot exploit certain known settings to gain "privs" access.
if minetest.chatcommands and minetest.chatcommands.set
and minetest.chatcommands.set.func then
	local prefix = modname .. "_"
	local oldfunc = minetest.chatcommands.set.func
	minetest.chatcommands.set.func = function(name, ...)
		-- If the server user also has privs access, just allow the
		-- setting change, and rehash as needed.
		if minetest.check_player_privs(name, {privs = true}) then
			local function postset(...)
				upgradepass()
				return ...
			end
			return postset(oldfunc(name, ...))
		end

		-- Wrap the built-in setting modification function to block
		-- certain settings from being set during the execution of
		-- this command.
		local oldset = minetest.setting_set
		minetest.setting_set = function(setting, ...)
			if setting and (setting == "name"
				or setting:sub(1, prefix:len()) == prefix) then
				error("NEEDPRIVS")
			end
			return oldset(setting, ...)
		end

		-- Helper to handle result of command pcall; report our custom
		-- error, bubble out other errors, otherwise return normally.
		-- Restore the normal setting modification API after the command.
		local function postset(ok, err, ...)
			minetest.setting_set = oldset
			if ok then
				return err, ...
			else
				if not err:find("NEEDPRIVS") then
					error(err)
				end
				return false, "Some settings require additional privileges to set."
			end
		end

		return postset(pcall(oldfunc, name, ...))
	end
end

------------------------------------------------------------------------
-- REGISTER CHAT COMMANDS

-- Helper function to add/remove the "privs" priviledge for a user.
local function changeprivs(name, priv)
	local privs = minetest.get_player_privs(name)
	privs.privs = priv
	minetest.set_player_privs(name, privs)
	return true, "Privileges of " .. name .. ": "
	.. minetest.privs_to_string(minetest.get_player_privs(name))
end

-- Keep track of last attempt, and apply a short delay to rate-limit
-- players trying to brute-force passwords.
local retry = {}

-- Register /su command to escalate privs by password.  The argument is the
-- password, which must match the one configured.  If no password is configured,
-- then the command will always return failure.
minetest.register_chatcommand("su", {
		description = "Escalate privileges by password.",
		func = function(name, pass)
			-- Check for already admin.
			if minetest.check_player_privs(name, {privs = true}) then
				return false, "You are already a superuser."
			end

			-- Check rate limit.
			local now = os_time()
			if retry[name] and now < (retry[name] + 5) then
				return false, "Wait a few seconds before trying again."
			end
			retry[name] = now

			-- Check password.
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

------------------------------------------------------------------------
-- STRICT MODE ENFORCEMENT

-- Allow a "strict" setting to be set, which requires players to use
-- /su to escalate to admin after login, i.e. their privs are NOT persisted
-- after logout.
local function strictenforce(player)
	if not minetest.setting_getbool(modname .. "_strict") then return end
	if not player then return end
	local name = player:get_player_name()
	if not name then return end
	return changeprivs(name)
end
minetest.register_on_joinplayer(strictenforce)
minetest.register_on_leaveplayer(strictenforce)
