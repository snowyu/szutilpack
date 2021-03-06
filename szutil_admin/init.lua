-- LUALOCALS < ---------------------------------------------------------
local minetest, pairs, string, table
    = minetest, pairs, string, table
local string_format, table_concat, table_sort
    = string.format, table.concat, table.sort
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

local function conf(n)
	return minetest.settings:get(modname .. "_" .. n)
end

local modprivs = minetest.string_to_privs(conf("priv") or "basic_privs")
local hideprivs = minetest.string_to_privs(conf("hide") or "stealth")
local onlinemsg = conf("online") or "Moderators currently online: %s"
local offlinemsg = conf("offline") or "No moderators in-game currently; try public chat for help."

minetest.registered_chatcommands.admin.func = function()
	local names = {}
	for _, player in pairs(minetest.get_connected_players()) do
		local pname = player:get_player_name()
		if minetest.check_player_privs(pname, modprivs)
		and not minetest.check_player_privs(pname, hideprivs) then
			names[#names + 1] = pname
		end
	end
	if #names > 0 then
		table_sort(names)
		return true, string_format(onlinemsg, table_concat(names, ", "))
	end
	return true, offlinemsg
end
