-- This is a library for working with facedirs, which are orthogonal
-- 3d rotation states with 24 possible values.

------------------------------------------------------------------------
-- CONSTRUCTORS AND STATIC PROPERTIES

-- Axis ("top" vector) information for each group of 4 facedir values.
local facedir_axis = { [0] = "u", "n", "s", "e", "w", "d" }
for k, v in pairs(facedir_axis) do
	facedir_axis[k] = sz_pos.dirs[v]
end

-- Create a new sz_facedir from a param2 value.
function sz_facedir:from_param(param)
	return sz_facedir:new({ param = param })
end

-- Create a new sz_facedir from the "back" (required) and "top"
-- (optional) direction vectors.
function sz_facedir:from_vectors(back, top)
	local min = 0
	local max = 23
	if top then
		for k, v in pairs(facedir_axis) do
			if v:eq(top) then
				min = k * 4
				max = k * 4 + 3
			end
		end
	end
	back = sz_pos:new(back)
	for i = min, max do
		if back:eq(minetest.facedir_to_dir(i)) then
			return sz_facedir:from_param(i)
		end
	end
end

------------------------------------------------------------------------
-- DIRECTIONS

function sz_facedir:back()
	return sz_pos:new(minetest.facedir_to_dir(self.param))
end

function sz_facedir:front()
	return self:back():neg()
end

function sz_facedir:top()
	return facedir_axis[math.floor(self.param / 4)]
end

function sz_facedir:bottom()
	return self:top():neg()
end

function sz_facedir:right()
	return self:top():cross(self:back())
end

function sz_facedir:left()
	return self:right():neg()
end

------------------------------------------------------------------------
-- ROTATION

-- Rotate 90 degrees around the given rotational axis (right-hand rule).
function sz_facedir:rotate(axis)
	axis = sz_pos:new(axis)
	local top = self:top()
	if top:dot(axis) == 0 then
		top = axis:cross(top)
	end
	local back = self:back()
	if back:dot(axis) == 0 then
		back = axis:cross(back)
	end
	return sz_facedir:from_vectors(back, top)
end

------------------------------------------------------------------------
return sz_facedir
