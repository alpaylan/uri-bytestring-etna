# uri-bytestring — Injected Bugs

RFC 3986 URI parser/serializer over ByteStrings (Soostone/uri-bytestring). Bug fixes mined from upstream history; modern HEAD is the base, each patch reverse-applies a fix to install the original bug.

Total mutations: 6

## Bug Index

| # | Variant | Name | Location | Injection | Fix Commit |
|---|---------|------|----------|-----------|------------|
| 1 | `authority_missing_double_slash_ac784c3_1` | `authority_serialize_missing_double_slash` | `src/URI/ByteString/Internal.hs:193` | `patch` | `ac784c373ef013046ddcb08f73fdc1af0f0272a1` |
| 2 | `fragment_serialize_no_encode_8e7ef60_1` | `fragment_serialize_no_pct_encode` | `src/URI/ByteString/Internal.hs:306` | `patch` | `8e7ef60bbb42773c2f9b93004dbfb61ab11dfe3a` |
| 3 | `normalization_segs_empty_slash_f52a33f_1` | `normalize_drops_root_path_slash` | `src/URI/ByteString/Internal.hs:208` | `patch` | `f52a33fb02f31ca8a701d42bdc7335e58bb4630b` |
| 4 | `relative_ref_drops_port_83adbc7_1` | `relative_ref_drops_port` | `src/URI/ByteString/Internal.hs:322` | `patch` | `83adbc78cc64438a6d4fd4975e900f935baaee7c` |
| 5 | `trailing_ampersand_afc9302_1` | `trailing_ampersand_yields_empty_pair` | `src/URI/ByteString/Internal.hs:643` | `patch` | `afc9302ca80beec70d4382f58fb870afa8dbe9b6` |
| 6 | `userinfo_missing_at_749eda6_1` | `userinfo_serialize_missing_at` | `src/URI/ByteString/Internal.hs:338` | `patch` | `749eda6df2d4e8647f556c51e5e3bf55e12e1fdf` |

## Property Mapping

| Variant | Property | Witness(es) |
|---------|----------|-------------|
| `authority_missing_double_slash_ac784c3_1` | `RelRefRoundTrip` | `witness_rel_ref_round_trip_case_double_slash` |
| `fragment_serialize_no_encode_8e7ef60_1` | `RoundTripUri` | `witness_round_trip_uri_case_fragment_special` |
| `normalization_segs_empty_slash_f52a33f_1` | `NormalizeRootPathKept` | `witness_normalize_root_path_kept_case_root_with_query` |
| `relative_ref_drops_port_83adbc7_1` | `RelRefRoundTrip` | `witness_rel_ref_round_trip_case_with_port` |
| `trailing_ampersand_afc9302_1` | `QueryNoEmptyPair` | `witness_query_no_empty_pair_case_trailing_amp` |
| `userinfo_missing_at_749eda6_1` | `RoundTripUri` | `witness_round_trip_uri_case_userinfo` |

## Framework Coverage

| Property | quickcheck | hedgehog | falsify | smallcheck |
|----------|---------:|-------:|------:|---------:|
| `RelRefRoundTrip` | ✓ | ✓ | ✓ | ✓ |
| `RoundTripUri` | ✓ | ✓ | ✓ | ✓ |
| `NormalizeRootPathKept` | ✓ | ✓ | ✓ | ✓ |
| `QueryNoEmptyPair` | ✓ | ✓ | ✓ | ✓ |

## Bug Details

### 1. authority_serialize_missing_double_slash

- **Variant**: `authority_missing_double_slash_ac784c3_1`
- **Location**: `src/URI/ByteString/Internal.hs:193` (inside `normalizeURI`)
- **Property**: `RelRefRoundTrip`
- **Witness(es)**:
  - `witness_rel_ref_round_trip_case_double_slash` — RelativeRef //example.org:1234/api/v1 must round-trip
- **Source**: internal — Fix resialisation of authority
  > serializeAuthority did not emit the leading '//' before host; serializeURI compensated by emitting 'scheme://' rather than 'scheme:'. The fix moves '//' into serializeAuthority where it belongs and keeps serializeURI emitting the bare ':' separator. Reversing the patch reinstates both halves of the bug.
- **Fix commit**: `ac784c373ef013046ddcb08f73fdc1af0f0272a1` — Fix resialisation of authority
- **Invariant violated**: parseRelativeRef strict (serializeURIRef' rr) must equal rr for any RelativeRef with authority.
- **How the mutation triggers**: Reversing the patch makes normalizeURI emit '<scheme>://' AND serializeAuthority drop the '//' prefix. For absolute URIs the two changes self-compensate (the joined output is unchanged), so the bug only surfaces for RelativeRefs: a relrr serializes without the leading '//' and re-parses as a path-only URI.

### 2. fragment_serialize_no_pct_encode

- **Variant**: `fragment_serialize_no_encode_8e7ef60_1`
- **Location**: `src/URI/ByteString/Internal.hs:306` (inside `serializeFragment`)
- **Property**: `RoundTripUri`
- **Witness(es)**:
  - `witness_round_trip_uri_case_fragment_special` — URI with fragment 'hello world' must round-trip
- **Source**: internal — Encode fragments on serialization
  > Fragment percent-decoding was added to the parser but the serializer continued to emit fragment bytes verbatim. URIs with fragments containing reserved or unsafe characters fail to round-trip because the serializer produces an invalid URI string.
- **Fix commit**: `8e7ef60bbb42773c2f9b93004dbfb61ab11dfe3a` — Encode fragments on serialization
- **Invariant violated**: parseURI strict (serializeURIRef' uri) must equal uri for any URI whose fragment contains characters needing pct-encoding.
- **How the mutation triggers**: Reversing the patch flips serializeFragment from 'urlEncodeQuery s' to plain 'bs s'. A URI with a fragment containing a space (or any non-pchar character) serializes to an invalid URI string that the strict parser rejects.

### 3. normalize_drops_root_path_slash

- **Variant**: `normalization_segs_empty_slash_f52a33f_1`
- **Location**: `src/URI/ByteString/Internal.hs:208` (inside `normalizeRelativeRef.path`)
- **Property**: `NormalizeRootPathKept`
- **Witness(es)**:
  - `witness_normalize_root_path_kept_case_root_with_query` — Normalizing http://example.com/?x=y must keep the slash
- **Source**: internal — Fix normalization bug
  > normalizeRelativeRef's path-rendering chain handled the rrPath=="" case (under unoSlashEmptyPath) but not segs==[""], which is what BS.split slash "/" produces under httpNormalization. A URI 'http://h/?q' normalized to 'http://h?q', losing the slash between authority and query.
- **Fix commit**: `f52a33fb02f31ca8a701d42bdc7335e58bb4630b` — Fix normalization bug
- **Invariant violated**: normalizeURIRef' httpNormalization (URI{path="/", query non-empty, fragment Nothing}) must contain '/?' between authority and query.
- **How the mutation triggers**: Reversing the patch removes the segs==[""] guard from normalizeRelativeRef. Normalizing 'http://example.com/?x=y' under httpNormalization yields 'http://example.com?x=y' (no slash before '?').

### 4. relative_ref_drops_port

- **Variant**: `relative_ref_drops_port_83adbc7_1`
- **Location**: `src/URI/ByteString/Internal.hs:322` (inside `serializeAuthority.effectivePort`)
- **Property**: `RelRefRoundTrip`
- **Witness(es)**:
  - `witness_rel_ref_round_trip_case_with_port` — RelativeRef //example.com:8080/path must round-trip
- **Source**: internal — Fix bug: RelativeRef serialization dropped port
  > serializeAuthority's effectivePort was 'p <- authorityPort; scheme <- mScheme; dropPort scheme p'. For a RelativeRef there is no scheme, so mScheme is Nothing and the Maybe monad short-circuits, dropping the port unconditionally. The fix splits dropPort into Nothing/Just-Scheme cases so the Nothing case keeps the port.
- **Fix commit**: `83adbc78cc64438a6d4fd4975e900f935baaee7c` — Fix bug: RelativeRef serialization dropped port
- **Invariant violated**: parseRelativeRef strict (serializeURIRef' rr) must equal rr for any RelativeRef whose authority has a port set.
- **How the mutation triggers**: Reversing the patch reinstates the Maybe-Scheme threading. Serializing 'RelativeRef Just(Authority Nothing host (Just port)) ...' drops the port entirely, so the round-trip yields a port-less RelativeRef.

### 5. trailing_ampersand_yields_empty_pair

- **Variant**: `trailing_ampersand_afc9302_1`
- **Location**: `src/URI/ByteString/Internal.hs:643` (inside `queryParser.itemsParser`)
- **Property**: `QueryNoEmptyPair`
- **Witness(es)**:
  - `witness_query_no_empty_pair_case_trailing_amp` — URI ending in '&' must not yield empty key/value pair
- **Source**: internal — Fixed bug with trailing ampersands
  > queryParser used 'sepBy' (queryItemParser opts) (word8' ampersand)' with no post-filter. A URI of the form '?a=b&' parses to queryPairs = [("a","b"),("","")] because sepBy' admits a trailing empty match. The fix filters out empty-key pairs.
- **Fix commit**: `afc9302ca80beec70d4382f58fb870afa8dbe9b6` — Fixed bug with trailing ampersands
- **Invariant violated**: parseURI strict 'http://h.com/p?<pairs>&' must produce a Query with no empty-key pair.
- **How the mutation triggers**: Reversing the patch removes the 'filter neQuery' wrapper. parseURI 'http://example.com/p?a=b&' then yields uriQuery = Query [("a","b"),("","")] instead of Query [("a","b")].

### 6. userinfo_serialize_missing_at

- **Variant**: `userinfo_missing_at_749eda6_1`
- **Location**: `src/URI/ByteString/Internal.hs:338` (inside `serializeUserInfo`)
- **Property**: `RoundTripUri`
- **Witness(es)**:
  - `witness_round_trip_uri_case_userinfo` — URI http://alice:secret@example.com/path must round-trip
- **Source**: internal — Fix serialization bug with userinfo
  > serializeUserInfo emitted '<user>:<pass>' with no trailing '@', so a serialized URI omitted the separator between userinfo and the host. Reversing the fix restores the original bug.
- **Fix commit**: `749eda6df2d4e8647f556c51e5e3bf55e12e1fdf` — Fix serialization bug with userinfo
- **Invariant violated**: For any URI containing userinfo, parseURI strict (serializeURIRef' uri) must yield a URI equal to the original.
- **How the mutation triggers**: Reverse-applying the patch removes the trailing '<> c8 '@'' from serializeUserInfo. A URI with userinfo serializes to '<scheme>://<user>:<pass><host>...' which the strict parser rejects (or re-parses with the userinfo absorbed into the host).
