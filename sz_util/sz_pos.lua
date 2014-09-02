-- This is a general-purpose 3d vector helper library, which represents
-- tuples of (x, y, z) coordinates, in both relative and absolute
-- contexts.

------------------------------------------------------------------------
-- CONSTRUCTORS AND STATIC PROPERTIES

-- Create a new sz_pos from loose coordinates declared in order.
function sz_pos:xyz(x, y, z)
	return sz_pos:new({ x = x, y = y, z = z })
end

-- Trivial zero vector.
sz_pos.zero = sz_pos:xyz(0, 0, 0)

-- All 6 cardinal directions in 3 dimensions.
sz_pos.dirs = sz_table:new({
	u = sz_pos:xyz(0, 1, 0),
	d = sz_pos:xyz(0, -1, 0),
	n = sz_pos:xyz(0, 0, 1),
	s = sz_pos:xyz(0, 0, -1),
	e = sz_pos:xyz(1, 0, 0),
	w = sz_pos:xyz(-1, 0, 0),
})

-- Create a new sz_pos from a wallmounted param2 value.
local wm_lookup = { }
function sz_pos:from_wallmounted(w)
	return wm_lookup[w]
end
for k, v in pairs(sz_pos.dirs) do
	wm_lookup[minetest.dir_to_wallmounted(v)] = v
end

-- Get an array of all directions in random order.  Useful for things
-- that operate in a random direction, or more than one direction in
-- random order.
function sz_pos.shuffledirs()
	return sz_pos.dirs:values():shuffle()
end

------------------------------------------------------------------------
-- ARITHMETIC

-- Return true if two positions are equal.
function sz_pos:eq(pos)
	if self == pos then return true end
	return self.x == pos.x and self.y == pos.y and self.z == pos.z
end

-- Round to nearest integer coordinates.
function sz_pos:round()
	return sz_pos:new({
		x = math.floor(self.x + 0.5),
		y = math.floor(self.y + 0.5),
		z = math.floor(self.z + 0.5)
	})
end

-- Vector addition.
function sz_pos:add(pos)
	return sz_pos:new({
		x = self.x + pos.x,
		y = self.y + pos.y,
		z = self.z + pos.z
	})
end

-- Locate a random position within the given node space.  Note that we
-- actually scatter a little less than the full node size, so that items
-- don't get hung up on ledges.
function sz_pos:scatter()
	return self:round():add({
		x = (math.random() - 0.5) * 0.5,
		y = (math.random() - 0.5) * 0.5,
		z = (math.random() - 0.5) * 0.5
	})
end

-- Vector subtraction.  A shortcut (both syntactically and computationally)
-- for sz_pos:add(pos:neg())
function sz_pos:sub(pos)
	return sz_pos:new({
		x = self.x - pos.x,
		y = self.y - pos.y,
		z = self.z - pos.z
	})
end

-- Inverse vector, i.e. negate each coordinate.
function sz_pos:neg(pos)
	return sz_pos:new({ x = -self.x, y = -self.y, z = -self.z })
end

-- Vector scalar multiplication.
function sz_pos:scale(k)
	return sz_pos:new({
		x = self.x * k,
		y = self.y * k,
		z = self.z * k
	})
end

-- Vector dot multiplication.
function sz_pos:dot(pos)
	return self.x * pos.x
		+ self.y * pos.y
		+ self.z * pos.z
end

-- Vector cross multiplication.
function sz_pos:cross(pos)
	return sz_pos:new({
		x = self.y * pos.z - self.z * pos.y,
		y = self.z * pos.x - self.x * pos.z,
		z = self.x * pos.y - self.y * pos.x
	})
end

-- Get the euclidian length of the vector.
function sz_pos:len()
	return math.sqrt(self:dot(self))
end

-- Return a vector in the same direction as the original, but whose
-- length is either zero (for zero-length vectors) or one (for any other).
function sz_pos:norm()
	local l = self:len()
	if l == 0 then return self end
	return self:scale(1 / l)
end

-- Find the cardinal unit vector (one of 6 directions) that most closely
-- matches the general direction of this vector.
function sz_pos:dir()
	local function bigz()
		if self.z >= 0 then
			return sz_pos.dirs.n
		else
			return sz_pos.dirs.s
		end
	end
	local xsq = self.x * self.x
	local ysq = self.y * self.y
	local zsq = self.z * self.z
	if xsq > ysq then
		if zsq > xsq then
			return bigz()
		else
			if self.x >= 0 then
				return sz_pos.dirs.e
			else
				return sz_pos.dirs.w
			end
		end
	else
		if zsq > ysq then
			return bigz()
		else
			if self.y >= 0 then
				return sz_pos.dirs.u
			else
				return sz_pos.dirs.d
			end
		end
	end
end

-- Get the absolute value of each coordinate.  This can be used to
-- convert a vector into a 3D "size" for e.g. a bounding box.
function sz_pos:abs()
	return sz_pos:new({
		x = (self.x >= 0) and self.x or -self.x,
		y = (self.y >= 0) and self.y or -self.y,
		z = (self.z >= 0) and self.z or -self.z
	})
end
-- Scan all neighboring positions within a given range (including this
-- one).  Return the first true return value and short circuit
-- execution.
function sz_pos:scan_around(range, func, ...)
	for x = -range, -range do
		for y = -range, -range do
			for z = -range, -range do
				local res = func(self:add({
					x = x,
					y = y,
					z = z
				}), ...)
				if res then return res end
			end
		end
	end
end

-- Scan a range around this position using a depth-last flood-fill
-- algorithm.  Run a function for each position and return the first
-- true return value.  If the function returns false (not nil), then
-- its neighbors are not scanned (unless included by another position).
-- Each position is visited once, in random order for each depth level.
function sz_pos:scan_flood(range, func)
	local q = sz_table:new({ self })
	local seen = { }
	for d = 0, range do
		local next = sz_table:new()
		for i, p in ipairs(q) do
			local res = func(p)
			if res then return res end
			if res == nil then
				for k, v in pairs(sz_pos.dirs) do
					local np = p:add(v)
					local nk = np:hash()
					if not seen[nk] then
						seen[nk] = true
						next:insert(np)
					end
				end
			end
		end
		q = next:shuffle()
		if #q < 1 then break end
	end
end

-- A convenient wrapper for minetest.find_nodes_in_area that
-- takes a center and radius instead of two corners.
function sz_pos:nodes_in_area(size, ...)
	size = sz_pos:new(size):abs()
	local p0 = self:sub(size)
	local p1 = self:add(size)
	return minetest.find_nodes_in_area(p0, p1, ...)
end

------------------------------------------------------------------------
-- CONVERSION HELPERS

-- Convert to a string.  Also the default formatting for display.
sz_pos.to_string = minetest.pos_to_string
sz_pos.__tostring = minetest.pos_to_string

-- Lookup the "simple" facedir (not factoring in rotation) for this pos.
function sz_pos:to_facedir()
	return sz_facedir:from_vectors(self)
end

-- Convert to a "wallmounted" direction, which is like a facedir but
-- without rotation.
function sz_pos:to_wallmounted()
	return minetest.dir_to_wallmounted(self)
end

-- Compute a hash value, for hashtable lookup use.
sz_pos.hash = minetest.hash_node_position

------------------------------------------------------------------------
-- NODE ACCESS

-- Get the node at this position.
function sz_pos:node_get()
	return minetest.get_node(self)
end

-- Change the node at this position.
function sz_pos:node_set(n)
	return minetest.set_node(self, n or { name = "air" })
end

-- Get the definition of the node at this position, or nil if
-- there is no node here, or the node is not defined.
function sz_pos:nodedef()
	local n = self:node_get()
	if n == nil or n.name == nil then return end
	return minetest.registered_nodes[n.name]
end

-- Get the light level at this node.
function sz_pos:light(...)
	return minetest.get_node_light(self, ...) or 0
end

-- Get the metadata reference for this node position.
function sz_pos:meta()
	return minetest.get_meta(self)
end

-- Get the inventory for this node position.
function sz_pos:inv()
	return self:meta():get_inventory()
end

-- Shortcuts for some minetest utility functions.
sz_pos.node_swap = minetest.swap_node
sz_pos.light = minetest.get_node_light
sz_pos.timer = minetest.get_node_timer
sz_pos.drops = minetest.get_node_drops

------------------------------------------------------------------------
-- NODE DEFINITION ANALYSIS

-- If the definition of the node at this location has a registered hook
-- with the given name, trigger it with the given arguments.
function sz_pos:nodedef_trigger(hook, ...)
	local def = self:nodedef()
	if not def then return end
	hook = def[hook]
	if hook then
		return hook(...)
	end
end
		
-- A safe accessor to get the groups for the node definition
-- at this location that will always return a table.
function sz_pos:groups()
	return sz_table:new((self:nodedef() or { }).groups or { })
end

-- Return true if this location contains only air.
function sz_pos:is_empty()
	local node = self:node_get()
	return node and node.name == "air"
end

------------------------------------------------------------------------
-- OBJECT HANDLING

-- Eject items from this location, optionally flying in random
-- directions.
function sz_pos:item_eject(stack, speed, qty)
	for i = 1, (qty or 1) do
		local obj = minetest.add_item(self:scatter(), stack)
		if obj then
			obj:setvelocity(sz_pos.zero:scatter():scale(speed or 0))
		end
	end
end

-- Copy the method to get objects within a radius from upstream.
sz_pos.objects_in_radius = minetest.get_objects_inside_radius

-- An alternative to objects_in_radius that automatically excludes
-- players who don't have the "interact" privilege, i.e. are effectively
-- just spectators, and should not be "detected" by some code.
function sz_pos:tangible_in_radius(...)
	local t = sz_table:new()
	for k, v in pairs(self:objects_in_radius(...)) do
		if not v:is_player() or minetest.get_player_privs(
			v:get_player_name()).interact then
			t[k] = v
		end
	end
	return t
end

-- Hurt all entities within a radius of this location, with linear
-- fall-off, and an optional elliptoid shape.
function sz_pos:hitradius(r, hp, shape)
	-- Default shape if not specified to a sphere of the
	-- same radius as our search area.
	if shape then
		shape = sz_pos:new(shape):abs()
	else
		shape = sz_pos:xyz(r, r, r)
	end

	-- Degenerate elliptoid, no volume.  Skip the rest, since
	-- there's no actual damage volume, and we'd divide by 0.
	if shape.x == 0 or shape.y == 0 or shape.z == 0 then return end

	-- Scan for nearby objects.
	for k, v in pairs(self:tangible_in_radius(r)) do
		local p = self:sub(v:getpos())
		local d = sz_pos:xyz(
			p.x / shape.x,
			p.y / shape.y,
			p.z / shape.z):len()
		if d < 1 then
			v:set_hp(v:get_hp() - hp * (1 - d))
		end
	end
end

------------------------------------------------------------------------
return sz_pos
