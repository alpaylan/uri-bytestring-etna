{-# LANGUAGE OverloadedStrings #-}
module Etna.Gens.Falsify where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS8
import           Data.List.NonEmpty (NonEmpty(..))
import qualified Test.Falsify.Generator as F
import qualified Test.Falsify.Range as FR

import Etna.Properties

ne :: [a] -> NonEmpty a
ne []     = error "Etna.Gens.Falsify.ne: empty list"
ne (x:xs) = x :| xs

lowerAlpha :: NonEmpty Char
lowerAlpha = ne ['a' .. 'z']

alphaNumChars :: NonEmpty Char
alphaNumChars = ne (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'])

unreservedChars :: NonEmpty Char
unreservedChars = ne (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ "-._~")

subDelimsChars :: NonEmpty Char
subDelimsChars = ne "!$&'()*+,;="

pcharChars :: NonEmpty Char
pcharChars =
  ne (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9']
       ++ "-._~" ++ "!$&'()*+,;=" ++ ":@")

wideAsciiChars :: NonEmpty Char
wideAsciiChars =
  ne (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9']
       ++ "-._~" ++ "!$&'()*+,;=" ++ ":@/?"
       ++ " <>[]\\^`{|}\"")

alphaNumPlusHyphen :: NonEmpty Char
alphaNumPlusHyphen = ne (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ "-")

unreservedPlusPlus :: NonEmpty Char
unreservedPlusPlus = ne (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ "-._~+")

upperAlpha :: NonEmpty Char
upperAlpha = ne (['a' .. 'z'] ++ ['A' .. 'Z'])

genBs :: NonEmpty Char -> Word -> Word -> F.Gen ByteString
genBs cs lo hi = do
  s <- F.list (FR.between (lo, hi)) (F.elem cs)
  pure (BS8.pack s)

genHostLabel :: F.Gen ByteString
genHostLabel = do
  hd  <- F.elem alphaNumChars
  rest <- genBs alphaNumPlusHyphen 0 11
  pure (BS8.cons hd rest)

genHost :: F.Gen ByteString
genHost = do
  numLabels <- F.inRange (FR.between (1 :: Int, 3))
  labels    <- traverse (const genHostLabel) [1 .. numLabels]
  pure (BS8.intercalate "." labels)

genScheme :: F.Gen ByteString
genScheme = do
  pick <- F.inRange (FR.between (0 :: Int, 3))
  case pick of
    0 -> F.elem (ne ["http", "https", "ftp", "ssh", "file"])
    1 -> F.elem (ne ["http", "https", "ftp", "ssh", "file"])
    2 -> F.elem (ne ["http", "https", "ftp", "ssh", "file"])
    _ -> do
        hd  <- F.elem upperAlpha
        len <- F.inRange (FR.between (0 :: Word, 5))
        rest <- F.list (FR.between (len, len)) (F.elem alphaNumChars)
        pure (BS8.pack (hd : rest))

genPath :: F.Gen ByteString
genPath = do
  pick <- F.inRange (FR.between (0 :: Int, 9))
  case pick of
    0 -> pure ""
    1 -> pure "/"
    _ -> do
      n <- F.inRange (FR.between (1 :: Int, 5))
      pieces <- traverse (const (genBs pcharChars 0 10)) [1 .. n]
      pure ("/" <> BS8.intercalate "/" pieces)

genUserInfo :: F.Gen (Maybe (ByteString, ByteString))
genUserInfo = do
  pick <- F.inRange (FR.between (0 :: Int, 4))
  case pick of
    0 -> pure Nothing
    1 -> pure Nothing
    _ -> do
      u <- genBs unreservedChars 1 10
      p <- genBs unreservedChars 0 10
      pure (Just (u, p))

genFragment :: F.Gen (Maybe ByteString)
genFragment = do
  pick <- F.inRange (FR.between (0 :: Int, 6))
  case pick of
    0 -> pure Nothing
    1 -> pure Nothing
    2 -> Just <$> genBs unreservedChars 0 12
    3 -> Just <$> genBs unreservedChars 0 12
    4 -> Just <$> genBs unreservedChars 0 12
    _ -> Just <$> genBs wideAsciiChars 1 12

genQueryPairs :: Word -> F.Gen [(ByteString, ByteString)]
genQueryPairs maxN = do
  n <- F.inRange (FR.between (0, maxN))
  traverse
    (const $ do
        k <- genBs unreservedChars 1 8
        v <- genBs unreservedPlusPlus 0 10
        pure (k, v))
    [1 .. n]

------------------------------------------------------------------------------
-- gen_round_trip_uri
--
-- Random absolute URI: random scheme, host (1-3 dotted labels), random
-- userinfo (often present), random port (often present, full 16-bit
-- range), random multi-segment path, 0-6 query pairs, and a fragment
-- whose distribution sometimes draws from a wide ASCII pool that
-- contains pct-encoding-required characters.
------------------------------------------------------------------------------
gen_round_trip_uri :: F.Gen UriArgs
gen_round_trip_uri = do
  scheme <- genScheme
  ui     <- genUserInfo
  host   <- genHost
  hasPort <- do
    p <- F.inRange (FR.between (0 :: Int, 3))
    pure (p /= 0)
  port   <- if hasPort
              then Just <$> F.inRange (FR.between (1 :: Int, 65535))
              else pure Nothing
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
gen_rel_ref_round_trip :: F.Gen RelRefArgs
gen_rel_ref_round_trip = do
  ui   <- genUserInfo
  host <- genHost
  port <- F.inRange (FR.between (1 :: Int, 65535))
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
gen_query_no_empty_pair :: F.Gen QueryArgs
gen_query_no_empty_pair = do
  scheme <- genScheme
  host   <- genHost
  path   <- genPath
  pairs  <- genQueryPairs 6
  trail  <- F.bool True
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
gen_normalize_root_path_kept :: F.Gen NormArgs
gen_normalize_root_path_kept = NormArgs <$> genHost
