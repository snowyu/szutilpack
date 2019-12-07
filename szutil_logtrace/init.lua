-- LUALOCALS < ---------------------------------------------------------
local ipairs, minetest, pairs, rawset, table, type
    = ipairs, minetest, pairs, rawset, table, type
local table_concat
    = table.concat
-- LUALOCALS > ---------------------------------------------------------

minetest.register_privilege("logtrace", "Receive server log messages")

minetest.register_chatcommand("logtrace", {
		description = "Toggle debug trace messages",
		privs = {logtrace = true},
		func = function(name)
			local player = minetest.get_player_by_name(name)
			if not player then return end
			local old = player:get_meta():get_string("logtrace") or ""
			local v = (old == "") and "1" or ""
			player:get_meta():set_string("logtrace", v)
			minetest.chat_send_player(name, "Log Trace: "
				.. (v ~= "" and "ON" or "OFF"))
		end,
	})

local function logtrace(...)
	local t = {"#", ...}
	for i, v in ipairs(t) do
		if type(v) == "table" then
			t[i] = minetest.serialize(v):sub(("return "):length())
		end
	end
	local msg = table_concat(t, " ")
	for _, p in pairs(minetest.get_connected_players()) do
		local n = p:get_player_name()
		if minetest.get_player_privs(n).logtrace then
			local a = p:get_meta():get_string("logtrace")
			if a and a ~= "" then
				minetest.chat_send_player(n, msg)
			end
		end
	end
end

local function tracify(func)
	return function(...)
		logtrace(...)
		return func(...)
	end
end
rawset(_G, "print", tracify(print))
minetest.log = tracify(minetest.log)
