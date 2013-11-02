sz_class = { }
sz_class.__index = sz_class

function sz_class:new(init)
	init = init or { }
	setmetatable(init, self)
	return init
end

function sz_class:loadsubclasses(mod, ...)
	local modpath = minetest.get_modpath(mod) .. "/";
	local classes = {...}
	for i, class in ipairs(classes) do
		local t = self:new()
		t.__index = t
		_G[class] = t
	end
	for i, class in ipairs(classes) do
		dofile(modpath .. class .. ".lua")
	end
end
