-- LUALOCALS < ---------------------------------------------------------
local math, tonumber
    = math, tonumber
local math_floor
    = math.floor
-- LUALOCALS > ---------------------------------------------------------

local stamp = tonumber("$Format:%at$")
if not stamp then return end
stamp = math_floor((stamp - 1540612800) / 60)
stamp = ("00000000" .. stamp):sub(-8)

-- luacheck: push
-- luacheck: globals config readtext readbinary

readtext = readtext or function() end
readbinary = readbinary or function() end

return {
	user = "Warr1024",
	pkg = "szutilpack",
	min = "5.0",
	version = stamp .. "-$Format:%h$",
	long_description = readtext(".cdbdesc.md"),
	screenshots = {readbinary(".cdbscreen.png")}
}

-- luacheck: pop
