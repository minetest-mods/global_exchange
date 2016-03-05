
local modpath = minetest.get_modpath(minetest.get_current_modname()) .. "/"

local exchange = (dofile(modpath .. "exchange.lua")).open_exchange(
	minetest.get_worldpath() .. "/global_exchange.db"
)

minetest.register_on_shutdown(function()
	exchange:close()
end)

assert(loadfile(modpath .. "atm.lua"))(exchange)
assert(loadfile(modpath .. "exchange_machine.lua"))(exchange)
assert(loadfile(modpath .. "digital_mailbox.lua"))(exchange)
