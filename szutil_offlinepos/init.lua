-- LUALOCALS < ---------------------------------------------------------
local ipairs, math, minetest, pairs, pcall, string, table
    = ipairs, math, minetest, pairs, pcall, string, table
local math_random, string_gmatch, string_match, table_concat
    = math.random, string.gmatch, string.match, table.concat
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()
local modstore = minetest.get_mod_storage()

local cache = {}
for k, v in pairs(modstore:to_table().fields) do
	cache[k] = minetest.string_to_pos(v)
end

minetest.register_globalstep(function()
		for _, player in ipairs(minetest.get_connected_players()) do
			local pname = player:get_player_name()
			local pos = player:get_pos()
			local opos = cache[pname]
			if (not opos) or (not vector.equals(pos, opos)) then
				modstore:set_string(pname, minetest.pos_to_string(pos))
				cache[pname] = pos
			end
		end
	end)

local function expire()
	for k in pairs(cache) do
		if not minetest.player_exists(k) then
			modstore:set_string(k, "")
			cache[k] = nil
		end
	end
	minetest.after(5 + math_random() * 5, expire)
end
minetest.after(0, expire)

minetest.register_privilege(modname, {
		description = "Can see position of other players",
		give_to_singleplayer = false,
		give_to_admin = true
	})

local function matchplayers(spec)
	local found = {}
	for k, v in pairs(cache) do
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
				pos = player and player:get_pos() or v,
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
			local s = cache[name]
			if s then
				return {
					get_pos = function() return s end,
					set_pos = function() end
				}
			end
		end
		return helper(oldfunc(...))
	end
end
