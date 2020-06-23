-- LUALOCALS < ---------------------------------------------------------
local math, minetest, pairs, string, type
    = math, minetest, pairs, string, type
local math_random, string_format
    = math.random, string.format
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

local function conf(k, n)
	return minetest.settings[k](minetest.settings, modname .. "_" .. n)
end

local motddesc = conf("get", "desc") or "terms"

local cmdname = conf("get", "cmdname") or "agree"
local cmdparam = conf("get", "cmdparam") or ("to " .. motddesc)
local cmdinstruct = conf("get", "cmdinstruct")
or "Please use the /motd chat command for instructions."

local grantprivs = conf("get", "grant") or "interact"
local purge = conf("get_bool", "purge")

local hudline1 = conf("get", "hudline1")
or ("You must agree to the " .. motddesc .. " to participate.")
local hudline2 = conf("get", "hudline2") or cmdinstruct

local already = conf("get", "already")
or ("You have already agreed and privileges were"
	.. " already granted. If you have lost them, then they can"
	.. " only be restored by an admin or moderator.")

local notice = conf("get", "notice") or ("*** %s agreed to " .. motddesc)

local huds = {}
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
			phud[1] = phud[1] or player:hud_add({
					hud_elem_type = "text",
					position = {x = 0.5, y = 0.5},
					text = hudline1,
					number = 0xFFC000,
					alignment = {x = 0, y = -1},
					offset = {x = 0, y = -1}
				})
			phud[2] = phud[2] or player:hud_add({
					hud_elem_type = "text",
					position = {x = 0.5, y = 0.5},
					text = hudline2,
					number = 0xFFC000,
					alignment = {x = 0, y = 1},
					offset = {x = 0, y = 1}
				})
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
			if param ~= cmdparam then return false, cmdinstruct end
			if minetest.check_player_privs(pname, modname) then
				return false, already
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

if purge then
	local modstore = minetest.get_mod_storage()

	local function processqueue()
		minetest.after(1 + math_random(), processqueue)
		local keep = {}
		for _, p in pairs(minetest.get_connected_players()) do
			keep[p:get_player_name()] = true
		end
		for k in pairs(modstore:to_table().fields) do
			if not keep[k] then
				minetest.remove_player(k)
				minetest.remove_player_auth(k)
			end
		end
		modstore:from_table({})
	end
	minetest.after(0, processqueue)

	minetest.register_on_leaveplayer(function(player)
			local pname = player:get_player_name()
			if minetest.check_player_privs(pname, modname) then return end
			modstore:set_int(pname, 1)
		end)
end
