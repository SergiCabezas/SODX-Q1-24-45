-module(gms3). % GMS3: Extensión de GMS2 con multicast confiable
-export([start/1, start/2]).

start(Name) ->
    Self = self(),
    spawn_link(fun() -> init(Name, Self) end).

init(Name, Master) ->
    {A1, A2, A3} = now(), % Obtener un valor único basado en el tiempo actual
    random:seed(A1, A2, A3), % Inicializar el generador aleatorio
    leader(Name, Master, [], 0).

start(Name, Grp) ->
    Self = self(),
    spawn_link(fun() -> init(Name, Grp, Self) end).

init(Name, Grp, Master) ->
    {A1, A2, A3} = now(), % Obtener un valor único basado en el tiempo actual
    random:seed(A1, A2, A3), % Inicializar el generador aleatorio
    Self = self(),
    Grp ! {join, Self},
    receive
        {view, Leader, Slaves} ->
            Ref = erlang:monitor(process, Leader), % Monitorear al líder
            Master ! joined,
            slave(Name, Master, Leader, Slaves, Ref, 0, undefined)
    after 1000 -> % Timeout de 1 segundo si no hay respuesta
        Master ! {error, "no reply from leader"}
    end.

% Extensión de la función líder para gestionar secuencia
leader(Name, Master, Slaves, N) ->
    receive
        {mcast, Msg} ->
            NextN = N + 1,
            bcast(Name, {msg, NextN, Msg}, Slaves),
            Master ! {deliver, Msg},
            leader(Name, Master, Slaves, NextN);
        {join, Peer} ->
            NewSlaves = lists:append(Slaves, [Peer]),
            bcast(Name, {view, self(), NewSlaves}, NewSlaves),
            leader(Name, Master, NewSlaves, N);
        stop ->
            ok;
        Error ->
            io:format("leader ~s: strange message ~w~n", [Name, Error])
    end.

% Extensión del esclavo para manejar secuencia y vista
slave(Name, Master, Leader, Slaves, Ref, N, Last) ->
    receive
        {mcast, Msg} ->
            Leader ! {mcast, Msg},
            slave(Name, Master, Leader, Slaves, Ref, N, Last);
        {msg, Seq, Msg} when Seq < N ->  % Ignorar duplicados
            slave(Name, Master, Leader, Slaves, Ref, N, Last);
        {msg, Seq, Msg} ->
            Master ! {deliver, Msg},
            slave(Name, Master, Leader, Slaves, Ref, Seq + 1, {msg, Seq, Msg});
        {view, NewLeader, NewSlaves} ->
            erlang:demonitor(Ref, [flush]),
            NewRef = erlang:monitor(process, NewLeader),
            slave(Name, Master, NewLeader, NewSlaves, NewRef, N, Last);
        {'DOWN', _Ref, process, Leader, _Reason} ->
            election(Name, Master, Slaves, N, Last);
        stop ->
            ok;
        Error ->
            io:format("slave ~s: strange message ~w~n", [Name, Error]),
            slave(Name, Master, Leader, Slaves, Ref, N, Last)
    end.

% Extensión de la elección para reenviar el último mensaje recibido
election(Name, Master, Slaves, N, Last) ->
    Self = self(),
    case Slaves of
        [Self | Rest] ->
            % Convertirse en líder y reenviar el último mensaje
            case Last of
                undefined -> ok;
                _ -> bcast(Name, Last, Rest)
            end,
            leader(Name, Master, Rest, N);
        [NewLeader | Rest] ->
            Ref = erlang:monitor(process, NewLeader),
            slave(Name, Master, NewLeader, Rest, Ref, N, Last);
        [] ->
            io:format("slave ~s: no leader available~n", [Name]),
            slave(Name, Master, undefined, [], undefined, N, Last)
    end.

% Función para enviar mensajes a múltiples nodos
bcast(_, Msg, Nodes) ->
    lists:foreach(fun(Node) ->
        Node ! Msg,
        crash(Node, Msg) % Simula fallos aleatorios
    end, Nodes).

% Función para simular fallos aleatorios
crash(Name, Msg) ->
    case random:uniform(100) of
        100 -> % El 1% de las veces el líder fallará aleatoriamente
            io:format("leader ~p CRASHED: msg ~p~n", [Name, Msg]),
            exit(no_luck);
        _ -> ok
    end.

