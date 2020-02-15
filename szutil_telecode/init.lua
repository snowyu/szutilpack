-- LUALOCALS < ---------------------------------------------------------
local error, minetest, pairs, string, table, tonumber
    = error, minetest, pairs, string, table, tonumber
local string_format, table_concat
    = string.format, table.concat
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

local worldkey = minetest.settings:get(modname .. "_key") or ""
if #worldkey < 1 then error(modname .. "_key must be set!") end

local function tcencode(pos)
	pos = vector.round(pos)

	local hash = minetest.hash_node_position(pos)
	hash = string_format("%x", hash)
	while #hash < 12 do hash = "0" .. hash end

	local cksum = minetest.sha1(worldkey .. hash):sub(1, 4)

	local enckey = minetest.sha1(worldkey .. cksum)
	local chars = {}
	for i = 1, 12 do
		chars[#chars + 1] = string_format("%x",
			tonumber(enckey:sub(i, i), 16)
			+ tonumber(hash:sub(i, i), 16))
		:sub(-1)
	end
	hash = table_concat(chars)

	return hash .. cksum
end

local function tcdecode(str)
	if not str:match("^[0-9a-f]*$") then return end
	if #str ~= 16 then return end

	local hash = str:sub(1, 12)
	local cksum = str:sub(13, 16)

	local enckey = minetest.sha1(worldkey .. cksum)
	local chars = {}
	for i = 1, 12 do
		chars[#chars + 1] = string_format("%x",
			16 + tonumber(hash:sub(i, i), 16)
			- tonumber(enckey:sub(i, i), 16))
		:sub(-1)
	end
	hash = table_concat(chars)

	local mysum = minetest.sha1(worldkey .. hash):sub(1, 4)
	if mysum ~= cksum then return end

	hash = tonumber(hash, 16)
	return minetest.get_position_from_hash(hash)
end

local function poof(pos)
	minetest.add_particlespawner({
			amount = 200,
			time = 0.05,
			minpos = {x = pos.x - 0.5, y = pos.y - 0.5, z = pos.z - 0.5},
			maxpos = {x = pos.x + 0.5, y = pos.y + 1.5, z = pos.z + 0.5},
			minacc = {x = 0, y = 0, z = 0},
			maxacc = {x = 0, y = 0, z = 0},
			minvel = {x = -2, y = -2, z = -2},
			maxvel = {x = 2, y = 2, z = 2},
			minexptime = 0.5,
			maxexptime = 2,
			minsize = 0.25,
			maxsize = 1,
			texture = "szutil_telecode.png"
		})
	minetest.sound_play("szutil_telecode", {
			pos = {x = pos.x, y = pos.y + 1, z = pos.z},
			gain = 2
		})
end

minetest.register_chatcommand("tc", {
		description = "Teleport by telecode",
		params = "[telecode]",
		func = function(pname, param)
			local player = minetest.get_player_by_name(pname)
			if not player then return false, "must be in game world" end

			param = param or ""
			if param == "" then
				return true, "telecode for your location: " .. tcencode(player:get_pos())
			end

			local pos = tcdecode(param)
			if not pos then
				return false, "invalid telecode"
			end

			local invdata = player:get_inventory():get_lists()
			for lname, list in pairs(invdata) do
				if lname ~= "hand" then
					for _, stack in pairs(list) do
						if not (stack:is_empty() or nodecore and nodecore.item_is_virtual(stack)) then
							return false, "inventory not empty"
						end
					end
				end
			end

			poof(player:get_pos())
			player:set_pos(pos)
			poof(pos)
			return true, "teleported to " .. param
		end
	})
