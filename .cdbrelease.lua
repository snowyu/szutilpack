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

return {
	user = "Warr1024",
	pkg = "szutilpack",
	version = stamp .. "-$Format:%h$"
}
