-module(groupy2).
-export([start/2, stop/0, stop/1]).


start(Module, Sleep) ->
    P = worker:start("P1", Module, Sleep),
    register(a, P), 
    
    Node1 = 'node2@sergi-Lenovo',
    Node2 = 'node3@sergi-Lenovo',
    Node3 = 'node4@sergi-Lenovo',
    Node4 = 'node5@sergi-Lenovo',
    
    P2 = rpc:call(Node1, worker, start, ["P2", Module, P, Sleep]),
    P3 = rpc:call(Node2, worker, start, ["P3", Module, P, Sleep]),
    P4 = rpc:call(Node3, worker, start, ["P4", Module, P, Sleep]),
    P5 = rpc:call(Node4, worker, start, ["P5", Module, P, Sleep]),
    
    Workers = [{b,P2},{c,P3},{d,P4},{e,P5}],
    {ok, Workers}.

stop() ->
    stop(a),
    stop(b),
    stop(c),
    stop(d),
    stop(e).

stop(Name) ->
    case whereis(Name) of
        undefined ->
            ok;
        Pid ->
            Pid ! stop
    end.

