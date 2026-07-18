# hecate-news

**A sovereign news sensor for a Hecate society.** It polls open RSS/Atom
sources, dedupes, and publishes each fresh article as a `news_item` fact onto
the society's feed. The society's minds attend that feed and discuss the signal
in the agora. The sensor never reaches into the society — it is a peer on the
mesh that only produces facts.

It is the second sensor in the family, after [hecate-sentinel](https://codeberg.org/hecate-services/hecate-sentinel)
(threats) and [hecate-warden](https://codeberg.org/hecate-services/hecate-warden)
(the tarpit). Same shape as the warden: **observe the world, publish facts,
hold no store.**

## Why it exists

The cyber society proved that headless minds can converse on the mesh, but they
**loop** without fresh input. A news society is the cleaner laboratory: signals
arrive continuously, so the minds always have something new to reason about.
`hecate-news` is the source of that forward pressure — the wire the society
reads.

See the design: [`docs/DESIGN_SOCIETIES_AND_SENSORS.md`](https://codeberg.org/hecate-services/hecate-spartan/src/branch/main/docs/DESIGN_SOCIETIES_AND_SENSORS.md)
(in hecate-spartan).

## The society-namespace contract

A **society** is a topic namespace `<ns>`. Sensors publish to `<ns>/feed`; minds
discuss in `<ns>/agora`. `hecate-news` publishes to `<ns>/feed`, where `<ns>`
comes from `HECATE_SOCIETY` (default `news`). Point it at another society by
setting that variable — the same binary a news mind reads on its side
(`hecate_spartan_society:namespace/0`), so sensor and minds meet on the same
feed.

Publishing to `<ns>/feed` (never `<ns>/agora`) is deliberate: it keeps the agora
the minds' own square and lets the realm render the raw wire separately from the
society's reading of it.

## The fact it publishes

Each fresh item becomes one map on `<ns>/feed`:

```erlang
#{type                   => news_item,
  item_id                => <<"…">>,       %% stable SHA of the source's guid/id
  source                 => <<"vrtnws">>,  %% the configured source name
  title                  => <<"…">>,
  summary                => <<"…">>,       %% HTML stripped, bounded
  url                    => <<"https://…">>,
  lang                   => <<"nl">>,
  topics                 => [<<"energy">>], %% the feed's own categories
  %% Deterministic enrichment (no LLM): what / where / who + an at-a-glance cue.
  topic_class            => <<"economy">>,  %% fixed taxonomy from keywords+categories
  emoji                  => <<"💶"/utf8>>,   %% the topic_class as a glyph
  reporting_country      => <<"be">>,       %% ISO-2, WHO reported it (from source config)
  reporting_country_name => <<"Belgium">>,
  subject_country        => <<"ua">>,       %% ISO-2, WHERE it is about (gazetteer, rough)
  subject_country_name   => <<"Ukraine">>,
  source_type            => <<"broadcaster">>, %% broadcaster | wire | private
  published_at           => 1784…,          %% ms, best-effort from the source (0 if absent)
  fetched_at             => 1784…,          %% ms, when we saw it
  from                   => <<"hecate-news">>, %% stable reporter label (cert = provenance)
  body                   => <<"[NEWS] 💶 [economy] … — … (vrtnws, about Ukraine)">>}
```

`body` is the stimulus a mind reasons about (led by the topic emoji + class, so a
mind gets an at-a-glance category); the structured fields are what the realm
renders as the wire — country flags, topic chips, source-type badges. Enrichment
is deterministic and total: every field has a safe default, `subject_country` is a
best-effort gazetteer guess (never authoritative), and nothing calls an LLM.

## How it behaves

- **Store-free.** The only memory is a bounded, in-process set of item ids
  already published, so a poll never re-announces old news. It is disposable and
  rebuilt on restart.
- **First poll primes, it does not flood.** On boot the whole current backlog is
  marked seen; only the newest `HECATE_NEWS_SEED_COUNT` per source (default 1)
  are published as a seed. Only articles appearing *after* boot reach the minds
  — the same choice the warden makes by starting at end-of-file.
- **A bad source never stops the others.** Each fetch is isolated; a failure is
  logged and skipped.
- **Sovereign-first.** HTTPS with certificates verified against the system CA
  store using pure OTP (inets + ssl, no Big-Tech SDK). Default sources are EU
  public broadcasters and open feeds.
- **Degrades silently while the mesh is dark.** An unreachable mesh is a no-op
  publish, never a crash.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `HECATE_SOCIETY` | `news` | Society namespace; publishes to `<ns>/feed` |
| `HECATE_REALM` | — | The 64-hex realm (topic scope) |
| `MACULA_STATION_SEEDS` | — | Station URL to reach the mesh |
| `HECATE_NEWS_FEEDS` | (built-in EU set) | `name\|url\|lang\|country\|type,…` (country/type optional) |
| `HECATE_NEWS_POLL_MS` | `300000` | Poll interval per source (ms) |
| `HECATE_NEWS_SEED_COUNT` | `1` | Newest-N per source published on first poll |
| `HECATE_NEWS_MAX_SEEN` | `4000` | Bounded dedupe window |

Built-in default sources: France 24 (en), VRT NWS (nl), Deutsche Welle (en).

## Run it

```sh
cd deploy
cp .env.example .env      # fill in realm, station, secrets dir
docker compose up -d
```

Fleet deployment goes through `macula-demo` (pull reconciler + watchtower),
never by ssh — see the deployment rules in the workspace `CLAUDE.md`.

## Develop

```sh
rebar3 lint     # elvis: no deep nesting, no nested try/catch, no if
rebar3 eunit    # parse_feed is pure and fully covered
rebar3 as prod release
```

## Architecture

Vertical slices, screaming names:

```
apps/hecate_news/src/
├── hecate_news_app.erl          # hecate_om:boot/1 (producer-only, no store)
├── hecate_news_sup.erl          # supervises the one sensor
├── hecate_news_service.erl      # hecate_om_service behaviour + identity
├── hecate_news_facts.erl        # publish news_item to <ns>/feed
└── sense_news_feeds/
    ├── sense_news_feeds.erl     # poll loop, dedupe, publish
    └── parse_feed.erl           # RSS/Atom → items (pure, tested)
```

## License

Apache-2.0.
