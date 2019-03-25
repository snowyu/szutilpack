-- LUALOCALS < ---------------------------------------------------------
local minetest, pairs, rawset, type, vector
= minetest, pairs, rawset, type, vector
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

local function playerize(param)
	if (not param) or (param == "") then return end
	if type(param) == "string" then
		local player = minetest.get_player_by_name(param)
		if player then return player, param end
		return
	end
	return param, param:get_player_name()
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
	c = player:get_attribute(modname)
	if (not c) or (c == "") then return end
	c = minetest.deserialize(c)
	watchdata_cache[pname] = c
	return c
end
local function watchdata_set(player, pname, data)
	pname = pname or player:get_player_name()
	watchdata_cache[pname] = data
	return player:set_attribute(modname, minetest.serialize(data))
end

local vzero = vector.new()
local function watch_restore(dtime, wplayer, wname)
	wname = wname or wplayer:get_player_name()

	local data = watchdata_get(wplayer, wname)
	if (not data) or (not data.restore) then return end

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
	wplayer:set_pos(restore.pos)

	if restore.inv then
		for k, v in pairs(restore.inv) do
			wplayer:get_inventory():set_list(k, v)
		end
		data.restore.inv = nil
	end

	if data.restore.ttl < 0 then data.restore = nil end
	return watchdata_set(wplayer, wname, data)
end

local function watch_stop(wparam, tparam)
	local wplayer, wname = playerize(wparam)
	if not wplayer then return false, "watcher not found" end

	local data = watchdata_get(wplayer, wname)
	if not data then return false, "not watching anybody" end

	local tplayer, tname = playerize(tparam)
	if tname and tname ~= data.target then
		return false, "not watching specified target"
	end

	data.restore = data.saved or data.restore
	if data.restore then data.restore.ttl = 0.5 end
	data.saved = nil
	watchdata_set(wplayer, wname, data)

	watch_restore(0, wplayer)

	return true
end

local function watch_start(wparam, tparam)
	local wplayer, wname = playerize(wparam)
	if not wplayer then return false, "watcher not found" end
	local tplayer, tname = playerize(tparam)
	if not tplayer then return false, "target not found" end
	if wname == tname then return watch_stop(wparam) end

	local data = watchdata_get(wplayer, wname) or {}
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
			}
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

	wplayer:set_attach(tplayer, "", vector.new(0, -5, -20), vector.new())
	wplayer:set_eye_offset(vector.new(0, -5, -20), vector.new())
	wplayer:set_properties({
			visual_size = {x = 0, y = 0},
			makes_footstep_sound = false,
			collisionbox = {0}
		})
	setprivs(wname, function(x) x.interact = nil end)

	return true
end

rawset(_G, modname, {
		restore = watch_restore,
		stop = watch_stop,
		start = watch_start
	})
