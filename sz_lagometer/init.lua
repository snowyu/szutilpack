local modname = minetest.get_current_modname()

-- How often to publish updates to players.  Too infrequent and the meter
-- is no longer as "real-time", but too frequent and they'll get bombarded
-- with HUD change packets.
local interval = tonumber(minetest.setting_get(modname .. "_interval")) or 2

-- The "fall-off ratio" to multiply the previous lag values by each tick.
-- Lag spikes will set the lag estimate high, and multiplying by this fall-off
-- ratio is the only way it will fall back down.
local falloff = tonumber(minetest.setting_get(modname .. "_falloff")) or 0.99

-- Keep track of our estimate of server lag.
local lag = 0

-- Keep track of connected players and their meters.
local meters = {}

-- Create a separate privilege for players to see the lagometer.  This
-- feature is too "internal" to show to all players unconditionally,
-- but not so "internal" that it should depend on the "server" priv.
core.register_privilege("lagometer", "Can see the lagometer")

-- Function to publish current lag values to all receiving parties.
local function publish()
	-- Format the lag string with the raw numerical value, and
	-- a cheapo ASCII "bar graph" to provide a better visual cue
	-- for its general magnitude.
	local t = string.format("Server Lag: %2.2f ", lag)
	local q = lag * 10 + 0.5
	if q > 40 then q = 40 end
	for i = 1, q, 1 do t = t .. "|" end

	-- Apply the appropriate text to each meter.
	for k, v in pairs(meters) do
		-- Players with privilege will see the meter, players without
		-- will get an empty string.  The meters are always left in place
		-- rather than added/removed for simplicity, and to make it easier
		-- to handle when the priv is granted/revoked while the player
		-- is connected.
		local s = ""
		if minetest.get_player_privs(k).lagometer then s = t end

		-- Only apply the text if it's changed, to minimize the risk of
		-- generating useless unnecessary packets.
		if v.text ~= s then
			v.player:hud_change(v.hud, "text", s)
			v.text = s
		end
	end
end

-- Run the publish method on a timer, so that player displays
-- are updated while lag is falling off.
local function update()
	publish()
	minetest.after(interval, update)
end
update()

-- Do the lag estimate work in a globalstep.  If the lag spikes
-- up, publish immediately; if not, allow the timer to publish as
-- it falls off.
minetest.register_globalstep(function(dtime)
	lag = lag * falloff
	if dtime > lag then
		lag = dtime
		publish()
	end
end)

-- When players join, create and register their HUD.  These
-- are created unconditionally, regardless of player privilege,
-- to simplify granting/removal without having to re-login.
minetest.register_on_joinplayer(function(player)
	meters[player:get_player_name()] = {
		player = player,
		text = "",
		hud = player:hud_add({
			hud_elem_type = "text",
			position = { x = 0.5, y = 1 },
			text = "",
			alignment = { x = 1, y = -1 },
			number = 0xC0C0C0,
			scale = { x = 1280, y = 20 },
			offset = { x = -262, y = -88 }
		})
	}
end)

-- Remove meter registrations when players leave.
minetest.register_on_leaveplayer(function(player)
	meters[player:get_player_name()] = nil
end)
