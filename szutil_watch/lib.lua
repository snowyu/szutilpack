-- LUALOCALS < ---------------------------------------------------------
local ipairs, minetest, pairs, rawset, type
    = ipairs, minetest, pairs, rawset, type
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()
local vzero = vector.new()

local function everyone(func)
	for _, p in ipairs(minetest.get_connected_players()) do
		func(p)
	end
end

local function playerize(param)
	if (not param) or (param == "") then return end
	if type(param) == "string" then
		local player = minetest.get_player_by_name(param)
		if player then return player, param end
		return
	end
	return param, param:get_player_name()
end

local function vischeck(player, ...)
	if not player then return end
	local props = player:get_properties()
	if not (props and props.visual_size and props.visual_size.x > 0
		and props.visual_size.y > 0) then return end
	return player, ...
end

local function setprivs(pname, setfunc)
	local privs = minetest.get_player_privs(pname)
	local r = setfunc(privs)
	if r ~= nil then return r end
	minetest.set_player_privs(pname, privs)
end

local watchdata_cache = {}
local function watchdata_get(player, pname)
	pname = pname or player:get_player_name()
	local c = watchdata_cache[pname]
	if c then return c end
	c = player:get_meta():get_string(modname)
	if (not c) or (c == "") then return end
	c = minetest.deserialize(c)
	if type(c) ~= "table" or not pairs(c)(c) then return end
	watchdata_cache[pname] = c
	return c
end
local function watchdata_set(player, pname, data)
	pname = pname or player:get_player_name()
	watchdata_cache[pname] = data
	return player:get_meta():set_string(modname, minetest.serialize(data))
end

local function watch_restore(dtime, wplayer, wname)
	wname = wname or wplayer:get_player_name()

	local data = watchdata_get(wplayer, wname)
	if not data then return end

	if data.target then
		return wplayer:set_breath(11)
	end

	if not data.restore then return end

	local restore = data.restore
	for k, v in pairs({
			ttl = 1,
			eye1 = {x = 0, y = 0, z = 0},
			eye2 = {x = 0, y = 0, z = 0},
			visual_size = {x = 1, y = 1},
			makes_footstep_sound = true,
			collisionbox = {-0.3, -1, -0.3, 0.3, 1, 0.3},
			interact = false,
			pos = {x = 0, y = 0, z = 0}
		}) do
		restore[k] = restore[k] or v
	end
	restore.ttl = restore.ttl - dtime

	wplayer:set_detach()
	wplayer:set_eye_offset(restore.eye1, restore.eye2)
	wplayer:set_properties({
			visual_size = restore.visual_size,
			makes_footstep_sound = restore.makes_footstep_sound,
			collisionbox = restore.collisionbox
		})
	setprivs(wname, function(x) x.interact = restore.interact end)
	if restore.inv then
		for k, v in pairs(restore.inv) do
			wplayer:get_inventory():set_list(k, v)
		end
		data.restore.inv = nil
	end
	if vector.distance(wplayer:get_pos(), restore.pos) < 16 then
		wplayer:set_hp(restore.hp or 20)
	end
	wplayer:set_pos(restore.pos)

	if data.restore.ttl < 0 then data.restore = nil end
	return watchdata_set(wplayer, wname, data)
end

local function watch_damage(wplayer, hp)
	local wname = wplayer:get_player_name()

	local data = watchdata_get(wplayer, wname)
	if data and data.target then return 0 end

	return hp
end

local function watch_stop(wparam, tparam)
	local wplayer, wname = playerize(wparam)
	if not wplayer then return false, "watcher not found" end

	local data = watchdata_get(wplayer, wname)
	if not data then return false, "not watching anybody" end

	local _, tname = playerize(tparam)
	if tname and tname ~= data.target then
		return false, "not watching specified target"
	end

	data.restore = data.saved or data.restore
	if data.restore then data.restore.ttl = 0.5 end
	data.saved = nil
	data.target = nil
	watchdata_set(wplayer, wname, data)

	watch_restore(0, wplayer)

	return true
end

local function watch_start(wparam, tparam, check)
	local wplayer, wname = playerize(wparam)
	if not wplayer then return false, "watcher not found" end
	local tplayer, tname = vischeck(playerize(tparam))
	if not tplayer then return false, "target not found or not allowed" end
	if wname == tname then return watch_stop(wparam) end

	if check and not check(wname, tname, wplayer, tplayer) then
		return false, "target not found or not allowed"
	end

	everyone(function(p) watch_stop(p, wplayer) end)

	local data = watchdata_get(wplayer, wname) or {}
	if data.target == tname then return end
	data.saved = data.saved or data.restore
	if not data.saved then
		local props = wplayer:get_properties()
		local eye1, eye2 = wplayer:get_eye_offset()
		data.saved = {
			pos = wplayer:get_pos(),
			interact = setprivs(wname, function(x) return x.interact or false end),
			visual_size = props.visual_size,
			makes_footstep_sound = props.makes_footstep_sound,
			collisionbox = props.collisionbox,
			eye1 = eye1,
			eye2 = eye2,
			inv = {
				main = wplayer:get_inventory():get_list("main") or {},
				craft = wplayer:get_inventory():get_list("craft") or {}
			},
			hp = wplayer:get_hp()
		}
		for n, l in pairs(data.saved.inv) do
			for k, v in pairs(l) do
				if type(v) == "userdata" then
					l[k] = v:to_string()
				end
			end
			wplayer:get_inventory():set_list(n, {})
		end
	end
	data.saved.ttl = nil
	data.restore = nil
	data.target = tname
	watchdata_set(wplayer, wname, data)

	wplayer:set_attach(tplayer, "", vector.new(0, 5, 0), vzero)
	wplayer:set_eye_offset(vector.new(0, 5, 0), vzero)
	wplayer:set_properties({
			visual_size = {x = 0, y = 0},
			makes_footstep_sound = false,
			collisionbox = {0}
		})
	wplayer:set_hp(20)
	setprivs(wname, function(x) x.interact = nil end)

	return true
end

rawset(_G, modname, {
		dataget = watchdata_get,
		dataset = watchdata_set,
		damage = watch_damage,
		restore = watch_restore,
		stop = watch_stop,
		start = watch_start,
		everyone = everyone
	})
