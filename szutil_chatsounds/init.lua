-- LUALOCALS < ---------------------------------------------------------
local ipairs, minetest, pairs, table, tonumber, tostring
    = ipairs, minetest, pairs, table, tonumber, tostring
local table_concat
    = table.concat
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

local function parsespec(param)
	local config = {}
	for _, s in ipairs(param:split(" ")) do
		local n = tonumber(s)
		if n then
			config[#config + 1] = {gain = n}
		else
			local gain, pitch = s:match("^(%S+):(%S+)$")
			gain = tonumber(gain)
			pitch = tonumber(pitch)
			if gain and pitch then
				config[#config + 1] = {gain = gain, pitch = pitch}
			else
				return false, "failed to parse spec"
			end
		end
	end
	return config
end

local default = parsespec(minetest.settings:get(modname)
	or "0.5:1.2 0.25 0.25 0.25:0.8 0")

local function dosound(player, pname, msgtype)
	local config = player:get_meta():get_string(modname) or ""
	config = config ~= "" and minetest.deserialize(config) or nil
	config = config and #config > 0 and config or default

	local data = (msgtype > #config) and config[#config] or config[msgtype]
	if (data.gain or 0) <= 0 then return end

	minetest.sound_play(modname, {
			to_player = pname,
			pitchvary = 0,
			gain = data.gain,
			pitch = data.pitch or 1
		})
end

minetest.register_chatcommand(modname, {
		description = "change chat sound configuration",
		params = "default or <gain[:pitch] for DM> [... for chat] [...emote]"
		.. " [...join/part] [...server] [...other]",
		func = function(pname, param)
			local player = minetest.get_player_by_name(pname)
			if not player then return false, "player not connected" end

			if param == "" then
				local config = player:get_meta():get_string(modname) or ""
				config = config ~= "" and minetest.deserialize(config) or nil
				config = config and #config > 0 and config or default
				local t = {}
				for _, e in ipairs(config) do
					if e.pitch then
						t[#t + 1] = e.gain .. ":" .. e.pitch
					else
						t[#t + 1] = e.gain
					end
				end
				return true, "current config: " .. table_concat(t)
			end

			if param == "default" then
				player:get_meta():set_string(modname, "")
				return false, "reset to default"
			end

			local config = parsespec(param)
			if #config < 1 then return false, "empty config" end

			player:get_meta():set_string(modname, minetest.serialize(config))
			return true, "config changed"
		end
	})

local pending = {}

minetest.register_globalstep(function()
		for _, player in pairs(minetest.get_connected_players()) do
			local pname = player:get_player_name()
			local msgtype = pending[pname]
			if msgtype then dosound(player, pname, msgtype) end
		end
		pending = {}
	end)

local function send(pname, text)
	text = tostring(text)

	local msgtype
	if text:match("^%s*DM%sfrom%s") then msgtype = 1 -- DM
	elseif text:match("^%s*%<") then msgtype = 2 -- public chat
	elseif text:match("^%s*%*%s") then msgtype = 3 -- emotes
	elseif text:match("^%s*%*%*%*%s") then msgtype = 4 -- join/part
	elseif text:match("^%s*%#%s") then msgtype = 5 -- server
	else msgtype = 6 end -- unknown/misc

	local n = pending[pname] or msgtype
	pending[pname] = msgtype > n and n or msgtype
end

local function sendall(text)
	for _, player in pairs(minetest.get_connected_players()) do
		send(player:get_player_name(), text)
	end
end

do
	local old_sendall = minetest.chat_send_all
	function minetest.chat_send_all(text, ...)
		sendall(text)
		return old_sendall(text, ...)
	end
end

minetest.register_on_chat_message(function(pname, text)
		if text:sub(1, 1) ~= "/"
		and minetest.check_player_privs(pname, "shout") then
			sendall("<" .. pname .. "> " .. text)
		end
	end)

do
	local old_sendp = minetest.chat_send_player
	function minetest.chat_send_player(pname, text, ...)
		send(pname, text)
		return old_sendp(pname, text, ...)
	end
end
