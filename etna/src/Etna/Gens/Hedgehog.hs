{-# LANGUAGE OverloadedStrings #-}
module Etna.Gens.Hedgehog where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS8
import           Hedgehog (Gen)
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Etna.Properties

lowerAlpha :: [Char]
lowerAlpha = ['a' .. 'z']

alphaNumChars :: [Char]
alphaNumChars = lowerAlpha ++ ['A' .. 'Z'] ++ ['0' .. '9']

unreservedChars :: [Char]
unreservedChars = alphaNumChars ++ "-._~"

subDelimsChars :: [Char]
subDelimsChars = "!$&'()*+,;="

pcharChars :: [Char]
pcharChars = unreservedChars ++ subDelimsChars ++ ":@"

wideAsciiChars :: [Char]
wideAsciiChars =
  unreservedChars ++ subDelimsChars ++ ":@/?" ++ " <>[]\\^`{|}\""

genBs :: [Char] -> Int -> Int -> Gen ByteString
genBs cs lo hi = do
  s <- Gen.string (Range.linear lo hi) (Gen.element cs)
  pure (BS8.pack s)

genHostLabel :: Gen ByteString
genHostLabel = do
  hd  <- Gen.element alphaNumChars
  rest <- genBs (alphaNumChars ++ "-") 0 11
  pure (BS8.cons hd rest)

genHost :: Gen ByteString
genHost = do
  numLabels <- Gen.int (Range.linear 1 3)
  labels    <- traverse (const genHostLabel) [1 .. numLabels]
  pure (BS8.intercalate "." labels)

genScheme :: Gen ByteString
genScheme = Gen.frequency
  [ (3, Gen.element ["http", "https", "ftp", "ssh", "file"])
  , (1, do
        hd  <- Gen.element (lowerAlpha ++ ['A' .. 'Z'])
        len <- Gen.int (Range.linear 0 5)
        rest <- traverse (const (Gen.element alphaNumChars)) [1 .. len]
        pure (BS8.pack (hd : rest)))
  ]

genPath :: Gen ByteString
genPath = Gen.frequency
  [ (1, pure "")
  , (1, pure "/")
  , (8, do
        n <- Gen.int (Range.linear 1 5)
        pieces <- traverse (const (genBs pcharChars 0 10)) [1 .. n]
        pure ("/" <> BS8.intercalate "/" pieces))
  ]

genUserInfo :: Gen (Maybe (ByteString, ByteString))
genUserInfo = Gen.frequency
  [ (2, pure Nothing)
  , (3, do
        u <- genBs unreservedChars 1 10
        p <- genBs unreservedChars 0 10
        pure (Just (u, p)))
  ]

genFragment :: Gen (Maybe ByteString)
genFragment = Gen.frequency
  [ (2, pure Nothing)
  , (3, Just <$> genBs unreservedChars 0 12)
  , (2, Just <$> genBs wideAsciiChars 1 12)
  ]

genQueryPairs :: Int -> Gen [(ByteString, ByteString)]
genQueryPairs maxN = do
  n <- Gen.int (Range.linear 0 maxN)
  traverse
    (const $ do
        k <- genBs unreservedChars 1 8
        v <- genBs (unreservedChars ++ "+") 0 10
        pure (k, v))
    [1 .. n]

------------------------------------------------------------------------------
-- gen_round_trip_uri
--
-- Random absolute URI: random scheme, host (1-3 dotted labels), random
-- userinfo (often present), random port (often present, full 16-bit
-- range), random multi-segment path, 0-6 query pairs, and a fragment
-- whose distribution sometimes draws from a wide ASCII pool. The
-- userinfo-missing-@, authority-missing-//, and fragment-no-encode bugs
-- surface organically when the random URI lands in their subspace.
------------------------------------------------------------------------------
gen_round_trip_uri :: Gen UriArgs
gen_round_trip_uri = do
  scheme <- genScheme
  ui     <- genUserInfo
  host   <- genHost
  port   <- Gen.frequency
              [ (1, pure Nothing)
              , (3, Just <$> Gen.int (Range.linear 1 65535))
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
------------------------------------------------------------------------------
gen_rel_ref_round_trip :: Gen RelRefArgs
gen_rel_ref_round_trip = do
  ui   <- genUserInfo
  host <- genHost
  port <- Gen.int (Range.linear 1 65535)
  path <- genPath
  pure RelRefArgs
    { rraUserInfo = ui
    , rraHost     = host
    , rraPort     = port
    , rraPath     = path
    }

------------------------------------------------------------------------------
-- gen_query_no_empty_pair
------------------------------------------------------------------------------
gen_query_no_empty_pair :: Gen QueryArgs
gen_query_no_empty_pair = do
  scheme <- genScheme
  host   <- genHost
  path   <- genPath
  pairs  <- genQueryPairs 6
  trail  <- Gen.bool
  pure QueryArgs
    { qaScheme = scheme
    , qaHost   = host
    , qaPath   = path
    , qaPairs  = pairs
    , qaTrail  = trail
    }

------------------------------------------------------------------------------
-- gen_normalize_root_path_kept
------------------------------------------------------------------------------
gen_normalize_root_path_kept :: Gen NormArgs
gen_normalize_root_path_kept = NormArgs <$> genHost
