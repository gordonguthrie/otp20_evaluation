#!/usr/bin/env escript

-record(dependency,
        {
          name               = []    :: string(),
          has_been_fixed     = false :: boolean(),
          code_stats                 :: integer(),
          has_c_src          = false :: boolean(),
          upgrades_required          :: string()
        }).

main([]) ->
       DepsDir = "/home/vagrant/riak/deps",
       {ok, Files} = file:list_dir(DepsDir),
       walk(Files, DepsDir, []).

walk([], _DepsDir, Acc) ->
    [print(X) || X <- lists:reverse(Acc)];
walk([H | T], DepsDir, Acc) ->
    % The original sin from which all other flow
    % directory-management-as-a-side-effect
    file:set_cwd(filename:join([DepsDir, H])),
    A  = has_rebar3_branch(#dependency{name = H}),
    {ok, Files} = file:list_dir(filename:join([DepsDir, H])),
    A2 = has_c_src(Files, A),
    A3 = upgrade_required(A2),
    %% A2 = get_cloc(DepsDir, H, A),
    walk(T, DepsDir, [A3 | Acc]).

print(X) ->
    Fields = record_info(fields, dependency),
    Vs = tuple_to_list(X),
    Vals = tl(Vs),
    KVs = lists:zip(Fields, Vals),
    io:format("~nDEPENDENCY~n----------~n", []),
    [io:format("- ~p:~n~s~n", [F, V]) || {F, V} <- KVs],
    ok.

upgrade_required(Acc) ->
    Cmd1 = "grep -R  \"rand:\" | wc -l",
    Cmd2 = "grep -Rl \"rand:\" | wc -l",
    Cmd3 = "grep -R  \"now()\" | wc -l",
    Cmd4 = "grep -Rl \"now()\" | wc -l",
    No_rands      = string:strip(os:cmd(Cmd1), both, $\n),
    No_rand_files = string:strip(os:cmd(Cmd2), both, $\n),
    No_nows       = string:strip(os:cmd(Cmd3), both, $\n),
    No_now_files  = string:strip(os:cmd(Cmd4), both, $\n),
    Req = io_lib:format("~s uses of the rand  module   in ~s files~n"
                        "~s uses of the now() function in ~s files~n",
                        [No_rands, No_rand_files, No_nows, No_now_files]),
    Acc#dependency{upgrades_required = Req}.

%get_cloc(Acc) ->
%    Cloc = os:cmd("cloc ./"),
%    Acc#dependency{code_stats = Cloc}.    

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
