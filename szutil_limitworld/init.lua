-- LUALOCALS < ---------------------------------------------------------
local VoxelArea, math, minetest, pairs, tonumber
    = VoxelArea, math, minetest, pairs, tonumber
local math_floor
    = math.floor
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

------------------------------------------------------------------------
-- CONFIGURATION

-- Position of center of elliptoid in which terrain is allowed.
local center = minetest.setting_get_pos(modname .. "_center") or {x = 0, y = 0, z = 0}

-- Size/apsect of elliptoid (radii in each direction) in which terrain is allowed.
local scale = minetest.setting_get_pos(modname .. "_scale")
if (not scale) or (scale.x == 0) or (scale.y == 0) or (scale.z == 0) then return end

-- Size/aspect of "inner" elliptoid in which liquids are allowed. The outer
-- shell of the world elliptoid will be a "margin" area in which liquids are
-- converted to solid to keep them from flowing out.
local margin = tonumber(minetest.settings:get(modname .. "_margin")) or 2
if scale.x <= margin or scale.y <= margin or scale.z <= margin then return end
local iscale = { x = scale.x - margin, y = scale.y - margin, z = scale.z - margin }

minetest.log(modname .. ": scale " .. minetest.pos_to_string(scale) .. " center "
	.. minetest.pos_to_string(center) .. " margin " .. margin)

-- Critical speed at which falling off the world damages players.
local fallspeed = tonumber(minetest.settings:get(modname .. "_fallspeed")) or 20

-- Relative rate of damage (linear with airspeed) for falling-off-world damage.
local falldamage = tonumber(minetest.settings:get(modname .. "_falldamage")) or 0.25

minetest.log(modname .. ": falling critical speed " .. fallspeed
	.. " damage rate " .. falldamage)

------------------------------------------------------------------------
-- NODE CONTENT ID'S

local c_air, c_solid;
local c_liquid = {}
minetest.after(0, function()
		c_air = minetest.get_content_id("air")
		c_solid = minetest.get_content_id("mapgen_stone")
		for k, v in pairs(minetest.registered_nodes) do
			if v.liquidtype ~= "none" then
				local i = minetest.get_content_id(k)
				if i then c_liquid[i] = true end
			end
		end
	end)

------------------------------------------------------------------------
-- MAP GENERATION LOGIC

-- Map generation hook that does actual terrain replacement.
minetest.register_on_generated(function()
		local vox, emin, emax = minetest.get_mapgen_object("voxelmanip")
		local data = vox:get_data()
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		local dx, dy, dz, ix, iy, iz, rs, irs, i
		for z = emin.z, emax.z do
			dz = (z - center.z) / scale.z
			dz = dz * dz
			iz = (z - center.z) / iscale.z
			iz = iz * iz
			for x = emin.x, emax.x do
				dx = (x - center.x) / scale.x
				dx = dx * dx
				ix = (x - center.x) / iscale.x
				ix = ix * ix
				for y = emin.y, emax.y do
					repeat
						-- Flatten y coordinate above center to zero, effectively
						-- treating an infinite cylinder above the bottom hemispherical
						-- shell of the world as "inside," to reduce lighting bugs caused
						-- by upper hemispherical carve-outs creating heightmap
						-- disagreements with mapgen.
						dy = y - center.y
						if dy > 0 then dy = 0 end

						-- Inside the inner allowed area: no changes.
						iy = dy / iscale.y
						iy = iy * iy
						irs = ix + iy + iz
						if irs < 1 then break end

						i = area:index(x, y, z)

						-- Outside the outer area: only air allowed.
						dy = dy / scale.y
						dy = dy * dy
						rs = dx + dy + dz
						if rs >= 1 then data[i] = c_air break end

						-- In the "shell" zone: solidify liquids.
						if c_liquid[data[i]] then data[i] = c_solid end
					until true
				end
			end
		end
		vox:set_data(data)
		vox:calc_lighting()
		vox:write_to_map()
	end)

------------------------------------------------------------------------
-- DAMAGE FROM FALLING OFF THE WORLD

-- Normally, "falling" damage is actually "landing" damage, but you won't
-- actually land if you fall off the edge; instead, in that outside zone,
-- apply actual "falling" damage so players aren't stuck falling forever.

-- Keep track of fractional HP, in case the server gives us very
-- fast cycles.
local falldmg = {}

-- Helper method to check falling damage for one player.
local function dofalldmg(dtime, player)
	-- Player must be falling at least as fast as the
	-- critical threshold speed.
	local vy = player:get_player_velocity().y
	if vy > -fallspeed then return end

	-- Player must be ouside of the world; falling inside
	-- the world elliptoid will follow normal "only landing hurts"
	-- rules.
	local pos = player:get_pos()
	local x = (pos.x - center.x) / scale.x
	local y = (pos.y - center.y) / scale.y
	local z = (pos.z - center.z) / scale.z
	local rs = x * x + y * y + z * z
	if rs < 1 or y >= 0 then return end

	-- Calculate falling damage, and add any fractional
	-- HP saved from before.
	local n = player:get_player_name()
	local d = (falldmg[n] or 0) + dtime
	* (-vy - fallspeed) * falldamage

	-- Apply whole HP damage to the player, if any.
	local f = math_floor(d)
	if f > 0 then player:set_hp(player:get_hp() - f) end

	-- Save remaining fractional HP for next cycle.
	falldmg[n] = d - f
end

-- Register hook to apply falling damage to all players.
minetest.register_globalstep(function(dtime)
		for _, player in pairs(minetest.get_connected_players()) do
			dofalldmg(dtime, player)
		end
	end)
