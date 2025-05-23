# What is Planar?

Planar is a bot for running automated trading strategies. It allows for interactive experimentation of new strategies through the julia REPL, and their live deployment to trading exchanges with almost zero code replication.

The bot is based around the concept of _strategies_. A strategy requires a primary currency which represents its balance and a primary exchange where all the orders will be forwarded (and against which they will be checked for validity).

Writing a planar strategy is equivalent to writing a julia module, that the bot will load (either dynamically or statically on deployments). Within the module you import the planar interface, such that you can specialize `call!` entry functions relative only to your strategy, the rest is up to you.

The framework provides a long list of convenience or utility functions to manipulate the strategy and assets objects defined in different modules. In fact the bot is quite modular and is made of almost 30 packages, even though the majority of them is required to actually run the bot.

From the strategy you can manage orders through `call!` functions and expect them to be executed during simulation and live trading (through the CCXT library, and other venues in a possible future) while returning _the same data structures_ even if populated through different means.

The advantage of Planar over trading bots written in other programming languages is its flexibility thanks to the julia parametric type system that allows to extend the bot by specializing functions to perform ad hoc logic. An exchange is behaving differently compared to others? You can specialize the `balance` function over only that particular exchange by defining:

``` julia
balance(exc::Exchange{:MyQuirkyExchange}, args...) ... end
```

where `:MyQuirkyExchange` is the `ExchangeID` symbol of the exchange you are targeting. 

This is how strategy `call!` functions also dispatch, because the strategies always have in their type parameters the `Symbol` which matches the module of the strategy itself. Indeed you cannot define multiple strategies with the same name.
And it is also how we are able to have almost zero code duplication between simulation and live trading, the execution mode is just another type parameter of the strategy.

The bot has tools to download, clean and store data, that make use of popular julia libraries. See [Data](data.md), and tools to resample time series see [Processing](./API/processing.md).

It can:
- track live data like tickers, trades, ohlcv, see [Watchers](watchers/watchers.md).
- compute statistics about backtest runs, see [Metrics](metrics.md)
- generate interactive and fully browsable plots for ohlcv data, indicators and backtesting runs, see [Plotting](plotting.md)
- Optimize strategy parameters [Optimization](optimization.md)

## Install (docker)
Recommended installation is through docker. There are 4 images:

|                                | precompiled 🧰               | sysimage 📦 |
|--------------------------------|------------------------------|---|
| only runtime 🖥‍                 | `planar-precomp`             | `planar-sysimage`   |
| with plotting and optimizer 📊 | `planar-precomp-interactive` | `planar-sysimage-interactive` |

```@setup
# Precompiled images are smaller, more flexible but have a slower startup. Compiled images are bigger, there might be unexpected issues, but are faster to startup.
```



```shell
docker pull docker.io/psydyllic/planar-precomp
docker run -it --rm docker.io/psydyllic/planar-precomp julia
using Planar # or PlanarInteractive for plotting and optimization
```

## Install (git)

Planar.jl requires at least Julia 1.9. Is not in the julia registry, to install it do the following:

- Clone the repository:
```bash
git clone --recurse-submodules https://github.com/psydyllic/Planar.jl
```
- Check the env vars in `.envrc`, then enabled them with `direnv allow`.
```bash
cd Planar.jl
direnv allow
```
- Activate the project specified by `JULIA_PROJECT` in the `.envrc`.
```bash
julia 
```
- Download and build dependencies:
```julia
] instantiate
using Planar  # or PlanarInteractive for plotting and optimization
```

## Quickstart

Load the default strategy, which you can look up at `./user/strategies/SimpleStrategy/` or [make your own](./strategy.md#Setup-a-new-strategy).

```julia
using Planar

@environment! # brings modules in scope
# arguments override defaults (see `s.config` fields)
s = strategy(:SimpleStrategy, exchange=:binance) 
```

Download some data:

```julia
# download last 1000 candles from strategy exchange
fetch_ohlcv(s, from=-1000) 
```

Load the data into the strategy universe:

```julia
load_ohlcv(s)
```

Backtest the strategy within the period available from the loaded data.

```julia
start!(s)
```

Plot the simulated trades.

```julia
using Plotting
using WGLMakie # or `GLMakie`
plots!() # or `Pkg.activate("PlanarInteractive"); using PlanarInteractive`
balloons(s)
```

## Packages
The most relevant underlying Planar modules.

- [Engine](./engine/engine.md): The actual backtest engine.
- [Strategies](./strategy.md): Types and concept for building strategies.
- [Exchanges](./exchanges.md): Loads exchanges instances, markets and pairlists, based on [ccxt](https://docs.ccxt.com/en/latest/manual.html).
- [Plotting](./plotting.md): Output plots for ohlcv data, indicators, backtests, based on [Makie](https://github.com/MakieOrg/Makie.jl).
- [Remote](./remote.md) Control the bot remotely.
- [Data](./data.md): Loading and saving ohlcv data (and more), based Zarr.
- [Metrics](./metrics.md): Statistics about backtests, and live operations.
- [Processing](./API/processing.md): Data cleanup, normalization, resampling functions.
- [Watchers](./watchers/watchers.md): Services for data pipelines, from sources to storage.
- [Misc](./API/misc.md): Ancillary stuff, like configuration, and some UI bits.
- [StrategyTools](./API/strategytools.md) and [StrategyStats](./API/strategystats.md): Offer some utilities to build strategies (rely on additional dependencies)

## Infos

- [Troubleshooting](./troubleshooting.md)
- [Devdocs](./devdocs.md)
- [Contacts](./contacts.md)
  
