-- LUALOCALS < ---------------------------------------------------------
local math, minetest, os, pairs, string, table, tonumber
    = math, minetest, os, pairs, string, table, tonumber
local math_floor, math_pow, os_time, string_format, string_match,
      table_concat
    = math.floor, math.pow, os.time, string.format, string.match,
      table.concat
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()
local modstore = minetest.get_mod_storage()

local maxint = math_pow(2, 52)
local function clamp(n)
	if n > maxint then return maxint end
	if n < -maxint then return -maxint end
	return n
end

local invites = modstore:get_string("invites")
invites = invites and minetest.deserialize(invites) or {}
local function savedb()
	local now = os_time()
	local newdb = {}
	for fromname, tolist in pairs(invites) do
		local newlist
		for toname, data in pairs(tolist) do
			if (not data.exp) or (data.exp < now) then
				minetest.log("action", "invite expired: " .. minetest.serialize({
							from = fromname,
							to = toname,
							data = data,
							now = now
						}))
				tolist[toname] = nil
			else
				newlist = newlist or {}
				newlist[toname] = data
			end
		end
		newdb[fromname] = newlist
	end
	invites = newdb
	return modstore:set_string("invites", minetest.serialize(invites))
end
local function dbvac()
	minetest.after(10, dbvac)
	return savedb()
end
dbvac()

minetest.register_privilege(modname, {
		description = "Invite other players to visit you",
		give_to_singleplayer = false
	})

minetest.register_chatcommand("invite", {
		description = "Invite another player to visit you",
		params = "<playername> [expire-seconds]",
		privs = {[modname] = true},
		func = function(pname, param)
			local player = minetest.get_player_by_name(pname)
			if not player then return false, "player not logged in" end
			local vname = player:get_meta():get_string(modname .. "_name")
			if vname and vname ~= "" then return false, "cannot invite while visiting" end

			local targname, expire = string_match(param, "([^ ]+) (.+)")
			expire = tonumber(expire or 86400)
			targname = targname or param
			if (not targname) or (not expire) then return false, "invalid parameters" end
			if targname == pname then return false, "cannot invite yourself" end
			local sender = minetest.get_player_by_name(pname)
			if not sender then return false, "sender not found in game" end
			local pos = vector.round(sender:get_pos())

			local v = invites[pname]
			if not v then
				v = {}
				invites[pname] = v
			end
			if expire <= 0 then
				if not v[targname] then return true, "invitation does not exist" end
				v[targname] = nil
				return true, "invitation removed"
			end
			if not minetest.player_exists(targname) then
				return false, "invited player does not exist"
			end
			v[targname] = {
				exp = clamp(os_time() + expire),
				pos = pos
			}
			savedb()

			local targ = minetest.get_player_by_name(targname)
			if targ then
				minetest.chat_send_player(targname, string_format(
						"invited by %q to %s, use command \"/visit %s\" to accept",
						pname, minetest.pos_to_string(pos), pname))
			end
			return true, "invitation created/updated"
		end
	})

local function tfmt(t)
	t = math_floor(t)
	if t < 60 then return t .. " sec" end
	t = math_floor(t / 60)
	if t < 60 then return t .. " min" end
	t = math_floor(t / 60)
	if t < 24 then return t .. " hr" end
	t = math_floor(t / 24)
	if t < 365 then return t .. " days" end
	t = math_floor(t / 365)
	if t < 100 then return t .. " years" end
	return "basically forever"
end
minetest.register_chatcommand("invites", {
		description = "List open invites",
		func = function(pname)
			local now = os_time()
			local t = {}
			for k1, v1 in pairs(invites) do
				for k2, v2 in pairs(v1) do
					if v2.exp > now then
						if k1 == pname then
							t[#t + 1] = string_format(
								"- invited %q to %s, %s left",
								k2, minetest.pos_to_string(v2.pos),
								tfmt(v2.exp - now))
						elseif k2 == pname then
							t[#t + 1] = string_format(
								"- received from %q to %s, %s left",
								k1, minetest.pos_to_string(v2.pos),
								tfmt(v2.exp - now))
						end
					end
				end
			end
			if #t < 1 then return true, "no invitations open" end
			return true, table_concat(t, "\n")
		end
	})

local function dumpitems(player)
	return nodecore and nodecore.inventory_dump and nodecore.inventory_dump(player)
end

minetest.register_chatcommand("visit", {
		description = "Teleport to accept an invitation",
		params = "<playername>",
		func = function(pname, param)
			if pname == param then return false, "cannot visit yourself" end
			local inv = invites[param]
			if not inv then return false, "invitation not found or expired" end
			inv = inv[pname]
			if (not inv) or (inv.exp <= os_time()) then
				return false, "invitation not found or expired"
			end

			local player = minetest.get_player_by_name(pname)
			if not player then return false, "player not logged in" end
			local meta = player:get_meta()
			local pos = meta:get_string(modname .. "_pos")
			if (not pos) or (pos == "") then
				meta:set_string(modname .. "_pos", minetest.pos_to_string(player:get_pos()))
			end
			meta:set_string(modname .. "_name", param)

			dumpitems(player)
			player:set_pos(inv.pos)
			minetest.chat_send_player(param, pname .. " is now visiting you")
			return true, string_format("now visiting %q, use \"/depart\" to return", param)
		end
	})

local function depart(player)
	local meta = player:get_meta()
	local pos = meta:get_string(modname .. "_pos")
	if (not pos) or (pos == "") then return false, " not currently visiting" end
	pos = minetest.string_to_pos(pos)
	dumpitems(player)
	player:set_pos(pos)
	minetest.chat_send_player(meta:get_string(modname .. "_name"),
		player:get_player_name() .. " visit ended")
	meta:set_string(modname .. "_pos", "")
	meta:set_string(modname .. "_name", "")
	return true
end

minetest.register_chatcommand("depart", {
		description = "Return from another player's invitation",
		func = function(pname)
			local player = minetest.get_player_by_name(pname)
			if not player then return false, "player not logged in" end
			return depart(player)
		end
	})

local function forcedepart(player)
	depart(player)
	return minetest.chat_send_player(player:get_player_name(),
	"invitation expired")
end
local function expireplayer(player, now)
	local vname = player:get_meta():get_string(modname .. "_name")
	if (not vname) or (vname == "") then return end
	local inv = invites[vname]
	if not inv then return forcedepart(player) end
	inv = inv[player:get_player_name()]
	if (not inv) or (inv.exp < now) then return forcedepart(player) end
end
local function expirecheck()
	minetest.after(1, expirecheck)
	local now = os_time()
	if not now then return end
	for _, player in pairs(minetest.get_connected_players()) do
		expireplayer(player, now)
	end
end
expirecheck()
