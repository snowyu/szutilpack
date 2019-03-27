-- LUALOCALS < ---------------------------------------------------------
local io, ipairs, math, minetest, pairs, table, type
    = io, ipairs, math, minetest, pairs, table, type
local io_open, math_floor, table_concat, table_sort
    = io.open, math.floor, table.concat, table.sort
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

------------------------------------------------------------------------
-- IN-MEMORY DATABASE AND UTILITY

local db = { }

local function getsub(tbl, id)
	local x = tbl[id]
	if x then return x end
	x = { }
	tbl[id] = x
	return x
end

local function statadd(blockid, playername, stat, value)
	local t = getsub(db, blockid)
	t = getsub(t, playername)
	t[stat] = (t[stat] or 0) + value
end

local function getpn(whom)
	if not whom then return end
	local pn = whom.get_player_name
	if not pn then return end
	pn = pn(whom)
	if not pn or not pn:find("%S") then return end
	return pn
end

local function blockid(pos)
	return math_floor((pos.x + 0.5) / 16)
	+ 4096 * math_floor((pos.y + 0.5) / 16)
	+ 16777216 * math_floor((pos.z + 0.5) / 16)
end

------------------------------------------------------------------------
-- PLAYER ACTIVITY EVENT HOOKS

local function reghook(func, stat, pwhom, ppos)
	return func(function(...)
			local t = {...}
			local whom = t[pwhom]
			local pn = getpn(whom)
			if not pn then return end
			local pos = ppos and t[ppos] or whom:getpos()
			local id = blockid(pos)
			return statadd(id, pn, stat, 1)
		end)
end
reghook(minetest.register_on_dignode,	    "dig",   3, 1)
reghook(minetest.register_on_placenode,	    "place", 3, 1)
reghook(minetest.register_on_dieplayer,	    "die",   1)
reghook(minetest.register_on_respawnplayer, "spawn", 1)
reghook(minetest.register_on_joinplayer,    "join",  1)
reghook(minetest.register_on_leaveplayer,   "leave", 1)
reghook(minetest.register_on_craft,	    "craft", 2)

minetest.register_on_player_hpchange(function(whom, change)
		local pn = getpn(whom)
		if not pn then return end
		local id = blockid(whom:getpos())
		if change < 0 then
			return statadd(id, pn, "hurt", -change)
		else
			return statadd(id, pn, "heal", change)
		end
	end)

------------------------------------------------------------------------
-- PLAYER MOVEMENT/IDLE HOOKS

local playdb = { }
local idlemin = 5
local function procstep(dt, player)
	local pn = getpn(player)
	if not pn then return end
	local pd = getsub(playdb, pn)

	local pos = player:getpos()
	local dir = player:get_look_dir()
	local cur = { pos.x, pos.y, pos.z, dir.x, dir.y, dir.z }
	local moved
	if pd.last then
		for i = 1, 6 do
			moved = moved or pd.last[i] ~= cur[i]
		end
	end
	pd.last = cur

	local id = blockid(pos)
	local t = pd.t or 0
	if moved then
		pd.t = 0
		if t >= idlemin then
			statadd(id, pn, "idle", t)
			return statadd(id, pn, "move", dt)
		else
			return statadd(id, pn, "move", t + dt)
		end
	else
		if t >= idlemin then
			return statadd(id, pn, "idle", dt)
		else
			pd.t = t + dt
			if (t + dt) >= idlemin then
				return statadd(id, pn, "idle", t + dt)
			end
		end
	end
end
minetest.register_globalstep(function(dt)
		for _, player in pairs(minetest.get_connected_players()) do
			procstep(dt, player)
		end
	end)

------------------------------------------------------------------------
-- DATABASE FLUSH CYCLE

local function deepadd(t, u)
	for k, v in pairs(u) do
		if type(v) == "table" then
			t[k] = deepadd(t[k] or { }, v)
		else
			t[k] = (t[k] or 0) + v
		end
	end
	return t
end

local function dbpath(id)
	local p = minetest.get_worldpath() .. "/" .. modname
	if id then
		id = "" .. id
		
		if id:sub(1, 3) ~= "blk" then
			id = "blk" .. id .. ".txt"
		end
		p = p .. "/" .. id
	end
	return p
end

local function dbload(id)
	local f = io_open(dbpath(id))
	if not f then return { } end
	local u = minetest.deserialize(f:read("*all"))
	f:close()
	return u
end

local lasttime = minetest.get_us_time() / 1000000
local savedqty = 0
local alltime = 0
local runtime = 0
local function dbflush(forcerpt)
	local now = minetest.get_us_time() / 1000000
	alltime = alltime + now - lasttime
	lasttime = now

	minetest.mkdir(dbpath())
	for id, t in pairs(db) do
		t = deepadd(dbload(id), t)
		minetest.safe_file_write(dbpath(id), minetest.serialize(t))
		savedqty = savedqty + 1
	end
	db = { }

	now = minetest.get_us_time() / 1000000
	runtime = runtime + now - lasttime

	if not forcerpt and ((runtime < 1 and alltime < 3600 and savedqty < 100)
	or savedqty < 1) then return end

	local function ms(i) return math_floor(i *1000000) / 1000 end
	minetest.log(modname .. ": recorded " .. savedqty .. " block(s) using "
		.. ms(runtime) .. "ms out of " .. ms(alltime) .. "ms ("
		.. (math_floor(runtime / alltime * 10000) / 100)
		.. "%)")
	runtime = 0
	alltime = 0
	savedqty = 0
end

local function flushcycle()
	dbflush()
	return minetest.after(60, flushcycle)
end
flushcycle()

minetest.register_on_shutdown(function()
		for _, player in pairs(minetest.get_connected_players()) do
			local pn = getpn(player)
			if pn then
				local id = blockid(player:getpos())
				statadd(id, pn, "shutdown", 1)
			end
		end
		dbflush(true)
	end)

------------------------------------------------------------------------
-- CHAT COMMAND

local function fmtrpt(t, id)
	local p = { }
	for k, v in pairs(t) do
		local n = 0
		for k2, v2 in pairs(v) do
			n = n + v2
		end
		p[#p + 1] = k
		p[k] = n
	end
	table_sort(p, function(a, b)
			if p[a] == p[b] then return a < b end
			return p[a] > p[b]
		end)

	local r = id and { "block", id } or { "world" }
	for _, k in ipairs(p) do
		r[#r + 1] = "[" .. k .. "]"
		local v = t[k]
		local s = { }
		for k2, v2 in pairs(v) do
			s[#s + 1] = k2
		end
		table_sort(s, function(a, b)
				if v[a] == v[b] then return a < b end
				return v[a] > v[b]
			end)
		for _, k2 in ipairs(s) do
			r[#r + 1] = k2
			r[#r + 1] = math_floor(v[k2])
		end
	end

	return table_concat(r, " ")
end

minetest.register_chatcommand("blockuse", {
		privs = {server = true},
		description = "Statistics about usage within the current mapblock.",
		func = function(name)
			local player = minetest.get_player_by_name(name)
			if not player then return end
			local id = blockid(player:getpos())

			local t = deepadd(deepadd({ }, getsub(db, id)), dbload(id))
			minetest.chat_send_player(name, fmtrpt(t, id))
		end
	})

minetest.register_chatcommand("worlduse", {
		privs = {server = true},
		description = "Statistics about usage across the entire world.",
		func = function(name)
			local t = { }
			for k, v in pairs(db) do
				t = deepadd(t, v)
			end
			for i, v in ipairs(minetest.get_dir_list(dbpath(), false)) do
				t = deepadd(t, dbload(v))
			end

			minetest.chat_send_player(name, fmtrpt(t))
		end
	})

------------------------------------------------------------------------
