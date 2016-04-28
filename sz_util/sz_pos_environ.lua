-- Extension methods for sz_pos that deal with general environmental
-- features, like the presence of nearby fluids or heat sources.

------------------------------------------------------------------------
-- FLUID DYNAMICS

-- Determine if the node at this position is a fluid, and measure
-- its "depth," up to a certain number of nodes above.
function sz_pos:fluid_depth(recurse)
	local def = self:nodedef()

	-- Solid nodes have an undefined depth.
	if not def or def.walkable then return nil end

	-- Non-walkable nodes are considered "air" and have
	-- zero depth by default.
	local depth = 0

	-- Source blocks are 9 ticks deep,
	-- since flowing are between 1 and 8.
	if def.liquidtype == "source" then
		depth = 9

	-- Flowing block depth is stored in param2.
	elseif def.liquidtype == "flowing" then
		local node = self:node_get()
		if not node then return 0 end
		depth = node.param2 % 8 + 1
	end

	-- If this node has a full depth, then add the depth of the
	-- node above, up to the recursion limit.
	if depth >= 8 and recurse and recurse > 0 then
		local above = self:add(sz_pos.dirs.u):fluid_depth(recurse - 1)
		if above then depth = depth + above end
	end

	return depth, def
end

-- Determine if there is "pressure" from a nearby fluid to "wash out" this
-- node if it's washable.  If washout is true, returns true, the position from
-- which washout is happening, and the definition of the node trying to do the
-- washout.  If washout is false, returns nil.
function sz_pos:fluid_washout(mindepth)
	-- Check for fluids from above.  Any fluid level above will try
	-- to descend into this node, washing out its contents.
	local above = self:add(sz_pos.dirs.u)
	local depth, def = above:fluid_depth()
	if depth and depth > 0 then
		return true, above, def
	end

	-- On each side, there must be fluid, that fluid must not have
	-- a node below it into which the fluid would flow instead of
	-- this one, and the fluid must have sufficient depth.
	mindepth = mindepth or 2
	for k, v in pairs({ sz_pos.dirs.n, sz_pos.dirs.s, sz_pos.dirs.e, sz_pos.dirs.w }) do
		local p = self:add(v)
		depth, def = p:fluid_depth()
		if depth and depth > mindepth then
			local b = p:add(sz_pos.dirs.d):node_get().name
			if b ~= "air" and b ~= def.liquid_alternative_flowing then
				return true, p, def
			end
		end
	end
end

------------------------------------------------------------------------
-- HEAT AND FLAME

-- Determine if fire is allowed at a certain location.
function sz_pos:fire_allowed()
	-- Check for whether fire should extinguish at this location.
	if fire and fire.flame_should_extinguish
		and fire.flame_should_extinguish(self) then
		return
	end

	-- Flames can replace air, anything flammable, and other flames.
	-- Multiple flames are supported using the "flame" group.
	if self:is_empty() then return true end
	local grp = self:groups()
	if grp.flammable or grp.flame then return true end
end

-- Helper for heat_level() that calculates the distance-adjusted
-- contribution from a single node.
local function heat_contrib(pos, v, group, mult)
	if pos:eq(v) then return 0 end
	v = sz_pos:new(v)
	if v:node_get().name == "ignore" then return end
	local contrib = v:groups()[group]
	if not contrib then return 0 end
	if type(contrib) ~= "number" then contrib = 1 end
	contrib = contrib * (mult or 1)
	v = v:sub(pos)
	v.y = v.y / 2
	return contrib / (v:dot(v) * 3)
end

-- Calculate a "heat" level for a given node, based on contribuions from
-- other nearby nodes, for things like environmental cooking.
function sz_pos:heat_level()
	local temp = 0

	-- Search the vicinity around and below the node, and calculate
	-- the temperature of its immediate surroundings.  Nodes in the "hot"
	-- group contribute to this based on their "hot" value, and contributions
	-- are inversely proportional to distance squared, though y distance is
	-- "squashed" to simulate convection.
	local min = self:add(sz_pos:xyz(-1, -2, -1))
	local max = self:add(sz_pos:xyz(1, 0, 1))
	for k, v in pairs(minetest.find_nodes_in_area(min, max, { "group:hot" })) do
		local c = heat_contrib(self, v, "hot")
		if not c then return end
		temp = temp + c
	end

	-- Similar to the "hot" check, we search for "puts_out_fire" (cold) nodes
	-- above and sum up their contributions, in the negative.
	local min = self:add(sz_pos:xyz(-1, 0, -1))
	local max = self:add(sz_pos:xyz(1, 2, 1))
	for k, v in pairs(minetest.find_nodes_in_area(min, max, { "group:puts_out_fire" })) do
		local c = heat_contrib(self, v, "puts_out_fire", -5)
		if not c then return end
		temp = temp + c
	end

	return temp
end
