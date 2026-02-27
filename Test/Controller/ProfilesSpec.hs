module Test.Controller.ProfilesSpec where

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
import Web.Controller.Profiles ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll (mockContextNoDatabase WebApplication config) do
    describe "ProfilesController" do
        it "redirects unauthenticated users away from edit profile" $ withContext do
            response <- callAction EditProfileAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users away from update profile" $ withContext do
            response <- callActionWithParams UpdateProfileAction [("firstName", "Taylor"), ("lastName", "Smith")]
            response `responseStatusShouldBe` status302
