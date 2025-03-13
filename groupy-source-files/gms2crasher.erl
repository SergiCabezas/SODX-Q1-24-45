-module(gms2).
-export([start/1, start/2]).

-define(arghh, 100). 

start(Name) ->
    Self = self(),
    spawn_link(fun() -> init(Name, Self) end).

init(Name, Master) ->
    {A1, A2, A3} = now(),
    random:seed(A1, A2, A3), 
    leader(Name, Master, []).

start(Name, Grp) ->
    Self = self(),
    spawn_link(fun() -> init(Name, Grp, Self) end).

init(Name, Grp, Master) ->
    {A1, A2, A3} = now(),
    random:seed(A1, A2, A3), 
    Self = self(),
    Grp ! {join, Self},
    receive
        {view, Leader, Slaves} ->
            Ref = erlang:monitor(process, Leader), 
            Master ! joined,
            slave(Name, Master, Leader, Slaves, Ref)
    end.

leader(Name, Master, Slaves) ->
    receive
        {mcast, Msg} ->
            bcast(Name, {msg, Msg}, Slaves),
            Master ! {deliver, Msg},
            leader(Name, Master, Slaves);
        {join, Peer} ->
            NewSlaves = lists:append(Slaves, [Peer]),
            bcast(Name, {view, self(), NewSlaves}, NewSlaves),
            leader(Name, Master, NewSlaves);
        stop ->
            ok;
        Error ->
            io:format("leader ~s: strange message ~w~n", [Name, Error]),
            leader(Name, Master, Slaves)
    end.

slave(Name, Master, Leader, Slaves, Ref) ->
    receive
        {mcast, Msg} ->
            Leader ! {mcast, Msg},
            slave(Name, Master, Leader, Slaves, Ref);
        {join, Peer} ->
            Leader ! {join, Peer},
            slave(Name, Master, Leader, Slaves, Ref);
        {msg, Msg} ->
            Master ! {deliver, Msg},
            slave(Name, Master, Leader, Slaves, Ref);
        {view, NewLeader, NewSlaves} ->
            erlang:demonitor(Ref, [flush]),  
            NewRef = erlang:monitor(process, NewLeader),  
            slave(Name, Master, NewLeader, NewSlaves, NewRef);
        {'DOWN', _Ref, process, Leader, _Reason} ->
            io:format("~s: leader ~p is down. Starting election.~n", [Name, Leader]),
            election(Name, Master, Slaves);
        stop ->
            ok;
        Error ->
            io:format("~s: strange message ~w~n", [Name, Error]),
            slave(Name, Master, Leader, Slaves, Ref)
    end.

election(Name, Master, Slaves) ->
    Self = self(),
    case Slaves of
        [Self | Rest] ->
            io:format(" ~s: new leader.~n", [Name]),
            leader(Name, Master, Rest);
        [NewLeader | Rest] ->
            Ref = erlang:monitor(process, NewLeader),
            io:format(" ~s: following new leader ~p.~n", [Name, NewLeader]),
            slave(Name, Master, NewLeader, Rest, Ref);
        [] ->
            io:format(" ~s:Exiting.~n", [Name]),
            ok
    end.

bcast(Name, Msg, Nodes) ->
    lists:foreach(fun(Node) ->
        Node ! Msg,
        crash(Name, Msg) 
    end, Nodes).

crash(Name, Msg) ->
    case random:uniform(?arghh) of
        ?arghh ->
            io:format("leader ~s CRASHED: msg ~w~n", [Name, Msg]),
            exit(no_luck); 
        _ ->
            ok
    end.

