module Test.Controller.StaticSpec where

import Network.HTTP.Types.Status

import Config
import IHP.FrameworkConfig
import IHP.HaskellSupport
import IHP.Prelude
import IHP.Test.Mocking
import Test.Hspec

import Generated.Types
import IHP.ControllerPrelude
import Network.Wai
import Web.Controller.Static ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll (mockContextNoDatabase WebApplication config) do
    describe "StaticController" do
        it "renders the welcome page" $ withContext do
            response <- callAction WelcomeAction
            response `responseStatusShouldBe` status200
            response `responseBodyShouldContain` "Sign In"
            response `responseBodyShouldContain` "Create Account"
