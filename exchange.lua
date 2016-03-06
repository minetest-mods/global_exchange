
local sql = require("lsqlite3")
local exports = {}

local init_query = [=[
BEGIN TRANSACTION;
CREATE TABLE if not exists Credit
(
	Owner TEXT PRIMARY KEY NOT NULL,
	Balance INTEGER NOT NULL
);

CREATE TABLE if not exists Log
(
	Id INTEGER PRIMARY KEY AUTOINCREMENT,
	Recipient TEXT NOT NULL,
	Time INTEGER NOT NULL,
	Message TEXT NOT NULL
);

CREATE TABLE if not exists Orders
(
	Id INTEGER PRIMARY KEY AUTOINCREMENT,
	Poster TEXT NOT NULL,
	Exchange TEXT NOT NULL,
	Type TEXT NOT NULL CHECK(Type IN ("buy", "sell")),
	Time INTEGER NOT NULL,
	Item TEXT NOT NULL,
	Amount INTEGER NOT NULL CHECK(Amount > 0),
	Rate INTEGER NOT NULL CHECK(Rate > 0)
);

CREATE TABLE if not exists Inbox
(
	Id INTEGER PRIMARY KEY AUTOINCREMENT,
	Recipient TEXT NOT NULL,
	Item TEXT NOT NULL,
	Amount INTEGER NOT NULL CHECK(Amount > 0)
);

CREATE INDEX if not exists credit_owner
ON Credit (Owner);

CREATE INDEX if not exists index_log
ON Log (Recipient, Time);

CREATE INDEX if not exists index_orders
ON Orders (Poster, Type, Time, Item, Rate);

CREATE INDEX if not exists index_inbox
ON Inbox (Recipient);

CREATE VIEW if not exists distinct_items AS
SELECT DISTINCT Item FROM Orders;

CREATE VIEW if not exists market_summary AS
SELECT
  distinct_items.Item,
  (
    SELECT sum(Orders.Amount) FROM Orders
    WHERE Orders.Item = distinct_items.Item
    AND Orders.Type = "buy"
  ),
  (
    SELECT max(Orders.Rate) FROM Orders
    WHERE Orders.Item = distinct_items.Item
    AND Orders.Type = "buy"
  ),
  (
    SELECT sum(Orders.Amount) FROM Orders
    WHERE Orders.Item = distinct_items.Item
    AND Orders.Type = "sell"
  ),
  (
    SELECT min(Orders.Rate) FROM Orders
    WHERE Orders.Item = distinct_items.Item
    AND Orders.Type = "sell"
  )
FROM distinct_items;


END TRANSACTION;
]=]


local new_act_query = [=[
INSERT INTO Credit (Owner, Balance)
VALUES (:owner,:start_balance);
]=]


local get_balance_query = [[
SELECT Balance FROM Credit
WHERE Owner = ?;
]]


local set_balance_query = [[
UPDATE Credit
SET Balance = ?
WHERE Owner = ?;
]]


local log_query = [[
INSERT INTO Log (Recipient, Time, Message)
VALUES(?, ?, ?);
]]


local search_desc_query = [=[
SELECT * FROM Orders
WHERE Exchange = :ex_name
AND Type = :order_type
AND Item = :item_name
ORDER BY Rate DESC;
]=]


local add_order_query = [=[
INSERT INTO Orders (Poster, Exchange, Type, Time, Item, Amount, Rate)
VALUES (:p_name, :ex_name, :order_type, :time, :item_name, :amount, :rate);
]=]


local del_order_query = [=[
DELETE FROM Orders
WHERE Id = ?;
]=]


local reduce_order_query = [=[
UPDATE Orders
SET Amount = Amount - ?
WHERE Id = ?;
]=]


-- Delete an order while also checking the player.
local cancel_order_query = [=[
DELETE FROM Orders
WHERE Id = :id
AND Poster = :p_name
]=]


local refund_order_query = [=[
UPDATE Credit
SET Balance = Balance + coalesce((
      SELECT sum(Rate * Amount) FROM Orders
      WHERE Poster = :p_name
      AND Type = "buy"
      AND Id = :id
    ), 0)
WHERE Owner = :p_name;
]=]


local search_asc_query = [=[
SELECT * FROM Orders
WHERE Exchange = :ex_name
AND Type = :order_type
AND Item = :item_name
ORDER BY Rate ASC;
]=]

local search_min_query = [=[
SELECT * FROM Orders
WHERE Exchange = :ex_name
AND Type = :order_type
AND Item = :item_name
AND Rate >= :rate_min
ORDER BY Rate DESC;
]=]


local search_max_query = [=[
SELECT * FROM Orders
WHERE Exchange = :ex_name
AND Type = :order_type
AND Item = :item_name
AND Rate <= :rate_max
ORDER BY Rate ASC;
]=]


local search_own_query = [=[
SELECT * FROM Orders
WHERE Poster = :p_name;
]=]


local insert_inbox_query = [=[
INSERT INTO Inbox(Recipient, Item, Amount)
VALUES(?, ?, ?);
]=]


local view_inbox_query = [=[
SELECT * FROM Inbox
WHERE Recipient = ?;
]=]


local get_inbox_query = [=[
SELECT Amount FROM Inbox
WHERE Id = :id;
]=]

local red_inbox_query = [=[
UPDATE Inbox
SET Amount = Amount - :change
WHERE Id = :id;
]=]

local del_inbox_query = [=[
DELETE FROM Inbox
WHERE Id = :id;
]=]

local summary_query = [=[
SELECT * FROM market_summary;
]=]

local transaction_log_query = [=[
SELECT Time, Message FROM Log
WHERE Recipient = :p_name
ORDER BY Time DESC;
]=]


local ex_methods = {}
local ex_meta = { __index = ex_methods }


local function sql_error(err)
	error("SQL error: " .. err)
end


local function is_integer(num)
	return num%1 == 0
end


local function exec_stmt(db, stmt, names)
	stmt:bind_names(names)

	local res = stmt:step()
	stmt:reset()

	if res == sqlite3.BUSY then
		return false, "Database Busy."
	elseif res ~= sqlite3.DONE then
		sql_error(db:errmsg())
	else
		return true
	end
end


function exports.open_exchange(path)
	local db = assert(sqlite3.open(path))

	local res = db:exec(init_query)

	if res ~= sqlite3.OK then
		sql_error(db:errmsg())
	end

	local stmts = {
		new_act_stmt = assert(db:prepare(new_act_query)),
		get_balance_stmt = assert(db:prepare(get_balance_query)),
		set_balance_stmt = assert(db:prepare(set_balance_query)),
		log_stmt = assert(db:prepare(log_query)),
		search_desc_stmt = assert(db:prepare(search_desc_query)),
		search_asc_stmt = assert(db:prepare(search_asc_query)),
		search_min_stmt = assert(db:prepare(search_min_query)),
		search_max_stmt = assert(db:prepare(search_max_query)),
		search_own_stmt = assert(db:prepare(search_own_query)),
		add_order_stmt = assert(db:prepare(add_order_query)),
		del_order_stmt = assert(db:prepare(del_order_query)),
		reduce_order_stmt = assert(db:prepare(reduce_order_query)),
		cancel_order_stmt = assert(db:prepare(cancel_order_query)),
		refund_order_stmt = assert(db:prepare(refund_order_query)),
		insert_inbox_stmt = assert(db:prepare(insert_inbox_query)),
		view_inbox_stmt = assert(db:prepare(view_inbox_query)),
		get_inbox_stmt = assert(db:prepare(get_inbox_query)),
		red_inbox_stmt = assert(db:prepare(red_inbox_query)),
		del_inbox_stmt = assert(db:prepare(del_inbox_query)),
		summary_stmt = assert(db:prepare(summary_query)),
		transaction_log_stmt = assert(db:prepare(transaction_log_query)),
	}


	local ret = { db = db,
		      stmts = stmts,
	}
	setmetatable(ret, ex_meta)

	return ret
end


function ex_methods.close(self)
	for k, v in pairs(self.stmts) do
		v:finalize()
	end

	self.db:close()
end

-- Returns success boolean
function ex_methods.log(self, message, recipient)
	recipient = recipient or ""

	local db = self.db
	local stmt = self.stmts.log_stmt

	stmt:bind_values(recipient, os.time(), message)

	local res = stmt:step()
	stmt:reset()

	if res == sqlite3.ERROR then
		sql_error(db:errmsg())
	elseif res == sqlite3.MISUSE then
		error("Programmer error.")
	elseif res == sqlite3.BUSY then
		return false, "Failed to log message."
	else
		return true
	end
end


-- Returns success boolean and error.
function ex_methods.new_account(self, p_name, amt)
	local db = self.db
	amt = amt or 0

	local exists = self:get_balance(p_name)

	if exists then
		return false, "Account already exists."
	end

	db:exec("BEGIN TRANSACTION;")

	local stmt = self.stmts.new_act_stmt

	stmt:bind_names({
		owner = p_name,
		start_balance = amt,
		time = os.time(),
	})

	local res = stmt:step()

	if res == sqlite3.MISUSE then
		error("Programmer error.")
	elseif res == sqlite3.BUSY then
		stmt:reset()
		db:exec("ROLLBACK;")
		return false, "Database Busy."
	elseif res ~= sqlite3.DONE then
		sql_error(db:errmsg())
	end

	stmt:reset()

	local log_succ1, log_err1 =
		self:log("Account opened with balance " .. amt, p_name)
	local log_succ2, log_err2 =
		self:log(p_name .. " opened an account with balance " .. amt)

	if not log_succ1 then
		db:exec("ROLLBACK;")
		return false, log_err1
	end

	if not log_succ2 then
		db:exec("ROLLBACK;")
		return false, log_err2
	end

	db:exec("COMMIT;")

	return true
end


-- Returns nil if no balance.
function ex_methods.get_balance(self, p_name)
	local db = self.db
	local stmt = self.stmts.get_balance_stmt

	stmt:bind_values(p_name)
	local res = stmt:step()

	if res == sqlite3.ERROR then
		sql_error(db:errmsg())
	elseif res == sqlite3.MISUSE then
		error("Programmer error.")
	elseif res == sqlite3.ROW then
		local balance = stmt:get_value(0)
		stmt:reset()

		return balance
	end

	stmt:reset()
end


-- Returns success boolean, and error message if false.
function ex_methods.set_balance(self, p_name, new_bal)
	local db = self.db
	local set_stmt = self.stmts.set_balance_stmt

	local bal = self:get_balance(p_name)

	if not bal then
		return false, p_name .. " does not have an account."
	end

	set_stmt:bind_values(new_bal, p_name)
	local res = set_stmt:step()

	if res == sqlite3.ERROR then
		sql_error(db:errmsg())
	elseif res == sqlite3.MISUSE then
		error("Programmer error.")
	elseif res == sqlite3.BUSY then
		set_stmt:reset()
		return false, "Database busy"
	else
		set_stmt:reset()
		return true
	end
end


-- Change balance by the given amount. Returns a success boolean, and error
-- message on fail.
function ex_methods.change_balance(self, p_name, delta)
	if not is_integer(delta)  then
		error("Non-integer credit delta")
	end

	local bal = self:get_balance(p_name)

	if not bal then
		return false, p_name .. " does not have an account."
	end

	if bal + delta < 0 then
		return false, p_name .. " does not have enough money."
	end

	if delta > 0 then
		self:log("Deposited " .. delta .. " credits", p_name)
	else --assume delta is never 0
		self:log("Withdrew " .. -delta .. " credits", p_name)
	end

	return self:set_balance(p_name, bal + delta)
end


-- Sends credits from one user to another. Returns a success boolean, and error
-- message on fail.
function ex_methods.transfer_credits(self, sender, receiver, amt)
	local db = self.db

	if not is_integer(amt) then
		return false, "Non-integer credit amount"
	end

	db:exec("BEGIN TRANSACTION;")

	local succ_minus, err = self:change_balance(sender, -amt)

	if not succ_minus then
		db:exec("ROLLBACK")
		return false, err
	end

	local succ_plus, err = self:change_balance(receiver, amt)

	if not succ_plus then
		db:exec("ROLLBACK")
		return false, err
	end

	local succ_log1 = self:log("Sent " .. amt .. " credits to " .. receiver, sender)

	if not succ_log1 then
		db:exec("ROLLBACK")
		return false, "Failed to log sender message"
	end

	local succ_log2 = self:log("Received " .. amt .. " credits from " .. sender, receiver)

	if not succ_log2 then
		db:exec("ROLLBACK")
		return false, "Failed to log receiver message"
	end

	db:exec("COMMIT;")

	return true
end


function ex_methods.give_credits(self, p_name, amt, msg)
	local db = self.db

	db:exec("BEGIN TRANSACTION;")

	local succ_change, err = self:change_balance(p_name, amt)

	if not succ_change then
		db:exec("ROLLBACK;")
		return false, err
	end

	local succ_log, err = self:log(msg, p_name)

	if not succ_log then
		db:exec("ROLLBACK;")
		return false, er
	end

	db:exec("COMMIT;")

	return true
end


-- Returns a list of orders, sorted by price.
function ex_methods.search_orders(self, ex_name, order_type, item_name)
	local stmt
	if order_type == "buy" then
		stmt = self.stmts.search_asc_stmt
	else
		stmt = self.stmts.search_desc_stmt
	end

	stmt:bind_names({
		ex_name = ex_name,
		order_type = order_type,
		item_name = item_name,
	})

	local orders,n = {},1

	for tab in stmt:nrows() do
		orders[n] = tab
		n = n+1
	end

	stmt:reset()
	return orders
end


-- Same as above, except not sorted in any particular order.
function ex_methods.search_player_orders(self, p_name)
	local stmt = self.stmts.search_own_stmt

	stmt:bind_names({p_name = p_name})

	local orders,n = {},1

	for tab in stmt:nrows() do
		orders[n] = tab
		n = n+1
	end

	stmt:reset()
	return orders
end


-- Adds a new order. Returns success, and an error string if failed.
function ex_methods.add_order(self, p_name, ex_name, order_type, item_name, amount, rate)
	if math.floor(amount) ~= amount then
		return false, "Noninteger quantity"
	end

	if amount <= 0 then
		return false, "Nonpositive quantity"
	end

	if math.floor(rate) ~= rate then
		return false, "Noninteger rate"
	end

	if rate <= 0 then
		return false, "Nonpositive rate"
	end

	local db = self.db
	local stmt = self.stmts.add_order_stmt

	stmt:bind_names({
		p_name = p_name,
		ex_name = ex_name,
		order_type = order_type,
		time = os.time(),
		item_name = item_name,
		amount = amount,
		rate = rate,
	})

	local res = stmt:step()

	if res == sqlite3.BUSY then
		stmt:reset()
		return false, "Database Busy"
	elseif res ~= sqlite3.DONE then
		sql_error(db:errmsg())
	end

	stmt:reset()
	return true
end


-- Returns true, or false and an error message.
function ex_methods.cancel_order(self, p_name, id, order_type, item_name, amount, rate)
	local params = { p_name = p_name,
			 id = id,
	}

	local db = self.db
	db:exec("BEGIN TRANSACTION;")

	local refund_stmt = self.stmts.refund_order_stmt
	local cancel_stmt = self.stmts.cancel_order_stmt

	local ref_succ, ref_err = exec_stmt(db, refund_stmt, params)
	if not ref_succ then
		db:exec("ROLLBACK")
		return false, ref_err
	end

	local canc_succ, canc_err = exec_stmt(db, cancel_stmt, params)
	if not canc_succ then
		db:exec("ROLLBACK")
		return false, canc_err
	end

	local message = "Cancelled an order to " ..
		order_type .. " " .. amount .. " " .. item_name .. "."

	if order_type == "buy" then
		message = message .. " (+" .. amount * rate .. ")"
	end

	local succ, err = self:log(message, p_name)
	if not succ then
		db:exec("ROLLBACK")
		return false, err
	end

	db:exec("COMMIT;")

	return true
end


-- Puts things in a player's item inbox. Returns success, and also returns an
-- error message if failed.
function ex_methods.put_in_inbox(self, p_name, item_name, amount)
	local db = self.db
	local stmt = self.stmts.insert_inbox_stmt

	stmt:bind_values(p_name, item_name, amount)

	local res = stmt:step()
	if res == sqlite3.BUSY then
		return false, "Database Busy."
	elseif res ~= sqlite3.DONE then
		sql_error(db:errmsg())
	end

	stmt:reset()

	return true
end


-- Tries to buy from orders at the provided rate, and posts an offer with any
-- remaining desired amount. Returns success. If succeeded, also returns amount
-- bought. If failed, returns an error message
function ex_methods.buy(self, p_name, ex_name, item_name, amount, rate)
	if not is_integer(amount) then
		return false, "Noninteger quantity"
	elseif amount <= 0 then
		return false, "Nonpositive quantity"
	elseif not is_integer(rate) then
		return false, "Noninteger rate"
	elseif rate <= 0 then
		return false, "Nonpositive rate"
	end

	local db = self.db

	local bal = self:get_balance(p_name)

	if not bal then
		return false, "Nonexistent account."
	end

	if bal < amount * rate then
		return false, "Not enough money."
	end


	db:exec("BEGIN TRANSACTION");

	local remaining = amount

	local del_stmt = self.stmts.del_order_stmt
	local red_stmt = self.stmts.reduce_order_stmt
	local search_stmt = self.stmts.search_max_stmt

	search_stmt:bind_names({
		ex_name = ex_name,
		order_type = "sell",
		item_name = item_name,
		rate_max = rate,
	})

	for row in search_stmt:nrows() do
		local poster = row.Poster
		local row_amount = row.Amount

		if row_amount <= remaining then
			del_stmt:bind_values(row.Id)

			local del_res = del_stmt:step()
			if del_res == sqlite3.BUSY then
				del_stmt:reset()
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, "Database Busy."
			elseif del_res ~= sqlite3.DONE then
				sql_error(db:errmsg())
			end
			del_stmt:reset()

			local ch_succ, ch_err =
				self:change_balance(poster, rate * row_amount)
			if not ch_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, ch_err
			end

			local log_succ, log_err =
				self:log(p_name .. " bought " .. row_amount .. " "
						 .. item_name .. " from you. (+"
						 .. rate * row_amount .. ")", poster)
			if not log_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, log_err
			end

			local log2_succ, log2_err =
				self:log("Bought " .. row_amount .. " " .. item_name
						 .. " from " .. poster
						 .. "(-" .. rate * row_amount .. ")",p_name)
			if not log2_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, log2_err
			end

			remaining = remaining - row_amount
		else -- row_amount > remaining
			red_stmt:bind_values(remaining, row.Id)

			local red_res = red_stmt:step()
			if red_res == sqlite3.BUSY then
				red_stmt:reset()
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, "Database Busy."
			elseif red_res ~= sqlite3.DONE then
				red_stmt:reset()
				search_stmt:reset()
				sql_error(db:errmsg())
			end
			red_stmt:reset()

			local ch_succ, ch_err =
				self:change_balance(poster, rate * remaining)
			if not ch_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, ch_err
			end

			local log_succ, log_err =
				self:log(p_name .. " bought " .. remaining .. " "
						 .. item_name .. " from you. (+"
						 .. rate * remaining .. ")", poster)
			if not log_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, log_err
			end

			local log2_succ, log2_err =
				self:log("Bought " .. remaining .. " " .. item_name
						 .. " from " .. poster .. " (-"
						 .. rate * remaining .. ")", p_name)
			if not log2_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, log2_err
			end

			remaining = 0
		end

		if remaining == 0 then break end
	end

	search_stmt:reset()

	local bought = amount - remaining
	local cost = amount * rate
	local ch_succ, ch_err = self:change_balance(p_name, -cost)
	if not ch_succ then
		db:exec("ROLLBACK;")
		return false, ch_err
	end

	if remaining > 0 then
		local add_succ, add_err =
			self:add_order(p_name, ex_name, "buy", item_name, remaining, rate)

		if not add_succ then
			db:exec("ROLLBACK;")
			return false, add_err
		end

		local log_succ, log_err =
		self:log("Posted buy offer for "
				 .. remaining .. " " .. item_name .. " at "
				 .. rate .. "/item (-"
				 .. remaining * rate .. ")", p_name)

		if not log_succ then
			db:exec("ROLLBACK;")
			return false, log_err
		end
	end

	db:exec("COMMIT;")

	return true, bought
end


-- Tries to sell to orders at the provided rate, and posts an offer with any
-- remaining desired amount. Returns success. If failed, returns an error message.
function ex_methods.sell(self, p_name, ex_name, item_name, amount, rate)
	if not is_integer(amount) then
		return false, "Noninteger quantity"
	elseif amount <= 0 then
		return false, "Nonpositive quantity"
	elseif not is_integer(rate) then
		return false, "Noninteger rate"
	elseif rate <= 0 then
		return false, "Nonpositive rate"
	end

	local db = self.db

	db:exec("BEGIN TRANSACTION");

	local remaining = amount
	local revenue = 0

	local del_stmt = self.stmts.del_order_stmt
	local red_stmt = self.stmts.reduce_order_stmt
	local search_stmt = self.stmts.search_min_stmt

	search_stmt:bind_names({
		ex_name = ex_name,
		order_type = "buy",
		item_name = item_name,
		rate_min = rate,
	})

	for row in search_stmt:nrows() do
		local poster = row.Poster
		local row_amount = row.Amount

		if row_amount <= remaining then
			del_stmt:bind_values(row.Id)

			local del_res = del_stmt:step()
			if del_res == sqlite3.BUSY then
				del_stmt:reset()
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, "Database Busy."
			elseif del_res ~= sqlite3.DONE then
				sql_error(db:errmsg())
			end
			del_stmt:reset()

			local in_succ, in_err =
				self:put_in_inbox(poster, item_name, row_amount)
			if not in_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, in_err
			end

			local log_succ, log_err =
				self:log(p_name .. " sold " .. row_amount .. " "
						 .. item_name .. " to you." , poster)
			if not log_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, log_err
			end

			local log2_succ, log2_err =
				self:log("Sold " .. row_amount .. " " .. item_name
						 .. " to " .. poster
						 .. "(+" .. rate * row_amount .. ")",p_name)
			if not log2_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, log2_err
			end

			remaining = remaining - row_amount
			revenue = revenue + row_amount * row.Rate
		else -- row_amount > remaining
			red_stmt:bind_values(remaining, row.Id)

			local red_res = red_stmt:step()
			if red_res == sqlite3.BUSY then
				red_stmt:reset()
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, "Database Busy."
			elseif red_res ~= sqlite3.DONE then
				red_stmt:reset()
				search_stmt:reset()
				sql_error(db:errmsg())
			end
			red_stmt:reset()

			local in_succ, in_err =
				self:put_in_inbox(poster, item_name, remaining)
			if not in_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, in_err
			end

			local log_succ, log_err =
				self:log(p_name .. " sold " .. remaining .. " "
						 .. item_name .. " to you.", poster)
			if not log_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, log_err
			end

			local log2_succ, log2_err =
				self:log("Sold " .. row_amount .. " " .. item_name
						 .. " to " .. poster .. " (+"
						 .. rate * remaining .. ")", p_name)
			if not log2_succ then
				search_stmt:reset()
				db:exec("ROLLBACK;")
				return false, log2_err
			end
			
			revenue = revenue + remaining * row.Rate
			remaining = 0
		end

		if remaining == 0 then break end
	end

	search_stmt:reset()

	local ch_succ, ch_err = self:change_balance(p_name, revenue)
	if not ch_succ then
		db:exec("ROLLBACK;")
		return false, ch_err
	end

	if remaining > 0 then
		local add_succ, add_err =
			self:add_order(p_name, ex_name, "sell", item_name, remaining, rate)

		if not add_succ then
			db:exec("ROLLBACK;")
			return false, add_err
		end

	end

	db:exec("COMMIT;")

	return true
end


-- On success, returns true and a list of inbox entries.
-- TODO: On failure, return false and an error message.
function ex_methods.view_inbox(self, p_name)
	local stmt = self.stmts.view_inbox_stmt

	stmt:bind_values(p_name)

	local res,n = {},1

	for row in stmt:nrows() do
		res[n] = row
		n = n+1
	end

	stmt:reset()

	return true, res
end


-- Returns success boolean. On success, also returns the number actually
-- taken. On failure, also returns an error message
function ex_methods.take_inbox(self, id, amount)
	local db = self.db
	local get_stmt = self.stmts.get_inbox_stmt
	local red_stmt = self.stmts.red_inbox_stmt
	local del_stmt = self.stmts.del_inbox_stmt

	get_stmt:bind_names({
		id = id,
		change = amount
	})

	local res = get_stmt:step()

	if res == sqlite3.BUSY then
		get_stmt:reset()
		return false, "Database Busy."
	elseif res == sqlite3.DONE then
		get_stmt:reset()
		return false, "Order does not exist."
	elseif res ~= sqlite3.ROW then
		sql_error(db:errmsg())
	end

	local available = get_stmt:get_value(0)
	get_stmt:reset()

	db:exec("BEGIN TRANSACTION;")

	if available > amount then
		red_stmt:bind_names({
			id = id,
			change = amount
		})

		local red_res = red_stmt:step()

		if red_res == sqlite3.BUSY then
			red_stmt:reset()
			db:exec("ROLLBACK;")
			return false, "Database Busy."
		elseif red_res ~= sqlite3.DONE then
			sql_error(db:errmsg())
		end

		red_stmt:reset()
	else
		del_stmt:bind_names({
			id = id,
		})

		local del_res = del_stmt:step()

		if del_res == sqlite3.BUSY then
			del_stmt:reset()
			db:exec("ROLLBACK;")
			return false, "Database Busy."
		elseif del_res ~= sqlite3.DONE then
			sql_error(db:errmsg())
		end

		del_stmt:reset()
	end

	db:exec("COMMIT;")
	return true, math.min(amount, available)

end


-- Returns a list of tables with fields:
--   item_name: Name of the item
--   buy_volume: Number of items sought
--   buy_max: Maximum buy rate
--   sell_volume: Number of items for sale
--   sell_min: Minimum sell rate
function ex_methods.market_summary(self)
	local stmt = self.stmts.summary_stmt

	local res,n = {},1
	for a in stmt:rows() do
		res[n] = {
			item_name = a[1],
			buy_volume = a[2],
			buy_max = a[3],
			sell_volume = a[4],
			sell_min = a[5],
		}
		n = n+1
	end
	stmt:reset()

	return res
end


-- Returns a list of log entries, sorted by time.
function ex_methods.player_log(self, p_name)
	local stmt = self.stmts.transaction_log_stmt
	stmt:bind_names({ p_name = p_name })

	local res,n = {},1

	for row in stmt:nrows() do
		res[n] = row
		n = n+1
	end

	stmt:reset()

	return res
end

function exports.test()
	local ex = exports.open_exchange("test.db")

	local alice_bal = ex:get_balance("Alice")
	local bob_bal = ex:get_balance("Bob")


	local function print_balances()
		print("Alice: ", ex:get_balance("Alice"))
		print("Bob: ", ex:get_balance("Bob"))
	end


	-- Initialize balances
	if alice_bal then
		ex:set_balance("Alice", 420)
	else
		ex:new_account("Alice", 420)
	end

	if bob_bal then
		ex:set_balance("Bob", 2015)
	else
		ex:new_account("Bob", 2015)
	end

	print_balances()


	-- Transfer a valid amount
	print("Transfering 1000 credits from Bob to Alice")

	local succ, err = ex:transfer_credits("Bob", "Alice", 1000)

	print("Success: ", succ, " ", err)
	print_balances()


	-- Transfer an invalid amount
	print("Transfering 3000 credits from Alice to Bob")

	local succ, err = ex:transfer_credits("Alice", "Bob", 3000)

	print("Success: ", succ, " ", err)
	print_balances()


	-- Simulate a transaction
	print("Alice posting an offer to buy 10 cobble at 2 credits each")
	local succ, err = ex:buy("Alice", "", "default:cobble", 10, 2)
	print("Success: ", succ, " ", err)
	print_balances()

	print("Bob posting an offer to sell 20 cobble at 1 credits each")
	local succ, err = ex:sell("Bob", "", "default:cobble", 20, 1)
	print("Success: ", succ, " ", err)
	print_balances()

	ex:close()
end


return exports
