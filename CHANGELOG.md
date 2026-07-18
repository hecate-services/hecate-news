# Changelog

All notable changes to hecate-news are documented here.

## [0.1.0] - 2026-07-18

Initial release. The second sensor in the society family (after sentinel and
warden): a sovereign news sensor.

### Added
- Store-free `hecate_om` producer service (`hecate_news_service`): mesh wiring,
  no reckon-db.
- `sense_news_feeds`: polls configured RSS/Atom sources over verified HTTPS,
  dedupes by stable item id (bounded in-process window), and publishes each
  fresh article as a `news_item` fact.
- `parse_feed`: pure RSS 2.0 / RSS 1.0 (RDF) / Atom parser with best-effort
  publication-time extraction and HTML-summary stripping; fully unit-tested.
- `hecate_news_facts`: publishes `news_item` to `<ns>/feed`, derived from
  `HECATE_SOCIETY` (default `news`) — the society-namespace contract, so the
  sensor and the society's minds meet on the same feed.
- First-poll priming (seed newest-N, mark the backlog seen) so a fresh boot does
  not flood the agora.
- Sovereign-first default sources: France 24, VRT NWS, Deutsche Welle.
- Containerfile (builds the macula NIF from source), ghcr.io build-push + lint
  CI, and a drop-in `deploy/` compose.
