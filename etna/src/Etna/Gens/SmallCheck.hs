{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
module Etna.Gens.SmallCheck where

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS8
import qualified Test.SmallCheck.Series as SC

import Etna.Properties

-- SmallCheck enumerates structurally up to a bounded depth. The bug
-- inputs we care about all live at small depth: ports, the trailing
-- ampersand, the root-only path. Depth budgets in the runner default to
-- 5; these series saturate well within that.

scElement :: [a] -> SC.Series m a
scElement xs = SC.generate (\_ -> xs)

genHost :: Monad m => SC.Series m ByteString
genHost = scElement ["a", "ab.cd"]

genScheme :: Monad m => SC.Series m ByteString
genScheme = scElement ["http", "https"]

genPath :: Monad m => SC.Series m ByteString
genPath = scElement ["/p", "/a/b"]

genUserInfo :: Monad m => SC.Series m (Maybe (ByteString, ByteString))
genUserInfo = scElement
  [ Nothing
  , Just ("u", "p")
  , Just ("alice", "secret")
  ]

genFragment :: Monad m => SC.Series m (Maybe ByteString)
genFragment = scElement
  [ Nothing
  , Just "frag"
  , Just "x y"     -- triggers fragment_serialize_no_encode
  , Just "a<b"
  ]

genQueryPairs :: Monad m => SC.Series m [(ByteString, ByteString)]
genQueryPairs = scElement
  [ []
  , [("a", "b")]
  , [("k1", "v1"), ("k2", "v2")]
  ]

------------------------------------------------------------------------------
-- series_round_trip_uri
------------------------------------------------------------------------------
series_round_trip_uri :: Monad m => SC.Series m UriArgs
series_round_trip_uri = do
  scheme <- genScheme
  ui     <- genUserInfo
  host   <- genHost
  port   <- scElement [Nothing, Just 8080, Just 443]
  path   <- genPath
  qPairs <- genQueryPairs
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
-- series_rel_ref_round_trip
------------------------------------------------------------------------------
series_rel_ref_round_trip :: Monad m => SC.Series m RelRefArgs
series_rel_ref_round_trip = do
  ui   <- genUserInfo
  host <- genHost
  port <- scElement [80, 443, 8080]
  path <- genPath
  pure RelRefArgs
    { rraUserInfo = ui
    , rraHost     = host
    , rraPort     = port
    , rraPath     = path
    }

------------------------------------------------------------------------------
-- series_query_no_empty_pair
------------------------------------------------------------------------------
series_query_no_empty_pair :: Monad m => SC.Series m QueryArgs
series_query_no_empty_pair = do
  scheme <- genScheme
  host   <- genHost
  path   <- genPath
  pairs  <- scElement [[("a", "b")], [("k", "v"), ("p", "q")]]
  trail  <- scElement [True, False]
  pure QueryArgs
    { qaScheme = scheme
    , qaHost   = host
    , qaPath   = path
    , qaPairs  = pairs
    , qaTrail  = trail
    }

------------------------------------------------------------------------------
-- series_normalize_root_path_kept
------------------------------------------------------------------------------
series_normalize_root_path_kept :: Monad m => SC.Series m NormArgs
series_normalize_root_path_kept = NormArgs <$> genHost
