-- LUALOCALS < ---------------------------------------------------------
local math, minetest, rawget, tonumber
    = math, minetest, rawget, tonumber
local math_abs, math_cos, math_floor, math_pi, math_sin, math_sqrt
    = math.abs, math.cos, math.floor, math.pi, math.sin, math.sqrt
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

local phi = (math_sqrt(5) + 1) / 2
local goldangle = math_pi * 2 / phi / phi

local scale = minetest.settings:get(modname .. "_scale") or 256
local areasize = minetest.setting_get_pos(modname .. "_area_size") or {x = 63, y = 127, z = 63}
areasize = vector.floor(vector.multiply({
			x = math_abs(areasize.x),
			y = math_abs(areasize.y),
			z = math_abs(areasize.z)
		}, 0.5))
local skipids = tonumber(minetest.settings:get(modname .. "_skip_ids"))

local modstore = minetest.get_mod_storage()
local lastid = modstore:get_int("lastid") or 0
if skipids and lastid < skipids then lastid = math_floor(skipids) end

local areas = rawget(_G, "areas")
local beds = rawget(_G, "beds")
local sethome = rawget(_G, "sethome")

local function playerid(player)
	local meta = player:get_meta()
	local id = meta:get_int(modname .. "_id")
	if id == 0 then
		lastid = lastid + 1
		modstore:set_int("lastid", lastid)
		id = lastid
		meta:set_int(modname .. "_id", id)
	end
	return id
end

local function findhome(player, pos)
	if not pos then
		local id = playerid(player)
		local theta = id * goldangle
		local r = (id - 1) * scale
		pos = vector.round({
				x = r * math_cos(theta),
				y = 0,
				z = r * math_sin(theta)
			})
	end
	while true do
		local ll = minetest.get_node_light(pos, 0.5)
		if not ll then
			minetest.after(1, function()
					return findhome(player, pos)
				end)
			return player:set_pos(pos)
		end
		if ll > 0 then
			player:get_meta():set_string(modname .. "_home", minetest.pos_to_string(pos))
			local pname = player:get_player_name()
			if areas and areasize.x > 0 and areasize.y > 0 and areasize.z > 0 then
				areas:add(
					pname,
					pname .. "'s Home",
					vector.subtract(pos, areasize),
					vector.add(pos, areasize)
				)
				areas:save()
			end
			if sethome then
				sethome.set(pname, pos)
			end
			return player:set_pos(pos)
		end
		pos.y = pos.y + 1
	end
end
minetest.register_on_newplayer(function(player)
		return findhome(player)
	end)

minetest.register_on_respawnplayer(function(player)
		if beds then
			local pname = player:get_player_name()
			if beds.spawn[pname] then return end
		end
		return minetest.after(0, function()
				local pos = player:get_meta():get_string(modname .. "_home")
				if pos and pos ~= "" then
					return player:set_pos(minetest.string_to_pos(pos))
				end
			end)
	end)

if not sethome then
	minetest.register_privilege("home", {
			description = "Can use /home",
			give_to_singleplayer = false
		})
	minetest.register_chatcommand("home", {
			description = "Teleport you to your home",
			privs = {home = true},
			func = function(pname)
				local player = minetest.get_player_by_name(pname)
				if not player then return false, "player not found" end
				local pos = player:get_meta():get_string(modname .. "_home")
				if not pos then return false, "No home set!" end
				player:set_pos(minetest.string_to_pos(pos))
			end
		})
end
