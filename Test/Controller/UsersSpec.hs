module Test.Controller.UsersSpec where

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
import Web.Controller.Users ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll (mockContextNoDatabase WebApplication config) do
    describe "UsersController" do
        it "renders the registration form" $ withContext do
            response <- callAction NewUserAction
            response `responseStatusShouldBe` status200
            response `responseBodyShouldContain` "Create Account"
            response `responseBodyShouldContain` "Sign in"
