-- This is a library for working with atomic transactions of multiple
-- nodes.  Transactions can be rolled back until they are committed, and
-- problematic conditions such as "ignore" nodes can abort the
-- transaction.

------------------------------------------------------------------------

local ignore = "ignore"
local trans_abort = "abort sz_nodetrans: "

local tn_helpers = { }
function tn_helpers:pre()
	local n = self:node_get()
	if n and n.name and n.name == ignore and self.trans
		and self.trans.abort_on_ignore then
		sz_nodetrans.abort("unloaded mapblock encountered")
	end
	if not n then
		sz_nodetrans.abort("sz_pos:node_get() returned nil")
	end
	n = sz_table:new(n)
	rawset(self, "pre", n)
	return n
end
function tn_helpers:now()
	local n = self.pre
	if not n then return end
	n = sz_table.copy(n)
	rawset(self, "now", n)
	return n
end
function tn_helpers:def()
	local n = self.now
	if not n then return { } end
	n = n.name
	if not n then return { } end
	return minetest.registered_items[n]
end
function tn_helpers:facedir()
	if now and now.param2 then
		return sz_facedir.from_param(now.param2)
	end
end
function tn_helpers:metapre()
	local m = self:meta()
	if not m then return end
	m = sz_table:new(m:to_table())
	self.metapre = m
	return m
end
function tn_helpers:metanow()
	local t = self.metapre
	if not t then return end
	t = sz_table.copy(t)
	self.metanow = t
	return t
end

local transnode = { }
function transnode:__index(self, key)
	local f = tn_helpers[key]
	if f then return f(self) end
	f = self.now[key]
	if f then return f end
	return sz_pos[key]
end
function transnode:__newindex(self, key, value)
	if not tn_helpers[key] then
		self.now[key] = value
	end
	rawset(self, key, value)
end

function sz_nodetrans:get(pos)
	local idx = self.idx
	if not idx then
		idx = sz_table:new()
		self.idx = idx
	end

	pos = sz_pos:new(pos)
	local hash = pos:hash()
	local state = idx[hash]
	if state then return state end

	state = pos:copy()
	state.trans = self
	setmetatable(state, transnode)

	idx[hash] = state
	return state
end

function sz_nodetrans:post(act)
	local dopost = self.dopost
	if not dopost then
		dopost = sz_table:new()
		self.dopost = dopost
	end
	dopost:insert(act)
end

function sz_nodetrans.abort(msg)
	error(trans_abort .. msg)
end

local function commit(aoi, ok, msg, ...)
	self.abort_on_ignore = aoi
	if not ok then
		if msg:sub(1, trans_abort:len()) == trans_abort then
			print(msg)
			return
		end
		error(msg, 0)
	end

	for k, v in pairs(self.idx or { }) do
		if minetest.serialize(v.pre) ~= minetest.serialize(v.now) then
			v:node_set(v.now)
		end
		if minetest.serialize(v.metapre) ~= minetest.serialize(v.metanow) then
			v:meta():from_table(v.metanow)
		end
		if v.now.post then v.now.post() end
	end
	self.idx = nil
	for k, v in pairs(self.dopost or { }) do
		v()
	end
	self.dopost = nil
	
	return msg, ...
end

function sz_nodetrans.begin(act)
	local aoi = self.abort_on_ignore
	self.abort_on_ignore = true
	commit(aoi, pcall(act))
end

------------------------------------------------------------------------
return sz_nodetrans
