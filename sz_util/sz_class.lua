sz_class = { }
sz_class.__index = sz_class

function sz_class:new(init)
	init = init or { }
	setmetatable(init, self)
	return init
end

function sz_class:loadlibs(...)
	local modname = minetest.get_current_modname()
	local modpath = minetest.get_modpath(modname) .. "/";
	for i, class in ipairs({...}) do
		dofile(modpath .. class .. ".lua")
	end
end

function sz_class:loadsubclasses(...)
	for i, class in ipairs({...}) do
		local t = self:new()
		t.__index = t
		_G[class] = t
	end
	return self:loadlibs(...)
end
