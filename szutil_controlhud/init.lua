-- LUALOCALS < ---------------------------------------------------------
local ipairs, math, minetest, pairs, table, tonumber
    = ipairs, math, minetest, pairs, table, tonumber
local math_random, table_concat
    = math.random, table.concat
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

minetest.register_chatcommand("controlhud", {
		description = "Set Control HUD scale (0 to disable)",
		func = function(name, param)
			local player = minetest.get_player_by_name(name)
			if not player then return end
			local num = tonumber(param)
			if not num then return false, "invalid scale" end
			player:get_meta():set_float(modname, num)
		end,
	})

local droptimes = {}
local olddrop = minetest.item_drop
function minetest.item_drop(stack, who, ...)
	if who and who:is_player() then
		droptimes[who:get_player_name()] = minetest.get_us_time() / 1000000
	end
	return olddrop(stack, who, ...)
end

local dir_simple = {"up", "down", "left", "right"}
local dir_compound = {
	upleft = true,
	upright = true,
	downleft = true,
	downright = true
}
local buttons = {"sneak", "jump", "LMB", "RMB"}

local huds = {}

local function dohuds(player)
	local scale = player:get_meta():get_float(modname) or 0

	local on = {}
	if scale > 0 then
		local ctl = player:get_player_control()

		local dir = {}
		for _, k in ipairs(dir_simple) do
			if ctl[k] then dir[#dir + 1] = k end
		end
		local comp = table_concat(dir)
		if dir_compound[comp] then dir = {comp} end

		on.base = true
		for _, k in ipairs(dir) do on[k] = true end
		for _, k in ipairs(buttons) do
			if ctl[k] then on[k] = true end
		end
		local dt = droptimes[player:get_player_name()]
		if dt and dt > (minetest.get_us_time() / 1000000 - 0.25) then
			on.drop = true
		end
	end

	local hud = huds[player:get_player_name()]
	if not hud then
		if scale <= 0 then return end
		hud = {}
		huds[player:get_player_name()] = hud
	end

	local now = minetest.get_us_time() / 1000000
	for k in pairs(hud) do on[k] = on[k] or false end
	for k, v in pairs(on) do
		local h = hud[k]
		if h or v then
			v = v and scale or 0
			local exp = now + math_random() * 2
			if not h then
				hud[k] = {
					id = player:hud_add({
							hud_elem_type = "image",
							scale = {x = v, y = v},
							position = {x = 1, y = 0},
							text = modname .. "_" .. k .. ".png",
							alignment = {x = -1, y = 1},
							offset = {x = -2, y = -2},
						}),
					scale = v,
					exp = exp
				}
			elseif h.scale ~= v or h.exp < now then
				h.scale = v
				h.exp = exp
				player:hud_change(h.id, "scale", {x = v, y = v})
			end
		end
	end
end

minetest.register_globalstep(function()
		for _, p in pairs(minetest.get_connected_players()) do
			dohuds(p)
		end
	end)

minetest.register_on_leaveplayer(function(player)
		huds[player:get_player_name()] = nil
	end)
