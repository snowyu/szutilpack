-- LUALOCALS < ---------------------------------------------------------
local error, ipairs, minetest, pairs, string, table, tonumber, type
    = error, ipairs, minetest, pairs, string, table, tonumber, type
local string_format, table_concat, table_remove, table_sort
    = string.format, table.concat, table.remove, table.sort
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

	return hash:sub(1, 4) .. "-" .. hash:sub(5, 8) .. "-"
	.. hash:sub(9, 12) .. "-" .. cksum
end

local function tcdecode(str)
	if not str or type(str) ~= "string" then return end
	str = str:gsub("-", "")
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

local function bookmarks(player)
	local data = player:get_meta():get_string(modname) or ""
	data = data ~= "" and minetest.deserialize(data) or {}
	return data, function()
		player:get_meta():set_string(modname, minetest.serialize(data))
	end
end

local function bkfind(player, str)
	local data = bookmarks(player)
	if not data then return nil, 'no match' end

	if data[str] then return {{k = str, v = data[str]}} end

	local found = {}
	for k, v in pairs(data) do
		if k:sub(1, #str) == str then found[#found + 1] = {k = k, v = v} end
	end
	if #found > 0 then return found end

	local pat = str:gsub("([^%w])", "%%%1")
	for k, v in pairs(data) do
		if k:match(pat) then found[#found + 1] = {k = k, v = v} end
	end
	return found
end

local function tcfind(player, str)
	local pos = tcdecode(str)
	if pos then return pos end

	local found = bkfind(player, str)
	if #found == 1 then return found[1].v end
	if #found > 1 then return nil, 'ambiguous' end
	return nil, 'no match'
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

			local pos, err = tcfind(player, param)
			if not pos then
				return false, "telecode not found: " .. err
			end

			if nodecore and nodecore.inventory_dump then
				nodecore.inventory_dump(player)
			end

			poof(player:get_pos())
			player:set_pos(pos)
			poof(pos)
			return true
		end
	})

minetest.register_chatcommand("tcsave", {
		description = "Save telecode bookmark",
		params = "<name> [telecode]",
		func = function(pname, param)
			local player = minetest.get_player_by_name(pname)
			if not player then return false, "must be in game world" end

			local words = param:split(' ')
			for i = #words, 1, -1 do
				if not words[i]:match("%S") then
					table_remove(words, i)
				end
			end
			if #words < 1 then return false, "name required" end

			local pos = tcdecode(words[#words])
			if pos then
				words[#words] = nil
			else
				pos = vector.round(player:get_pos())
			end
			local keyname = table_concat(words, " ")

			local data, save = bookmarks(player)
			data[keyname] = pos
			save()

			return true, tcencode(pos) .. " saved as " .. keyname
		end
	})

minetest.register_chatcommand("tcls", {
		description = "List telecode bookmarks",
		params = "<search>",
		func = function(pname, param)
			local player = minetest.get_player_by_name(pname)
			if not player then return false, "must be in game world" end

			local found = bkfind(player, param)
			if #found < 1 then return false, "no match found" end
			table_sort(found, function(a, b) return a.k < b.k end)

			for _, e in ipairs(found) do
				minetest.chat_send_player(pname, "- " .. tcencode(e.v)
					.. ": " .. e.k)
			end
		end
	})

minetest.register_chatcommand("tcrm", {
		description = "Remove telecode bookmark",
		params = "<name>",
		func = function(pname, param)
			local player = minetest.get_player_by_name(pname)
			if not player then return false, "must be in game world" end

			local data, save = bookmarks(player)
			if not data[param] then return false, "bookmark not found" end
			data[param] = nil
			save()
		end
	})
