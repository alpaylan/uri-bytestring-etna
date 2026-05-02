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

unreservedChars :: [Char]
unreservedChars = lowerAlpha ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ "-._~"

needsEncodingChars :: [Char]
needsEncodingChars = " <>[]\\^`{|}\""

genBs :: [Char] -> Int -> Int -> Gen ByteString
genBs cs lo hi = do
  s <- Gen.string (Range.linear lo hi) (Gen.element cs)
  pure (BS8.pack s)

genHost :: Gen ByteString
genHost = do
  l1 <- genBs lowerAlpha 1 6
  hasDot <- Gen.bool
  if hasDot
    then do
      l2 <- genBs lowerAlpha 1 4
      pure (l1 <> "." <> l2)
    else pure l1

genScheme :: Gen ByteString
genScheme = Gen.element ["http", "https", "ftp", "x"]

genPath :: Gen ByteString
genPath = do
  segs <- Gen.int (Range.linear 1 2)
  pieces <- traverse (\_ -> genBs lowerAlpha 1 5) [1 .. segs]
  pure ("/" <> BS8.intercalate "/" pieces)

genUserInfo :: Gen (Maybe (ByteString, ByteString))
genUserInfo = Gen.frequency
  [ (1, pure Nothing)
  , (1, do
        u <- genBs lowerAlpha 1 5
        p <- genBs lowerAlpha 0 5
        pure (Just (u, p)))
  ]

genFragment :: Gen (Maybe ByteString)
genFragment = Gen.frequency
  [ (1, pure Nothing)
  , (2, Just <$> genBs unreservedChars 0 6)
  , (1, do
        a <- genBs unreservedChars 1 3
        b <- genBs unreservedChars 0 3
        c <- Gen.element needsEncodingChars
        pure (Just (a <> BS8.singleton c <> b)))
  ]

------------------------------------------------------------------------------
-- gen_round_trip_uri
------------------------------------------------------------------------------
gen_round_trip_uri :: Gen UriArgs
gen_round_trip_uri = do
  scheme <- genScheme
  ui     <- genUserInfo
  host   <- genHost
  port   <- Gen.frequency
              [ (1, pure Nothing)
              , (1, Just <$> Gen.int (Range.linear 1 65535))
              ]
  path   <- genPath
  qPairs <- do
    n <- Gen.int (Range.linear 0 2)
    traverse
      (\_ -> do
          k <- genBs lowerAlpha 1 4
          v <- genBs unreservedChars 0 5
          pure (k, v))
      [1 .. n]
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
  n      <- Gen.int (Range.linear 1 3)
  pairs  <- traverse
    (\_ -> do
        k <- genBs lowerAlpha 1 4
        v <- genBs unreservedChars 0 4
        pure (k, v))
    [1 .. n]
  trail <- Gen.bool
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
