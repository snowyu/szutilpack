sz_pos = {
	alldirs = {
		e = { x = 1, y = 0, z = 0 },
		w = { x = -1, y = 0, z = 0 },
		u = { x = 0, y = 1, z = 0 },
		d = { x = 0, y = -1, z = 0 },
		n = { x = 0, y = 0, z = 1 },
		s = { x = 0, y = 0, z = -1 },
	},
	zero = { x = 0, y = 0, z = 0 },
	new = function(x, y, z)
		return { x = x, y = y, z = z }
	end,
	eq = function(a, b)
		return a.x == b.x
			and a.y == b.y
			and a.z == b.z
	end,
	add = function(a, b)
		return {
			x = a.x + b.x,
			y = a.y + b.y,
			z = a.z + b.z
		}
	end,
	inv = function(a)
		return {
			x = -a.x,
			y = -a.y,
			z = -a.z
		}
	end,
	sub = function(a, b)
		return {
			x = a.x - b.x,
			y = a.y - b.y,
			z = a.z - b.z
		}
	end,
	scale = function(a, s)
		return {
			x = a.x * s,
			y = a.y * s,
			z = a.z * s
		}
	end,
	dot = function(a, b)
		return a.x * b.x
			+ a.y * b.y
			+ a.z * b.z
	end,
	cross = function(a, b)
		return {
			x = a.y * b.z - a.z * b.y,
			y = a.z * b.x - a.x * b.z,
			z = a.x * b.y - a.y * b.x
		}
	end,
	abs = function(a)
		return math.sqrt(dot(a, a))
	end,
	norm = function(a)
		return scale(a, 1 / abs(a))
	end,
}
