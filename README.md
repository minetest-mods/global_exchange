#Global Exchange

This mod provides a server-wide trading exchange for items. It is available
under GNU GPL version 3 or any later version. lsqlite3 is required by this mod,
and can be installed through luarocks. ($ sudo luarocks install lsqlite3)

Nodes
=====
 - ATM (global_exchange:atm) - Used by players to make an account, to view their
 balance, and to send money to other players.
 - Exchange (global_exchange:exchange) - Used by players to search and post
 orders, and to view a summary of current market prices.
 - Digital Mailbox (global_exchange:mailbox) - Used by players to claim items
 sent to buy orders.

Using the Exchange
==================
Main Screen
-----------
The first screen you see is where you can search and post new buy/sell orders.
Here is an overview of each element:
 - Market Summary - Pressing this will take you to the market summary screen.
 - Your Orders - This will take you to a screen where you can view and cancel
 your existing orders.
 - Item - This field is for entering the item name (e.g. default:cobble) of the
 item you want to search or post an order for.
 - Amount - This field is for entering how many of the item you want to buy/sell
 when posting an order. It has no purpose in searches.
 - Select Item - This button takes you to a screen for choosing your item
 graphically, instead of manually typing an item name.
 - Rate - This field is for entering the desired price per item when posting an
 order. For buy orders, this is the maximum price - your order will also accept
 items that are cheaper. For sell orders, this is the minimum price - your
 order will also accept buyers that are willing to pay more. The Rate field has
 no effect on searches
 - Search - This button searches existing orders for the selected item. If you
 have the "Sell" box checked, it will only display buy orders, and will display
 them in descending rate. If you have the box unchecked, it will show sell
 orders in order of ascending rate.
 - Post Order - This posts a new order for the item with the given amount and
 rate. If the "Sell" box is checked, this is a sell order, so the exchange will
 remove the items from your inventory. If it's unchecked, you are making a buy
 order, so it will deduct credits from your account. If there are already
 matching orders, it will immediately fill your order up to the amount possible,
 and the remainder will stay as a new order.
 - Sell - This checkbox determines what kind of orders to search for, and also
 what kind of order you are posting.
 - Search Results - This will display the results of your search. Clicking on an
 element here will automatically fill the "Amount" and "Rate" fields, so that if
 you click "Post Order", it will match the order you clicked.

Market Summary
--------------
This summarizes the various items available on the exchange. From left to right,
the columns display the item name, the description (what is shown in inventory),
the amount requested by buyers, the maximum rate offered by buyers, the amount
offered by sellers, and the minimum rate offered by sellers. It is updated
periodically.

Your Orders
-----------
This screen lets you see and cancel your orders. To cancel an order, click the
order and press the "Cancel" button.

Select Item
-----------
This displays a creative-style inventory menu for selecting an item for searches
or posting orders. To select an item, drag it from the inventory to the box near
the bottom of the form

Buying/Selling
==============
Once you have opened the exchange, you have a few options. If you don't already
know what you want to buy or sell, you can look at the Market Summary to get a
glance at what people are offering. After you have decided on what you are
going to do, return to the exchange page.

If you are selling an item, you should check the "Sell" checkbox. Otherwise,
leave it unchecked. Next, you need to select the item you want to deal in. There
are two ways: typing the item name (e.g. default:cobble) in manually to the item
field, or using the "Select Item" menu. If you haven't already decided on a price,
or you want to make sure your order is filled quickly, you can conduct a search.
To do this, click the "Search" button. This will give you a list of results. If
you checked the "Sell" box, then these will be buy orders, and will show the
maximum price per item each buyer is willing to accept. Otherwise, these will be
sell orders, displaying the minimum price each seller will accept. If you click
on a search result, it will automatically fill your Amount and Rate fields to
match.

The Amount and Rate fields are used to decide how much and how expensively you
want to make your order. When selling, the Rate field is the minimum price you
will accept. When buying, it is the maximum. Once everything is filled out how
you want it, press the "Post Order" button. If there are matching offers (when
you post a buy/sell offer, there are one or more sell/buy offers with a price
at least as good), then that part of your offer will immediately be filled. For
example, if you post a buy order for 10 cobblestone at 5 credits each, and there
is a sell offer for 5 cobblestone 3 credits each, it will give you 5 cobble
immediately, and leave an order on the exchange for 5 more cobblestone.

Once your offer is on the exchange, you can view or cancel it from the "Your
Orders" menu.
