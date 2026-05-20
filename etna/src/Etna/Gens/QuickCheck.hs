{-# LANGUAGE OverloadedStrings #-}
module Etna.Gens.QuickCheck where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS8
import qualified Test.QuickCheck as QC

import Etna.Properties

-- | Lowercase ASCII letters used for some narrow components.
lowerAlpha :: [Char]
lowerAlpha = ['a' .. 'z']

-- | Alphanumeric ASCII (the safest superset for hosts/schemes).
alphaNumChars :: [Char]
alphaNumChars = lowerAlpha ++ ['A' .. 'Z'] ++ ['0' .. '9']

-- | RFC3986 unreserved chars: parser-safe in nearly every URI position.
unreservedChars :: [Char]
unreservedChars = alphaNumChars ++ "-._~"

-- | Sub-delims + selected pchar extras. Legal inside path/query/userinfo
-- segments. Adds breadth to query keys/values without pct-encoding.
subDelimsChars :: [Char]
subDelimsChars = "!$&'()*+,;="

-- | Path-/query-segment chars (pchar minus pct-encoded escapes).
pcharChars :: [Char]
pcharChars = unreservedChars ++ subDelimsChars ++ ":@"

-- | A wide ASCII pool that frequently lands on chars requiring percent
-- encoding. Used for fragments so the gen organically explores bytes
-- that the buggy serializer fails on, without hand-crafting bug bait.
wideAsciiChars :: [Char]
wideAsciiChars =
  unreservedChars ++ subDelimsChars ++ ":@/?" ++ " <>[]\\^`{|}\""

-- | Generate a short bytestring drawn from a character class.
genBs :: [Char] -> Int -> Int -> QC.Gen ByteString
genBs cs lo hi = do
  n <- QC.choose (lo, hi)
  cs' <- QC.vectorOf n (QC.elements cs)
  pure (BS8.pack cs')

-- | An RFC3986-shaped host: 1-3 dot-separated alphanum labels, each
-- 1-12 chars. The first char of each label is alphanum (parser-safe);
-- the rest may include hyphen.
genHostLabel :: QC.Gen ByteString
genHostLabel = do
  hd  <- QC.elements alphaNumChars
  rest <- genBs (alphaNumChars ++ "-") 0 11
  pure (BS8.cons hd rest)

genHost :: QC.Gen ByteString
genHost = do
  numLabels <- QC.choose (1 :: Int, 3)
  labels <- QC.vectorOf numLabels genHostLabel
  pure (BS8.intercalate "." labels)

-- | Schemes are alphanum, must start with a letter.
genScheme :: QC.Gen ByteString
genScheme = QC.frequency
  [ (3, QC.elements ["http", "https", "ftp", "ssh", "file"])
  , (1, do
        hd  <- QC.elements (lowerAlpha ++ ['A' .. 'Z'])
        len <- QC.choose (0 :: Int, 5)
        rest <- QC.vectorOf len (QC.elements alphaNumChars)
        pure (BS8.pack (hd : rest)))
  ]

-- | Path: "" or 1-5 segments, each 0-10 pchar bytes. Always begins with
-- '/' when non-empty. Wider than the upstream "1-2 alphabetic segments"
-- so bugs that depend on path shape (e.g. authority/'/' boundary) are
-- exercised on a broader distribution.
genPath :: QC.Gen ByteString
genPath = QC.frequency
  [ (1, pure "")
  , (1, pure "/")
  , (8, do
        n <- QC.choose (1 :: Int, 5)
        pieces <- QC.vectorOf n (genBs pcharChars 0 10)
        pure ("/" <> BS8.intercalate "/" pieces))
  ]

genUserInfo :: QC.Gen (Maybe (ByteString, ByteString))
genUserInfo = QC.frequency
  [ (2, pure Nothing)
  , (3, do
        u <- genBs unreservedChars 1 10
        p <- genBs unreservedChars 0 10
        pure (Just (u, p)))
  ]

genFragment :: QC.Gen (Maybe ByteString)
genFragment = QC.frequency
  [ (2, pure Nothing)
    -- Most fragments are unreserved-only and round-trip cleanly.
  , (3, Just <$> genBs unreservedChars 0 12)
    -- Some draw from a wider ASCII pool that contains characters
    -- requiring pct-encoding. The fragment-encoding bug surfaces
    -- whenever the random fragment lands on one of those bytes.
  , (2, Just <$> genBs wideAsciiChars 1 12)
  ]

genQueryPairs :: Int -> QC.Gen [(ByteString, ByteString)]
genQueryPairs maxN = do
  n <- QC.choose (0 :: Int, maxN)
  QC.vectorOf n $ do
    k <- genBs unreservedChars 1 8
    v <- genBs (unreservedChars ++ "+") 0 10
    pure (k, v)

------------------------------------------------------------------------------
-- gen_round_trip_uri
--
-- Draws an arbitrary absolute URI: random scheme, random host, random
-- userinfo (often present), random port (often present, full 16-bit
-- range), random multi-segment path, 0-6 query pairs, and a fragment
-- whose distribution organically lands on bug-triggering bytes. The
-- userinfo-missing-@, authority-missing-//, and fragment-no-encode bugs
-- all surface whenever the random URI lands in their respective
-- subspace.
------------------------------------------------------------------------------
gen_round_trip_uri :: QC.Gen UriArgs
gen_round_trip_uri = do
  scheme <- genScheme
  ui     <- genUserInfo
  host   <- genHost
  port   <- QC.frequency
              [ (1, pure Nothing)
              , (3, Just <$> QC.choose (1, 65535))
              ]
  path   <- genPath
  qPairs <- genQueryPairs 6
  frag   <- genFragment
  pure UriArgs
    { uaScheme = scheme
    , uaUserInfo = ui
    , uaHost = host
    , uaPort = port
    , uaPath = path
    , uaQuery = qPairs
    , uaFragment = frag
    }

------------------------------------------------------------------------------
-- gen_rel_ref_round_trip
--
-- Random RelativeRef with authority+port. The authority-//-missing and
-- relative-ref-drops-port bugs both depend on the port being present
-- and the URI being relative; this generator produces those by
-- construction but otherwise lets the host/userinfo/port/path roam.
------------------------------------------------------------------------------
gen_rel_ref_round_trip :: QC.Gen RelRefArgs
gen_rel_ref_round_trip = do
  ui   <- genUserInfo
  host <- genHost
  port <- QC.choose (1, 65535)
  path <- genPath
  pure RelRefArgs
    { rraUserInfo = ui
    , rraHost     = host
    , rraPort     = port
    , rraPath     = path
    }

------------------------------------------------------------------------------
-- gen_query_no_empty_pair
--
-- Random URI built around a query of 0-6 pairs, with a 50/50 trailing
-- ampersand. The trailing-ampersand bug surfaces whenever the gen lands
-- on (qaTrail = True ∧ pairs non-empty), which the discard predicate in
-- the property already filters appropriately.
------------------------------------------------------------------------------
gen_query_no_empty_pair :: QC.Gen QueryArgs
gen_query_no_empty_pair = do
  scheme <- genScheme
  host   <- genHost
  path   <- genPath
  pairs  <- genQueryPairs 6
  trail  <- QC.elements [True, False]
  pure QueryArgs
    { qaScheme = scheme
    , qaHost   = host
    , qaPath   = path
    , qaPairs  = pairs
    , qaTrail  = trail
    }

------------------------------------------------------------------------------
-- gen_normalize_root_path_kept
--
-- Property fixes uriPath="/" and uriQuery=∅ internally; the only free
-- variable is the host. Widen by drawing arbitrary parser-valid hosts
-- (1-3 dotted labels) instead of a single label.
------------------------------------------------------------------------------
gen_normalize_root_path_kept :: QC.Gen NormArgs
gen_normalize_root_path_kept = NormArgs <$> genHost
