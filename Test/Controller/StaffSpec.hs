module Test.Controller.StaffSpec where

import Config
import Generated.Types
import IHP.ControllerPrelude
import IHP.FrameworkConfig
import IHP.HaskellSupport
import IHP.Prelude
import IHP.Test.Mocking
import Network.HTTP.Types.Status
import Network.Wai
import Test.Hspec
import Web.Controller.Staff ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll (mockContextNoDatabase WebApplication config) do
    describe "StaffController" do
        let sampleStaffId = Id "6f9638dc-f13c-4ed3-b4f1-a2f860532cab"
        it "redirects unauthenticated users from edit staff form" $ withContext do
            response <- callActionWithParams (EditStaffAction sampleStaffId) [("weekOffset", "7")]
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from update staff" $ withContext do
            response <- callActionWithParams (UpdateStaffAction sampleStaffId)
                [("firstName", "Test"), ("lastName", "User"), ("weekOffset", "7")]
            response `responseStatusShouldBe` status302
