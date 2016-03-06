
-- A telling machine. Call this file with the exchange argument.
local exchange = ...

local atm_form = "global_exchange:atm_form"

local main_menu =[[
size[6,2]
button[0,0;2,1;new_account;New Account]
button[2,0;2,1;info;Account Info]
button[4,0;2,1;wire;Wire Monies]
button[1,1;4,1;transaction_log;Transaction Log]
]]


local function logout(x,y)
	return "button[" .. x .. "," .. y .. ";2,1;logout;Log Out]"
end


local function label(x,y,text)
	return "label[" .. x .. "," .. y .. ";"
		.. minetest.formspec_escape(text) .. "]"
end

local function field(x,y, w,h, name, label, default)
	return "field[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";"
		.. name .. ";" .. minetest.formspec_escape(label) .. ";"
		.. minetest.formspec_escape(default) .. "]"
end

local unique_num = 1

local function unique()
	local ret = unique_num
	unique_num = unique_num + 1

	return ret
end


local function new_account_fs(p_name)
	local act_suc, err = exchange:new_account(p_name)

	local fs
	if not act_suc then
		fs = label(0.5,0.5, "Error: " .. err)
	else
		fs = label(0.5,0.5, "Congratulations on \nyour new account.")
	end

	return "size[4,3]" .. fs .. logout(0.5,2)
end


local function info_fs(p_name)
	local balance = exchange:get_balance(p_name)

	local fs
	if not balance then
		fs = label(0.5,0.5, "You don't have an account.")
	else
		fs = label(0.5,0.5, "Balance: " .. balance)
	end

	return "size[4,3]" .. fs .. logout(0.5,2)
end


local function wire_fs(p_name)
	local balance = exchange:get_balance(p_name)

	local fs = "size[4,5]" .. logout(0,4)

	if not balance then
		return fs .. label(0.5,0.5, "You don't have an account.")
	end

	-- To prevent duplicates
	return fs .. field(-100, -100, 0,0, "trans_id", "", unique()) ..
		label(0.5,0.5, "Balance: " .. balance) ..
		field(0.5,1.5, 2,1, "recipient", "Send to:", "") ..
		field(0.5,2.5, 2,1, "amount", "Amount", "") ..
		"button[2,4;2,1;send;Send]"
end


local function send_fs(p_name, receiver, amt_str)
	local fs = "size[7,3]"

	local amt = tonumber(amt_str)

	if not amt or amt <= 0 then
		return fs .. label(0.5,0.5, "Invalid transfer amount.") ..
			"button[0.5,2;2,1;wire;Back]"
	end

	local succ, err = exchange:transfer_credits(p_name, receiver, amt)

	if not succ then
		return fs .. label(0.5,0.5, "Error: " .. err) ..
			"button[0.5,2;2,1;wire;Back]"
	end
	return fs.. label(0.5,0.5, "Successfully sent " ..
		amt .. " credits to " .. receiver) ..
		"button[0.5,2;2,1;wire;Back]"
end


local function log_fs(p_name)
	local res = {
		"size[8,8]label[0,0;Transaction Log]button[0,7;2,1;logout;Log Out]",
		"tablecolumns[text;text]",
		"table[0,1;8,6;log_table;Time,Message",
	}

	for i, entry in ipairs(exchange:player_log(p_name)) do
		i = i*4
		res[i] = ","
		res[i+1] = tostring(entry.Time)
		res[i+2] = ","
		res[i+3] = entry.Message
	end
	res[#res+1] ="]"

	return table.concat(res)
end


local trans_ids = {}


minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= atm_form then return end
	if fields.quit then return true end

	local p_name = player:get_player_name()

	local this_id = fields.trans_id

	if this_id and this_id == trans_ids[p_name] then
		return true
	end

	trans_ids[p_name] = this_id

	if fields.logout then
		minetest.show_formspec(p_name, atm_form, main_menu)
	end

	if fields.new_account then
		minetest.show_formspec(p_name, atm_form, new_account_fs(p_name))
	end

	if fields.info then
		minetest.show_formspec(p_name, atm_form, info_fs(p_name))
	end

	if fields.wire then
		minetest.show_formspec(p_name, atm_form, wire_fs(p_name))
	end

	if fields.send then
		minetest.show_formspec(p_name, atm_form,
				       send_fs(p_name, fields.recipient, fields.amount))
	end

	if fields.transaction_log then
		minetest.show_formspec(p_name, atm_form, log_fs(p_name))
	end

	return true
end)


minetest.register_node("global_exchange:atm", {
	description = "ATM",
	tiles = {"global_exchange_atm_top.png",
		 "global_exchange_atm_top.png",
		 "global_exchange_atm_side.png",
	},
	groups = {cracky=2},
	on_rightclick = function(pos, _, clicker)
		minetest.show_formspec(clicker:get_player_name(), atm_form, main_menu)
	end,
})


minetest.register_craft( {
	output = "global_exchange:atm",
	recipe = {
		{ "default:stone", "default:stone", "default:stone" },
		{ "default:stone", "default:gold_ingot", "default:stone" },
		{ "default:stone", "default:stone", "default:stone" },
	}
})
