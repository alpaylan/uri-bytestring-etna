{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Property functions for the uri-bytestring ETNA workload.
--
-- Each property takes a single concrete @Args@ value, calls into the
-- library under test, and returns 'PropertyResult'. The same property is
-- driven by all four PBT backends and by the witness replay path.
module Etna.Properties where

import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Etna.Result
import URI.ByteString

------------------------------------------------------------------------------
-- Property 1: RoundTripUri
--
-- Covers variants:
--   * userinfo_missing_at_749eda6     — serializeUserInfo dropped trailing '@'
--   * authority_missing_double_slash_ac784c3 — serializeAuthority dropped "//"
--   * fragment_serialize_no_encode_8e7ef60   — serializeFragment didn't url-encode
--
-- Property: building a URI from concrete components, serializing it to
-- the canonical wire form (no normalization), and re-parsing must yield
-- the same URI. With any of the three bugs reverse-applied, the
-- intermediate ByteString is malformed (missing '@' / missing '//' /
-- containing literal characters needing pct-encoding) and either
-- re-parse fails or the resulting URIRef differs from the original.
------------------------------------------------------------------------------

data UriArgs = UriArgs
  { uaScheme   :: !ByteString
  , uaUserInfo :: !(Maybe (ByteString, ByteString))
  , uaHost     :: !ByteString
  , uaPort     :: !(Maybe Int)
  , uaPath     :: !ByteString
  , uaQuery    :: ![(ByteString, ByteString)]
  , uaFragment :: !(Maybe ByteString)
  } deriving (Show, Eq)

toAbsoluteUri :: UriArgs -> URIRef Absolute
toAbsoluteUri UriArgs {..} =
  URI
    { uriScheme    = Scheme uaScheme
    , uriAuthority = Just Authority
        { authorityUserInfo = fmap (\(u, p) -> UserInfo u p) uaUserInfo
        , authorityHost     = Host uaHost
        , authorityPort     = fmap Port uaPort
        }
    , uriPath      = uaPath
    , uriQuery     = Query uaQuery
    , uriFragment  = uaFragment
    }

property_round_trip_uri :: UriArgs -> PropertyResult
property_round_trip_uri ua =
  let uri = toAbsoluteUri ua
      ser = serializeURIRef' uri
  in case parseURI strictURIParserOptions ser of
       Left e -> Fail $
         "parse of serialized URI failed: " ++ show e ++
         " (serialized: " ++ show ser ++
         ", original: " ++ show uri ++ ")"
       Right uri' ->
         if uri == uri'
           then Pass
           else Fail $
             "round-trip mismatch: original=" ++ show uri ++
             "; serialized=" ++ show ser ++
             "; reparsed=" ++ show uri'

------------------------------------------------------------------------------
-- Property 2: RelRefRoundTrip
--
-- Covers variants:
--   * relative_ref_drops_port_83adbc7 — serializeAuthority dropped port
--     for relative refs because the Maybe-Scheme monad short-circuited
--
-- Property: a relative reference with authority+port serializes such
-- that re-parsing yields an equal RelativeRef. With the bug, the port
-- is omitted from the serialized output (because mScheme = Nothing and
-- the buggy effectivePort threads scheme through the Maybe), so the
-- round-trip strips the port.
------------------------------------------------------------------------------

data RelRefArgs = RelRefArgs
  { rraUserInfo :: !(Maybe (ByteString, ByteString))
  , rraHost     :: !ByteString
  , rraPort     :: !Int
  , rraPath     :: !ByteString
  } deriving (Show, Eq)

toRelRef :: RelRefArgs -> URIRef Relative
toRelRef RelRefArgs {..} =
  RelativeRef
    { rrAuthority = Just Authority
        { authorityUserInfo = fmap (\(u, p) -> UserInfo u p) rraUserInfo
        , authorityHost     = Host rraHost
        , authorityPort     = Just (Port rraPort)
        }
    , rrPath     = rraPath
    , rrQuery    = mempty
    , rrFragment = Nothing
    }

property_rel_ref_round_trip :: RelRefArgs -> PropertyResult
property_rel_ref_round_trip rra =
  let rr  = toRelRef rra
      ser = serializeURIRef' rr
  in case parseRelativeRef strictURIParserOptions ser of
       Left e -> Fail $
         "parseRelativeRef failed: " ++ show e ++
         " (serialized: " ++ show ser ++
         ", original: " ++ show rr ++ ")"
       Right rr' ->
         if rr == rr'
           then Pass
           else Fail $
             "rel-ref round-trip mismatch: original=" ++ show rr ++
             "; serialized=" ++ show ser ++
             "; reparsed=" ++ show rr'

------------------------------------------------------------------------------
-- Property 3: QueryNoEmptyPair
--
-- Covers variants:
--   * trailing_ampersand_afc9302 — queryItemParser turned trailing '&'
--     into an empty ("","") pair instead of dropping it
--
-- Property: parseURI on a URI string of the form "<base>?<pairs>&" must
-- not produce any ("", "") pair in the query. With the bug, sepBy' over
-- '&' admits an empty match at the trailing position, yielding an empty
-- key-value pair.
------------------------------------------------------------------------------

data QueryArgs = QueryArgs
  { qaScheme :: !ByteString
  , qaHost   :: !ByteString
  , qaPath   :: !ByteString
  , qaPairs  :: ![(ByteString, ByteString)]
  , qaTrail  :: !Bool          -- if True, append a trailing '&'
  } deriving (Show, Eq)

renderQueryUri :: QueryArgs -> ByteString
renderQueryUri QueryArgs {..} =
  qaScheme <> "://" <> qaHost <> qaPath <> "?" <> renderPairs <> trail
  where
    renderPairs = BS.intercalate "&"
      [ k <> "=" <> v | (k, v) <- qaPairs ]
    trail = if qaTrail then "&" else ""

property_query_no_empty_pair :: QueryArgs -> PropertyResult
property_query_no_empty_pair qa
  | null (qaPairs qa) = Discard
  | any (\(k, _) -> BS.null k) (qaPairs qa) = Discard
  | otherwise =
      let raw = renderQueryUri qa
      in case parseURI strictURIParserOptions raw of
           Left _  -> Discard
           Right u ->
             let pairs = queryPairs (uriQuery u)
                 emptyPairs = [ (k, v) | (k, v) <- pairs, BS.null k ]
             in if null emptyPairs
                  then Pass
                  else Fail $
                    "parsed query contains empty key pair(s): " ++
                    show emptyPairs ++ " (input: " ++ show raw ++
                    ", parsed: " ++ show pairs ++ ")"

------------------------------------------------------------------------------
-- Property 4: NormalizeRootPathKept
--
-- Covers variants:
--   * normalization_segs_empty_slash_f52a33f — normalizeRelativeRef
--     dropped the segs==[""] case so a URI with rrPath="/" normalized
--     to having no path under aggressiveNormalization. With
--     httpNormalization the bug does not surface (because
--     unoDropExtraSlashes is False there); we use aggressiveNormalization
--     which sets unoDropExtraSlashes=True and so collapses ["",""] into
--     [""] before path rendering.
--
-- Property: normalizing a URI with rrPath="/" via aggressiveNormalization
-- must end with "/" between authority and query/end-of-string. With the
-- bug, the slash is lost because segs collapses to [""] which renders
-- as the empty string when the segs==[""] guard is removed.
------------------------------------------------------------------------------

data NormArgs = NormArgs
  { nrHost  :: !ByteString
  } deriving (Show, Eq)

property_normalize_root_path_kept :: NormArgs -> PropertyResult
property_normalize_root_path_kept (NormArgs host)
  | BS.null host = Discard
  | otherwise =
      let uri = URI
            { uriScheme    = Scheme "http"
            , uriAuthority = Just Authority
                { authorityUserInfo = Nothing
                , authorityHost     = Host host
                , authorityPort     = Nothing
                }
            , uriPath      = "/"
            , uriQuery     = mempty
            , uriFragment  = Nothing
            }
          ser = normalizeURIRef' aggressiveNormalization uri
      in if BS8.pack "/" `BS.isSuffixOf` ser
           then Pass
           else Fail $
             "normalized URI dropped root path slash: " ++ show ser
