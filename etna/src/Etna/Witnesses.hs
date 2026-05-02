{-# LANGUAGE OverloadedStrings #-}
module Etna.Witnesses where

import Etna.Properties
import Etna.Result

------------------------------------------------------------------------------
-- RoundTripUri witnesses
------------------------------------------------------------------------------

-- | Detects 'userinfo_missing_at_749eda6': serializeUserInfo dropped the
-- '@' separator, so a URI with userinfo round-tripped to a URI without
-- userinfo (or failed to re-parse).
witness_round_trip_uri_case_userinfo :: PropertyResult
witness_round_trip_uri_case_userinfo =
  property_round_trip_uri UriArgs
    { uaScheme   = "http"
    , uaUserInfo = Just ("alice", "secret")
    , uaHost     = "example.com"
    , uaPort     = Nothing
    , uaPath     = "/path"
    , uaQuery    = []
    , uaFragment = Nothing
    }

-- | Detects 'authority_missing_double_slash_ac784c3' via a relative
-- reference round-trip: the absolute-URI round-trip self-compensates
-- (normalizeURI's "://" change is cancelled by serializeAuthority's
-- "//" change), but for a RelativeRef there is no `scheme + "://"` to
-- compensate, so dropping the "//" from serializeAuthority breaks the
-- relrr serialization.
witness_rel_ref_round_trip_case_double_slash :: PropertyResult
witness_rel_ref_round_trip_case_double_slash =
  property_rel_ref_round_trip RelRefArgs
    { rraUserInfo = Nothing
    , rraHost     = "example.org"
    , rraPort     = 1234
    , rraPath     = "/api/v1"
    }

-- | Detects 'fragment_serialize_no_encode_8e7ef60': serializeFragment
-- did not pct-encode reserved/unsafe chars, so a fragment containing
-- a space (or similar) produced an invalid URI string that either
-- failed to re-parse or yielded a different fragment.
witness_round_trip_uri_case_fragment_special :: PropertyResult
witness_round_trip_uri_case_fragment_special =
  property_round_trip_uri UriArgs
    { uaScheme   = "http"
    , uaUserInfo = Nothing
    , uaHost     = "example.com"
    , uaPort     = Nothing
    , uaPath     = "/x"
    , uaQuery    = []
    , uaFragment = Just "hello world"
    }

------------------------------------------------------------------------------
-- RelRefRoundTrip witness
------------------------------------------------------------------------------

-- | Detects 'relative_ref_drops_port_83adbc7': serializeAuthority's
-- effectivePort was sequenced through `mScheme`, which was Nothing for
-- a RelativeRef, so the port was always dropped from the serialization.
witness_rel_ref_round_trip_case_with_port :: PropertyResult
witness_rel_ref_round_trip_case_with_port =
  property_rel_ref_round_trip RelRefArgs
    { rraUserInfo = Nothing
    , rraHost     = "example.com"
    , rraPort     = 8080
    , rraPath     = "/path"
    }

------------------------------------------------------------------------------
-- QueryNoEmptyPair witness
------------------------------------------------------------------------------

-- | Detects 'trailing_ampersand_afc9302': sepBy' over '&' admitted a
-- trailing empty match, producing a ("", "") pair in the parsed query.
witness_query_no_empty_pair_case_trailing_amp :: PropertyResult
witness_query_no_empty_pair_case_trailing_amp =
  property_query_no_empty_pair QueryArgs
    { qaScheme = "http"
    , qaHost   = "example.com"
    , qaPath   = "/p"
    , qaPairs  = [("a", "b")]
    , qaTrail  = True
    }

------------------------------------------------------------------------------
-- NormalizeRootPathKept witness
------------------------------------------------------------------------------

-- | Detects 'normalization_segs_empty_slash_f52a33f': normalizeRelativeRef
-- dropped the segs==[""] case so a URI with rrPath="/" lost its slash
-- between authority and query under httpNormalization.
witness_normalize_root_path_kept_case_root_with_query :: PropertyResult
witness_normalize_root_path_kept_case_root_with_query =
  property_normalize_root_path_kept NormArgs
    { nrHost = "example.com"
    }
