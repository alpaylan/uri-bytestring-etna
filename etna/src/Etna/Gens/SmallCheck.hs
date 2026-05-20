{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
module Etna.Gens.SmallCheck where

import Data.ByteString (ByteString)
import qualified Test.SmallCheck.Series as SC

import Etna.Properties

-- SmallCheck enumerates the cross-product of every supplied list, so
-- the total test count is the product of all genX list lengths. We
-- supply a moderate menagerie that covers the bug-relevant subspaces
-- (port present/absent, userinfo present/absent, fragment with
-- pct-encoding-needing chars, root-only path, trailing ampersand)
-- without inflating the cross-product into seven figures.

scElement :: [a] -> SC.Series m a
scElement xs = SC.generate (\_ -> xs)

genHost :: Monad m => SC.Series m ByteString
genHost = scElement
  [ "a"
  , "ab.cd"
  , "Example.COM"
  , "host-1.io"
  ]

genScheme :: Monad m => SC.Series m ByteString
genScheme = scElement ["http", "https", "FILE"]

genPath :: Monad m => SC.Series m ByteString
genPath = scElement
  [ ""
  , "/"
  , "/p"
  , "/a/b"
  , "/x.y/z"
  ]

genUserInfo :: Monad m => SC.Series m (Maybe (ByteString, ByteString))
genUserInfo = scElement
  [ Nothing
  , Just ("u", "")
  , Just ("alice", "secret")
  , Just ("Bob1", "X-Y_Z")
  ]

-- Fragment menagerie spans clean, dotted, and pct-encoding-needing
-- variants so the fragment-encode bug surfaces as part of the
-- cross-product rather than being singled out by a hand-crafted entry.
genFragment :: Monad m => SC.Series m (Maybe ByteString)
genFragment = scElement
  [ Nothing
  , Just "frag"
  , Just "fr-ag.1"
  , Just "x y"        -- needs pct-encode
  , Just "{json}"     -- needs pct-encode
  ]

genQueryPairs :: Monad m => SC.Series m [(ByteString, ByteString)]
genQueryPairs = scElement
  [ []
  , [("a", "b")]
  , [("k1", "v1"), ("k2", "v2")]
  , [("name", "alice"), ("year", "2025")]
  ]

------------------------------------------------------------------------------
-- series_round_trip_uri
--
-- Exhaustive cross-product over moderate menageries of each component.
-- Total ≈ 3 schemes × 4 hosts × 5 paths × 4 userinfo × 5 ports × 4
-- queries × 5 fragments = 24,000 cases. Bug-trigger inputs (fragment
-- with pct-encoded chars, userinfo present, port present) appear as a
-- natural slice of the cross-product.
------------------------------------------------------------------------------
series_round_trip_uri :: Monad m => SC.Series m UriArgs
series_round_trip_uri = do
  scheme <- genScheme
  ui     <- genUserInfo
  host   <- genHost
  port   <- scElement [Nothing, Just 80, Just 443, Just 8080, Just 65535]
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
  port <- scElement [1, 80, 443, 8080, 65535]
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
  pairs  <- scElement
    [ [("a", "b")]
    , [("k", "v"), ("p", "q")]
    , [("a", "1"), ("b", "2"), ("c", "3")]
    ]
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
