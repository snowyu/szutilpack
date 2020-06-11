-- LUALOCALS < ---------------------------------------------------------
local minetest, string
    = minetest, string
local string_format
    = string.format
-- LUALOCALS > ---------------------------------------------------------

minetest.register_chatcommand("nuke_player", {
		params = "-f <playername>",
		description = "Completely destroy a player account",
		privs = {privs = true},
		func = function(name, param)
			if param:sub(1, 3) ~= "-f " then
				return false, "Must use the -f flag to force"
			end
			param = param:sub(4)
			if not minetest.player_exists(param) then
				return false, "Player not found"
			end
			if minetest.get_player_by_name(param) then
				minetest.kick_player(param, "Account being removed by admin")
			end
			minetest.remove_player(param)
			minetest.remove_player_auth(param)
			minetest.log("warning", string_format(
					"player account %q was destroyed by %q",
					name, param))
			return true, string_format("Player %q destroyed", param)
		end
	})
