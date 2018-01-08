%%%-------------------------------------------------------------------
%% @doc erledit public API
%% @end
%%%-------------------------------------------------------------------

-module(erledit).

-behaviour(application).
-behaviour(supervisor).

%% Console callbacks
-export([start/0, stop/0]).

%% Application callbacks
-export([start/2, stop/1]).

%% Supervisor callbacks
-export([init/1]).

%% Cowboy callbacks
-export([init/2]).

%%====================================================================
%% API
%%====================================================================

start() -> application:ensure_all_started(?MODULE).
start(_StartType, _StartArgs) ->
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/compile", ?MODULE, <<>>},
            {"/", cowboy_static, {priv_file, ?MODULE, "index.html"}}
        ]}
    ]),
    {ok, _} = cowboy:start_clear(listener_8080,
        [{port, 8080}],
        #{env => #{dispatch => Dispatch}}
    ),
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%%--------------------------------------------------------------------
stop() -> application:stop(?MODULE).
stop(_State) ->
    ok.

%%====================================================================
%% Supervisor callbacks
%%====================================================================

init([]) ->
    {ok, { {one_for_all, 0, 1}, []} }.


%%====================================================================
%% Cowboy callbacks
%%====================================================================

init(Req0, Buf) ->
    case cowboy_req:read_body(Req0) of
        {ok, Data, Req1} ->
            Resp = case compile_module(Data) of
                {ok, _} -> #{error => [], warning => []};
                {warning, _, Warnings} -> Warnings;
                {error, Errors} -> Errors
            end,
            Req2 = cowboy_req:reply(200, #{
                <<"content-type">> => <<"application/json">>
            }, jsx:encode(Resp), Req1),
            {ok, Req2, <<>>};
        {more, Data, Req1} ->
            init(Req1, <<Data/binary, Buf/binary>>)
    end.

%%====================================================================
%% Internal functions
%%====================================================================
compile_module(ModuleCodeBinStr) when is_binary(ModuleCodeBinStr) ->
    case erl_scan:string(binary_to_list(ModuleCodeBinStr)) of
        {ok, Tokens, _} ->
            TokenGroups = cut_dot(Tokens),
            case lists:foldl(
                    fun(TokenGroup, Acc) when is_list(Acc) ->
                            case erl_parse:parse_form(TokenGroup) of
                                {ok, AbsForm} -> [AbsForm | Acc];
                                {error, ErrorInfo} ->
                                    {error, #{error => [error_info(ErrorInfo)],
                                              warning => []}}
                            end;
                        (_, Error) -> Error
                    end, [], TokenGroups) of
                Forms when is_list(Forms) ->
                    case compile:forms(Forms, [return]) of
                        error -> {error, #{error => <<"unknown">>}};
                        {ok, _Module, Bin} -> {ok, Bin};
                        {ok, _Module, Bin, []} -> {ok, Bin};
                        {ok, _Module, Bin, Warnings} ->
                            io:format("~p: Warnings ~p~n", [?LINE, Warnings]),
                            {warning, Bin, #{error => [],
                                             warning => error_info(Warnings)}};
                        {error, Errors, []} ->
                            io:format("~p: Errors ~p~n", [?LINE, Errors]),
                            {error, #{error => error_info(Errors),
                                      warning => []}};
                        {error, Errors, Warnings} ->
                            io:format("~p: Errors ~p~n", [?LINE, Errors]),
                            io:format("~p: Warnings ~p~n", [?LINE, Warnings]),
                            {error, #{error => error_info(Errors),
                                      warning => error_info(Warnings)}}
                    end;
                Error -> Error
            end;
        {error, ErrorInfo, ErrorLocation} ->
            {error, {scan, ErrorInfo, ErrorLocation}}
    end.

cut_dot(Tokens) -> cut_dot(Tokens, [[]]).
cut_dot([], [[]|Acc]) -> cut_dot([], Acc);
cut_dot([], Acc) -> Acc;
cut_dot([{dot,_} = Dot | Tokens], [A | Rest]) ->
    cut_dot(Tokens, [[], lists:reverse([Dot | A]) | Rest]);
cut_dot([T | Tokens], [A | Rest]) -> cut_dot(Tokens, [[T | A] | Rest]).

error_info([]) -> [];
error_info([{_, _, _} = ErrorInfo | ErrorInfos]) ->
    [error_info(ErrorInfo) | error_info(ErrorInfos)];
error_info([{_,ErrorInfos}|Tail]) ->
    error_info(ErrorInfos) ++ error_info(Tail);
error_info({Line, Module, ErrorDesc}) ->
    #{
        line => Line,
        msg => list_to_binary(Module:format_error(ErrorDesc))
    }.