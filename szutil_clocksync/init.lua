-- LUALOCALS < ---------------------------------------------------------
local math, minetest, os, tonumber
    = math, minetest, os, tonumber
local math_floor, math_random, os_date
    = math.floor, math.random, os.date
-- LUALOCALS > ---------------------------------------------------------

local basespeed = tonumber(minetest.settings:get("time_speed_base")) or 72

local dt, mt, rt, diff, ts
local expire = 0

local function adjdrift()
	dt = os_date("!*t")
	while dt.min > 20 do dt.min = dt.min - 20 end
	rt = (dt.min + dt.sec / 60) / 20 + 0.25
	if rt > 1 then rt = rt - 1 end

	mt = minetest.get_timeofday()

	diff = rt - mt
	if diff < 0 then diff = diff + 1 end
	if diff > 0.5 then diff = diff - 1 end

	ts = basespeed * (1 + diff)
	return minetest.settings:set("time_speed", ts)
end

minetest.register_globalstep(function()
		local now = minetest.get_us_time() / 1000000
		if now > expire then
			expire = now + 10 + math_random() * 10
			return adjdrift()
		end
	end)

local function fmt(k, v)
	v = math_floor(v * 10000) / 10000
	return "; " .. k .. " = " .. v
end
local function fmtt(k, v)
	return fmt(k, math_floor(v * 24000))
end

minetest.register_chatcommand("clocksync", {
		description = "Get clock sync stats",
		privs = {server = true},
		func = function(name)
			local now = minetest.get_us_time() / 1000000
			return minetest.chat_send_player(name,
				"clock sync stats"
				.. fmtt("mt", mt)
				.. fmtt("rt", rt)
				.. fmtt("diff", diff)
				.. fmt("ts", ts)
				.. fmt("next", expire - now))
		end
	})
