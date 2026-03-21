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
import Test.Support
import Web.Controller.Profiles ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll testContext do
    describe "ProfilesController" do
        it "redirects unauthenticated users away from edit profile" $ withContext do
            response <- callAction EditProfileAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users away from update profile" $ withContext do
            response <- callActionWithParams UpdateProfileAction [("firstName", "Taylor"), ("lastName", "Smith")]
            response `responseStatusShouldBe` status302

        it "renders the profile form as a native submit form" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Profile Venue"
                user <- createUserRecord "profile-native-submit@example.com" "staff" True
                _ <- createVenueMembershipRecord venue user "worker"
                _ <- createStaffRecord venue (Just user) "Taylor" "Smith"

                response <- withUserAndCurrentVenue user venue.id do
                    callAction EditProfileAction

                response `responseStatusShouldBe` status200
                response `responseBodyShouldContain` "data-disable-javascript-submission=\"true\""
