minetest.register_chatcommand("regstats", {
	description = "Statistics about total registered things.",
	func = function(name)
		local regpref = "registered_"
		local regkeys = sz_table:new()
		for k, v in pairs(core) do
			if k:startswith(regpref) then
				regkeys:insert(k:sub(regpref:len() + 1))
			end
		end
		regkeys:sort()
		local regrpt = sz_table:new()
		for i, k in ipairs(regkeys) do
			local qty = 0
			for ik, iv in pairs(core[regpref .. k]) do
				qty = qty + 1
			end
			if qty > 0 then regrpt:insert(k .. " " .. qty) end
		end
		minetest.chat_send_player(name, "registration count: " .. regrpt:concat(", "))
	end
})


minetest.register_chatcommand("regnodes", {
	description = "Statistics about total registered nodes, by mod.",
	func = function(name)
		local rn = sz_table:new({ TOTAL = 0 })
		for k, v in pairs(minetest.registered_nodes) do
			local mod = k
			local idx = k:find(":", 1, true)
			if idx then mod = mod:sub(1, idx) .. "*" end
			rn[mod] = (rn[mod] or 0) + 1
			rn.TOTAL = rn.TOTAL + 1
		end
		local keys = rn:keys()
		keys:sort(function(a, b)
			if rn[a] == rn[b] then return a < b end
			return rn[a] > rn[b]
		end)
		local noderpt = sz_table:new()
		for i, v in ipairs(keys) do
			noderpt:insert(rn[v] .. " " .. v)
		end
		minetest.chat_send_player(name, "registered node count: " .. noderpt:concat(", "))
	end
})
