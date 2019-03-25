-- LUALOCALS < ---------------------------------------------------------
local ipairs, minetest
    = ipairs, minetest
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()
local lib = _G[modname]

minetest.register_privilege("watch", "Player can watch other players")

local function everyone(func) 		
	for _, p in ipairs(minetest.get_connected_players()) do
		func(p)
	end
end

minetest.register_globalstep(function(dt)
		everyone(function(p) lib.restore(dt, p) end)
	end)

minetest.register_on_joinplayer(lib.stop)

minetest.register_on_leaveplayer(function(player)
		lib.stop(player)
		everyone(function(p) lib.stop(p, player) end)
	end)

minetest.register_chatcommand("watch", {
		params = "<to_name>",
		description = "watch a given player",
		privs = {watch = true},
		func = lib.start
	})

minetest.register_chatcommand("unwatch", {
		description = "unwatch a player",
		privs = {watch = true},
		func = lib.stop
	})
