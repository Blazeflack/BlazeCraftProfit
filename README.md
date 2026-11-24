# BlazeCraftProfit

Crafting costs and estimated auction profits inside the WoW Forever professions interface, using Goldwright prices.

The selected recipe shows two material costs: minimum auction prices and market value.
Each cost has two profits, selling the full craft at minimum or market value, after the AH fee.
Positive profit is green; negative profit is red. Hover the panel for full amounts and details.

Vendor purchase prices take priority in both cost calculations. Opening a merchant records
money-only, unlimited-stock offers at their per-item price. Prices are saved per character,
including the discount offered on that visit. Until a price is learned, Goldwright prices apply.
Owned materials still count at their full price. Missing required prices show **Unknown**.

Install alongside **Goldwright** and its appropriate price data. Without auction data, known
vendor material costs can still be shown, but auction-dependent values remain unknown.

Amounts are per craft, not per individual output item or the selected batch size. Variable
output uses the midpoint of the recipe's quantity range, explained in the tooltip. This is an estimate,
not a measured probability distribution. Deposits, failed auctions and crafting procs are not included.
The AH side and fee come from Goldwright (including its measured fee when available).

The panel appears below the reagents. If the recipe leaves too little space, it attaches below
the professions window to avoid covering crafting controls. Long amounts are available in the tooltip.
Recipes without a known auctionable item output show unknown profit. Recrafting, salvaging and
gathering recipes are not priced. Unselected ambiguous reagent alternatives remain unknown.

This is an initial version. Vendor-price persistence still requires in-game verification.
No Auctionator dependency or Auctionator source code is used.
