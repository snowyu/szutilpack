sz_tbl = {
	shuffle = function(t)
		for i = 1, #t, 1 do
			local j = math.random(1, #t)
			t[i], t[j] = t[j], t[i]
		end
	end,
}
