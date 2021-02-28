-- LUALOCALS < ---------------------------------------------------------
local dofile
    = dofile
-- LUALOCALS > ---------------------------------------------------------

-- luacheck: push
-- luacheck: globals config readtext readbinary

readtext = readtext or function() end
readbinary = readbinary or function() end

return {
	pkg = "szutilpack",
	version = dofile("./version.lua"),
	type = "mod",
	title = "SzUtilPack",
	short_description = "A collection of misc dependency-free utilities primarily for server hosts.",
	tags = {
		"environment",
		"library",
		"world_tools",
		"player_effects",
		"server_tools",
		"transport"
	},
	content_warnings = {},
	license = "MIT",
	media_license = "MIT",
	long_description = readtext('README.md'),
	repo = "https://gitlab.com/sztest/szutilpack",
	maintainers = {"Warr1024"},
	screenshots = {readbinary('.cdbscreen.png')}
}

-- luacheck: pop
