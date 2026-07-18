%%% @doc Top supervisor for hecate_news.
%%%
%%% One child: the feed sensor. It polls the configured sovereign sources,
%%% dedupes by item id, and publishes each fresh news_item as a FACT onto the
%%% society's feed. There is no central "manager" — the sensor owns its own
%%% poll loop, dedupe window, and mesh publishing.
-module(hecate_news_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        %% Polls the RSS/Atom sources, dedupes, and publishes news_item facts to
        %% <ns>/feed. Degrades silently while the mesh is dark or a source is
        %% down — a bad source never stops the others.
        worker(sense_news_feeds)
    ],
    {ok, {SupFlags, Children}}.

worker(Module) ->
    #{id => Module,
      start => {Module, start_link, []},
      restart => permanent,
      shutdown => 5000,
      type => worker,
      modules => [Module]}.
