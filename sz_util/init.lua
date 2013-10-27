sz = {
	pos_alldirs = {
		e = { x = 1, y = 0, z = 0 },
		w = { x = -1, y = 0, z = 0 },
		u = { x = 0, y = 1, z = 0 },
		d = { x = 0, y = -1, z = 0 },
		n = { x = 0, y = 0, z = 1 },
		s = { x = 0, y = 0, z = -1 },
	},
	pos_zero = { x = 0, y = 0, z = 0 },
	pos = function(x, y, z)
		return { x = x, y = y, z = z }
	end,
	pos_eq = function(a, b)
		return a.x == b.x
			and a.y == b.y
			and a.z == b.z
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
	end,

	tbl_shuffle = function(t)
		for i = 1, #t, 1 do
			local j = math.random(1, #t)
			t[i], t[j] = t[j], t[i]
		end
	end,
}
