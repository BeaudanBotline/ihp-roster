module Test.Controller.UsersSpec where

import Network.HTTP.Types.Status
import IHP.Prelude
import IHP.Test.Mocking
import IHP.FrameworkConfig
import IHP.HaskellSupport
import Test.Hspec
import Config
import Generated.Types
import Web.Routes
import Web.Types
import Web.Controller.Users ()
import Web.FrontController ()
import Network.Wai
import IHP.ControllerPrelude

tests :: Spec
tests = beforeAll (mockContextNoDatabase WebApplication config) do
    describe "UsersController" do
        it "renders the registration form" $ withContext do
            response <- callAction NewUserAction
            response `responseStatusShouldBe` status200
            response `responseBodyShouldContain` "Create Account"
            response `responseBodyShouldContain` "Sign in"
