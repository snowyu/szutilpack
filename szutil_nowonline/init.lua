-- LUALOCALS < ---------------------------------------------------------
local math, minetest, pairs, table, tonumber, tostring
    = math, minetest, pairs, table, tonumber, tostring
local math_random, table_concat, table_remove, table_sort
    = math.random, table.concat, table.remove, table.sort
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

local timedelay = tonumber(minetest.settings:get(modname .. "_time")) or 300
local linedelay = tonumber(minetest.settings:get(modname .. "_lines")) or 25
local maxnames = tonumber(minetest.settings:get(modname .. "_names")) or 50

local lines = 0
local exp = 0

local function delaymsg(msg)
	return minetest.after(0, function()
			return minetest.chat_send_all(msg)
		end)
end

local function sendall(isann)
	lines = lines + 1
	if not isann then return end

	local now = minetest.get_us_time() / 1000000
	if (lines < linedelay) and (now < exp) then return end
	exp = now + timedelay
	lines = 0

	local names = {}
	for _, player in pairs(minetest.get_connected_players()) do
		if not minetest.check_player_privs(player, "stealth") then
			names[#names + 1] = player:get_player_name()
		end
	end
	table_sort(names)

	local more = 0
	while #names > maxnames do
		table_remove(names, math_random(1, #names))
		more = more + 1
	end
	if more > 0 then
		names[#names + 1] = "(" .. more .. " more)"
	end

	if #names > 0 then
		delaymsg("*** Online: " .. table_concat(names, ", "))
	else
		delaymsg("*** Server is empty.")
	end
end

do
	local old_sendall = minetest.chat_send_all
	function minetest.chat_send_all(text, ...)
		sendall(tostring(text):match("^%s*%*%*%*%s"))
		return old_sendall(text, ...)
	end
end

minetest.register_on_chat_message(function(pname, text)
		if text:sub(1, 1) ~= "/"
		and minetest.check_player_privs(pname, "shout") then
			sendall()
		end
	end)
