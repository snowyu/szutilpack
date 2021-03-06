-- LUALOCALS < ---------------------------------------------------------
local assert, minetest, os, pairs, require, string, tostring
    = assert, minetest, os, pairs, require, string, tostring
local os_remove, string_gsub, string_match
    = os.remove, string.gsub, string.match
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

-- Keep track of multiple connected clients.
local clients = {}

-- Lua pattern string to strip color codes from chat text.
local stripcolor = minetest.get_color_escape_sequence('#ffffff')
stripcolor = string_gsub(stripcolor, "%W", "%%%1")
stripcolor = string_gsub(stripcolor, "ffffff", "%%x+")

-- Intercept broadcast messages and send them all clients.
do
	local old_sendall = minetest.chat_send_all
	function minetest.chat_send_all(text, ...)
		local t = string_gsub(text, stripcolor, "")
		for _, v in pairs(clients) do
			if v.sent ~= t then
				v.sock:send(t .. "\n")
			else
				v.sent = nil
			end
		end
		return old_sendall(text, ...)
	end
end

-- Intercept non-command chat messages and send them to all clients.
minetest.register_on_chat_message(function(name, text)
		if text:sub(1, 1) ~= "/"
		and minetest.check_player_privs(name, "shout") then
			local t = string_gsub(text, stripcolor, "")
			for _, v in pairs(clients) do
				v.sock:send("<" .. name .. "> " .. t .. "\n")
			end
		end
	end)

-- Create a listening unix-domain socket inside the world dir.
-- All sockets and connections will be non-blocking, by setting
-- timeout to zero, so we don't block the game engine.
local master = assert(require("socket.unix")())
assert(master:settimeout(0))
local sockpath = minetest.get_worldpath() .. "/" .. modname .. ".sock"
os_remove(sockpath)
assert(master:bind(sockpath))
assert(master:listen())

-- Helper function to log console debugging information.
local function clientlog(client, str)
	minetest.log("action", modname .. "[" .. client.id .. "]: " .. str)
end

-- Attempt to accept a new client connection.
local function accept()
	local sock, err = master:accept()
	if sock then
		-- Make the new client non-blocking too.
		assert(sock:settimeout(0))

		-- Try to determine an identifier for the connection.
		local id = string_match(tostring(sock), "0x%x+")
		or tostring(sock)

		-- Register new connection.
		local c = {id = id, sock = sock}
		clients[id] = c

		clientlog(c, "connected")
	elseif err ~= "timeout" then
		minetest.log("warning", modname .. " accept(): " .. err)
	end
end

-- Attempt to receive an input line from the console client, if
-- one is ready (buffered non-blocking IO)
local function receive(client)
	local line, err = client.sock:receive("*l")
	if line ~= nil then
		clientlog(client, "message: " .. line)
		client.sent = line
		minetest.chat_send_all(line)
	elseif err ~= "timeout" then
		clientlog(client, err)
		clients[client.id] = nil
	end
end

-- On every server cycle, check for new connections, and
-- process commands from existing ones.
minetest.register_globalstep(function()
		accept()
		for _, client in pairs(clients) do receive(client) end
	end)
