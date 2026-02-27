module Web.Controller.RosterWeeks where

import Application.Helper.Controller
import Data.Coerce (coerce)
import Data.Time (addDays, diffDays, getCurrentTime, utctDay)
import qualified Data.Time.Calendar as Calendar
import Web.Controller.Prelude
import Web.View.RosterWeeks.Show

instance Controller RosterWeeksController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted

    action RosterWeeksAction = do
        -- Redirect to the current week's offset based on today's date
        now <- liftIO getCurrentTime
        venueConfig <- fetchVenueConfig

        let today = utctDay now
        let epoch = venueConfig.weekOffsetEpoch
        let daysSinceEpoch = diffDays today epoch
        let currentWeekOffset = fromIntegral (daysSinceEpoch `div` 7)

        redirectTo ShowRosterWeekAction { weekOffset = currentWeekOffset }

    action ShowRosterWeekAction { weekOffset } = do
        venueConfig <- fetchVenueConfig
        let epoch = venueConfig.weekOffsetEpoch
        let weekStartDate = addDays (toInteger (weekOffset * 7)) epoch
        let weekEndDate = addDays 6 weekStartDate

        -- Try to fetch the roster week from the database
        rosterWeekOrNothing <- query @RosterWeek
            |> filterWhere (#weekOffset, weekOffset)
            |> fetchOneOrNothing

        case rosterWeekOrNothing of
            Just rosterWeek -> do
                -- We found it, render the week view
                rosterDays <- query @RosterDay
                    |> filterWhere (#rosterWeekId, coerce rosterWeek.id)
                    |> fetch
                render ShowView { rosterWeek = Just rosterWeek, rosterDays, weekOffset, weekStartDate, weekEndDate }
            Nothing -> do
                -- It doesn't exist yet, show the "Create" view/button
                render ShowView { rosterWeek = Nothing, rosterDays = [], weekOffset, weekStartDate, weekEndDate }

    action CreateRosterWeekAction { weekOffset } = do
        ensureManagerRole

        -- Make sure it doesn't already exist
        existing <- query @RosterWeek |> filterWhere (#weekOffset, weekOffset) |> fetchOneOrNothing
        case existing of
            Just week -> do
                redirectTo ShowRosterWeekAction { weekOffset = week.weekOffset }
            Nothing -> do
                -- Create the roster week
                rosterWeek <- newRecord @RosterWeek
                    |> set #weekOffset weekOffset
                    |> set #isLive False
                    |> createRecord

                -- Create 7 roster days for the week
                forM_ [0..6] \dayOffset -> do
                    newRecord @RosterDay
                        |> set #rosterWeekId (coerce rosterWeek.id)
                        |> set #dayOffset dayOffset
                        |> createRecord

                setSuccessMessage "Roster week created successfully"
                redirectTo ShowRosterWeekAction { weekOffset }

    action PublishRosterWeekAction { rosterWeekId } = do
        ensureManagerRole
        rosterWeek <- fetch rosterWeekId
        rosterWeek
            |> set #isLive True
            |> updateRecord

        setSuccessMessage "Roster week published successfully"
        redirectTo ShowRosterWeekAction { weekOffset = rosterWeek.weekOffset }

