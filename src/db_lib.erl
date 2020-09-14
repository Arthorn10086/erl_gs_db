-module(db_lib).

%%%=======================STATEMENT====================
-description("db_lib").
-author("arthorn10086").

%%%=======================EXPORT=======================
-export([get_db_name/1, get_query_by_key/4, get_all_key_sql/3, get_fields_sql/2,
    term_to_string/1, string_to_term/1]).
-export([now_millisecond/0, now_second/0, get_zero_second/0]).

%%%=======================INCLUDE======================
%%%=======================DEFINE======================

%%%=======================RECORD=======================

%%%=======================TYPE=========================
%%-type my_type() :: atom() | integer().


%%%=================EXPORTED FUNCTIONS=================
now_millisecond() ->
    {M, S, MS} = os:timestamp(),
    M * 1000000000 + S * 1000 + MS div 1000.
now_second() ->
    {M, S, _} = os:timestamp(),
    M * 1000000 + S.

get_zero_second() ->
    {TM, TS, MS} = os:timestamp(),
    Now = TM * 1000000 + TS,
    {_, {H, M, S}} = calendar:now_to_local_time({TM, TS, MS}),
    Now - (H * 60 * 60 + M * 60 + S).
%% ----------------------------------------------------
%% @doc  
%%        获得表进程ID
%% @end
%% ----------------------------------------------------
get_db_name(Name) ->
    list_to_atom("server_db:" ++ atom_to_list(Name)).

%% ----------------------------------------------------
%% @doc
%%        获得表字段
%% @end
%% ----------------------------------------------------
get_fields_sql(Name, DataBase) ->
    "select COLUMN_NAME from information_schema.COLUMNS where table_name = '"
        ++ atom_to_list(Name) ++ "' and table_schema = '" ++ DataBase ++ "';".

%% ----------------------------------------------------
%% @doc
%%       查询语句
%% @end
%% ----------------------------------------------------
get_query_by_key(DBName, KeyName, _KeyType, Key) ->
    "SELECT * FROM " ++ atom_to_list(DBName) ++ " WHERE " ++ atom_to_list(KeyName) ++ "=" ++ integer_to_list(Key) ++ ";".

%% ----------------------------------------------------
%% @doc
%%       查询所有Key
%% @end
%% ----------------------------------------------------
get_all_key_sql(DBName, KeyName, _KeyType) ->
    "SELECT " ++ atom_to_list(KeyName) ++ " FROM " ++ atom_to_list(DBName) ++ ";".
%% ----------------------------------------------------
%% @doc
%%       转化成sql string
%% @end
%% ----------------------------------------------------
term_to_string(Term) when is_atom(Term) ->
    atom_to_list(Term);
term_to_string(Term) when is_integer(Term) ->
    integer_to_list(Term);
term_to_string(Term) when is_float(Term) ->
    float_to_list(Term);
term_to_string(Term) when is_tuple(Term); is_list(Term); is_binary(Term); is_map(Term) ->
    binary_to_list(unicode:characters_to_binary(io_lib:format("'~p.'", [Term])));
term_to_string(Term) when is_pid(Term) ->
    erlang:pid_to_list(Term);
term_to_string(Term) when is_function(Term) ->
    erlang:fun_to_list(Term).
%% ----------------------------------------------------
%% @doc
%%       sql string 转化为 erlang term
%% @end
%% ----------------------------------------------------
string_to_term(Text) ->
    case erl_scan:string(Text) of
        {ok, Tokens, _EndLine} ->
            case erl_parse:parse_exprs(Tokens) of
                {ok, Expr} ->
                    case catch erl_eval:exprs(Expr, []) of
                        {value, V, _} ->
                            V;
                        E ->
                            throw({'parse_error3', E, Text})
                    end;
                E ->
                    throw({'parse_error2', E, Text})
            end;
        E ->
            throw({'parse_error1', E, Text})
    end.


%%%===================LOCAL FUNCTIONS==================
%% ----------------------------------------------------
%% @doc  
%%  
%% @end
%% ----------------------------------------------------
