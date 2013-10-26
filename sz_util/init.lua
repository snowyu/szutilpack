sz = {
	facedir_to_dir = { },
	pos_zero = { x = 0, y = 0, z = 0 },
	pos = function(x, y, z)
		return { x = x, y = y, z = z }
	end,
	pos_add = function(a, b)
		return {
			x = a.x + b.x,
			y = a.y + b.y,
			z = a.z + b.z
		}
	end,
	pos_inv = function(a)
		return {
			x = -a.x,
			y = -a.y,
			z = -a.z
		}
	end,
	pos_sub = function(a, b)
		return {
			x = a.x - b.x,
			y = a.y - b.y,
			z = a.z - b.z
		}
	end,
	pos_scale = function(a, s)
		return {
			x = a.x * s,
			y = a.y * s,
			z = a.z * s
		}
	end,
	pos_dot = function(a, b)
		return a.x * b.x
			+ a.y * b.y
			+ a.z * b.z
	end,
	pos_cross = function(a, b)
		return {
			x = a.y * b.z - a.z * b.y,
			y = a.z * b.x - a.x * b.z,
			z = a.x * b.y - a.y * b.x
		}
	end,
	pos_abs = function(a)
		return math.sqrt(pos_dot(a, a))
	end,
	pos_norm = function(a)
		return pos_scale(a, 1 / pos_abs(a))
	end
}

for k, v in pairs({
	{ x = 1, y = 0, z = 0 },
	{ x = -1, y = 0, z = 0 },
	{ x = 0, y = 1, z = 0 },
	{ x = 0, y = -1, z = 0 },
	{ x = 0, y = 0, z = 1 },
	{ x = 0, y = 0, z = -1 },
	}) do
	sz.facedir_to_dir[minetest.dir_to_facedir(v)] = v
end
