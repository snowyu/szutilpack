-- Some special extensions for sz_pos to play special effects, with
-- hopefully-intelligent rate limiting to prevent very large complex
-- events from hammering networks and clients.

------------------------------------------------------------------------
-- SPECIAL EFFECTS RATE LIMITING

-- Cache to keep track of rate limit data.
local limitfx_cache = { }

-- Possibly add some special effect at the given location, subject to
-- rate limits.  Up to "burst" effects are tolerated before limiting
-- to about 1 effect per "period" seconds, with some random scattering.
-- Rate limits are individual by "name", representing a distinct
-- audio or visual signature such as "smoke" or "boom."  "func" is
-- only called if the rate limit check passes.  "cell" is the size of
-- effect volume cells over which effects are spatially combined.
function sz_pos:limitfx(name, burst, period, func, cell)
	local now = minetest.get_gametime()

	-- Sanitize inputs.
	if burst < 1 then burst = 1 end
	if period <= 0 then period = 1 end

	-- Look up the existing data for the given cell/name.
	local cellkey = self:scale(1 / (cell or 4)):round():hash()
		.. ":" .. name
	local data = limitfx_cache[cellkey] or { q = 0, t = now }

	-- Calculate what the "quantity" value would be now, based on
	-- the existing data at a previous time.
	local nowq = data.q - (now - data.t) / period

	-- Do a random check for whether or not to play the FX, based
	-- on the current quantity and burst tolerance, skip the rest
	-- if we're not going to play.
	if (1 + math.random() * (burst - 1)) <= nowq then return end

	-- Update the limitfx cache.
	limitfx_cache[cellkey] = { q = nowq + 1, t = now, p = period }

	-- Play the effect, if passed as a closure, otherwise return
	-- the fact that we would have played one.
	if func then return func(self) end
	return true
end

-- Garbage-collect the limitfx cache every so often, so it doesn't
-- gradually expand to fill RAM on a long-running server.
local function limitfx_gc()
	minetest.after(60 + math.random() * 15, limitfx_gc)

	local now = minetest.get_gametime()
	local rm = { }
	for k, v in pairs(limitfx_cache) do
		if (v.q - (now - v.t) / v.p) <= 0 then
			rm[k] = true
		end
	end
	for k, v in pairs(rm) do
		limitfx_cache[k] = nil
	end
end
limitfx_gc()

------------------------------------------------------------------------
-- SPECIAL EFFECTS HELPERS

-- Play a sound at the location, with some sane defaults.
function sz_pos:sound(name, spec, burst, period, cell)
	spec = spec or { }
	spec.pos = spec.pos or self
	return self:limitfx("sound:" .. name, burst or 3, period or 0.5,
		function() return minetest.sound_play(name, spec) end,
		cell or 4)

end

-- Add smoke particles with some sane defaults.
function sz_pos:smoke(qty, vel, spec, burst, period, name, cell)
	vel = sz_pos:new(vel or sz_pos:xyz(2, 2, 2))
	spec = spec or { }
	spec.amount = qty or spec.amount or 5
	spec.time = spec.time or 0.25
	spec.minpos = spec.minpos or self:sub(sz_pos:xyz(0.5, 0.5, 0.5))
	spec.maxpos = spec.maxpos or self:add(sz_pos:xyz(0.5, 0.5, 0.5))
	spec.maxvel = spec.maxvel or vel:abs()
	spec.minvel = spec.minvel or sz_pos:new(spec.maxvel):neg()
	spec.maxacc = spec.maxacc or sz_pos.dirs.u:scale(3)
	spec.minacc = spec.minacc or sz_pos:new(spec.maxacc):scale(1 / 3)
	spec.maxexptime = spec.maxexptime or 2
	spec.minexptime = spec.minexptime or spec.maxexptime / 2
	spec.maxsize = spec.maxsize or 8
	spec.minsize = spec.minsize or spec.maxsize / 2
	spec.texture = spec.texture or "tnt_smoke.png"
	if spec.collisiondetection == nil then spec.collisiondetection = true end
	return self:limitfx(name or "particle:smoke", burst or 5, period or 1,
		function() return minetest.add_particlespawner(spec) end,
		cell or 4)
end
