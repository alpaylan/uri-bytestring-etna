# uri-bytestring — ETNA Tasks

Total tasks: 24

## Task Index

| Task | Variant | Framework | Property | Witness |
|------|---------|-----------|----------|---------|
| 001 | `authority_missing_double_slash_ac784c3_1` | quickcheck | `RelRefRoundTrip` | `witness_rel_ref_round_trip_case_double_slash` |
| 002 | `authority_missing_double_slash_ac784c3_1` | hedgehog | `RelRefRoundTrip` | `witness_rel_ref_round_trip_case_double_slash` |
| 003 | `authority_missing_double_slash_ac784c3_1` | falsify | `RelRefRoundTrip` | `witness_rel_ref_round_trip_case_double_slash` |
| 004 | `authority_missing_double_slash_ac784c3_1` | smallcheck | `RelRefRoundTrip` | `witness_rel_ref_round_trip_case_double_slash` |
| 005 | `fragment_serialize_no_encode_8e7ef60_1` | quickcheck | `RoundTripUri` | `witness_round_trip_uri_case_fragment_special` |
| 006 | `fragment_serialize_no_encode_8e7ef60_1` | hedgehog | `RoundTripUri` | `witness_round_trip_uri_case_fragment_special` |
| 007 | `fragment_serialize_no_encode_8e7ef60_1` | falsify | `RoundTripUri` | `witness_round_trip_uri_case_fragment_special` |
| 008 | `fragment_serialize_no_encode_8e7ef60_1` | smallcheck | `RoundTripUri` | `witness_round_trip_uri_case_fragment_special` |
| 009 | `normalization_segs_empty_slash_f52a33f_1` | quickcheck | `NormalizeRootPathKept` | `witness_normalize_root_path_kept_case_root_with_query` |
| 010 | `normalization_segs_empty_slash_f52a33f_1` | hedgehog | `NormalizeRootPathKept` | `witness_normalize_root_path_kept_case_root_with_query` |
| 011 | `normalization_segs_empty_slash_f52a33f_1` | falsify | `NormalizeRootPathKept` | `witness_normalize_root_path_kept_case_root_with_query` |
| 012 | `normalization_segs_empty_slash_f52a33f_1` | smallcheck | `NormalizeRootPathKept` | `witness_normalize_root_path_kept_case_root_with_query` |
| 013 | `relative_ref_drops_port_83adbc7_1` | quickcheck | `RelRefRoundTrip` | `witness_rel_ref_round_trip_case_with_port` |
| 014 | `relative_ref_drops_port_83adbc7_1` | hedgehog | `RelRefRoundTrip` | `witness_rel_ref_round_trip_case_with_port` |
| 015 | `relative_ref_drops_port_83adbc7_1` | falsify | `RelRefRoundTrip` | `witness_rel_ref_round_trip_case_with_port` |
| 016 | `relative_ref_drops_port_83adbc7_1` | smallcheck | `RelRefRoundTrip` | `witness_rel_ref_round_trip_case_with_port` |
| 017 | `trailing_ampersand_afc9302_1` | quickcheck | `QueryNoEmptyPair` | `witness_query_no_empty_pair_case_trailing_amp` |
| 018 | `trailing_ampersand_afc9302_1` | hedgehog | `QueryNoEmptyPair` | `witness_query_no_empty_pair_case_trailing_amp` |
| 019 | `trailing_ampersand_afc9302_1` | falsify | `QueryNoEmptyPair` | `witness_query_no_empty_pair_case_trailing_amp` |
| 020 | `trailing_ampersand_afc9302_1` | smallcheck | `QueryNoEmptyPair` | `witness_query_no_empty_pair_case_trailing_amp` |
| 021 | `userinfo_missing_at_749eda6_1` | quickcheck | `RoundTripUri` | `witness_round_trip_uri_case_userinfo` |
| 022 | `userinfo_missing_at_749eda6_1` | hedgehog | `RoundTripUri` | `witness_round_trip_uri_case_userinfo` |
| 023 | `userinfo_missing_at_749eda6_1` | falsify | `RoundTripUri` | `witness_round_trip_uri_case_userinfo` |
| 024 | `userinfo_missing_at_749eda6_1` | smallcheck | `RoundTripUri` | `witness_round_trip_uri_case_userinfo` |

## Witness Catalog

- `witness_rel_ref_round_trip_case_double_slash` — RelativeRef //example.org:1234/api/v1 must round-trip
- `witness_round_trip_uri_case_fragment_special` — URI with fragment 'hello world' must round-trip
- `witness_normalize_root_path_kept_case_root_with_query` — Normalizing http://example.com/?x=y must keep the slash
- `witness_rel_ref_round_trip_case_with_port` — RelativeRef //example.com:8080/path must round-trip
- `witness_query_no_empty_pair_case_trailing_amp` — URI ending in '&' must not yield empty key/value pair
- `witness_round_trip_uri_case_userinfo` — URI http://alice:secret@example.com/path must round-trip
