module Main where

import Etna.Result (PropertyResult(..))
import Etna.Witnesses
  ( witness_round_trip_uri_case_userinfo
  , witness_round_trip_uri_case_fragment_special
  , witness_rel_ref_round_trip_case_with_port
  , witness_rel_ref_round_trip_case_double_slash
  , witness_query_no_empty_pair_case_trailing_amp
  , witness_normalize_root_path_kept_case_root_with_query
  )
import System.Exit (exitFailure, exitSuccess)

cases :: [(String, PropertyResult)]
cases =
  [ ("witness_round_trip_uri_case_userinfo",         witness_round_trip_uri_case_userinfo)
  , ("witness_round_trip_uri_case_fragment_special", witness_round_trip_uri_case_fragment_special)
  , ("witness_rel_ref_round_trip_case_with_port",    witness_rel_ref_round_trip_case_with_port)
  , ("witness_rel_ref_round_trip_case_double_slash", witness_rel_ref_round_trip_case_double_slash)
  , ("witness_query_no_empty_pair_case_trailing_amp",
       witness_query_no_empty_pair_case_trailing_amp)
  , ("witness_normalize_root_path_kept_case_root_with_query",
       witness_normalize_root_path_kept_case_root_with_query)
  ]

main :: IO ()
main = do
  let failures =
        [ (n, msg) | (n, Fail msg) <- cases ] ++
        [ (n, "discard") | (n, Discard) <- cases ]
  if null failures
    then do
      putStrLn $ "OK: all " ++ show (length cases) ++ " witnesses passed"
      exitSuccess
    else do
      mapM_ (\(n, m) -> putStrLn (n ++ ": FAIL: " ++ m)) failures
      exitFailure
