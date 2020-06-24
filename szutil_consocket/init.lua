-- LUALOCALS < ---------------------------------------------------------
local assert, error, ipairs, minetest, os, pairs, pcall, string,
      tostring
    = assert, error, ipairs, minetest, os, pairs, pcall, string,
      tostring
local os_remove, string_gsub, string_lower, string_match
    = os.remove, string.gsub, string.lower, string.match
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

------------------------------------------------------------------------
-- VIRTUAL PLAYER SETUP

-- Name for the virtual "player" used for the console.
local CONSOLE = "CONSOLE"

-- Override privileges for the "console player", granting
-- them every privilege, including "cheats". We assume that
-- there are no "anti-privileges" registered that would
-- actually limit access.
do
	local old_checkprivs = minetest.get_player_privs
	function minetest.get_player_privs(who, ...)
		if who == CONSOLE then
			local p = {}
			for k in pairs(minetest.registered_privileges) do
				if k ~= "shout" then p[k] = true end
			end
			return p
		else
			return old_checkprivs(who, ...)
		end
	end
end

-- Disallow any player from actually connecting with the
-- "console" player name, which would grant them the corresponding
-- special privileges.
minetest.register_on_prejoinplayer(function(name)
		if string_lower(name) == string_lower(CONSOLE) then
			return "Player name " .. CONSOLE .. " is reserved."
		end
	end)

-- Hook to send messages to a client socket for immediate
-- command responses.
local conmsg

-- Lua pattern string to strip color codes from chat text.
local stripcolor = minetest.get_color_escape_sequence('#ffffff')
stripcolor = string_gsub(stripcolor, "%W", "%%%1")
stripcolor = string_gsub(stripcolor, "ffffff", "%%x+")

-- Intercept messages sent to the "console" player and send them
-- to the actual console instead.
do
	local old_chatsend = minetest.chat_send_player
	function minetest.chat_send_player(who, text, ...)
		if who == CONSOLE then
			text = string_gsub(text, stripcolor, "")
			if conmsg then conmsg(text) end
			return print("to " .. CONSOLE .. ": " .. text)
		else
			return old_chatsend(who, text, ...)
		end
	end
end

-- Intercept broadcast messages and send them to the console
-- user, if in response to a command.
do
	local old_sendall = minetest.chat_send_all
	function minetest.chat_send_all(text, ...)
		if conmsg then conmsg(string_gsub(text, stripcolor, "")) end
		return old_sendall(text, ...)
	end
end

------------------------------------------------------------------------
-- CONSOLE CLIENT SOCKETS

-- Keep track of multiple connected clients.
local clients = {}

-- Create a listening unix-domain socket inside the world dir.
-- All sockets and connections will be non-blocking, by setting
-- timeout to zero, so we don't block the game engine.
local master
do
	local ie = minetest.request_insecure_environment()
	if not ie then return error(modname .. " must be listed in secure.trusted_mods") end
	pcall(function()
			local cp = ie.io.popen("lua5.1 -e 'print(package.cpath)'")
			or ie.io.popen("lua51 -e 'print(package.cpath)'")
			or ie.io.popen("lua -e 'print(package.cpath)'")
			or ie.io.popen("luajit -e 'print(package.cpath)'")
			or error("failed to execute lua")
			ie.package.cpath = cp:read("*all")
		end)
	master = assert(ie.require("socket.unix")())
	assert(master:settimeout(0))
	local sockpath = minetest.get_worldpath() .. "/" .. modname .. ".sock"
	os_remove(sockpath)
	assert(master:bind(sockpath))
	assert(master:listen())
end

-- Helper function to log console debugging information.
local function clientlog(client, str)
	print(modname .. "[" .. client.id .. "]: " .. str)
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
		c.sock:send("connected as " .. id .. "\n> ")
	elseif err ~= "timeout" then
		print(CONSOLE .. " accept(): " .. err)
	end
end

-- Execute actual console commands.
local function concmd(client, line)
	-- Special "exit" command to disconnect, e.g. when
	-- unable to send an EOF or interrupt.
	if line == "/exit" then
		clients[client.id] = nil
		return client.sock:close()
	end

	-- Try to run registered chat commands, and return a
	-- failure if not found.
	for _, v in ipairs(minetest.registered_on_chat_messages) do
		local ok, err = pcall(function() return v(CONSOLE, line) end)
		if ok and err then return end
		if not ok then
			return minetest.chat_send_player(CONSOLE, err)
		end
	end
	minetest.chat_send_player(CONSOLE, "unrecognized command")
end

-- Attempt to receive an input line from the console client, if
-- one is ready (buffered non-blocking IO)
local function receive(client)
	local line, err = client.sock:receive("*l")
	if line ~= nil then
		-- Prepend the slash. We assume that all input is to
		-- be commands rather than accidentally leaking chat.
		while line:sub(1, 1) == "/" do
			line = line:sub(2)
		end
		line = "/" .. line
		clientlog(client, "command: " .. line)

		-- Hook console messages and send to client, too.
		conmsg = function(x)
			client.sock:send(x .. "\n")
		end
		local ok, err2 = pcall(function() concmd(client, line) end)
		conmsg = nil
		if not ok then return error(err2) end
		client.sock:send("> ")
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
