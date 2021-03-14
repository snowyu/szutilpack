-- LUALOCALS < ---------------------------------------------------------
local error, math, minetest, pairs, string, type
    = error, math, minetest, pairs, string, type
local math_ceil, math_random, string_format, string_gsub, string_lower,
      string_sub
    = math.ceil, math.random, string.format, string.gsub, string.lower,
      string.sub
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()
local modstore = minetest.get_mod_storage()

local closed = modstore:get_string("closed") ~= ""

local function conf(k, n)
	return minetest.settings[k](minetest.settings, modname .. "_" .. n)
end

local motddesc = conf("get", "desc") or "terms"

local limitsoft = conf("get", "limitsoft") or 3
local limithard = conf("get", "limithard") or math_ceil(limitsoft * 1.5)
if limithard < limitsoft then error("hard limit cannot be less than soft limit") end
local limitmsg = conf("get", "limitmsg") or "There are too many new players"
.. " right now; please try again in a few minutes."

local cmdname = conf("get", "cmdname") or "agree"
local cmdparam = conf("get", "cmdparam") or ("to " .. motddesc)
local cmdinstruct = conf("get", "cmdinstruct")
or "Please use the /motd chat command for instructions."

local grantprivs = conf("get", "grant") or "interact"
local purge = conf("get_bool", "purge")

local hudline1 = conf("get", "hudline1")
or ("You must agree to the " .. motddesc .. " to participate.")
local hudline2 = conf("get", "hudline2") or cmdinstruct

local hudclosed1 = conf("get", "hudclosed1")
or "New player registrations are currently disabled."
local hudclosed2 = conf("get", "hudclosed2") or hudline2

local already = conf("get", "already")
or ("You have already agreed and privileges were"
	.. " already granted. If you have lost them, then they can"
	.. " only be restored by an admin or moderator.")

local notice = conf("get", "notice") or ("*** %s agreed to " .. motddesc)
local noticeclosed = conf("get", "noticeclosed") or (notice
	.. " ... but registration currently is closed.")
notice = notice .. "."

local jointag = conf("get", "jointag") or " [new]"
local purgetag = conf("get", "purgetag") or " [gone]"

local phashkey = minetest.settings:get("szutil_motd_hashkey") or ""
local function phash(pname)
	if #phashkey < 1 then return "0000" end
	return string_sub(minetest.sha1(phashkey .. pname .. phashkey .. pname), 1, 4)
end
local function phsub(line, pname)
	return string_gsub(line, "<phash>", phash(pname))
end

local function tagmsg(func, suff)
	return function(pname, ...)
		if minetest.check_player_privs(pname, modname) then
			return func(pname, ...)
		end
		local oldsend = minetest.chat_send_all
		function minetest.chat_send_all(text, ...)
			minetest.chat_send_all = oldsend
			return oldsend(text .. suff, ...)
		end
		local function helper(...)
			minetest.chat_send_all = oldsend
			return ...
		end
		return helper(func(pname, ...))
	end
end

if jointag and jointag ~= "" then
	minetest.send_join_message = tagmsg(minetest.send_join_message, jointag)
end

if limitsoft >= 0 and limithard > 0 then
	local emerging = {}
	minetest.register_on_prejoinplayer(function(name)
			if minetest.check_player_privs(name, modname) then return end
			local lobby = 0
			for _, p in pairs(minetest.get_connected_players()) do
				local pname = p:get_player_name()
				emerging[pname] = nil
				if not minetest.check_player_privs(p:get_player_name(), modname)
				then lobby = lobby + 1 end
			end
			for _, t in pairs(emerging) do
				if t + 60 < minetest.get_us_time() then lobby = lobby + 1 end
			end
			if lobby > math_random(limitsoft, limithard) then return limitmsg end
			emerging[name] = minetest.get_us_time() / 1000000
		end)
end

local huds = {}
local function dohud(player, id, offset, text)
	if not id then
		return player:hud_add({
				hud_elem_type = "text",
				position = {x = 0.5, y = 0.5},
				text = text,
				number = 0xFFC000,
				alignment = {x = 0, y = offset},
				offset = {x = 0, y = offset}
			})
	end
	player:hud_change(id, "text", text)
	return id
end
local function hudcheck(pname)
	pname = type(pname) == "string" and pname or pname:get_player_name()
	minetest.after(0, function()
			local player = minetest.get_player_by_name(pname)
			if not player then return end

			local phud = huds[pname]

			if minetest.check_player_privs(player, modname) then
				player:hud_set_flags({crosshair = true})
				if phud then
					for _, id in pairs(phud) do
						player:hud_remove(id)
					end
				end
				huds[pname] = nil
				return
			end

			player:hud_set_flags({crosshair = false})
			if not phud then
				phud = {}
				huds[pname] = phud
			end
			phud[1] = dohud(player, phud[1], -1, phsub(
					closed and hudclosed1 or hudline1, pname))
			phud[2] = dohud(player, phud[2], 1, phsub(
					closed and hudclosed2 or hudline2, pname))
		end)
end
minetest.register_on_leaveplayer(function(player)
		huds[player:get_player_name()] = nil
	end)
minetest.register_on_joinplayer(hudcheck)

minetest.register_privilege(modname, {
		description = "agreed to " .. motddesc,
		give_to_singleplayer = false,
		give_to_admin = false,
		on_grant = hudcheck,
		on_revoke = hudcheck
	})

minetest.register_chatcommand(cmdname, {
		description = cmdinstruct,
		func = function(pname, param)
			if param ~= phsub(cmdparam, pname) then return false, cmdinstruct end
			if minetest.check_player_privs(pname, modname) then
				return false, already
			end
			if closed then
				return minetest.chat_send_all(string_format(noticeclosed, pname))
			end
			minetest.chat_send_all(string_format(notice, pname))
			local grant = minetest.string_to_privs(grantprivs)
			grant[modname] = true
			local privs = minetest.get_player_privs(pname)
			for priv in pairs(grant) do
				privs[priv] = true
				minetest.run_priv_callbacks(pname, priv, pname, "grant")
			end
			minetest.set_player_privs(pname, privs)
			hudcheck(pname)
		end
	})

local function setclosed(val)
	if closed == val then return end
	closed = val
	modstore:set_string("closed", closed and "1" or "")
	for _, p in pairs(minetest.get_connected_players()) do
		hudcheck(p)
	end
end
minetest.register_chatcommand(modname, {
		description = "Toggle new player registrations by /" .. cmdname,
		params = "[on|off]",
		privs = {ban = true},
		func = function(_, param)
			if string_lower(param) == "on" then
				setclosed(false)
			elseif string_lower(param) == "off" then
				setclosed(true)
			elseif param ~= "" then
				return false, "Use on/off to enable/disable registration,"
				.. " or blank to query current state"
			end
			return true, "New player registrations "
			.. (closed and "DISALLOWED" or "ALLOWED")
		end
	})

if purge then
	local s = modstore:get_string("purge")
	local cache = s and s ~= "" and minetest.deserialize(s) or {}
	local function save() modstore:set_string("purge", minetest.serialize(cache)) end

	local function processqueue()
		minetest.after(1 + math_random(), processqueue)
		local keep = {}
		for _, p in pairs(minetest.get_connected_players()) do
			keep[p:get_player_name()] = true
		end
		for k in pairs(cache) do
			if not keep[k] then
				minetest.remove_player(k)
				minetest.remove_player_auth(k)
			end
			cache[k] = nil
		end
		save()
	end
	minetest.after(0, processqueue)

	minetest.register_on_leaveplayer(function(player)
			local pname = player:get_player_name()
			if minetest.check_player_privs(pname, modname) then return end
			cache[pname] = true
		end)

	if purgetag and purgetag ~= "" then
		minetest.send_leave_message = tagmsg(minetest.send_leave_message, purgetag)
	end
end
