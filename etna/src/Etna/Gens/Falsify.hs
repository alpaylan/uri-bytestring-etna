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

unreservedChars :: NonEmpty Char
unreservedChars = ne (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ "-._~")

needsEncodingChars :: NonEmpty Char
needsEncodingChars = ne " <>[]\\^`{|}\""

genBs :: NonEmpty Char -> Word -> Word -> F.Gen ByteString
genBs cs lo hi = do
  s <- F.list (FR.between (lo, hi)) (F.elem cs)
  pure (BS8.pack s)

genHost :: F.Gen ByteString
genHost = do
  l1 <- genBs lowerAlpha 1 6
  hasDot <- F.bool True
  if hasDot
    then do
      l2 <- genBs lowerAlpha 1 4
      pure (l1 <> "." <> l2)
    else pure l1

genScheme :: F.Gen ByteString
genScheme = F.elem (ne ["http", "https", "ftp", "x"])

genPath :: F.Gen ByteString
genPath = do
  segs <- F.inRange (FR.between (1 :: Int, 2))
  pieces <- traverse (\_ -> genBs lowerAlpha 1 5) [1 .. segs]
  pure ("/" <> BS8.intercalate "/" pieces)

genUserInfo :: F.Gen (Maybe (ByteString, ByteString))
genUserInfo = do
  hasIt <- F.bool True
  if hasIt
    then do
      u <- genBs lowerAlpha 1 5
      p <- genBs lowerAlpha 0 5
      pure (Just (u, p))
    else pure Nothing

genFragment :: F.Gen (Maybe ByteString)
genFragment = do
  -- 0=Nothing, 1=normal unreserved, 2=with bug-trigger char
  pick <- F.inRange (FR.between (0 :: Int, 3))
  case pick of
    0 -> pure Nothing
    1 -> Just <$> genBs unreservedChars 0 6
    2 -> Just <$> genBs unreservedChars 0 6
    _ -> do
      a <- genBs unreservedChars 1 3
      b <- genBs unreservedChars 0 3
      c <- F.elem needsEncodingChars
      pure (Just (a <> BS8.singleton c <> b))

------------------------------------------------------------------------------
-- gen_round_trip_uri
------------------------------------------------------------------------------
gen_round_trip_uri :: F.Gen UriArgs
gen_round_trip_uri = do
  scheme <- genScheme
  ui     <- genUserInfo
  host   <- genHost
  hasPort <- F.bool True
  port   <- if hasPort
              then Just <$> F.inRange (FR.between (1 :: Int, 65535))
              else pure Nothing
  path   <- genPath
  n      <- F.inRange (FR.between (0 :: Int, 2))
  qPairs <- traverse
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
  n      <- F.inRange (FR.between (1 :: Int, 3))
  pairs  <- traverse
    (\_ -> do
        k <- genBs lowerAlpha 1 4
        v <- genBs unreservedChars 0 4
        pure (k, v))
    [1 .. n]
  trail <- F.bool True
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
