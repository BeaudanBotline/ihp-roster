module Main where

import Test.Hspec
import IHP.Prelude

import qualified Test.Controller.StaticSpec

main :: IO ()
main = hspec do
    Test.Controller.StaticSpec.tests
