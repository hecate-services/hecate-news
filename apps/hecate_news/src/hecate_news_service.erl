%%% @doc Hecate News — implements the hecate_om_service behaviour.
%%%
%%% A news sensor for the society. Same pattern as the warden: observe the
%%% world, publish FACTS to a feed, hold no store. It polls sovereign-first
%%% sources (EU public broadcasters, open RSS/Atom; no Big-Tech news API), and
%%% for each fresh item it publishes a `news_item' fact to the configured
%%% society's `<ns>/feed'. The minds attend that feed and reason about the
%%% signal in the agora — the sensor never reaches INTO the society.
%%%
%%% STORELESS: no store_id/0 + data_dir/0, so hecate_om:boot/1 wires the mesh
%%% but starts no reckon-db. The sensor's only memory is a bounded in-process
%%% set of item ids it has already published (so a poll does not re-announce old
%%% news); that set is disposable and rebuilt on restart.
-module(hecate_news_service).
-behaviour(hecate_om_service).

-export([info/0, start/1, stop/1, health/0, capabilities/0, identity_spec/0]).

info() ->
    #{name        => <<"hecate-news">>,
      version     => <<"0.1.0">>,
      description => <<"Sovereign news sensor: RSS/Atom to the society feed">>}.

start(_Opts) ->
    hecate_news_sup:start_link().

stop(_State) ->
    ok.

%% Green once the sensor's poll loop is running. A source being down is not a
%% health failure — the sensor keeps polling the rest.
health() ->
    ok.

%% What the news sensor announces it can do: it reports news items, and nothing
%% else. It cannot post to the agora, cannot message a mind, cannot act — it is
%% a producer of signals only. Each capability is a map (name + version), the
%% shape hecate_om_capabilities matches on when another service looks one up.
capabilities() ->
    [#{name => <<"news.report_item">>, version => 1}].

%% The UCAN the sensor asks the realm to mint: authority to publish on the
%% society's feed, and NOTHING else. Popped, an attacker gains a news poster for
%% one society — no cognition, no store, no LLM key.
identity_spec() ->
    #{scope     => <<"news">>,
      actions   => [<<"report">>],
      resources => [feed_resource()],
      ttl_days  => 30}.

%% The society's feed the sensor publishes on, as a UCAN resource. Derived from
%% the target society so a news sensor for `news' and one for `spartan' request
%% exactly the topic they use.
feed_resource() ->
    <<(hecate_news_facts:namespace())/binary, "/feed">>.
