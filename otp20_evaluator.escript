#!/usr/bin/env escript

-record(dependency,
        {
          name               = []    :: string(),
          has_been_fixed     = false :: yes | no | partially,
          has_c_src          = false :: boolean(),
          upgrades_required          :: string(),
          files_with_PULSE   = false :: boolean(),
          files_with_EQC     = false :: boolean(),
          code_stats                 :: integer()
        }).

main([]) ->
    io:format("Usage: runs on the directory /home/vagrant/riak/deps~n"),
    io:format("Expects the dependencies to have been fetched but not compiled~n"),
    DepsDir = "/home/vagrant/riak/deps",
    {ok, Files} = file:list_dir(DepsDir),
    walk(Files, DepsDir, []).

walk([], _DepsDir, Acc) ->
    Sort_results = fun(#dependency{has_been_fixed = Status1,
                                   name           = Name1},
                       #dependency{has_been_fixed = Status2,
                                   name           = Name2}) ->
                           case {Status1, Status2} of
                               {S, S} -> (Name1 < Name2);
                               {_, _} -> (Status1 < Status2)
                           end
                   end,
    Results = lists:sort(Sort_results, Acc),
    [print(X) || X <- Results];
walk([H | T], DepsDir, Acc) ->
    % The original sin from which all other flow
    % directory-management-as-a-side-effect
    file:set_cwd(filename:join([DepsDir, H])),
    A  = has_rebar3_branch(#dependency{name = H}),
    {ok, Files} = file:list_dir(filename:join([DepsDir, H])),
    A2 = has_c_src(Files, A),
    A3 = upgrade_required(A2),
    A4 = files_with_PULSE(A3),
    A5 = files_with_EQC(A4),
    A6 = get_cloc(A5),
    walk(T, DepsDir, [A6 | Acc]).

print(X) ->
    Fields = record_info(fields, dependency),
    Vs = tuple_to_list(X),
    Vals = tl(Vs),
    KVs = lists:zip(Fields, Vals),
    io:format("~nDEPENDENCY~n----------~n", []),
    [io:format(get_format(V), [F, V]) || {F, V} <- KVs],
    ok.

get_format(N) when is_integer(N) ->
    "- ~p:~n~p~n";
get_format(_) ->
    "- ~p:~n~s~n".

files_with_PULSE(Acc) ->
    Acc#dependency{files_with_PULSE = has("PULSE")}.

files_with_EQC(Acc) ->
    Acc#dependency{files_with_EQC = has("EQC")}.

has(String) ->
    Cmd = "grep -Rl \"" ++ String ++ "\" | wc -l",
    list_to_integer(string:strip(os:cmd(Cmd), both, $\n)).

upgrade_required(Acc) ->
    Cmd1 = "grep -R  \"rand:\" | wc -l",
    Cmd2 = "grep -Rl \"rand:\" | wc -l",
    Cmd3 = "grep -R  \"now()\" | wc -l",
    Cmd4 = "grep -Rl \"now()\" | wc -l",
    No_rands      = list_to_integer(string:strip(os:cmd(Cmd1), both, $\n)),
    No_rand_files = list_to_integer(string:strip(os:cmd(Cmd2), both, $\n)),
    No_nows       = list_to_integer(string:strip(os:cmd(Cmd3), both, $\n)),
    No_now_files  = list_to_integer(string:strip(os:cmd(Cmd4), both, $\n)),
    Req1 = 
        case No_rands of
            0 -> "";
            _ -> io_lib:format("~p uses of the rand  module   in ~p files~n",
                        [No_rands, No_rand_files])
        end,
    Req2 = 
        case No_nows of
            0 -> "";
            _ -> io_lib:format("~p uses of the now() function in ~p files~n",
                               [No_nows, No_now_files])
        end,
    Acc#dependency{upgrades_required = lists:flatten(Req1 ++ Req2)}.

get_cloc(Acc) ->
    Cloc = os:cmd("cloc ./"),
    Acc#dependency{code_stats = Cloc}.    

has_rebar3_branch(Acc) ->
    Branches = clean_up(os:cmd("git branch -a | grep rebar3")),
    HasBranch = has_rebar3(Branches),
    Status = case HasBranch of
        true  -> yes;
        false -> if
                     length(Branches) > 0 -> partially;
                     el/=se               -> no
                 end
             end,
    Acc#dependency{has_been_fixed = Status}.

has_rebar3([])                            -> false;
has_rebar3(["rebar3" | _T])               -> true; 
has_rebar3(["remotes/origin/rebar3"| _T]) -> true; 
has_rebar3([_H | T])                      -> has_rebar3(T).

clean_up(String) ->
    Branches = string:tokens(String, " "),
    _Branches2 = [string:strip(string:strip(X), both, $\n) || X <- Branches].
        
has_c_src([],             Acc) -> Acc;
has_c_src(["c_src" | _T], Acc) -> Acc#dependency{has_c_src = true};
has_c_src([_H | T],       Acc) -> has_c_src(T, Acc). 
