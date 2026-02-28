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
        it "renders the welcome page for unauthenticated users" $ withContext do
            response <- callAction WelcomeAction
            response `responseStatusShouldBe` status200
            response `responseBodyShouldContain` "Sign In"
            response `responseBodyShouldContain` "Create Account"

        it "redirects authenticated users to the roster week view" $ withContext do
            pendingWith "requires real DB-backed mockContext to exercise withUser + initAuthentication"
