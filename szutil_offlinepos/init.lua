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

local storetbl = modstore:to_table()
minetest.register_globalstep(function()
		local dirty
		for _, player in pairs(minetest.get_connected_players()) do
			local pname = player:get_player_name()
			local pstr = minetest.pos_to_string(player:get_pos())
			if storetbl.fields[pname] ~= pstr then
				storetbl.fields[pname] = pstr
				dirty = true
			end
		end
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
