module Test.Controller.AdminSpec where

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
import Web.Controller.Admin ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll (mockContextNoDatabase WebApplication config) do
    describe "AdminController" do
        it "redirects unauthenticated users from admin page" $ withContext do
            response <- callAction AdminAction
            response `responseStatusShouldBe` status302
