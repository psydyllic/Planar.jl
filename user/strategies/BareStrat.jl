@doc "!!! editing this file triggers precompilation."
module BareStrat
using ..Strategies: Strategies as st
using .st
using .st.ExchangeTypes
using .st.ExchangeTypes.Ccxt: ccxt_exchange
using .st.TimeTicks
using .st: AssetCollection
import .st: call!
using .st.Misc: Sim, NoMargin, Paper, call!
using .st.Instances: ByPos, BySide, Isolated, Long, Short, cash, posside, position
using .st: Buy, Sell
using .st.OrderTypes: MarketOrder, ShortMarketOrder

const DESCRIPTION = "BaseStrat"
const EXC = :binance
const EXCID = ExchangeTypes.ExchangeID(EXC)
const S{M} = Strategy{M,nameof(@__MODULE__),typeof(EXCID),Isolated}
const SC{E,M,R} = Strategy{M,nameof(@__MODULE__()),E,R}
const TF = tf"1m"

function call!(s::S, ::ResetStrategy) end

call!(_::S, ::WarmupPeriod) = Day(1)

function ordertp(
    ai, ::BySide{O}=ifelse(P == Long, Buy, Sell), ::ByPos{P}=posside(ai)
) where {O,P}
    ifelse(P == Long, MarketOrder{O}, ShortMarketOrder{O})
end

function call!(s::T, ts::DateTime, ctx) where {T<:SC}
    date = ts
    foreach(s.universe) do ai
        oside = rand((Buy, Sell))
        pside = rand((Long, Short))
        tp = ordertp(ai, oside, pside)
        if isopen(ai)
            if posside(ai) == pside
                tp = ordertp(ai, oside, pside)
                call!(s, ai, tp; amount=float(ai) / 3, date)
            elseif ismargin(s)
                this_pos = position(ai)
                this_side = posside(this_pos)
                while isopen(this_pos)
                    call!(s, ai, this_side, date, PositionClose())
                end
                call!(s, ai, tp; amount=ai.limits.amount.min, date)
            end
        elseif cash(s) > ai.limits.cost.min
            call!(s, ai, tp; amount=ai.limits.amount.min, date)
        end
    end
end

function call!(::Type{<:SC}, ::StrategyMarkets)
    ["BTC/USDT:USDT", "ETH/USDT:USDT", "SOL/USDT:USDT"]
end

## Optimization
# function call!(s::S, ::OptSetup)
#     (;
#         ctx=Context(Sim(), tf"15m", dt"2020-", now()),
#         params=(),
#         # space=(kind=:MixedPrecisionRectSearchSpace, precision=Int[]),
#     )
# end
# function call!(s::S, params, ::OptRun) end

# function call!(s::S, ::OptScore)::Vector
#     [mt.sharpe(s)]
# end

end
