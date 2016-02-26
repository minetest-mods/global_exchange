
local modpath = minetest.get_modpath(minetest.get_current_modname()) .. "/"
local savepath = minetest.get_worldpath() .. "/global_exchange.db"

local income_str = minetest.setting_get("citizens_income")
local income = income_str and tonumber(income_str) or 10

local income_interval = 1200

local income_msg = "You receive your citizen's income (+" .. income .. ")"

local next_payout = os.time() + income_interval

local ex = dofile(modpath .. "exchange.lua")
local exchange = ex.open_exchange(savepath)


minetest.register_on_shutdown(function()
		exchange:close()
end)


-- Only check once in a while
local elapsed = 0

minetest.register_globalstep(function(dtime)
		elapsed = elapsed + dtime
		if elapsed <= 5 then return end

		elapsed = 0

		local now = os.time()
		if now < next_payout then return end

		next_payout = now + income_interval

		for i, player in ipairs(minetest.get_connected_players()) do
			local p_name = player:get_player_name()

			local succ =
				exchange:give_credits(p_name, income,
						      "Citizen's Income (+" .. income .. ")")

			if succ then
				minetest.chat_send_player(p_name, income_msg)
			end
		end
end)


assert(loadfile(modpath .. "atm.lua"))(exchange)
assert(loadfile(modpath .. "exchange_machine.lua"))(exchange)
assert(loadfile(modpath .. "digital_mailbox.lua"))(exchange)
