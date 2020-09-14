%%%-------------------------------------------------------------------
%% @doc erl_gs_db public API
%% @end
%%%-------------------------------------------------------------------

-module(erl_gs_db).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%%====================================================================
%% API
%%====================================================================

start(_StartType, _StartArgs) ->
    {ok, CacheTactics} = application:get_env(db_cache_tactics),
    {ok, PoolName} = application:get_env(pool_name),
    erl_gs_db_sup:start_link(CacheTactics, PoolName).

%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================
