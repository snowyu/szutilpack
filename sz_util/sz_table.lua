-- This is a helper class for tables of arbitrary data.  It provides
-- access to some of the Lua built-in table helpers, as well as some of
-- its own functionality.

------------------------------------------------------------------------
-- GENERAL HELPER METHODS

-- Randomize the order of an array.  WARNING: modifies original!
function sz_table:shuffle()
	local l = #self
	for i, v in ipairs(self) do
		local j = math.random(1, l)
		self[i], self[j] = self[j], v
	end
	return self
end

-- Create an independent copy of this table.  This is NOT a deep copy,
-- and all referenced objects are aliases of the original table.
function sz_table:copy()
	local t = sz_table:new()
	for k, v in pairs(self) do
		t[k] = v
	end
	return t
end

-- Merge a list of tables together into one table.  Each key in the
-- output table will hold the value of the first input table to define
-- a value for that key.
function sz_table.merge(...)
	local t = sz_table:new()
	for i, p in ipairs({...}) do
		for k, v in pairs(p) do
			if t[k] == nil then
				t[k] = v
			end
		end
	end
	return t
end

-- Like sz_table.merge, merge a list of tables together, keeping the
-- value for each key from the first table to define it.  This also
-- recursively deep-merges any values which are also tables.
function sz_table.mergedeep(...)
	local t = sz_table:new()
	for i, p in ipairs({...}) do
		for k, v in pairs(p) do
			local o = t[k]
			if o == nil then
				t[k] = v
			elseif type(o) == "table" and type(v) == "table" then
				t[k] = sz_table.mergedeep(o, v)
			end
		end
	end
	return t
end

-- Create an array of all keys in this table.  This is useful for
-- creating duplicate-free lists by using creating a t[valure] = true
-- index, then using keys to convert it back to a {value, value...}
-- array.
function sz_table:keys()
	local t = sz_table:new()
	for k, v in pairs(self) do
		t:insert(k)
	end
	return t
end

-- Create an array of all values in the table.
function sz_table:values()
	local t = sz_table:new()
	for k, v in pairs(self) do
		t:insert(v)
	end
	return t
end

-- Copy minetest's serialize method.
sz_table.serialize = minetest.serialize

------------------------------------------------------------------------
-- LUA BUILT-IN LIBRARY METHODS

-- Copy all helper methods from the standard table library that aren't
-- already defined in sz_table, e.g. concat, insert, sort...
for k, v in pairs(table) do
	if not sz_table[k] then
		sz_table[k] = v
	end
end
