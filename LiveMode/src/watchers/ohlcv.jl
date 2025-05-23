using Watchers.WatchersImpls:
    ccxt_ohlcv_watcher, ccxt_ohlcv_tickers_watcher, ccxt_ohlcv_candles_watcher
import Watchers.WatchersImpls: cached_ohlcv!
using .st: logpath
using .Data: DataFrame, propagate_ohlcv!

@doc """ Continuously propagates OHLCV data.

$(TYPEDSIGNATURES)

This function continuously propagates OHLCV (Open, High, Low, Close, Volume) data for a given watcher `w` and ai `ai`.
It enters an infinite loop where it safely waits for a process in the watcher, then checks if the watcher is stopped.
If the watcher is not stopped, it tries to propagate the OHLCV data.

"""
propagate_loop(s::RTStrategy, ai, w::Watcher) = begin
    data = ai.data
    met = ohlcvmethod(s)
    try
        while true
            safewait(w.beacon.process)
            try
                propagate_ohlcv!(data)
                cached_ohlcv!(ai, met)
            catch exception
                @debug "watchers: propagate loop" exception
            end
        end
    catch
        @warn "watchers: propagate loop stopped" ai = raw(ai)
    end
end

@doc """ Continuously propagates OHLCV data for each asset in the universe.

$(TYPEDSIGNATURES)

This function continuously propagates OHLCV (Open, High, Low, Close, Volume) data for each asset in a strategy's universe.
It enters an infinite loop where it safely waits for a process in the watcher, then checks if the watcher is stopped.
If the watcher is not stopped, it tries to propagate the OHLCV data for each asset in the strategy's universe.

"""
propagate_loop(s::RTStrategy, w::Watcher) = begin
    try
        while true
            safewait(w.beacon.process)
            for ai in s.universe
                try
                    propagate_ohlcv!(ai.data)
                catch exception
                    @debug "watchers: propagate loop" exception
                end
            end
        end
    catch
        @warn "watchers: propagate loop stopped" s = nameof(s)
    end
end

@doc """ Returns the OHLCV method for the strategy.

$(TYPEDSIGNATURES)

Fetches the `live_ohlcv_method` attribute from the strategy `s`.
Returns the method used for generating OHLCV data in the strategy.
values: `tickers`, `trades`, `candles`

"""
ohlcvmethod(s::Strategy) = attr(s, :live_ohlcv_method, :candles)
ohlcvmethod(ai::AssetInstance) = attr(ai, :live_ohlcv_method, :candles)
function ohlcvmethod!(s::Strategy, k=:candles)
    if k ∉ (:tickers, :candles, :trades)
        error("ohlcv methods supported are `tickers`, `candles` and `trades`")
    end
    s[:live_ohlcv_method] = k
    for ai in universe(s)
        attr!(ai, :live_ohlcv_method, k)
    end
end

@doc """ Returns the watchers for OHLCV data.

$(TYPEDSIGNATURES)

Determines if OHLCV data should be generated by trades.
If so, it returns the dictionary of watchers for each asset instance.
Otherwise, it returns the single watcher for the strategy `s`.

"""
function ohlcv_watchers(s::RTStrategy)
    if ohlcvmethod!(s) == :trades
        @lget! s.attrs :live_ohlcv_watchers Dict{AssetInstance,Watcher}()
    else
        attr(s, :live_ohlcv_watcher, nothing)
    end
end

@doc """ Watches and propagates OHLCV data.

$(TYPEDSIGNATURES)

This function starts watchers for OHLCV (Open, High, Low, Close, Volume) data based on the strategy's universe and whether OHLCV data should be generated by trades.
For each asset in the universe, it starts a watcher that propagates OHLCV data.
If OHLCV data should not be generated by trades, it starts a single watcher for all assets in the universe.

"""
function watch_ohlcv!(s::RTStrategy; exc=exchange(s), kwargs...)
    ow = ohlcv_watchers(s)
    met = ohlcvmethod(s)
    if met == :trades
        function start_watcher(ai)
            # NOTE: define it as local, otherwise async would clobber it before
            # being saved in the dict
            local w
            sym = raw(ai)
            eid = exchangeid(exc)
            default_view = @lget! ai.data s.timeframe cached_ohlcv!(
                eid, met, s.timeframe, sym
            )
            prev_w = get(ow, ai, missing)
            if !ismissing(prev_w)
                if isrunning(prev_w)
                    close(prev_w)
                end
            end
            w = ccxt_ohlcv_watcher(exc, sym; s.timeframe, default_view)
            Watchers.load!(w)
            w[:propagate_task] = @async propagate_loop(s, ai, w)
            start!(w)
            ow[ai] = w
        end
        @sync for ai in s.universe
            @async start_watcher(ai)
        end
    else
        eid = exchangeid(s)
        default_view = Dict{String,DataFrame}(
            raw(ai) =>
                @lget!(ai.data, s.timeframe, cached_ohlcv!(eid, met, s.timeframe, raw(ai)))
            for ai in s.universe
        )
        buffer_capacity = attr(s, :live_buffer_capacity, 100)
        view_capacity = attr(
            s, :live_view_capacity, count(s.timeframe, tf"1d") + 1 + buffer_capacity
        )
        n_jobs = attr(s, :live_ohlcv_jobs, 4)
        function propagate_callback(_, sym)
            @debug "watchers: propagating" _module = LogWatchOHLCV sym
            ai = asset_bysym(s, sym)
            ohlcv_dict(ai) |> propagate_ohlcv!
            cached_ohlcv!(ai, met)
        end
        watcher_func = if met == :tickers
            (exc; kwargs...) -> ccxt_ohlcv_tickers_watcher(exc; kwargs...)
        elseif met == :candles
            (exc; syms, kwargs...) -> ccxt_ohlcv_candles_watcher(exc, syms; kwargs...)
        else
            error("call: invalid ohlcv method $met")
        end
        s[:live_ohlcv_watcher] =
            w = watcher_func(
                exc;
                timeframe=s.timeframe,
                syms=(raw(ai) for ai in s.universe),
                flush=false,
                logfile=logpath(s; name="tickers_watcher_$(nameof(s))"),
                buffer_capacity,
                view_capacity,
                n_jobs,
                default_view,
                callback=propagate_callback,
            )
        w[:quiet] = true
        w[:resync_noncontig] = true
        w[:startup_task] = @async begin
            wv = w.view
            @sync for ai in s.universe
                sym = raw(ai)
                wv[sym] = ai.data[s.timeframe]
                @async Watchers.load!(w, sym)
            end
        end
        start!(w)
    end
end

@doc """ Stops watching OHLCV data.

$(TYPEDSIGNATURES)

This function stops the watchers that were started to propagate OHLCV (Open, High, Low, Close, Volume) data based on the strategy's universe.
If the watcher is a single instance, it stops the watcher.
If the watcher is a dictionary of watchers, it stops each watcher in the dictionary.

"""
function stop_watch_ohlcv!(s::RTStrategy)
    w = ohlcv_watchers(s)
    isnothing(w) && return nothing
    if w isa Watcher
        if isrunning(w)
            stop!(w)
        end
    elseif valtype(w) <: Watcher
        for ai_w in values(w)
            if isrunning(ai_w)
                stop!(ai_w)
            end
        end
    else
        error()
    end
end

function empty_ohlcv(s::Strategy, ai::AssetInstance)
    cached_ohlcv!(exchangeid(s), ohlcvmethod(s), period(s.timeframe), raw(ai))
end

function empty_ohlcv(ai::AssetInstance, tf::TimeFrame; met=:candles)
    cached_ohlcv!(exchangeid(ai), ohlcvmethod(ai), period(tf), raw(ai))
end

@doc "Ensures dataframes in the strategy are present in the cache"
function cached_ohlcv!(s::Strategy)
    eid = exchangeid(s)
    met = ohlcvmethod!(s)
    for ai in universe(s)
        sym = raw(ai)
        for (tf, data) in ohlcv_dict(ai)
            cached_ohlcv!(eid, met, period(tf), sym; def=data)
        end
    end
end

function cached_ohlcv!(ai::AssetInstance, met=:candles)
    eid = exchangeid(ai)()
    sym = raw(ai) |> string
    for (tf, data) in ohlcv_dict(ai)
        cached_ohlcv!(eid, met, period(tf), sym; def=data)
    end
end

if cached_ohlcv! ∉ st.STRATEGY_LOAD_CALLBACKS.live
    push!(st.STRATEGY_LOAD_CALLBACKS.live, cached_ohlcv!)
end

export ohlcvmethod!, ohlcvmethod
