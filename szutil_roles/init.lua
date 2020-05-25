-- LUALOCALS < ---------------------------------------------------------
local minetest, pairs, rawset, string
    = minetest, pairs, rawset, string
local string_match
    = string.match
-- LUALOCALS > ---------------------------------------------------------

local modstore = minetest.get_mod_storage()

local special = {
	all = true,
	default = true
}

local function canwrite(role)
	if special[role] then return end
	local def = minetest.registered_privileges[role]
	return (not def) or def.roleprivs
end

local function setrole(role, privstr)
	rawset(minetest.registered_privileges, role, nil)
	minetest.register_privilege(role, {
			description = "=> " .. privstr,
			give_to_singleplayer = false,
			give_to_admin = false,
			roleprivs = minetest.string_to_privs(privstr)
		})
end

do
	local loaded = modstore:to_table()
	loaded = loaded and loaded.fields
	if loaded then
		for k, v in pairs(loaded) do
			if canwrite(k) then setrole(k, v) end
		end
	end
end

minetest.register_chatcommand("role", {
		params = "<role> (<priv> | <role>)[,...]",
		description = "(Re)define a role",
		privs = {privs = true},
		func = function(_, param)
			local role, privstr = string_match(param, "([^ ]+) (.+)")
			if not role or not privstr then
				return false, "Invalid parameters (see /help roledef)"
			end
			for k in pairs(minetest.string_to_privs(privstr)) do
				if (not special[k]) and (not minetest.registered_privileges[k]) then
					return false, "Invalid priv or role: " .. k
				end
			end
			modstore:set_string(role, privstr)
			setrole(role, privstr)
		end
	})

local function union(t, f) for k in pairs(f) do t[k] = true end return t end

local privexpand = minetest.string_to_privs

local function expandroles(privs)
	local seen = union({}, special)
	local dirty = true
	while dirty do
		dirty = false
		local newpriv = {}
		for k in pairs(privs) do
			if k == "all" then
				privs = {}
				for p, def in pairs(minetest.registered_privileges) do
					if not def.roleprivs then privs[p] = true end
				end
				return privs
			end
			local def = minetest.registered_privileges[k]
			if def and def.roleprivs then
				if not seen[k] then
					seen[k] = true
					dirty = true
					union(newpriv, def.roleprivs)
				end
			else
				newpriv[k] = true
			end
		end
		privs = newpriv
	end
	if privs.default then
		union(privs, privexpand(minetest.settings:get("default_privs")))
		privs.default = nil
	end
	return privs
end

function minetest.string_to_privs(privs)
	return expandroles(privexpand(privs))
end

local revoke = minetest.registered_chatcommands.revoke
if revoke and not minetest.registered_chatcommands.revokeme then
	minetest.register_chatcommand("revokeme", {
			params = "<privilege> | all",
			description = "Revoke privileges from yourself",
			privs = revoke.privs,
			func = function(pname, param)
				return revoke.func(pname, pname .. " " .. param)
			end
		})
end
