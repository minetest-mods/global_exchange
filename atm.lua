-- A telling machine. Call this file with the exchange argument.
local exchange = ...

local atm_form = "global_exchange:atm_form"

local main_menu =[[
size[6,2]
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


minetest.register_node("global_exchange:atm_bottom", {
	description = "ATM",
	inventory_image = "global_exchange_atm_icon.png",
	wield_image = "global_exchange_atm_hi_front.png",
	drawtype = "nodebox",
	tiles = {
		"global_exchange_atm_lo_top.png",
		"global_exchange_atm_side.png",
		"global_exchange_atm_side.png",
		"global_exchange_atm_side.png",
		"global_exchange_atm_back.png^[transform2",
		"global_exchange_atm_lo_front.png",
	},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	stack_max = 1,
	light_source = 3,
	node_box = {
		type = "fixed",
		fixed = {
		{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
			{-0.5, 0.5, -0.5, -0.375, 1.125, -0.25},
			{0.375, 0.5, -0.5, 0.5, 1.125, -0.25},
			{-0.5, 0.5, -0.25, 0.5, 1.5, 0.5},
			{-0.5, 1.125, -0.4375, -0.375, 1.25, -0.25},
			{0.375, 1.125, -0.4375, 0.5, 1.25, -0.25},
			{-0.5, 1.25, -0.375, -0.375, 1.375, -0.25},
			{0.375, 1.25, -0.375, 0.5, 1.375, -0.25},
			{-0.5, 1.375, -0.3125, -0.375, 1.5, -0.25},
			{0.375, 1.375, -0.3125, 0.5, 1.5, -0.25},
		},
	},
	on_place = function(itemstack, placer, pointed_thing)
		local under = pointed_thing.under
		local pos
		if minetest.registered_items[minetest.get_node(under).name].buildable_to then
			pos = under
		else
			pos = pointed_thing.above
		end
		if minetest.is_protected(pos, placer:get_player_name()) and
				not minetest.check_player_privs(placer, "protection_bypass") then
			minetest.record_protection_violation(pos, placer:get_player_name())
			return itemstack
		end
		local def = minetest.registered_nodes[minetest.get_node(pos).name]
		if not def or not def.buildable_to then
			minetest.remove_node(pos)
			return itemstack
		end
		local dir = minetest.dir_to_facedir(placer:get_look_dir())
		local pos2 = {x = pos.x, y = pos.y + 1, z = pos.z}
		local def2 = minetest.registered_nodes[minetest.get_node(pos2).name]
		if not def2 or not def2.buildable_to then
			return itemstack
		end
		minetest.set_node(pos, {name = "global_exchange:atm_bottom", param2 = dir})
		minetest.set_node(pos2, {name = "global_exchange:atm_top", param2 = dir})
		if not minetest.setting_getbool("creative_mode") then
			itemstack:take_item()
			return itemstack
		end
	end,
	on_destruct = function(pos)
		local pos2 = {x = pos.x, y = pos.y + 1, z = pos.z}
		local n2 = minetest.get_node(pos2)
		if minetest.get_item_group(n2.name, "atm") == 2 then
			minetest.remove_node(pos2)
		end
	end,
	groups = {cracky=2, atm = 1},
	on_rightclick = function(pos, _, clicker)
		minetest.sound_play("atm_beep", {pos = pos, gain = 0.3, max_hear_distance = 5})
		minetest.show_formspec(clicker:get_player_name(), atm_form, main_menu)
	end,
})

minetest.register_node("global_exchange:atm_top", {
	drawtype = "nodebox",
	tiles = {
		"global_exchange_atm_hi_top.png",
		"global_exchange_atm_side.png",--not visible anyway
		"global_exchange_atm_side.png",
		"global_exchange_atm_side.png",
		"global_exchange_atm_back.png",
		"global_exchange_atm_hi_front.png",
	},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	light_source = 3,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, -0.375, 0.125, -0.25},
			{0.375, -0.5, -0.5, 0.5, 0.125, -0.25},
			{-0.5, -0.5, -0.25, 0.5, 0.5, 0.5},
			{-0.5, 0.125, -0.4375, -0.375, 0.25, -0.25},
			{0.375, 0.125, -0.4375, 0.5, 0.25, -0.25},
			{-0.5, 0.25, -0.375, -0.375, 0.375, -0.25},
			{0.375, 0.25, -0.375, 0.5, 0.375, -0.25},
			{-0.5, 0.375, -0.3125, -0.375, 0.5, -0.25},
			{0.375, 0.375, -0.3125, 0.5, 0.5, -0.25},
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {0, 0, 0, 0, 0, 0},
	},
	groups = {
		atm = 2,
		not_in_creative_inventory = 1
	},
})

minetest.register_craft( {
	output = "global_exchange:atm",
	recipe = {
		{ "default:stone", "default:stone", "default:stone" },
		{ "default:stone", "default:gold_ingot", "default:stone" },
		{ "default:stone", "default:stone", "default:stone" },
	}
})

minetest.register_alias("global_exchange:atm", "global_exchange:atm_bottom")
