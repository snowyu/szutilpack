sz_class = { }
sz_class.__index = sz_class

function sz_class:new(init)
	init = init or { }
	setmetatable(init, self)
	return init
end

function sz_class:loadlibs(...)
	local modname = minetest.get_current_modname()
	local modpath = minetest.get_modpath(modname) .. "/"
	for i, class in ipairs({...}) do
		dofile(modpath .. class .. ".lua")
	end
end

function sz_class:loadsubclasses(...)
	for i, class in ipairs({...}) do
		local t = self:new(rawget(_G, class))
		t.__index = t
		if class:sub(1, 3) == "sz_" then
			rawset(_G, class, t)
		else
			_G[class] = t
		end
	end
	return self:loadlibs(...)
end
