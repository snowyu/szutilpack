-- LUALOCALS < ---------------------------------------------------------
local math, minetest, pairs, tonumber
    = math, minetest, pairs, tonumber
local math_abs, math_floor, math_random
    = math.abs, math.floor, math.random
-- LUALOCALS > ---------------------------------------------------------

local limit = tonumber(minetest.get_mapgen_setting("mapgen_limit")) or 31000
local chunksize = tonumber(minetest.get_mapgen_setting("chunksize")) or 5
chunksize = chunksize * 16
limit = math_floor(limit / chunksize)
local limit_min = (-limit + 0.5) * chunksize + 7.5
local limit_max = (limit - 0.5) * chunksize + 7.5
local limit_ctr = (limit_min + limit_max) / 2

local function oobdirs(pos)
	if pos.x >= limit_min and pos.x < limit_max
	and pos.y >= limit_min and pos.y < limit_max
	and pos.z >= limit_min and pos.z < limit_max then return end

	local relx = pos.x - limit_ctr
	local rely = pos.y - limit_ctr
	local relz = pos.z - limit_ctr
	local absx = math_abs(relx)
	local absy = math_abs(rely)
	local absz = math_abs(relz)
	local axisx = {x = relx / absx, y = 0, z = 0}
	local axisy = {x = 0, y = rely / absy, z = 0}
	local axisz = {x = 0, y = 0, z = relz / absz}
	if absx > absy then
		if absx > absz then
			return axisx, axisy, axisz
		end
		return axisz, axisx, axisy
	end
	if absz > absy then
		return axisz, axisx, axisy
	end
	return axisy, axisz, axisx
end

local function checkplayer(player)
	local pos = player:get_pos()
	pos.x = pos.x + math_random() * 16 - 8
	pos.y = pos.y + math_random() * 16 - 8
	pos.z = pos.z + math_random() * 16 - 8
	local axis, orth1, orth2 = oobdirs(pos)
	if not axis then return end
	local diag = {
		x = math_abs(orth1.x + orth2.x),
		y = math_abs(orth1.y + orth2.y),
		z = math_abs(orth1.z + orth2.z)
	}
	local n = ({"0", "1", "2", "3", "4", "5", "6", "7", "8",
			"9", "a", "b", "c", "d", "e", "f"})[math_random(1, 16)]
	n = n .. n
	n = n .. n .. n
	minetest.add_particlespawner({
			time = 1,
			amount = 10,
			minpos = vector.add(pos, vector.multiply(diag, -8)),
			maxpos = vector.add(pos, vector.multiply(diag, 8)),
			minvel = vector.multiply(diag, -8),
			maxvel = vector.multiply(diag, 8),
			minexptime = 1,
			maxexptime = 2,
			minsize = 0.25,
			maxsize = 1,
			texture = "[combine:1x1^[noalpha^[colorize:#" .. n .. ":255",
			playername = player:get_player_name(),
			glow = -15
		})
end

minetest.register_globalstep(function()
		for _, player in pairs(minetest.get_connected_players()) do
			checkplayer(player)
		end
	end)
