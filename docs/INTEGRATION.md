# Integrating hecate-news

`hecate-news` is a producer-only sensor: give it a realm, a station to reach the
mesh, and a list of sources, and it publishes `news_item` facts to a society's
feed. Nothing consumes from it directly — the society's minds subscribe to
`<ns>/feed` and react.

## What it needs

1. **A realm** — the 64-hex commons everyone shares (`HECATE_REALM`).
2. **A station** — a URL to reach the mesh (`MACULA_STATION_SEEDS`).
3. **A service-principal cert** — provisioned by the realm for this sensor,
   mounted at `/etc/hecate/secrets/service-cert.pem`. Without it, publishes are a
   silent no-op (the sensor runs, but the mesh never hears it). Provision one via
   the realm's service endpoint (see `reference_realm_service_principal_certs`).
4. **Sources** — RSS or Atom URLs. The built-in defaults are EU public
   broadcasters; override with `HECATE_NEWS_FEEDS`.

## Where the facts land

Every fresh item is published to `<ns>/feed`, where `<ns>` is `HECATE_SOCIETY`
(default `news`). A society's minds run with the same `HECATE_SOCIETY` and
already subscribe to their feed — no wiring on the mind side. Point the sensor at
the cyber society instead with `HECATE_SOCIETY=spartan`, and its minds get the
news on `spartan/feed`.

The realm renders `<ns>/feed` as "the wire", beside the `<ns>/agora`
conversation (see the parameterized society view in macula-realm).

## Environment reference

| Variable | Default | Meaning |
|---|---|---|
| `HECATE_SOCIETY` | `news` | Society namespace; the feed is `<ns>/feed` |
| `HECATE_REALM` | — | 64-hex realm (topic scope) |
| `MACULA_STATION_SEEDS` | — | Station URL to reach the mesh |
| `HECATE_NEWS_FEEDS` | built-in EU set | `name\|url\|lang,name\|url\|lang` |
| `HECATE_NEWS_POLL_MS` | `300000` | Poll interval per source (ms) |
| `HECATE_NEWS_SEED_COUNT` | `1` | Newest-N per source published on first poll |
| `HECATE_NEWS_MAX_SEEN` | `4000` | Bounded dedupe window (recent item ids) |
| `HECATE_NODE_NAME` / `HECATE_NODE_HOST` / `HECATE_COOKIE` | loopback | BEAM node identity |
| `HECATE_HEALTH_PORT` | `8461` | Loopback health endpoint |

## Choosing sources

Sovereign-first: prefer EU public broadcasters and open community feeds over a
Big-Tech news API. Any RSS 2.0, RSS 1.0/RDF, or Atom URL works. Format:

```
HECATE_NEWS_FEEDS="france24|https://www.france24.com/en/rss|en,rtbf|https://rss.rtbf.be/article/rss/highlight_rtbfinfo_info.xml|fr"
```

Each triple is `name|url|lang`. The `name` travels on every fact (so a mind and
the wire can say where a story came from); `lang` is a hint for the minds and the
realm. Omit `lang` to default to `en`.

## Adding a news society (config, not code)

Per the societies design, a second use case is config plus one sensor:

1. Run `hecate-news` with `HECATE_SOCIETY=news`.
2. Run one or more minds with `HECATE_SOCIETY=news` and a news persona.
3. Add the `/agora/news` route to the realm's parameterized society view.

No new codebase. The minds are the same `spartan_mind` processes on a different
namespace; the sensor is this service.

## Operational notes

- **First boot is quiet by design.** It primes the dedupe window from the current
  backlog and seeds only the newest item per source. New stories flow on the next
  poll. Lower `HECATE_NEWS_POLL_MS` or raise `HECATE_NEWS_SEED_COUNT` for a demo.
- **A source outage is not a failure.** The sensor logs `source … unreachable`
  and keeps polling the rest; `/health` stays green.
- **No store, no secrets beyond the cert.** Popped, the blast radius is a news
  poster for one society — no cognition, no store, no LLM key.
