-module(memory_table).
-author("arthorn10086").

-behaviour(gen_server).

%% API
-export([start_link/3]).

%% gen_server callbacks
-export([init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3]).

-export([lock/5, update/5, delete/5, get/5]).

-define(SERVER, ?MODULE).
-record(state, {keyets, ets}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
start_link(ID, Name, Options) ->
    gen_server:start_link({local, ID}, ?MODULE, [{Name, Options}], []).


%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
    {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term()} | ignore).
init([{Name, _Options}]) ->
    KeyEts = ets:new(?MODULE, [protected, ordered_set]),
    Ets = ets:new(Name, [named_table, 'protected', 'set']),
    {ok, #state{keyets = KeyEts, ets = Ets}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
        State :: #state{}) ->
    {reply, Reply :: term(), NewState :: #state{}} |
    {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
    {noreply, NewState :: #state{}} |
    {noreply, NewState :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
    {stop, Reason :: term(), NewState :: #state{}}).
handle_call({Action, Key, Value, Vsn, LockTime, Locker}, _From, State) ->
    Reply = action(State, Action, Key, Value, Vsn, Locker, LockTime, db_lib:now_millisecond()),
    {reply, Reply, State};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
    {noreply, NewState :: #state{}} |
    {noreply, NewState :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #state{}}).
handle_cast(_Request, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
    {noreply, NewState :: #state{}} |
    {noreply, NewState :: #state{}, timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #state{}}).
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
        State :: #state{}) -> term()).
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
        Extra :: term()) ->
    {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

action(State, Action, Key, Value, Vsn, Locker, LockTime, MS) ->
    case erlang:get({lock, Key}) of
        undefined when LockTime > 0 ->
            erlang:put({lock, Key}, {Locker, MS + LockTime}),
            ?MODULE:Action(State, Key, Value, Vsn, MS);
        undefined ->
            ?MODULE:Action(State, Key, Value, Vsn, MS);
        {Locker, _} ->
            erlang:put({lock, Key}, {Locker, MS + LockTime}),
            ?MODULE:Action(State, Key, Value, Vsn, MS);
        {_Lock, EndTime} ->
            if
                EndTime < MS ->
                    erlang:put({lock, Key}, {Locker, MS + LockTime}),
                    ?MODULE:Action(State, Key, Value, Vsn, MS);
                true ->
                    lock_error
            end
    end.

lock(_, _, _, _, _) ->
    ok.
get(State, Key, _, _, _MS) ->
    #state{ets = Ets, keyets = KeyEts} = State,
    case ets:lookup(KeyEts, Key) of
        [] ->
            none;
        _ ->
            case ets:lookup(Ets, Key) of
                [] ->
                    none;
                [{Key, V, Time, Version}] ->
                    {ok, V, Version, Time}
            end
    end.
update(State, Key, Value, Vsn, MS) ->
    #state{ets = Ets, keyets = KeyEts} = State,
    case ets:lookup(Ets, Key) of
        [] ->
            ets:insert(KeyEts, {Key}),
            ets:insert(Ets, {Key, Value, MS, 1});
        [{_, _, _, Vsn}] ->
            ets:insert(Ets, {Key, Value, MS, Vsn + 1});
        [{_, _, _, _OldVsn}] ->
            {'error', 'version_error'}
    end.
delete(State, Key, _, _, _) ->
    #state{ets = Ets, keyets = KeyEts} = State,
    ets:delete(KeyEts, Key),
    ets:delete(Ets, Key).