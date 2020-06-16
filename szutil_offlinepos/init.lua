-- LUALOCALS < ---------------------------------------------------------
local minetest, pairs, pcall, string, table
    = minetest, pairs, pcall, string, table
local string_gmatch, string_match, table_concat
    = string.gmatch, string.match, table.concat
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()
local modstore = minetest.get_mod_storage()

minetest.register_privilege(modname, {
		description = "Can see position of other players",
		give_to_singleplayer = false,
		give_to_admin = true
	})

local function matchplayers(spec)
	local found = {}
	local fields = modstore:to_table().fields
	for k, v in pairs(fields) do
		local matched
		for p in string_gmatch(spec, "[^%s]+") do
			if not matched then
				local ok, res = pcall(function() return string_match(k, p) end)
				matched = matched or (ok and res)
			end
		end
		if matched then
			local player = minetest.get_player_by_name(k)
			found[k] = {
				name = k,
				pos = player and player:get_pos() or minetest.string_to_pos(v),
				player = player
			}
		end
	end
	return found
end

minetest.register_chatcommand("pos", {
		description = "Get current position of players",
		privs = {[modname] = true},
		func = function(_, param)
			local rpt = {}
			for k, v in pairs(matchplayers(param)) do
				rpt[#rpt + 1] = k .. " at "
				.. minetest.pos_to_string(vector.round(v.pos))
				.. (v.player and " [online]" or "")
			end
			if #rpt < 1 then rpt = {"no match found"} end
			return true, table_concat(rpt, "\n")
		end
	})

local trackcache = {}
local function gettracking(player, pname)
	local tracking = {}
	if minetest.check_player_privs(pname, modname) then
		tracking = trackcache[pname]
		if not tracking then
			local s = player:get_meta():get_string(modname)
			tracking = s and s ~= "" and minetest.deserialize(s) or {}
		end
	end
	return tracking
end

local function trackset(pname, param, value)
	local player = minetest.get_player_by_name(pname)
	if not player then return false, "Cannot track while offline" end

	local set
	if (not param) or (param == "") then
		if value then
			set = {}
			for _, p in pairs(minetest.get_connected_players()) do
				local n = p:get_player_name()
				set[n] = {
					name = n,
					pos = p:get_pos(),
					player = p
				}
			end
		else
			set = matchplayers(".")
		end
	else
		set = matchplayers(param)
	end

	local tracking = gettracking(player, pname)
	for k in pairs(set) do
		if k ~= pname then tracking[k] = value end
	end
	for k in pairs(tracking) do
		if not minetest.player_exists(k) then
			tracking[k] = nil
		end
	end

	trackcache[pname] = tracking
	player:get_meta():set_string(modname, minetest.serialize(tracking))

	local total = 0
	for _ in pairs(tracking) do total = total + 1 end
	return true, "now tracking " .. total .. " player(s)"
end

minetest.register_chatcommand("postrack", {
		description = "Enable tracking position of players",
		privs = {[modname] = true},
		func = function(pname, param)
			return trackset(pname, param, true)
		end
	})
minetest.register_chatcommand("posuntrack", {
		description = "Disable tracking position of players",
		privs = {[modname] = true},
		func = function(pname, param)
			return trackset(pname, param)
		end
	})

local huds = {}

minetest.register_on_leaveplayer(function(player)
		huds[player:get_player_name()] = nil
	end)

minetest.register_globalstep(function()
		for _, player in pairs(minetest.get_connected_players()) do
			local pname = player:get_player_name()
			modstore:set_string(pname, minetest.pos_to_string(player:get_pos()))

			local tracking = gettracking(player, pname)

			local phuds = huds[pname]
			if not phuds then
				if not pairs(tracking)(tracking) then return end
				phuds = {}
				huds[pname] = phuds
			end

			local show = {}
			for k in pairs(tracking) do
				local peer = minetest.get_player_by_name(k)
				local ppos = peer and peer:get_pos()
				if not ppos then
					local s = modstore:get_string(k)
					ppos = s and s ~= "" and minetest.string_to_pos(s)
				end
				if ppos then
					ppos.y = ppos.y + 1.25
					ppos.on = not not peer
					show[k] = ppos
				end
			end

			for k, v in pairs(show) do
				local old = phuds[k]
				if old then
					if not vector.equals(old.pos, v) then
						player:hud_change(old.id, "world_pos", v)
						old.pos = v
					end
					if old.on ~= v.on then
						player:hud_change(old.id, "name", v.on and k
							or ("[" .. k .. "]"))
						old.on = v.on
					end
				else
					phuds[k] = {
						pos = v,
						on = v.on,
						id = player:hud_add({
								hud_elem_type = "waypoint",
								world_pos = v,
								name = v.on and k or ("[" .. k .. "]"),
								number = 0xffff00
							})
					}
				end
			end

			for k, v in pairs(phuds) do
				if not show[k] then
					player:hud_remove(v.id)
					phuds[k] = nil
				end
			end
			if not pairs(phuds)(phuds) then huds[pname] = nil end
		end
		local storetbl = modstore:to_table()
		local dirty
		for k in pairs(storetbl.fields) do
			if not minetest.player_exists(k) then
				storetbl.fields[k] = nil
				dirty = true
			end
		end
		if dirty then modstore:from_table(storetbl) end
	end)

local teleport = minetest.registered_chatcommands.teleport
if teleport and teleport.func then
	local oldfunc = teleport.func
	teleport.func = function(...)
		local oldget = minetest.get_player_by_name
		local function helper(...)
			minetest.get_player_by_name = oldget
			return ...
		end
		function minetest.get_player_by_name(name, ...)
			local player = oldget(name, ...)
			if player then return player end
			local s = modstore:get_string(name)
			if s and s ~= "" then
				return {
					get_pos = function()
						return minetest.string_to_pos(s)
					end,
					set_pos = function() end
				}
			end
		end
		return helper(oldfunc(...))
	end
end
