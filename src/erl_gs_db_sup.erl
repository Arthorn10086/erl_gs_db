%%%-------------------------------------------------------------------
%% @doc erl_gs_db top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(erl_gs_db_sup).

-behaviour(supervisor).

%% API
-export([start_link/2, set/2, delete/1, check_options/1, get_database/1, get_pool_name/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================
%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%  write_through  缓存在数据变化时自动更新数据库
%%  write_behind   缓存定期批量的去更新数据库
%% @end
%%--------------------------------------------------------------------
-spec(start_link(Type :: write_through|write_behind, atom()) ->
    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(Tactics, PoolName) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, [Tactics, PoolName]).

set(Name, Options) ->
    case check_options(Options) of
        true ->
            {_, Mod} = lists:keyfind(mod, 1, Options),
            ID = db_lib:get_db_name(Name),
            case whereis(ID) of
                undefined ->
                    {_, Tactics} = get_cache_tactics(),
                    ChildSpec = {ID, {Mod, start_link, [ID, Name, [{'cache_tactics', Tactics} | Options]]},
                        permanent, 5000, worker, [Mod]},
                    supervisor:start_child(?MODULE, ChildSpec);
                _ ->
                    ok
            end,
            ets:insert(?MODULE, {Name, Options});
        false ->
            false
    end.
delete(Name) ->
    ets:delete(?MODULE, Name).
get_cache_tactics() ->
    [Tactics] = ets:lookup(?MODULE, '$db_cache_tactics'),
    Tactics.
get_pool_name() ->
    [{_, Name}] = ets:lookup(?MODULE, '$pool_name'),
    Name.
get_database(PoolName) ->
    [{_, DataBase}] = ets:lookup(?MODULE, PoolName),
    DataBase.

check_options(Options) ->
    Bool1 = lists:all(fun(Key) -> lists:keymember(Key, 1, Options) end, [mod, key, interval, cache_time, cache_size]),
    Bool2 = case lists:keyfind(mod, 1, Options) of
        {_, server_db_file} ->
            {_, Interval} = lists:keyfind(interval, 1, Options),
            Interval > 0;
        _ ->
            true
    end,
    Bool1 andalso Bool2.
%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
    {ok, {SupFlags :: {RestartStrategy :: supervisor:strategy(),
        MaxR :: non_neg_integer(), MaxT :: non_neg_integer()},
        [ChildSpec :: supervisor:child_spec()]
    }} |
    ignore |
    {error, Reason :: term()}).
init([Tactics, PoolName]) ->
    ets:new(?MODULE, [named_table, public, set]),
    ets:insert(?MODULE, [{'$db_cache_tactics', Tactics}, {'$pool_name', PoolName}]),
    Pools = element(4, sys:get_state(mysql_poolboy_sup)),
    lists:foreach(fun(Child) ->
        Name = element(3, Child),
        {_M, _F, [_Args1, Args2]} = element(4, Child),
        {_, Database} = lists:keyfind('database', 1, Args2),
        ets:insert(?MODULE, {Name, Database})
    end, Pools),
    RestartStrategy = one_for_one,
    MaxRestarts = 10,
    MaxSecondsBetweenRestarts = 60,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    {ok, {SupFlags, []}}.

