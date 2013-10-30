sz_nodepos = { }

function sz_nodepos:new(init)
	init = init or { }
	setmetatable(init, self)
	self.__index = self

	if init.node == nil then
		init.node = minetest.get_node(init)
	end
	if init.node == nil then
		init.def = nil
	elseif init.def == nil then
		init.def = minetest.registered_items[init.node.name]
	end

	return init
end

function sz_nodepos:is_empty()
	local node = self.node
	return node == nil or node.name == "air"
end

local solid_drawtypes = {
	normal = true,
	glasslike = true,
	glasslike_framed = true,
	allfaces = true,
	allfaces_optional = true,
}
function sz_nodepos:is_solid()
	local def = self.def
	return def ~= nil
		and def.walkable
		and not def.climbable
		and solid_drawtypes[def.drawtype]
		and def.liquidtype == "none"
end

function sz_nodepos:groups()
	local def = self.def or { }
	return def.groups or { }
end
