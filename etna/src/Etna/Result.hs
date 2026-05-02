module Etna.Result (PropertyResult(..)) where

data PropertyResult
  = Pass
  | Fail !String
  | Discard
  deriving (Show, Eq)
