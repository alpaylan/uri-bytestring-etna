{-# LANGUAGE OverloadedStrings #-}
module Etna.Gens.QuickCheck where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS8
import qualified Test.QuickCheck as QC

import Etna.Properties

-- | Lowercase ASCII letters used everywhere — strict-mode parser-safe.
lowerAlpha :: [Char]
lowerAlpha = ['a' .. 'z']

unreservedChars :: [Char]
unreservedChars = lowerAlpha ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ "-._~"

-- | Characters that are *not* pchar and so force url-encoding when
-- placed in a fragment. Triggers fragment_serialize_no_encode.
needsEncodingChars :: [Char]
needsEncodingChars = " <>[]\\^`{|}\""

-- | Generate a short bytestring drawn from a character class.
genBs :: [Char] -> Int -> Int -> QC.Gen ByteString
genBs cs lo hi = do
  n <- QC.choose (lo, hi)
  cs' <- QC.vectorOf n (QC.elements cs)
  pure (BS8.pack cs')

genHost :: QC.Gen ByteString
genHost = do
  -- e.g. "abc.de"
  l1 <- genBs lowerAlpha 1 6
  hasDot <- QC.elements [True, False]
  if hasDot
    then do
      l2 <- genBs lowerAlpha 1 4
      pure (l1 <> "." <> l2)
    else pure l1

genScheme :: QC.Gen ByteString
genScheme = QC.elements ["http", "https", "ftp", "x"]

genPath :: QC.Gen ByteString
genPath = do
  -- always begins with '/'; one or two segments
  segs <- QC.choose (1 :: Int, 2)
  pieces <- QC.vectorOf segs (genBs lowerAlpha 1 5)
  pure ("/" <> BS8.intercalate "/" pieces)

genUserInfo :: QC.Gen (Maybe (ByteString, ByteString))
genUserInfo = QC.frequency
  [ (1, pure Nothing)
  , (1, do
        u <- genBs lowerAlpha 1 5
        p <- genBs lowerAlpha 0 5
        pure (Just (u, p)))
  ]

genFragment :: QC.Gen (Maybe ByteString)
genFragment = QC.frequency
  [ (1, pure Nothing)
  , (2, Just <$> genBs unreservedChars 0 6)
  , (1, do                                   -- triggers variant 4
        a <- genBs unreservedChars 1 3
        b <- genBs unreservedChars 0 3
        c <- QC.elements needsEncodingChars
        pure (Just (a <> BS8.singleton c <> b)))
  ]

------------------------------------------------------------------------------
-- gen_round_trip_uri
------------------------------------------------------------------------------
gen_round_trip_uri :: QC.Gen UriArgs
gen_round_trip_uri = do
  scheme <- genScheme
  ui     <- genUserInfo
  host   <- genHost
  port   <- QC.frequency
              [ (1, pure Nothing)
              , (1, Just <$> QC.choose (1, 65535))
              ]
  path   <- genPath
  qPairs <- do
    n <- QC.choose (0 :: Int, 2)
    QC.vectorOf n $ do
      k <- genBs lowerAlpha 1 4
      v <- genBs unreservedChars 0 5
      pure (k, v)
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
------------------------------------------------------------------------------
gen_query_no_empty_pair :: QC.Gen QueryArgs
gen_query_no_empty_pair = do
  scheme <- genScheme
  host   <- genHost
  path   <- genPath
  n      <- QC.choose (1 :: Int, 3)
  pairs  <- QC.vectorOf n $ do
    k <- genBs lowerAlpha 1 4
    v <- genBs unreservedChars 0 4
    pure (k, v)
  trail <- QC.elements [True, False]
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
gen_normalize_root_path_kept :: QC.Gen NormArgs
gen_normalize_root_path_kept = NormArgs <$> genHost
