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
        it "redirects unauthenticated users from staff list" $ withContext do
            response <- callAction StaffAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from new staff form" $ withContext do
            response <- callAction NewStaffAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from create staff" $ withContext do
            response <- callActionWithParams CreateStaffAction
                [("firstName", "Test"), ("lastName", "User")]
            response `responseStatusShouldBe` status302
