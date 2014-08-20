-- There are a number of ways in which machinery can be made to fail
-- catastrophically.  When this happens, we dig the node, deconstruct it
-- into its craft components, suffer some random loss of some of those
-- components, scatter the pieces, and play some explosion effects.

------------------------------------------------------------------------

-- Some tweakable settings.
local shatter_radius = 3
local shatter_speed = 20

-- The main helper method to actually shatter a node; it figures out
-- the standard behavior mostly automatically.  Accepts a reason string
-- to include in logs.
function sz_pos:shatter(reason, item)

	-- If we're not provided an item to shatter at this location,
	-- then we're breaking a node; get the node that's being torn
	-- apart and make sure it's valid.
	local node
	if not item then
		node = self:node_get()
		if not node or not node.name or node.name == "air"
			or node.name == "ignore" or node.name == "" then
			return
		end
		item = node.name
		local def = minetest.registered_items[node.name]
		if not def or not def.groups or not def.groups.can_shatter then return end
		if def and def.drop and def.drop ~= "" then item = def.drop end
	end

	-- Admin log notification.
	msg = item
	if node and node.name ~= item then
		msg = "node " .. node.name .. " -> " .. item
	end
	local msg = "shattered " .. msg .. " at " .. self:to_string()
	if reason then msg = msg .. " because: " .. reason end
	print(msg)

	-- "Un-craft" the node into minute pieces.
	local inv = sz_util.shatter_item(item)

	-- Remove any shattered node.
	if node then self:node_set() end

	-- Any nearby entities get hurt from this.
	-- Damage falloff is linear, meh.
	for k, v in pairs(minetest.get_objects_inside_radius(self, 3)) do
		local dmg = shatter_radius - self:sub(v:getpos()):len()
		if dmg > 0 then
			v:set_hp(v:get_hp() - dmg)
		end
	end

	-- For each item, there is a chance it's destroyed.
	-- For everything that's not destroyed, eject it violently.
	for k, v in pairs(inv) do
		local q = 0
		for i = 1, v do
			if math.random() <= 0.8 then q = q + 1 end
		end
		if q > 1 then
			self:item_eject(k, shatter_speed, q)
		end
	end

	-- Play special effects.
	self:sound("tnt_explode")
	self:smoke(5, sz_pos:xyz(shatter_speed, shatter_speed, shatter_speed):scale(0.25))
end
