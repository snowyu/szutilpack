local modpath = minetest.get_modpath("sz_util");
for k, v in pairs({

	"pos",
	"nodepos",
	"tbl",

}) do dofile(modpath .. "/" .. v .. ".lua") end
