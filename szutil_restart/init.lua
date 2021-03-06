-- LUALOCALS < ---------------------------------------------------------
local io, ipairs, math, minetest, pairs, string, tonumber
    = io, ipairs, math, minetest, pairs, string, tonumber
local io_open, math_floor, string_format
    = io.open, math.floor, string.format
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

------------------------------------------------------------------------
-- Global configuration

local function conf(n)
	return minetest.settings:get(modname .. "_" .. n)
end

-- Default restart grace time.
local grace = tonumber(conf("grace")) or 300

-- Amount of time before a restart that the countdown will be
-- announced/displayed.
local countdown = conf("countdown") or grace

-- Amount of time during which the countdown will flash.
local critical = conf("countdown") or 10

-- Primary color of the countdown HUD.
local hudcolor = conf("hudcolor") or 0xFFFF00

-- Flashing color of HUD during critical countdown.
local hudcolorflash = conf("hudcolor") or 0xFF0000

-- Don't restart the server too often; give players at least this
-- much time after a restart, if any are on.
local minuptime = tonumber(conf("minuptime")) or 7200

-- Always restart after the server has been up this long.
local maxuptime = tonumber(conf("maxuptime")) or 86400

-- Restart shutdown message.
local shtudownmsg = string_format("\n\n%s\n%s",
	conf("shutdownmsg1") or "SERVER RESTARTING FOR UPDATES",
	conf("shutdownmsg2") or "nPlease reconnect in about 10 seconds")

-- Message when players are kicked off for restart
local kickmsg = conf("kickmsg") or "*** Kicking players off for restart"

-- Message used to announce pending restart in chat.
local chatmsg = conf("chatmsg") or "*** Server restart in %s"

-- Message used to display pending restart in HUD.
local hudmsg = conf("hudmsg") or "RESTART IN %s"

------------------------------------------------------------------------
-- Global time functions

-- Function to get current uptime of server.
local uptime
do
	local starttime = minetest.get_us_time()
	uptime = function()
		return (minetest.get_us_time() - starttime) / 1000000
	end
end

-- If restart requested, this is the uptime value at which the
-- restart should happen, nil if none pending.
local req

-- Get number of seconds until restart, if any.
local function remain()
	return req and req - uptime()
end

-- Get formatted restart time, if any
local function remaintext()
	if not req then return end
	local cdown = math_floor(remain())
	local min = cdown / 60
	local sec = cdown % 60
	if min < 60 then return string_format("%d:%02d", min, sec) end
	local hr = min / 60
	min = min % 60
	return string_format("%d:%02d:%02d", hr, min, sec)
end

------------------------------------------------------------------------
-- Trigger conditions

do
	local function restarttrigger(reason, time)
		minetest.log("RESTART REQUEST (" .. reason .. ")")
		req = uptime() + (time or grace)
		if time then return end
		if req < minuptime then req = minuptime
		elseif req > maxuptime then req = maxuptime end
	end

	-- Server admins can manually request a restart, including with a
	-- custom grace time. Restarts cannot be canceled entirely (nor
	-- should they be, probably), but can be delayed indefinitely.
	minetest.register_chatcommand("trigger_restart", {
			description = "Signal a restart request manually, or reset countdown",
			privs = {server = true},
			func = function(name, param)
				restarttrigger("manual by " .. name, tonumber(param))
			end
		})

	-- Automatically detect a restart condition.
	local function restartcheck()
		if req then return end

		-- Trigger restart if the server has reached its maximum uptime.
		if uptime() >= maxuptime then
			return restarttrigger("max uptime")
		end

		-- Trigger a restart if a file exists in the world dir to allow
		-- an external script to request it.
		local f = io_open(minetest.get_worldpath() .. "/restart")
		if f then
			f:close()
			return restarttrigger("file trigger")
		end

		return minetest.after(2, restartcheck)
	end
	restartcheck()
end

------------------------------------------------------------------------
-- Handle actual restart event

do
	local shuttingdown
	minetest.register_globalstep(function()
			if shuttingdown or not req then return end
			local pcount = #minetest.get_connected_players()
			if pcount > 0 and remain() > 0 then return end
			shuttingdown = true
			if #minetest.get_connected_players() > 0 then
				minetest.chat_send_all(kickmsg)
			end
			return minetest.request_shutdown(shtudownmsg, true)
		end)
end

------------------------------------------------------------------------
-- Announce pending restarts in chat streams

do
	local announced
	local lastsent
	minetest.register_globalstep(function()
			-- Skip if no countdown yet.
			if not req then return end

			-- Never announce if no players online.
			if #minetest.get_connected_players() < 1 then return end

			-- Announce if the remaining time has changed, or
			-- we've crossed to/from the active countdown phase.
			if announced ~= req or (lastsent > countdown) ~= (remain() > countdown) then
				announced = req
				lastsent = remain()
				minetest.chat_send_all(string_format(chatmsg, remaintext()))
			end
		end)
end

------------------------------------------------------------------------
-- Announce pending restarts via HUD

do
	local huds = {}
	minetest.register_on_leaveplayer(function(player)
			huds[player:get_player_name()] = nil
		end)
	minetest.register_globalstep(function()
			if #minetest.get_connected_players() < 1 then return end

			if (not req) or (remain() > countdown) then
				for pname, hud in pairs(huds) do
					local player = minetest.get_player_by_name(pname)
					if player then player:hud_remove(hud.id) end
					huds[pname] = nil
				end
				return
			end

			local number = (remain() < critical and (remain() - math_floor(remain()) < 0.5))
			and hudcolorflash or hudcolor
			local text = string_format(hudmsg, remaintext())

			for _, player in ipairs(minetest.get_connected_players()) do
				local pname = player:get_player_name()
				local hud = huds[pname]
				if hud then
					if hud.number ~= number then
						player:hud_change(hud.id, "number", number)
						hud.number = number
					end
					if hud.text ~= text then
						player:hud_change(hud.id, "text", text)
						hud.text = text
					end
				else
					huds[pname] = {
						number = number,
						text = text,
						id = player:hud_add({
								label = "restart_warn",
								hud_elem_type = "text",
								position = {x = 0.5, y = 0.8},
								text = text,
								number = number,
								alignment = {x = 0, y = 1},
								offset = {x = 0, y = 0}
							})
					}
				end
			end
		end)
end
