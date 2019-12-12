-- LUALOCALS < ---------------------------------------------------------
local minetest, pairs, string, table, type
    = minetest, pairs, string, table, type
local string_gmatch, string_match, string_sub, table_concat
    = string.gmatch, string.match, string.sub, table.concat
-- LUALOCALS > ---------------------------------------------------------

local function isstealth(player)
	if type(player) == "string" then
		player = minetest.get_player_by_name(player)
	end
	if not player then return end
	return minetest.check_player_privs(player, "stealth")
end

local saved = {}
local function nonzero(t)
	for _, v in pairs(t) do if v ~= 0 then return true end end
end
local function updatevisible(player)
	local pname = player:get_player_name()
	local props = player:get_properties()
	local atts = player:get_nametag_attributes()

	local isvis = nonzero(props.visual_size)
	or props.pointable
	or atts.color.a > 0

	if isvis then saved[pname] = {p = props, a = atts} end
	local needvis = not isstealth(player)
	if isvis == needvis then return end

	player:set_properties({
			visual_size = needvis and saved[pname].p.visual_size or {x = 0, y = 0},
			pointable = needvis and saved[pname].p.pointable or false,
			makes_footstep_sound = needvis and saved[pname].p.makes_footstep_sound or false
		})
	player:set_nametag_attributes({
			color = needvis and saved[pname].a.color or {r = 0, g = 0, b = 0, a = 0}
		})
	minetest.after(0, function() return updatevisible(player) end)
end

local function grantrevoke(pname)
	return minetest.after(0, function()
			local player = minetest.get_player_by_name(pname)
			if player then return updatevisible(player) end
		end)
end

minetest.register_privilege("stealth", {
		description = "Invisibility",
		give_to_singleplayer = false,
		give_to_admin = false,
		on_grant = grantrevoke,
		on_revoke = grantrevoke
	})

minetest.register_on_joinplayer(updatevisible)

local hooked
local function chathook()
	if minetest.chat_send_all == hooked then return end
	local oldsend = minetest.chat_send_all
	hooked = function(msg, ...)
		local pname = string_match(msg, "^%*%*%* (%S+) joined the game.$")
		or string_match(msg, "^%*%*%* (%S+) left the game.$")
		if pname and isstealth(pname) then return end
		return oldsend(msg, ...)
	end
	minetest.chat_send_all = hooked
	minetest.after(0, chathook)
end
chathook()

local function stripstatus(msg, ...)
	local pref, clients = string_match(msg, "^(.*)clients={(.*)}$")
	local clist = {}
	for pname in string_gmatch(clients, "%S+") do
		if string_sub(pname, -1) == "," then
			pname = string_sub(pname, 1, #pname - 1)
		end
		if not isstealth(pname) then
			clist[#clist + 1] = pname
		end
	end
	msg = pref .. "clients={" .. table_concat(clist, ", ") .. "}"
	return msg, ...
end
local oldstatus = minetest.get_server_status
function minetest.get_server_status(...)
	return stripstatus(oldstatus(...))
end