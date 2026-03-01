module Main where

import IHP.Prelude
import Test.Hspec

import qualified Test.ConflictSpec
import qualified Test.Controller.AdminSpec
import qualified Test.Controller.DashboardSpec
import qualified Test.Controller.LeaveRequestsSpec
import qualified Test.Controller.ProfilesSpec
import qualified Test.Controller.RosterWeeksSpec
import qualified Test.Controller.SessionsSpec
import qualified Test.Controller.StaffSpec
import qualified Test.Controller.StaticSpec
import qualified Test.Controller.TimesheetsSpec
import qualified Test.Controller.UsersSpec
import qualified Test.RosterGridSpec
import qualified Test.SchemaSpec

main :: IO ()
main = hspec do
    Test.Controller.StaticSpec.tests
    Test.Controller.SessionsSpec.tests
    Test.Controller.UsersSpec.tests
    Test.Controller.AdminSpec.tests
    Test.Controller.DashboardSpec.tests
    Test.Controller.ProfilesSpec.tests
    Test.Controller.LeaveRequestsSpec.tests
    Test.Controller.StaffSpec.tests
    Test.Controller.TimesheetsSpec.tests
    Test.Controller.RosterWeeksSpec.tests
    Test.RosterGridSpec.tests
    Test.SchemaSpec.tests
    Test.ConflictSpec.tests
