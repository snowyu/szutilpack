-- Load the master utility base class.
dofile(minetest.get_modpath(minetest.get_current_modname())
	.. "/sz_class.lua");

-- Load subclasses defined in this mod.
sz_class:loadsubclasses("sz_table")
sz_table:loadsubclasses(
	"sz_pos",
	"sz_facedir"
)
