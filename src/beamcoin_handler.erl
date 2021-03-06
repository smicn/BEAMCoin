-module(beamcoin_handler).

-behavior(libp2p_framed_stream).

-export([init/3, handle_data/3, handle_info/3]).

-record(state, {
          parent :: pid(),
          multiaddr :: string()
         }).

init(client, Connection, [Parent]) ->
    {_, MultiAddr} = libp2p_connection:addr_info(Connection),
    ok = pg2:join(Parent, self()),
    {ok, #state{parent=Parent, multiaddr=MultiAddr}};
init(server, Connection, [_Path, Parent]) ->
    {_, MultiAddr} = libp2p_connection:addr_info(Connection),
    ok = pg2:join(Parent, self()),
    {ok, #state{parent=Parent, multiaddr=MultiAddr}}.

handle_data(_, Data, State=#state{}) ->
    case binary_to_term(Data) of
        {block, Block} ->
            lager:info("Got block over libp2p"),
            State#state.parent ! {mined_block, Block, State#state.multiaddr},
            {noresp, State};
        Other ->
            lager:warning("unhandled p2p message in ~s : ~p", [?MODULE, Other]),
            {stop, normal, State}
    end.

handle_info(_, {block, Block}, State) ->
    lager:info("publishing block to network"),
    {resp, term_to_binary({block, Block}), State};
handle_info(_, Msg, State) ->
    lager:info("p2p handler got unexpected info message ~p", [Msg]),
    {noresp, State}.
