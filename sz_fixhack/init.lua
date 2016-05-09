local modname = minetest.get_current_modname()

-- Proportion of time to spend each cycle on recalculations.  For instance,
-- a value of 0.05 will mean that we attempt to use about 5% of each step
-- cycle trying to do recalculates.
local cycletime = tonumber(minetest.setting_get(modname .. "_cycletime")) or 0.02

-- How often statistics are written to the log, to track server CPU use.
local stattime = tonumber(minetest.setting_get(modname .. "_stattime")) or 3600

-- How often a mapblock can be recalculated, at the earliest.
local calctime = tonumber(minetest.setting_get(modname .. "_calctime")) or 60

-- Simple positional helper functions.
local function posadd(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end
local function blockmin(v) return {x = v.x * 16, y = v.y * 16, z = v.z * 16} end
local function blockmax(v) return posadd(blockmin(v), {x = 15, y = 15, z = 15}) end

-- Generate exponentially-distributed random values, so low values (nearby
-- positions) are more likely to get prompt attention.
local function exporand()
	local r = math.random()
	if r == 0 then return exporand() end
	r = math.log(r)
	if math.random() < 0.5 then r = -r end
	return r
end

local mapgenqueue = {}
-- Run voxelmanip lighting calc on chunks post-mapgen.  It seems as though
-- the default mapgen lighting calc disagrees with this one (water does not
-- absorb light; bug?)
minetest.register_on_generated(function(minp, maxp)
	for x = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
		for y = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
			for z = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
				local pos = {x = x, y = y, z = z}
				mapgenqueue[minetest.hash_node_position(pos)] = pos
			end
		end
	end
end)

-- Keep track of each block processed, and when its check expires
-- and reprocessing is possible.
local processed = {}

-- Statistics for reporting display.
local proctime = 0
local totaltime = 0
local totalqty = 0

-- Amount of time available for processing.
local availtime = 0

-- Helper method to automatically process blocks
-- (shared by mapgen and random queue).
local function procblock(pos, nextcalc)
	-- Don't reprocess already-processed blocks too soon.
	local h = minetest.hash_node_position(pos)
	if processed[h] then return end
	processed[h] = nextcalc

	-- Don't process a block if it's not loaded, or if any of its
	-- neighbors is not loaded, as that can cause lighting bugs (at least).
	if not minetest.get_node_or_nil(blockmin(pos))
		or not minetest.get_node_or_nil(blockmin(posadd(pos, {x = 0, y = 1, z = 0})))
		or not minetest.get_node_or_nil(blockmin(posadd(pos, {x = 1, y = 0, z = 0})))
		or not minetest.get_node_or_nil(blockmin(posadd(pos, {x = -1, y = 0, z = 0})))
		or not minetest.get_node_or_nil(blockmin(posadd(pos, {x = 0, y = 0, z = 1})))
		or not minetest.get_node_or_nil(blockmin(posadd(pos, {x = 0, y = 0, z = -1})))
		or not minetest.get_node_or_nil(blockmin(posadd(pos, {x = 0, y = -1, z = 0})))
		then return end

	-- Recalc all fluids and lighting in that block.
	local vm = minetest.get_voxel_manip(blockmin(pos), blockmax(pos))
	vm:update_liquids()
	vm:calc_lighting()
	vm:write_to_map()
	vm:update_map()

	-- Keep track for periodic statistic summary.
	totalqty = totalqty + 1
end

-- Run recalculates during each cycle.
minetest.register_globalstep(function(dtime)
	-- Don't attempt to do anything if nobody is connected.  There seems
	-- to be some issue that may be crashing servers that run for a long
	-- time with no players connected, which this may help avert.
	local players = minetest.get_connected_players()
	if #players < 1 then return end

	-- Add our allotment to the amount of time available.
	availtime = availtime + dtime * cycletime

	-- If we have a net deficit of time available, shrink it over
	-- time, so we don't have to wait forever for it to linearly
	-- crawl back to positive.
	if availtime < 0 then availtime = availtime * 0.75 end

	-- Calculate when the recalculation is supposed to stop, based on
	-- real-time clock.
	local starttime = os.clock()
	local endtime = starttime + availtime

	-- Get the current timestamp, to be used in expiration timestamps.
	local now = os.time()

	-- Prune already-expired blocks from the processed list.
	local del = {}
	for k, v in pairs(processed) do
		if v < now then del[k] = true end
	end
	for k, v in pairs(del) do
		processed[k] = nil
	end

	local nextcalc = now + calctime

	-- Process generated chunks first.
	for k, v in pairs(mapgenqueue) do
		procblock(v, nextcalc)
		mapgenqueue = {}
	end

	-- Skip random recalcs if we don't actually have any time to do them.
	if endtime > starttime then
		-- Keep searching for blocks to recalc until we run out of allotted time.
		while os.clock() < endtime do
			-- Pick a random player, and then pick a random exponentially-
			-- distributed random block around that player.
			local pos = players[math.random(1, #players)]:getpos()
			pos.x = math.floor(pos.x / 16 + exporand() + 0.5)
			pos.y = math.floor(pos.y / 16 + exporand() + 0.5)
			pos.z = math.floor(pos.z / 16 + exporand() + 0.5)
			procblock(pos, nextcalc)
		end
	end

	-- Update our actual end time (in case we ran long with voxel operations),
	-- and keep track for periodic statistic summary.
	endtime = os.clock()
	totaltime = totaltime + dtime
	proctime = proctime + endtime - starttime

	-- Update available time allotment.
	availtime = availtime + starttime - endtime
end)

-- Periodically display statistics, so we can track actual performance.
local function reportstats()
	if totaltime == 0 then
		print(modname .. ": processing suspended")
		return
	end
	local function ms(i) return math.floor(i * 1000000) / 1000 end
	print(modname .. ": processed " .. totalqty .. " mapblocks using "
		.. ms(proctime) .. "ms out of " .. ms(totaltime) .. "ms ("
		.. (math.floor(proctime / totaltime * 10000) / 100) .. "%)")
	totalqty = 0
	totaltime = 0
	proctime = 0
	minetest.after(stattime, reportstats)
end
minetest.after(stattime, reportstats)
