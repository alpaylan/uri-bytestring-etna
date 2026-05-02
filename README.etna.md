# uri-bytestring — ETNA Workload

ETNA-mined workload for `uri-bytestring`, the RFC 3986 URI parser/serializer
over `ByteString` (Soostone/uri-bytestring). Modern HEAD
(`f2f3b5e0897bb18d4e884b1cb0ac20ccefd6618f`, v0.4.0.1) is the base; six
historical bug fixes are turned into reverse-applied patches under
`patches/<variant>.patch`.

## Layout

```
.                          upstream fork (Soostone/uri-bytestring), unchanged
cabal.project              ours; pins `packages: . etna/` + GHC 9.6.6
etna.toml                  ours; manifest, single source of truth
patches/<variant>.patch    ours; per-variant bug-injection patches
etna/                      ours; runner package
  etna-runner.cabal        runner depends on uri-bytestring + 4 PBT libs
  src/Etna/Result.hs       PropertyResult ADT
  src/Etna/Properties.hs   property_<snake> :: Args -> PropertyResult
  src/Etna/Witnesses.hs    frozen-input witnesses for each variant
  src/Etna/Gens/{QC,HH,F,SC}.hs  per-framework generators
  app/Main.hs              CLI dispatcher (etna/quickcheck/hedgehog/falsify/smallcheck)
  test/Witnesses.hs        cabal test-suite asserting Pass on every witness
BUGS.md, TASKS.md          generated; do not hand-edit
```

## Variants

Six bugs from upstream history, reverse-applied as patches. Each is
detected by both the etna witness replay and all four PBT backends.

| # | Variant | Property | Upstream fix |
|---|---------|----------|--------------|
| 1 | `userinfo_missing_at_749eda6_1`            | `RoundTripUri`           | 749eda6 |
| 2 | `authority_missing_double_slash_ac784c3_1` | `RelRefRoundTrip`        | ac784c3 |
| 3 | `relative_ref_drops_port_83adbc7_1`        | `RelRefRoundTrip`        | 83adbc7 |
| 4 | `fragment_serialize_no_encode_8e7ef60_1`   | `RoundTripUri`           | 8e7ef60 |
| 5 | `trailing_ampersand_afc9302_1`             | `QueryNoEmptyPair`       | afc9302 |
| 6 | `normalization_segs_empty_slash_f52a33f_1` | `NormalizeRootPathKept`  | f52a33f |

Variant 2 is bound to `RelRefRoundTrip` (not `RoundTripUri`) because the
upstream fix touched both `normalizeURI` (`://` → `:`) and
`serializeAuthority` (added `//` prefix); for absolute URIs the two
changes self-compensate, so the bug only surfaces on relative refs.

## Properties (4)

* `RoundTripUri`           — for any constructed `URIRef Absolute`,
  `parseURI strict (serializeURIRef' uri) == uri`.
* `RelRefRoundTrip`        — same for `URIRef Relative` via
  `parseRelativeRef`.
* `QueryNoEmptyPair`       — parsing a URI string with a trailing `&`
  must not yield an empty key/value pair in the query.
* `NormalizeRootPathKept`  — `normalizeURIRef' aggressiveNormalization
  uri` must end with `/` for a URI whose `uriPath = "/"`. (httpNormalization
  alone does not surface the bug — it has `unoDropExtraSlashes = False`
  so `segs = ["",""]` does not collapse to `[""]`.)

## How to build / test

```sh
cabal build all
cabal test etna-witnesses                                  # base sanity
cd etna && cabal run -v0 etna-runner -- quickcheck RoundTripUri
```

The runner emits one JSON line per invocation and exits 0 except on
argv parse error. The Etna driver's `log_process_output` parses these
JSON lines from stdout (Hedgehog's progress text on stdout is
non-JSON and gets ignored).

## Per-variant validation

```sh
git apply -R --whitespace=nowarn patches/<variant>.patch   # install bug
cabal test etna-witnesses                                  # expect FAIL
cd etna && cabal run -v0 etna-runner -- quickcheck <Property>   # expect failed
cd .. && git apply --whitespace=nowarn patches/<variant>.patch  # restore base
```

## GHC version

`ghc 9.6.6`, pinned via `cabal.project`'s `with-compiler` line. Required
for falsify ≥ 0.2 (which needs base ≥ 4.18).
