
-- A telling machine. Call this file with the exchange argument.
local exchange = ...

local atm_form = "global_exchange:atm_form"

local function main_menu(p_name)
	local balance = exchange:get_balance(p_name)
	local formspec = 'size[6,2]' ..
	'label[0,0;' .. p_name .. '\'s account]' ..
	'label[0,0.5;Balance: ' .. balance .. ']' ..
	'button[0,1;2,1;cash;Cash In/Out]' ..
	'button[2,1;2,1;wire;Transfer]' ..
	'button[4,1;2,1;transaction_log;History]'
	return formspec
end

local function back(x,y)
	return "button[" .. x .. "," .. y .. ";2,1;main;Back]"
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

function cash_fs(p_name)
  local balance = exchange:get_balance(p_name)
  local formspec =
    'size[8,9]'..
    'label[0,0;' .. p_name .. '\'s account]' ..
    'label[0,1;Balance: ' .. balance .. ']' ..
    --money
    'list[detached:global_exchange;money;0,2;3,1;]'..
    --player inventory
    'list[current_player;main;0,4;8,4;]'..
    --back button
    back(0,8)
--print(formspec)
  return formspec
end

function bills2balance(stack, p_name)
  local bal = exchange:get_balance(p_name)
  local name = stack:get_name()
  local count = stack:get_count()
  if name == 'currency:minegeld' then
    bal = bal + count
  elseif name == 'currency:minegeld_5' then
    bal = bal + count * 5
  elseif name == 'currency:minegeld_10' then
    bal = bal + count * 10
  end
  return bal
end

local function wire_fs(p_name)
	local balance = exchange:get_balance(p_name)

	local fs = "size[4,5]" .. back(0,4)

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
		"size[8,8]label[0,0;Transaction Log]button[0,7;2,1;main;Back]",
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

	if fields.main then
		minetest.show_formspec(p_name, atm_form, main_menu(p_name))
	end

	if fields.cash then
		minetest.show_formspec(p_name, atm_form, cash_fs(p_name))
		local balance = exchange:get_balance(p_name)
		local inv = minetest.get_inventory({type="detached", name="global_exchange"})
		inv:set_size('money', 3)
		local stacks = inv:get_list('money')
		local tens = math.floor(balance/10)
		if tens > 0 then
			inv:set_stack('money', 1, 'currency:minegeld_10 ' .. tens)
			balance = balance - tens * 10
		else
			inv:set_stack('money', 1, '')
		end
		local fives = math.floor(balance/5)
		if fives > 0 then
			inv:set_stack('money', 2, 'currency:minegeld_5 ' .. fives)
			balance = balance - fives * 5
		else
			inv:set_stack('money', 2, '')
		end
		local ones = math.floor(balance)
		if ones > 0 then
			inv:set_stack('money', 3, 'currency:minegeld ' .. ones)
			balance = balance - ones
		else
			inv:set_stack('money', 3, '')
		end
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
		fixed = {-0.5, -0.5, -0.5, 0.5, 1.5, 0.5},
	},
	after_place_node = function(pos, placer, itemstack)
		local n = minetest.get_node_or_nil(pos)
		if not n or not n.param2 then
			minetest.remove_node(pos)
			return true
		end
		local pos2 = {x = pos.x, y = pos.y + 1, z = pos.z}
		if minetest.get_node(pos2).name ~= "air" then
			minetest.remove_node(pos)
			return true
		end
		minetest.set_node(pos2, {name = n.name:gsub("%_bottom", "_top"), param2 = n.param2})
		return false
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
		minetest.show_formspec(clicker:get_player_name(), atm_form, main_menu(clicker:get_player_name()))
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
		atm = 2
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
