-- LUALOCALS < ---------------------------------------------------------
local minetest, pairs, string, table
    = minetest, pairs, string, table
local string_find, table_concat, table_sort
    = string.find, table.concat, table.sort
-- LUALOCALS > ---------------------------------------------------------

local modname = minetest.get_current_modname()

local givecmd = minetest.registered_chatcommands.give
if not (givecmd and givecmd.func) then return end

local function sortci(a, b)
	return a:lower() < b:lower()
	or a:lower() == b:lower() and a < b
end

local function finditems(search)
	local match = {}
	for _, s in pairs(search:split(" ")) do
		match[#match + 1] = s:lower()
	end
	local items = {}
	local keys = {}
	for k, v in pairs(minetest.registered_items) do
		if k ~= "" then
			local d = (v.description or ""):gsub("\n.* ", "")
			if d ~= "" then d = d .. " " end
			d = d .. "[" .. k .. "]"
			local ok = true
			for _, s in pairs(search:split(" ")) do
				ok = ok and string_find(d:lower(), s:lower(), 1, true)
			end
			if ok then
				d = minetest.formspec_escape(d)
				items[#items + 1] = d
				keys[d] = k
			end
		end
	end
	table_sort(items, sortci)
	local lookup = {}
	for i = 1, #items do lookup["DCL:" .. i] = keys[items[i]] end
	return items, lookup
end

local shown = {}

local function givemenu(pname, search)
	local form = "size[12,8]"

	form = form .. "field[0.25,0.5;12,1;search;Search;"
	.. minetest.formspec_escape(search) .. "]"

	local items, lookup = finditems(search)
	form = form .. "textlist[0,1;12,6;item;" .. table_concat(items, ",") .. "]"

	local names = {}
	for _, p in pairs(minetest.get_connected_players()) do
		names[#names + 1] = minetest.formspec_escape(p:get_player_name())
	end
	table_sort(names, sortci)
	local idx = 0
	for i = 1, #names do if names[i] == minetest.formspec_escape(pname) then idx = i end end
	form = form .. "dropdown[0,7.5;12;whom;" .. table_concat(names, ",") .. ";" .. idx
	.. "]field_close_on_enter[search;false]"

	shown[pname] = lookup
	return minetest.show_formspec(pname, modname, form)
end

minetest.register_chatcommand("givemenu", {
		description = "Give items via formspec menu",
		privs = {give = true},
		func = givemenu
	})

minetest.register_on_player_receive_fields(function(player, formname, fields)
		if formname ~= modname or not minetest.check_player_privs(player, "give")
		then return end

		local pname = player:get_player_name()
		if fields.key_enter_field == "search" then
			return givemenu(pname, fields.search)
		end

		local lookup = shown[pname]
		local name = lookup and lookup[fields.item]
		local def = name and minetest.registered_items[name]
		if def then
			return givecmd.func(pname, table_concat({
						fields.whom,
						name,
						def.stack_max
					}, " "))
		end
	end)

minetest.after(0, function()
		minetest.registered_chatcommands.gm = minetest.registered_chatcommands.gm or
		minetest.registered_chatcommands.givemenu
	end)
