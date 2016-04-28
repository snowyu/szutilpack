-- Some very basic common methods, and/or miscellany.

------------------------------------------------------------------------
-- MODIFY NODE DEFINITIONS

-- Merge modifications into a node definition.  This works for current
-- and future registrations, by way of intercepting the
-- minetest.register_node method.
local nodemods = {}
function sz_util.modify_node(name, mod)
	-- Mods can be a table, to be merged over the original;
	-- convert to a function.
	if type(mod) == "table" then
		local modtbl = mod
		mod = function(old) return sz_table.mergedeep(modtbl, old) end
	end

	-- Mod functions should only apply to each node type once.
	local oldmod = mod
	local modsdone = {}
	mod = function(def, name, ...)
		if modsdone[name] then return def end
		modsdone[name] = true
		return oldmod(def, name, ...)
	end

	-- Add the mod to the mods table, for future matching
	-- registrations.
	local mods = nodemods[name]
	if not mods then
		mods = sz_table:new()
		nodemods[name] = mods
	end
	mods:insert(mod)

	-- Apply the mod to any existing registrations.
	local function modold(name, old)
		local mn = minetest.get_current_modname()
		if name:sub(1, mn:len() + 1) ~= (mn .. ":")
			and name:sub(1, 1) ~= ":" then
			name = ":" .. name
		end
		minetest.register_node(name, mod(old, name))
	end
	if name == "*" then
		for k, v in pairs(minetest.registered_nodes) do
			modold(k, v)
		end
	else
		modold(name, minetest.registered_nodes[name])
	end
end
local oldreg = minetest.register_node
minetest.register_node = function(name, def, ...)
	local function applymods(mods)
		if not mods then return end
		for i, v in ipairs(mods) do
			def = v(def, name)
		end
	end
	applymods(nodemods[name])
	applymods(nodemods["*"])
	return oldreg(name, def, ...)
end

------------------------------------------------------------------------
-- SHATTER ITEM

-- Break apart an item into its constituent parts by effectively
-- reversing crafting recipes, favoring those that will produce more
-- total items.
function sz_util.shatter_item(item, iterations)
	item = ItemStack(item)

	-- Figure out the initial quantities of items we're working
	-- with here, and put the item in the "working pile."
	local inv = sz_table:new()
	inv[item:get_name()] = item:get_count()
		* (65535 - item:get_wear()) / 65535

	-- Run the specified number of iterations of recipe reversal,
	-- choosing recipes to try at random.
	iterations = iterations or 10
	for pass = 1, iterations do
		-- Make sure we have at least 1 thing to break down.
		local ik = inv:keys()
		if #ik < 1 then break end

		-- Pick a random item to break from the pile we've
		-- accumulated.
		ik = ik[math.random(1, #ik)]

		-- Pick a random recipe for the item.
		local recs = minetest.get_all_craft_recipes(ik)
		local rec
		if recs and #recs > 0 then
			rec = recs[math.random(1, #recs)]
		end


		-- Require a valid crafting recipe.  Cooking recipes, etc.
		-- won't work because we're going to "uncraft" the item,
		-- not "uncook" it.
		if rec and rec.output and ((rec.type == "normal")
			or (rec.type == "shapeless")) then

			-- If we have more than 1, break apart a random
			-- number of them.
			local u = inv[ik]
			if u > 1 then u = math.random(1, inv[ik]) end

			-- Figure out how many items the recipe is supposed
			-- to make; that will be a divisor for the quantities
			-- produced by each item we break.
			local q = ItemStack(rec.output):to_table().count

			-- Determine if the item being broken up is made via
			-- "precision" crafting; if it is, then we can break it
			-- into similar "precision" items.  Precision-crafted
			-- items such as finely cut nodeboxes may be crafted
			-- together into non-precision items like full nodes,
			-- but "shattering" doesn't have the precision to reverse
			-- that.
			local luik = minetest.registered_items[ik]
			local precisionok = luik and luik.groups
				and luik.groups.precision_craft

			-- Start copying the "uncrafting recipe outputs" into
			-- a new list, and keep track of whether or not we
			-- run into a situation that indicates that the recipe
			-- is actually "irreversible" or that reversing it
			-- could cause balance issues (i.e. breaking apart a
			-- common item into rare and valuable components).
			local newinv = sz_table:new()
			local irrev = false
			for rk, rv in pairs(rec.items) do
				if rv and rv ~= "" then
					-- We can't break apart into a group, it has
					-- to be a specific thing.
					if rv:sub(0, 6) == "group:" then
						irrev = true
						break
					end

					-- Look up the item definition.  If the input item
					-- is part of the special "precision_craft" group, then
					-- the recipe is only reversible if the object being
					-- broken up is also precision.
					if not precisionok then
						local lun = minetest.registered_items[rv]
						if lun and lun.groups
							and lun.groups.precision_craft then
							irrev = true
							break
						end
					end

					-- Add the input item from the crafting recipe
					-- into the uncrafting recipe output.
					newinv[rv] = (newinv[rv] or 0) + (u / q)
				end
			end

			-- Skip the rest if the recipe was deemed "irreversible."
			if not irrev then
				-- Round down the number of items produced
				-- by the recipe, and count the total.
				local t = 0
				for rk, rv in pairs(newinv) do
					rv = math.floor(rv)
					if rv > 0 then
						newinv[rk] = rv
					else
						newinv[rk] = nil
					end
					t = t + rv
				end

				-- Only apply the recipe if it produced more than 1
				-- item, or 10% of the time if it's 1:1 with input.
				if t > u or t == u and math.random(1, 10) == 1 then
					-- Remove the original quantity of items that
					-- were un-crafted.
					local q = inv[ik] - u
					if q < 1 then q = nil end

					-- Add the new quantities.
					inv[ik] = q
					for nk, nv in pairs(newinv) do
						inv[nk] = (inv[nk] or 0) + nv
					end
				end
			end
		end
	end

	-- Return the resulting table, which is keyed on item name,
	-- and with item quantities in values.  It is left as an exercise
	-- to the caller to determine if any loss should be incurred (beyond
	-- any partial quantity truncation already done) and how to deliver
	-- the shattered items.
	return inv
end

------------------------------------------------------------------------
-- METADATA / PURE TABLE CONVERSION

-- NodeMetaRef:to_table() apparently returns a "mixed" lua table with
-- some userdata refs mixed in with pure lua structures.  These methods
-- attempt to convert metadata to/from pure lua data, which can be
-- serialized and copied around freely.

-- Convert metadata to a pure lua table.
function sz_util.meta_to_lua(meta)
	if not meta then return end

	local t = meta:to_table()
	local o = {}

	-- Copy fields, if there are any.
	if t.fields then 
		for k, v in pairs(t.fields) do
			o.f = t.fields
			break
		end
	end

	-- Copy inventory, if there are any.
	local i = meta:get_inventory()
	for k, v in pairs(i:get_lists()) do
		o.i = o.i or {}

		local j = {}
		o.i[k] = j

		local s = i:get_size(k)
		j.s = s

		j.i = {}
		for n = 0, s do
			local x = i:get_stack(k, n)
			if x then j.i[n] = x:to_table() end
		end
	end

	-- Try to return nil, if possible, for an empty
	-- metadata table, otherwise return the data.
	for k, v in pairs(o) do return o end
end

-- Write a pure lua metadata table back into a NodeMetaRef.
function sz_util.lua_to_meta(lua, meta)
	-- Always clear the meta, and load the fields if any.
	local t = {fields = {}, inventory = {}}
	if lua and lua.f then t.fields = lua.f end
	meta:from_table(t)

	-- Load inventory, if any.
	if lua and lua.i then
		local i = m:get_inventory()
		for k, v in pairs(lua.i) do
			i:set_size(k, v.s)
			for sk, sv in pairs(v.i) do
				i:set_stack(ik, sk, ItemStack(sv))
			end
		end
	end
end

------------------------------------------------------------------------
return sz_util
