
local exchange = ...
local search_cooldown = 2

local main_state = {}
-- ^ A per-player state for the main form. It contains these values:
--     old_fields: Keeps track of the fields before this update, when changing
--                 things slightly
--     search_results: The last search results the player obtained
--     last_search_time: The last time the player did a search. Used to implement
--                       a cooldown on searches
--     sell: A boolean whether the player has sell selected


local function default_main_state()
	return { old_fields = {},
		 search_results = {},
		 last_search_time = 0,
	}
end


minetest.register_on_joinplayer(function(player)
	main_state[player:get_player_name()] = default_main_state()
end)

minetest.register_on_leaveplayer(function(player)
	main_state[player:get_player_name()] = nil
end)


local main_form = "global_exchange:exchange_main"


local tablecolumns =
	"tablecolumns[text;text;text;text;text;text]"


local function table_from_results(results, x, y, w, h, selected)
	local fs_tab = {}

	local function insert(str)
		table.insert(fs_tab, str)
	end

	insert(tablecolumns)
	insert("table[" .. x .. "," .. y .. ";" .. w .. "," .. h .. ";")
	insert("result_table;")
	insert("Poster,Type,Item,Description,Amount,Rate")

	local all_items = minetest.registered_items

	for i, row in ipairs(results) do
		insert(",")
		insert(tostring(row.Poster))
		insert(",")
		insert(tostring(row.Type))
		insert(",")
		insert(tostring(row.Item))
		insert(",")
		if all_items[row.Item] then
			insert(all_items[row.Item].description)
		else
			insert("Unknown Item")
		end
		insert(",")
		insert(tostring(row.Amount))
		insert(",")
		insert(tostring(row.Rate))
	end

	if selected and selected ~= "" then
		insert(";")
		insert(selected)
	end
	insert("]")

	return table.concat(fs_tab)
end


local function mk_main_fs(p_name, new_item, err_str, success)
	local fs = "size[8,9]"

	local state = main_state[p_name]
	if not state then return end -- Should have been initialized on player join

	local old_fields = state.old_fields
	local results = state.search_results
	local item_def = new_item or old_fields.item or ""
	local amount_def = old_fields.amount or ""
	local rate_def = old_fields.rate or ""
	local sell_def = state.sell or false
	local selected_def = old_fields.selected or ""

	local bal = exchange:get_balance(p_name)

	if bal then
		fs = fs .. "label[0,0;Balance: " .. bal .. "]"
	else
		fs = fs .. "label[0.2,0.5;Use an ATM to make your account.]"
	end

	fs = fs .. "button[6,0;2,1;your_orders;Your Orders]"
	fs = fs .. "field[0.2,1.5;3,1;item;Item: ;" .. item_def .. "]"
	fs = fs .. "field[3.2,1.5;3,1;amount;Amount: ;" .. amount_def .. "]"
	fs = fs .. "button[6,1;2,1.4;select_item;Select Item]"
	fs = fs .. "checkbox[5,3;sell;Sell;" .. tostring(sell_def) .. "]"
	fs = fs .. "field[0.2,2.5;2,1;rate;Rate: ;" .. rate_def .. "]"
	fs = fs .. "button[2,2;2,1.4;search;Search]"
	fs = fs .. "button[4,2;3,1.4;post_order;Post Order]"

	if err_str then
		fs = fs .. "label[0,3;Error: " .. err_str .. "]"
	end

	if success then
		fs = fs .. "label[0,3;Success!]"
	end

	fs = fs .. table_from_results(results, 0, 4, 8, 5, selected_def)

	return fs
end


local function show_main(p_name, new_item, err_str, success)
	minetest.show_formspec(p_name, main_form, mk_main_fs(p_name, new_item, err_str, success))
end


-- Something similar to creative inventory
local selectable_inventory_size = 0

-- Create detached inventory after loading all mods
minetest.after(0, function()
	local inv = minetest.create_detached_inventory("global_exchange", {
		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			local p_name = player:get_player_name()

			if from_list == "main" and to_list == "p_" .. p_name then
				return 1
			else
				return 0
			end
		end,
		allow_put = function()
			return 0
		end,
		allow_take = function()
			return 0
		end,
		on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			local p_name = player:get_player_name()
			local p_list = "p_" .. p_name

			local item_name = inv:get_list(p_list)[1]:get_name()
			inv:set_list(p_list, {})
			inv:add_item("main", item_name)
			show_main(p_name, item_name)
		end,
	})

	local selectable_list = {}
	for name, def in pairs(minetest.registered_items) do
		if (not def.groups.not_in_creative_inventory or def.groups.not_in_creative_inventory == 0)
		and def.description and def.description ~= "" then
			table.insert(selectable_list, name)
		end
	end
	table.sort(selectable_list)
	inv:set_size("main", #selectable_list)
	for _,itemstring in ipairs(selectable_list) do
		inv:add_item("main", ItemStack(itemstring))
	end

	selectable_inventory_size = #selectable_list
end)


minetest.register_on_joinplayer(function(player)
	local big_inv = minetest.get_inventory({type="detached", name="global_exchange"})
	local p_list = "p_" .. player:get_player_name()

	big_inv:set_size(p_list, 1)
end)
	

local select_form = "global_exchange:select_form"


local function mk_select_formspec(p_name, start_i, pagenum)
	pagenum = math.floor(pagenum)
	local pagemax = math.floor((selectable_inventory_size - 1) / (8 * 4) + 1)
	local p_list = "p_" .. p_name

	return "size[9.3,8]" ..
		"list[detached:global_exchange;main;0.3,0.5;8,4;" .. tostring(start_i) .. "]" ..
		"button[0.3,4.5;1.6,1;select_prev;<<]"..
		"button[6.7,4.5;1.6,1;select_next;>>]"..
		"label[2.0,5.55;"..tostring(pagenum).."/"..tostring(pagemax).."]"..
		"list[detached:global_exchange;" .. p_list .. ";0.3,7;1,1;]"
end


local player_pages = {}


local function show_select(p_name)
	local pagenum = player_pages[p_name] or 1
	local start_i = (pagenum - 1) * 8 * 4

	local fs = mk_select_formspec(p_name, start_i, pagenum)
	minetest.show_formspec(p_name, select_form, fs)
end


local own_form = "global_exchange:my_orders"

local own_state = {}
-- ^ Per=player state for the own orders form. Contains these fields:
--     selected_index: The selected index
--     own_results: Results for own orders.

local function mk_own_orders_fs(p_name, results, selected)
	local fs = "size[8,8]"
	
	local state = main_state[p_name]

	fs = fs .. "label[0.5,0.2;Your Orders]"
	fs = fs .. "button[6,0;2,1;refresh;Refresh]"
	fs = fs .. table_from_results(results, 0, 2, 8, 4.5, selected or "")
	fs = fs .. "button[0,7;2,1;cancel;Cancel]"
	fs = fs .. "button[3,7;2,1;back;Back]"

	return fs
end


local function show_own_orders(p_name, results, selected)
	minetest.show_formspec(p_name, own_form, mk_own_orders_fs(p_name, results, selected))
end


-- Returns success, and also returns an error message if failed.
local function post_order(player, ex_name, order_type, item_name, amount_str, rate_str)
	local p_name = player:get_player_name()
	
	if item_name == "" then
		return false, "You must input an item"
	end
	
	if not minetest.registered_items[item_name] then
		return false, "That item does not exist."
	end

	local amount = tonumber(amount_str)
	local rate = tonumber(rate_str)

	if not amount then
		return false, "Invalid amount."
	end

	if not rate then
		return false, "Invalid rate."
	end

	local p_inv = player:get_inventory()
	local stack = ItemStack(item_name)
	stack:set_count(amount)
	
	if order_type == "buy" then
		if not p_inv:room_for_item("main", stack) then
			return false, "Not enough space in inventory."
		end

		local succ, res = exchange:buy(p_name, ex_name, item_name, amount, rate)
		if not succ then
			return false, res
		end

		stack:set_count(res)
		p_inv:add_item("main", stack)
	else
		if not p_inv:contains_item("main", stack) then
			return false, "Items not in inventory."
		end

		local succ, res = exchange:sell(p_name, ex_name, item_name, amount, rate)
		if not succ then
			return false, res
		end

		p_inv:remove_item("main", stack)
	end

	return true
end


local function handle_main(player, formname, fields)
	if formname ~= main_form then return end
	local p_name = player:get_player_name()
	local state = main_state[p_name]
	local old_fields = state.old_fields

	for k, v in pairs(fields) do
		old_fields[k] = v
	end

	if fields["select_item"] then
		show_select(p_name)
	end

	if fields["search"] then
		local now = os.time()
		local last_search = state.last_search_time

		if now - last_search < search_cooldown then
			show_main(p_name, nil, "Please wait before searching again.")
			return true
		end

		-- If the player is selling, she wants "buy" type offers.
		local order_type
		if state.sell then
			order_type = "buy"
		else
			order_type = "sell"
		end
		local item_name = fields["item"]

		local results = exchange:search_orders("", order_type, item_name)
		state.search_results = results
		state.last_search_time = now

		show_main(p_name)
	end

	if fields["sell"] then
		if fields["sell"] == "true" then
			state.sell = true
		else
			state.sell = false
		end
	end
	

	if fields["post_order"] then
		local now = os.time()
		local last_search = state.last_search_time

		if now - last_search < search_cooldown then
			show_main(p_name, nil, "Please wait before posting.")
			return true
		end

		local order_type
		if state.sell then
			order_type = "sell"
		else
			order_type = "buy"
		end
		local item_name = fields["item"]
		local amount_str = fields["amount"]
		local rate_str = fields["rate"]

		local succ, err =
			post_order(player, "", order_type, item_name, amount_str, rate_str)

		if succ then
			state.search_results = {}
			show_main(p_name, nil, nil, true)
		else
			show_main(p_name, nil, err)
		end
	end


	if fields["result_table"] then
		local results = state.search_results
		local event = minetest.explode_table_event(fields["result_table"])

		if event.type ~= "CHG" then
			return true
		end

		local index = event.row - 1
		result = results[index]
		
		if result then
			old_fields.amount = tostring(result.Amount)
			old_fields.rate = tostring(result.Rate)
		end

		show_main(p_name)
	end

	if fields["your_orders"] then
		if not own_state[p_name] then
			own_state[p_name] = {}
		end
		local o_state = own_state[p_name]

		o_state.own_results = exchange:search_player_orders(p_name) or {}

		show_own_orders(p_name, o_state.own_results)
	end

	return true
end


local function handle_select(player, formname, fields)
	if formname ~= select_form then return end

	local p_name = player:get_player_name()
	
	local pagemax = math.floor((selectable_inventory_size - 1) / (8 * 4) + 1)
	local pagenum = player_pages[p_name] or 1

	if fields["select_prev"] then
		player_pages[p_name] = math.max(1, pagenum - 1)
		show_select(p_name)
	elseif fields["select_next"] then
		player_pages[p_name] = math.min(pagemax, pagenum + 1)
		show_select(p_name)
	end

	return true
end


local function handle_own_orders(player, formname, fields)
	if formname ~= own_form then return end

	local p_name = player:get_player_name()

	local state = own_state[p_name] or {}
	local results = state.own_results or {}
	local idx = state.selected_index

	if fields["refresh"] then
		state.own_results = exchange:search_player_orders(p_name) or {}
		show_own_orders(p_name, state.own_results)
	end

	if fields["cancel"] and idx then
		local row = results[idx]
		if not row then return true end
		local p_inv = player:get_inventory()

		local amount = row.Amount
		local item = row.Item
		local stack = ItemStack(item)
		stack:set_count(amount)
		if row.Type == "sell" then
			if not p_inv:room_for_item("main", stack) then
				show_own_orders(p_name, state.own_results, "Not enough room.")
				return true
			end
		end

		local succ, err = exchange:cancel_order(p_name, row.Id)
		if succ then
			table.remove(results, idx)
			if row.Type == "sell" then
				p_inv:add_item("main", stack)
			end
		else
			-- Refresh the results, since there might have been a problem.
			state.own_results = exchange:search_player_orders(p_name) or {}
		end

		show_own_orders(p_name, state.own_results)
	end

	if fields["result_table"] then
		local event = minetest.explode_table_event(fields["result_table"])
		if event.type == "CHG" then
			state.selected_index = event.row - 1
			show_own_orders(p_name, results, event.row)
		end
	end

	if fields["back"] then
		show_main(p_name)
	end

	return true
end


minetest.register_on_player_receive_fields(handle_main)
minetest.register_on_player_receive_fields(handle_select)
minetest.register_on_player_receive_fields(handle_own_orders)


minetest.register_node("global_exchange:exchange", {
	description = "Exchange",
	tiles = {"global_exchange_atm_top.png",
		 "global_exchange_atm_top.png",
		 "global_exchange_atm_side.png",
	},
	groups = {cracky=2},
	on_rightclick = function(pos, node, clicker)
		local p_name = clicker:get_player_name()
		local state = main_state[p_name]
		if state then
			state.search_results = {}
		end

		show_main(p_name)
	end,
})
