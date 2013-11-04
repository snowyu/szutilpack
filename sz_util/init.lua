local modname = "sz_util";

-- Load the master utility base class.
dofile(minetest.get_modpath(modname) .. "/sz_class.lua");

-- Load subclasses defined in this mod.
sz_class:loadsubclasses(modname,
	"sz_table",
	"sz_pos",
	"sz_facedir"
)
