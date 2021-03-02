-- LUALOCALS < ---------------------------------------------------------
local ipairs, loadstring, math, minetest, pairs, string, tonumber
    = ipairs, loadstring, math, minetest, pairs, string, tonumber
local math_ceil, math_floor, string_format, string_rep, string_sub
    = math.ceil, math.floor, string.format, string.rep, string.sub
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

------------------------------------------------------------------------
-- SETTINGS

local function getconf(suff)
	return tonumber(minetest.settings:get(modname .. "_" .. suff))
end

-- How often to publish updates to players. Too infrequent and the meter
-- is no longer as "real-time", but too frequent and they'll get
-- bombarded with HUD change packets.
local interval = getconf("interval") or 2

-- The amount of time in each measurement period. This is also the
-- amount of time between each period expiration.
local period_length = getconf("period_length") or 2

-- The number of time periods across which to accumualate statistics.
local period_count = getconf("period_count") or 30

-- Size of buckets into which dtime values are sorted in weighted
-- histogram.
local bucket_step = getconf("bucket_step") or 0.05

-- Maximum number of buckets. All step times too large for any other
-- bucket will go into the highest bucket.
local bucket_max = getconf("bucket_max") or 20

-- Maximum number of characters to use for ascii bar graph
local graphbar_width = getconf("graphbar_width") or 40

-- Constructor function to pre-initialize a new period table.
local newperiod = loadstring("return {" .. string_rep("0,", bucket_max) .. "}")

------------------------------------------------------------------------
-- MEASUREMENT

-- Queue of accounting periods.
local periods = {}

-- Precise game runtime clock.
local clock = 0

-- Collect statistics at each step.
minetest.register_globalstep(function(dtime)
		-- Update clock.
		clock = clock + dtime

		-- Find current accounting period, initialize
		-- if not already present.
		local key = math_floor(clock / period_length)
		local cur = periods[key]
		if not cur then
			cur = newperiod()
			periods[key] = cur
		end

		-- Find correct histogram bucket.
		local bucket = math_floor(dtime / bucket_step)
		if bucket > bucket_max then bucket = bucket_max
		elseif bucket < 1 then bucket = 1 end

		-- Add weight to bucket.
		cur[bucket] = cur[bucket] + dtime
	end)

------------------------------------------------------------------------
-- USER TOGGLE

-- Create a separate privilege for players to see the lagometer. This
-- feature is too "internal" to show to all players unconditionally,
-- but not so "internal" that it should depend on the "server" priv.
minetest.register_privilege("lagometer", "Can see the lagometer")

-- Command to manually toggle the lagometer.
minetest.register_chatcommand("lagometer", {
		description = "Toggle the lagometer",
		privs = {lagometer = true},
		func = function(name)
			local player = minetest.get_player_by_name(name)
			if not player then return end
			local old = player:get_meta():get_string("lagometer") or ""
			local v = (old == "") and "1" or ""
			player:get_meta():set_string("lagometer", v)
			minetest.chat_send_player(name, "Lagometer: "
				.. (v ~= "" and "ON" or "OFF"))
		end,
	})

------------------------------------------------------------------------
-- REPORTING

-- Keep track of connected players and their meters.
local meters = {}

-- Pre-allocated bar graph.
local graphbar = string_rep("|", graphbar_width)

-- Function to publish current lag values to all receiving parties.
local function publish()
	-- Expire old periods, and accumulate current ones.
	local accum = newperiod()
	do
		local curkey = math_floor(clock / period_length)
		for pk, pv in pairs(periods) do
			if pk <= curkey - period_count then
				periods[pk] = nil
			else
				for ik, iv in ipairs(pv) do
					accum[ik] = accum[ik] + iv
				end
			end
		end
	end

	-- Construct the weighted historgram visualization.
	for bucket = 1, bucket_max do
		local qty = accum[bucket]

		local line = qty <= 0 and "" or string_format(" % 2.2f % s % 2.2f % s", qty,
			-- Maximum width of a graph bar corresponds to 50% of the total
			-- time in the window, so that there will never be 2 bars of the
			-- same length that don't have the same amount of time, even if
			-- there is one bar that's longer than all others and is cut off.
			string_sub(graphbar, 1, math_ceil(qty * 2 * graphbar_width
					/ period_length / period_count)),
			bucket * bucket_step,
			string_rep("\n", bucket - 1))

		-- Apply the appropriate text to each meter.
		for _, player in ipairs(minetest.get_connected_players()) do
			local pname = player:get_player_name()
			local meter = meters[pname]
			if not meter then
				meter = {}
				meters[pname] = meter
			end
			local mline = meter[bucket]

			-- Players with privilege will see the meter, players without
			-- will get an empty string. The meters are always left in place
			-- rather than added/removed for simplicity, and to make it easier
			-- to handle when the priv is granted/revoked while the player
			-- is connected.
			local text = ""
			if minetest.get_player_privs(pname).lagometer
			and (player:get_meta():get_string("lagometer") or "") ~= ""
			then text = line end

			-- Only apply the text if it's changed, to minimize the risk of
			-- generating useless unnecessary packets.
			if text ~= "" and not mline then
				meter[bucket] = {
					text = text,
					hud = player:hud_add({
							hud_elem_type = "text",
							position = {x = 1, y = 1},
							text = text,
							alignment = {x = -1, y = -1},
							number = 0xC0C0C0,
							offset = {x = -4, y = -4}
						})
				}
			elseif mline and text == "" then
				player:hud_remove(mline.hud)
				meter[bucket] = nil
			elseif mline and mline.text ~= text then
				player:hud_change(mline.hud, "text", text)
				mline.text = text
			end
		end
	end
end

-- Run the publish method on a timer, so that player displays
-- are updated while lag is falling off.
local function update()
	publish()
	minetest.after(interval, update)
end
minetest.after(0, update)

-- Remove meter registrations when players leave.
minetest.register_on_leaveplayer(function(player)
		meters[player:get_player_name()] = nil
	end)
