-- There are a number of ways in which machinery can be made to fail
-- catastrophically.  When this happens, we dig the node, deconstruct it
-- into its craft components, suffer some random loss of some of those
-- components, scatter the pieces, and play some explosion effects.

------------------------------------------------------------------------

-- The main helper method to actually shatter a node; it figures out
-- the standard behavior mostly automatically.  Accepts a reason string
-- to include in logs.
function sz_pos:shatter(reason, item, lossratio, speed, sound, smoke)

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

	-- Any nearby entities get hurt from this.  Amount of damage is
	-- related to the amount of actual shrapnel produced.
	local dmg = 0
	for k, v in pairs(inv) do dmg = dmg + v end
	dmg = math.sqrt(dmg)
	self:hitradius(dmg, dmg)

	-- For each item, there is a chance it's destroyed.
	-- For everything that's not destroyed, eject it violently.
	for k, v in pairs(inv) do
		local q = 0
		for i = 1, v do
			if math.random() <= (lossratio or 0.8) then q = q + 1 end
		end
		if q > 1 then
			self:item_eject(k, speed, q)
		end
	end

	-- Play special effects.
	if sound or sound ~= nil then self:sound(sound or "tnt_explode") end
	self:smoke(5, sz_pos:xyz(speed, speed, speed):scale(0.25),
		{texture = smoke})
end
