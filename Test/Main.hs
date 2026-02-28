module Main where

import IHP.Prelude
import Test.Hspec

import qualified Test.ConflictSpec
import qualified Test.Controller.DashboardSpec
import qualified Test.Controller.ProfilesSpec
import qualified Test.Controller.RosterWeeksSpec
import qualified Test.Controller.SessionsSpec
import qualified Test.Controller.StaffSpec
import qualified Test.Controller.StaticSpec
import qualified Test.Controller.UsersSpec
import qualified Test.SchemaSpec

main :: IO ()
main = hspec do
    Test.Controller.StaticSpec.tests
    Test.Controller.SessionsSpec.tests
    Test.Controller.UsersSpec.tests
    Test.Controller.DashboardSpec.tests
    Test.Controller.ProfilesSpec.tests
    Test.Controller.StaffSpec.tests
    Test.Controller.RosterWeeksSpec.tests
    Test.SchemaSpec.tests
    Test.ConflictSpec.tests
