module Test.Controller.StaticSpec where

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
import Web.Controller.Static ()
import Web.FrontController ()
import Network.Wai
import IHP.ControllerPrelude

tests :: Spec
tests = beforeAll (mockContextNoDatabase WebApplication config) do
    describe "StaticController" do
        it "renders the welcome page" $ withContext do
            response <- callAction WelcomeAction
            response `responseStatusShouldBe` status200
            response `responseBodyShouldContain` "It's working!"
