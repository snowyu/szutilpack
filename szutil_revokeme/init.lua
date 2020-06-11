-- LUALOCALS < ---------------------------------------------------------
local minetest
    = minetest
-- LUALOCALS > ---------------------------------------------------------

local revoke = minetest.registered_chatcommands.revoke
if revoke and not minetest.registered_chatcommands.revokeme then
	minetest.register_chatcommand("revokeme", {
			params = "<privilege> | all",
			description = "Revoke privileges from yourself",
			privs = revoke.privs,
			func = function(pname, param)
				return revoke.func(pname, pname .. " " .. param)
			end
		})
end
