# Engine

Within the Planar "model", we use the _call!_ and _call!_ functions to communicate between _strategies_ and _executors_. The executor calls the strategy, implying that the strategy should do or return something. The strategy calls the executor, expecting it to do or return something.

In the Planar framework, the user generally only writes `call!` functions within their strategies.

Unlike other trading bots that offer a set of methods for tuning purposes, usually tied to the super class of the strategy, Planar conventionally deals only with `call!` functions. This allows you to know that whenever a _call!_ call is made from the strategy, it is a point where simulation and live execution may diverge.

The functions are implemented in a way that they dispatch differently according to the execution mode of the strategy. There are 3 execution modes:

- `Sim`: This mode is used by the backtester to run simulations.
- `Paper`: This is the dry run mode, which runs the bot as if it were live, working with live data feeds and simulating order execution with live prices.
- `Live`: Similar to `Paper`, but with order execution actually forwarded to a live exchange (e.g., through CCXT).

If the strategy is instantiated in `Sim` mode, calling `call!(s, ...)`, where `s` is the strategy object of type `Strategy{Sim, N, E, M, C}`, the `call!` function will dispatch to the `Sim` execution method. The other two parameters, `N` and `E`, are required for concretizing the strategy type:
- `N<:Symbol`: The symbol that matches the module name of the strategy, such as `:Example`.
- `E<:ExchangeID`: The symbol that has already been checked to match a valid CCXT exchange, which will be the exchange that the strategy will operate on.
- `M<:MarginMode`: The margin mode of the strategy, which can be `NoMargin`, `IsolatedMargin`, or `CrossMargin`. Note that the margin mode also has a type parameter to specify if hedged positions (having long and short on the same asset at the same time) are allowed. `Isolated` and `Cross` are shorthand for `IsolatedMargin{NotHedged}` and `CrossMargin{NotHedged}`.
- `C`: The symbol of the `CurrencyCash` that represents the balance of the strategy, e.g., `:USDT`.

To follow the `call!` dispatch convention, you can expect the first argument of every call function to the executor to be the strategy object itself, while strategy functions might have either the strategy object or the type of the strategy as the first argument (`Type{Strategy{...}}`).
    

