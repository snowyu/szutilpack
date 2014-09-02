-- Extension methods for sz_pos that deal with general environmental
-- features, like the presence of nearby fluids or heat sources.

------------------------------------------------------------------------

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
