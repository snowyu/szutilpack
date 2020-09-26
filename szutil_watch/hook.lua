-- LUALOCALS < ---------------------------------------------------------
local ipairs, minetest
    = ipairs, minetest
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()
local lib = _G[modname]

minetest.register_privilege("watch", "Player can watch all other players")

local huds = {}
local function handlehud(player)
	local data = lib.dataget(player) or {}
	local text = ""
	if data.target then text = "Watching: " .. data.target end
	local pname = player:get_player_name()
	local tip = huds[pname]
	if tip then
		if text ~= tip.text then
			player:hud_change(tip.id, "text", text)
			tip.text = text
		end
		return
	end
	if text == "" then return end
	huds[pname] = {
		id = player:hud_add({
				hud_elem_type = "text",
				position = {x = 0.5, y = 0.25},
				text = text,
				number = 0xFFFFFF,
				alignment = {x = 0, y = 0},
				offset = {x = 0, y = 0},
			}),
		text = text
	}
end

local watchshare = {}
local function canwatch(wname, tnname)
	if minetest.check_player_privs(wname, "watch") then return true end
	local share = watchshare[tnname]
	return share and (share[wname] or share['*'])
end

minetest.register_globalstep(function(dt)
		lib.everyone(function(p)
				lib.restore(dt, p)
				if p:get_armor_groups().immortal then
					p:set_breath(11)
				end
				return handlehud(p)
			end)
	end)

minetest.register_on_joinplayer(function(player)
		return lib.stop(player)
	end)

minetest.register_on_leaveplayer(function(player)
		watchshare[player:get_player_name()] = nil
		lib.stop(player)
		lib.everyone(function(p) lib.stop(p, player) end)
		huds[player:get_player_name()] = nil
	end)

minetest.register_chatcommand("watch", {
		params = "<to_name>",
		description = "watch a given player",
		func = function(name, param)
			return lib.start(name, param, canwatch)
		end
	})

minetest.register_chatcommand("unwatch", {
		description = "unwatch a player",
		func = lib.stop
	})

minetest.register_chatcommand("watchshare", {
		params = "[...<name|*>]",
		description = "set the list of players who can watch you",
		func = function(name, param)
			local share = {}
			for _, p in ipairs(param:split(' ')) do
				share[p] = true
			end
			watchshare[name] = share
			lib.everyone(function(p)
					if not canwatch(p:get_player_name(), name) then
						lib.stop(p, name)
					end
				end)
			return true, "Allowed watchers: " .. param
		end
	})
