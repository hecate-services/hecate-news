%%% @doc Publishing what the news sensor sees onto the society's feed.
%%%
%%% The sensor is a producer: it observes the world and tells the society. These
%%% are integration FACTS, not domain events — the sensor holds no store. A fact
%%% lands on `<ns>/feed', where the society's minds attend it (see the spartan
%%% society-namespace contract). Degrades silently while the mesh is dark: an
%%% unreachable mesh must never crash the poll loop.
%%%
%%% Two shapes travel in one map: the STRUCTURED item (title, url, source, ...)
%%% that the realm renders as "the wire", and a `body' — the rendered stimulus a
%%% mind reasons about. A mind's stimulus gate reads `body' (a non-empty
%%% binary), so a fact with no body is heard but ignored.
-module(hecate_news_facts).

-export([namespace/0, item/1]).

%% Bound the summary carried on the wire. Enough for a mind to react; not a
%% payload that bloats a mind's reasoning context (the same lesson the sleep
%% cycle taught — see hecate-spartan).
-define(SUMMARY_MAX, 600).
-define(TITLE_MAX, 300).
%% The sender label carried on every fact as `from'. A stable, honest name for
%% the source of the signal — never a mind's DID, so a mind never mistakes a news
%% item for its own speech and always considers it. (hecate_om v1 has no service
%% DID API; provenance is the realm-signed cert at the transport layer.)
-define(REPORTER, <<"hecate-news">>).

%% @doc The society this sensor publishes into. Default `news' (this sensor's
%% natural society); set HECATE_SOCIETY to point it at another society's feed.
%% Matches hecate_spartan_society:namespace/0 on the mind side, so a news mind
%% (HECATE_SOCIETY=news) and this sensor meet on `news/feed'.
-spec namespace() -> binary().
namespace() ->
    case os:getenv("HECATE_SOCIETY") of
        S when is_list(S), S =/= "" -> unicode:characters_to_binary(S);
        _Unset                      -> <<"news">>
    end.

%% @doc Publish one news item as a fact on the society's feed. `Item' is the
%% parsed map from a source (title, summary, url, source, lang, item_id,
%% published_at). We add provenance (the sensor's DID), the rendered `body' a
%% mind reads, and `fetched_at'.
-spec item(map()) -> ok.
item(Item) when is_map(Item) ->
    Title   = clip(mget(title, Item, <<>>), ?TITLE_MAX),
    Summary = clip(mget(summary, Item, <<>>), ?SUMMARY_MAX),
    Source  = mget(source, Item, <<"unknown">>),
    Fact = #{type         => news_item,
             item_id      => mget(item_id, Item, <<>>),
             source       => Source,
             title        => Title,
             summary      => Summary,
             url          => mget(url, Item, <<>>),
             lang         => mget(lang, Item, <<"en">>),
             topics       => mget(topics, Item, []),
             published_at => mget(published_at, Item, 0),
             fetched_at   => erlang:system_time(millisecond),
             from         => ?REPORTER,
             body         => body(Title, Summary, Source)},
    publish(feed_topic(), Fact).

%% --- Internal ---

%% The stimulus a mind reasons about: a compact, readable headline line. Only
%% the title and source when there is no summary, so a mind is never handed an
%% empty body (which its gate would drop).
body(Title, <<>>, Source) ->
    <<"[NEWS] ", Title/binary, " (", Source/binary, ")">>;
body(Title, Summary, Source) ->
    <<"[NEWS] ", Title/binary, " — ", Summary/binary, " (", Source/binary, ")">>.

feed_topic() ->
    <<(namespace())/binary, "/feed">>.

publish(Topic, Fact) ->
    case {hecate_om:macula_client(), hecate_om_identity:realm()} of
        {{ok, Pool}, {ok, Realm}} ->
            catch macula:publish(Pool, Realm, Topic, Fact),
            ok;
        _DarkOrNoRealm ->
            ok
    end.

%% Bound a binary to N graphemes, appending an ellipsis when clipped. Grapheme
%% count (not bytes) so multibyte EU text is never cut mid-character.
clip(Bin, Max) when is_binary(Bin) ->
    clip_len(Bin, string:length(Bin), Max);
clip(_NotBin, _Max) ->
    <<>>.

clip_len(Bin, Len, Max) when Len =< Max ->
    Bin;
clip_len(Bin, _Len, Max) ->
    <<(string:slice(Bin, 0, Max))/binary, "…"/utf8>>.

mget(Key, Map, Default) ->
    maps:get(Key, Map, Default).
