
local exchange = ...

local mailbox_form = "global_exchange:digital_mailbox"

local mailbox_contents = {}
local selected_index = {}
-- Map from player names to their most recent search result

local function get_mail(p_name)
	local mail_maybe = mailbox_contents[p_name]
	if mail_maybe then
		return mail_maybe
	else
		mailbox_contents[p_name] = {}
		return mailbox_contents[p_name]
	end
end


local function mk_inbox_list(results, x, y, w, h)
	local res = {}
	table.insert(res, "textlist[")
	table.insert(res, tostring(x))
	table.insert(res, ",")
	table.insert(res, tostring(y))
	table.insert(res, ";")
	table.insert(res, tostring(w))
	table.insert(res, ",")
	table.insert(res, tostring(h))
	table.insert(res, ";result_list;")

	for i, row in ipairs(results) do
		table.insert(res, row.Amount .. " " .. row.Item)
		table.insert(res, ",")
	end
	table.insert(res, "]")

	return table.concat(res)
end


local function mk_mail_fs(p_name, results, err_str)
	fs = "size[6,8]"
	fs = fs .. "label[0,0;Inbox]"
	if err_str then
		fs = fs .. "label[3,0;Error: " .. err_str .. "]"
	end
	fs = fs .. mk_inbox_list(results, 0, 1, 6, 6)
	fs = fs .. "button[0,7;2,1;claim;Claim]"

	return fs
end


local function show_mail(p_name, results, err_str)
	minetest.show_formspec(p_name, mailbox_form, mk_mail_fs(p_name, results, err_str))
end


local function handle_fields(player, formname, fields)
	if formname ~= mailbox_form then return end
	if fields["quit"] then return true end

	local p_name = player:get_player_name()
	local idx = selected_index[p_name]

	if fields["claim"] and idx then
		local row = get_mail(p_name)[idx]

		if row then
			local stack = ItemStack(row.Item)
			stack:set_count(row.Amount)

			local p_inv = player:get_inventory()
			if not p_inv:room_for_item("main", stack) then
				show_mail(p_name, get_mail(p_name), "Not enough room.")
				return true
			end
			
			local succ, res = exchange:take_inbox(row.Id, row.Amount)
			if not succ then
				show_mail(p_name, get_mail(p_name), res)
			end

			stack:set_count(res)

			p_inv:add_item("main", stack)

			table.remove(get_mail(p_name), idx)
			show_mail(p_name, get_mail(p_name))
		end
	end

	if fields["result_list"] then
		local event = minetest.explode_textlist_event(fields["result_list"])

		if event.type == "CHG" then
			selected_index[p_name] = event.index
		end
	end

	return true
end


minetest.register_on_player_receive_fields(handle_fields)


minetest.register_node("global_exchange:mailbox", {
	description = "Digital Mailbox",
	tiles = {"global_exchange_atm_top.png",
		 "global_exchange_atm_top.png",
		 "global_exchange_mailbox_side.png",
	},
	groups = {cracky=2},
	on_rightclick = function(pos, node, clicker)
		local p_name = clicker:get_player_name()
		local succ, res = exchange:view_inbox(p_name)
		mailbox_contents[p_name] = res
		minetest.show_formspec(p_name, mailbox_form, mk_mail_fs(p_name, res))
	end,
})


minetest.register_craft( {
	output = "global_exchange:mailbox",
	recipe = {
		{ "default:stone", "default:gold_ingot", "default:stone" },
		{ "default:stone", "default:chest", "default:stone" },
		{ "default:stone", "default:stone", "default:stone" },
	}
})
