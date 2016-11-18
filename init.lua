
local insecure_env = minetest.request_insecure_environment()
assert(insecure_env,
	"global_exchange needs to be trusted to run under mod security.")

local modpath = minetest.get_modpath(minetest.get_current_modname()) .. "/"

local income = tonumber(minetest.setting_get("citizens_income")) or 10
local income_interval = 1200
local income_msg = "You receive your citizen's income (+" .. income .. ")"

local next_payout = os.time() + income_interval

local exchange =
        assert(loadfile(modpath .. "exchange.lua"))(insecure_env).open_exchange(
		minetest.get_worldpath() .. "/global_exchange.db"
)


minetest.register_on_shutdown(function()
	exchange:close()
end)


local function check_giving()
	local now = os.time()
	if now < next_payout then
		return
	end

	next_payout = now + income_interval

	for _, player in ipairs(minetest.get_connected_players()) do
		local p_name = player:get_player_name()

		local succ = exchange:give_credits(p_name, income,
			"Citizen's Income (+" .. income .. ")")

		if succ then
			minetest.chat_send_player(p_name, income_msg)
		end
	end

	minetest.after(5, check_giving)
end

minetest.after(5, check_giving)



assert(loadfile(modpath .. "atm.lua"))(exchange)
assert(loadfile(modpath .. "exchange_machine.lua"))(exchange)
assert(loadfile(modpath .. "digital_mailbox.lua"))(exchange)
